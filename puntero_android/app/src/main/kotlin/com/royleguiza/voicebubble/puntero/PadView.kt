package com.royleguiza.voicebubble.puntero

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import kotlin.math.roundToInt

/**
 * Superficie del trackpad, como el prototipo HTML: una sola placa lisa (sin
 * botones ni grilla) con una guía fina a la derecha para desplazar.
 *
 * - Deslizar: mueve el puntero.
 * - Tocar: clic. Mantener: clic largo (se hace al soltar).
 * - Dos dedos o la guía de la derecha: desplazar la página (al soltar).
 *
 * Android cancela los gestos inyectados mientras haya un dedo real apoyado,
 * así que todo se despacha al levantar el dedo.
 *
 * Los gestos los clasifica [PadGestures] (lógica pura, testeada en JVM).
 */
@SuppressLint("ViewConstructor")
internal class PadView(
    context: Context,
    private val palette: Palette,
    private val naturalScroll: Boolean,
    private val haptic: String,
    private val listener: Listener,
) : View(context) {

    interface Listener {
        fun onMove(dx: Float, dy: Float)
        fun onTap()
        fun onLongPress()

        /** Se mantuvo apretado: el clic largo quedó armado (se hace al soltar). */
        fun onLongPressArmed()

        /** [gestureDy]: recorrido vertical del gesto de scroll a despachar. */
        fun onScroll(gestureDy: Float)
    }

    private val d = resources.displayMetrics.density
    private val gestures = PadGestures(slopPx = 6f * d)

    private val padRadius = 22f * d
    private val railW = 24f * d
    private val railInset = 10f * d
    private val thumbH = 34f * d

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f * d
    }
    private val hintPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 13f * d
        typeface = Fonts.inter(context)
    }
    private var hintText = DEFAULT_HINT
    private var hintSticky = false
    private var hintLayout: StaticLayout? = null
    private var hintAlpha = 1f
    private var hintAnim: ValueAnimator? = null
    private var touchTint = 0f
    private var tintAnim: ValueAnimator? = null
    private var thumbOffset = 0f
    private var thumbAnim: ValueAnimator? = null
    private val rect = RectF()

    private enum class Mode { NONE, PAD, RAIL }

    private var mode = Mode.NONE
    private var railLastY = 0f
    private var railDownY = 0f

    /** Scroll juntado durante el toque; se manda al soltar. */
    private var pendingScroll = 0f

    private val longPressCheck = Runnable {
        if (gestures.longPressDue(SystemClock.uptimeMillis()) != null) {
            performPadHaptic(isFirm = true)
            listener.onLongPressArmed()
        }
    }

    companion object {
        const val DEFAULT_HINT = "Deslizá para mover · Tocá para hacer clic"
    }

    init {
        contentDescription = "Superficie del trackpad. Deslizá para mover el puntero, tocá para hacer clic."
        isHapticFeedbackEnabled = haptic != PointerProtocol.HAPTIC_NONE
    }

    /**
     * Cambia el texto guía (p. ej. los pasos del arrastre). Con [sticky] no se
     * desvanece al mover: es una instrucción que hay que poder releer.
     */
    fun setHint(text: String, sticky: Boolean = false) {
        hintAnim?.cancel()
        hintText = text
        hintSticky = sticky
        hintLayout = null
        hintAlpha = 1f
        invalidate()
    }

    /** Vibración corta; el sistema decide si está habilitada («vibración al tocar»). */
    private fun performPadHaptic(isFirm: Boolean) {
        if (haptic == PointerProtocol.HAPTIC_NONE) return
        val firm = isFirm || haptic == PointerProtocol.HAPTIC_FIRM
        performHapticFeedback(if (firm) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.KEYBOARD_TAP)
    }

    private fun flushScroll() {
        val total = pendingScroll
        pendingScroll = 0f
        if (total != 0f) listener.onScroll(total)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        hintLayout = null
    }

    private fun hint(): StaticLayout? {
        hintLayout?.let { return it }
        val avail = (width - 2 * railW - 16 * d).toInt()
        if (avail <= 0) return null
        return StaticLayout.Builder.obtain(hintText, 0, hintText.length, hintPaint, avail)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(2f * d, 1f)
            .build()
            .also { hintLayout = it }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        rect.set(0f, 0f, w, h)

        fill.color = blend(palette.surf2, palette.ember, 0.06f * touchTint)
        canvas.drawRoundRect(rect, padRadius, padRadius, fill)
        stroke.color = palette.line
        rect.inset(stroke.strokeWidth / 2, stroke.strokeWidth / 2)
        canvas.drawRoundRect(rect, padRadius, padRadius, stroke)

        if (hintAlpha > 0f) {
            hint()?.let { layout ->
                hintPaint.color = palette.fg2
                hintPaint.alpha = (255 * hintAlpha).roundToInt()
                canvas.save()
                canvas.translate((w - layout.width) / 2f, (h - layout.height) / 2f)
                layout.draw(canvas)
                canvas.restore()
            }
        }

        // Guía de desplazamiento: línea fina + pastilla que sigue al dedo.
        val trackX = w - 9f * d - 1.5f * d
        fill.color = withAlpha(palette.fg2, 0.16f)
        rect.set(trackX - 1.5f * d, railInset, trackX + 1.5f * d, h - railInset)
        canvas.drawRoundRect(rect, 1.5f * d, 1.5f * d, fill)
        val travel = (h - 2 * railInset - thumbH) / 2f
        val cy = h / 2f + thumbOffset.coerceIn(-travel, travel)
        fill.color = withAlpha(palette.fg2, if (mode == Mode.RAIL) 0.85f else 0.55f)
        rect.set(trackX - 2.5f * d, cy - thumbH / 2, trackX + 2.5f * d, cy + thumbH / 2)
        canvas.drawRoundRect(rect, 2.5f * d, 2.5f * d, fill)
    }

    private fun fadeHint() {
        if (hintSticky || hintAlpha < 1f) return
        hintAnim = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = 400L
            addUpdateListener {
                hintAlpha = it.animatedValue as Float
                invalidate()
            }
            start()
        }
        hintAlpha = 0.999f
    }

    private fun setTouching(on: Boolean) {
        tintAnim?.cancel()
        tintAnim = ValueAnimator.ofFloat(touchTint, if (on) 1f else 0f).apply {
            duration = 200L
            addUpdateListener {
                touchTint = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    private fun springThumb() {
        thumbAnim?.cancel()
        thumbAnim = ValueAnimator.ofFloat(thumbOffset, 0f).apply {
            duration = 260L
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                thumbOffset = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        val now = SystemClock.uptimeMillis()
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                pendingScroll = 0f
                if (e.x >= width - railW) {
                    mode = Mode.RAIL
                    railLastY = e.y
                    railDownY = e.y
                    invalidate()
                } else {
                    mode = Mode.PAD
                    gestures.down(e.x, e.y, now)
                    setTouching(true)
                    removeCallbacks(longPressCheck)
                    postDelayed(longPressCheck, PadGestures.LONG_PRESS_MS)
                }
            }
            MotionEvent.ACTION_POINTER_DOWN -> {
                if (mode == Mode.PAD) removeCallbacks(longPressCheck)
            }
            MotionEvent.ACTION_MOVE -> when (mode) {
                Mode.RAIL -> {
                    val dy = e.y - railLastY
                    railLastY = e.y
                    thumbOffset = e.y - railDownY
                    invalidate()
                    if (dy != 0f) {
                        fadeHint()
                        pendingScroll += PadGestures.railDelta(dy)
                    }
                }
                Mode.PAD -> {
                    val count = e.pointerCount
                    var sum = 0f
                    for (i in 0 until count) sum += e.getY(i)
                    // Con un dedo se sigue al que quedó apoyado (índice 0 tras levantar otro).
                    when (val a = gestures.move(e.getX(0), e.getY(0), count, sum / count)) {
                        is PadGestures.Action.Move -> {
                            removeCallbacks(longPressCheck)
                            fadeHint()
                            listener.onMove(a.dx, a.dy)
                        }
                        is PadGestures.Action.Scroll -> {
                            removeCallbacks(longPressCheck)
                            fadeHint()
                            pendingScroll += PadGestures.scrollDelta(a.fingerDy, naturalScroll)
                        }
                        else -> {}
                    }
                }
                Mode.NONE -> {}
            }
            MotionEvent.ACTION_UP -> {
                removeCallbacks(longPressCheck)
                if (mode == Mode.PAD) {
                    when (gestures.up(now)) {
                        PadGestures.Action.Tap -> {
                            performPadHaptic(isFirm = false)
                            listener.onTap()
                        }
                        PadGestures.Action.LongPress -> listener.onLongPress()
                        else -> {}
                    }
                    setTouching(false)
                } else if (mode == Mode.RAIL) {
                    springThumb()
                }
                mode = Mode.NONE
                flushScroll()
            }
            MotionEvent.ACTION_CANCEL -> {
                removeCallbacks(longPressCheck)
                gestures.cancel()
                pendingScroll = 0f
                if (mode == Mode.PAD) setTouching(false) else if (mode == Mode.RAIL) springThumb()
                mode = Mode.NONE
            }
        }
        return true
    }

    /** Corta animaciones y el temporizador del clic largo (al sacar la ventana). */
    fun release() {
        removeCallbacks(longPressCheck)
        hintAnim?.cancel()
        tintAnim?.cancel()
        thumbAnim?.cancel()
    }

    override fun onDetachedFromWindow() {
        release()
        super.onDetachedFromWindow()
    }

    private fun withAlpha(color: Int, alpha: Float): Int =
        (color and 0x00FFFFFF) or ((alpha * 255).roundToInt() shl 24)

    private fun blend(from: Int, to: Int, t: Float): Int {
        fun ch(shift: Int) = (((from ushr shift) and 0xFF) * (1 - t) + ((to ushr shift) and 0xFF) * t).roundToInt()
        return (0xFF shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }
}
