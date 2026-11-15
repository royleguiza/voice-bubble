package com.royleguiza.voicebubble.puntero

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator

/**
 * Puntero virtual: ventana TYPE_ACCESSIBILITY_OVERLAY (queda por encima de la
 * barra de estado, la cortina y los diálogos del sistema) que nunca recibe
 * toques ni foco.
 *
 * Coordenadas: [posX]/[posY] son la PUNTA del puntero en pantalla completa. La
 * ventana es chica y se mueve con él; [getPosition] lee dónde quedó dibujada de
 * verdad, así el clic cae justo en la punta que se ve. Como la ventana es de
 * Accesibilidad (de confianza) ya no hay que correrla de la punta ni
 * apartarla durante el gesto: la punta dibujada ES el punto del clic.
 *
 * Además dibuja, en otra ventana igual, el anillo fijo del origen del
 * arrastre en dos pasos ([setOrigin] / [clearOrigin]).
 *
 * REGLA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas.
 */
internal class PointerOverlay(
    context: Context,
    private val windowManager: WindowManager,
    private val screen: ScreenProbe,
) {
    private val density = context.resources.displayMetrics.density

    /** Distancia de la esquina de la ventana a la punta (deja lugar al anillo del clic). */
    private val hotPx = (HOT_DP * density).toInt()
    private val windowPx = (WINDOW_DP * density).toInt()

    private val pointerView = PointerView(context, hotPx.toFloat())
    private val markView = OriginMarkView(context, hotPx.toFloat())
    private var pointerAttached = false
    private var markAttached = false
    private var visible = false

    private var screenWidth = context.resources.displayMetrics.widthPixels
    private var screenHeight = context.resources.displayMetrics.heightPixels

    // Punta del puntero, en coordenadas de pantalla completa.
    var posX = screenWidth / 2f
        private set
    var posY = screenHeight / 3f
        private set

    var sensitivity: Float = PointerProtocol.DEFAULT_SENSITIVITY
    var accelCurve: String = PointerProtocol.ACCEL_DYNAMIC
    var pointerStyle: String = PointerProtocol.STYLE_ARROW
        set(value) {
            field = value
            pointerView.setStyle(value)
        }

    private companion object {
        const val HOT_DP = 22f
        const val WINDOW_DP = 64f
    }

    private val pointerParams = overlayParams()
    private val markParams = overlayParams()

    /**
     * Ventana de Accesibilidad sin toques ni foco, en pantalla completa real:
     * sin correrse por la barra de estado ni el recorte de la cámara (si no,
     * el clic caería más arriba que la punta).
     */
    private fun overlayParams() = WindowManager.LayoutParams(
        windowPx,
        windowPx,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        windowAnimations = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            fitInsetsTypes = 0
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    init {
        pointerView.setStyle(pointerStyle)
        readScreen()
    }

    private fun readScreen() {
        val (w, h) = screen.size()
        if (w > 0 && h > 0) {
            screenWidth = w
            screenHeight = h
        }
    }

    /** Muestra el puntero; [initialX]/[initialY] = dónde ponerlo (si no, donde estaba). Devuelve false si Android no dejó crear la ventana. */
    fun show(initialX: Float? = null, initialY: Float? = null): Boolean {
        readScreen()
        if (initialX != null) posX = initialX
        if (initialY != null) posY = initialY
        clampCoordinates()
        pointerParams.x = posX.toInt() - hotPx
        pointerParams.y = posY.toInt() - hotPx
        if (!pointerAttached) {
            try {
                windowManager.addView(pointerView, pointerParams)
                pointerAttached = true
            } catch (_: Exception) {
                return false
            }
        } else {
            updateLayout()
        }
        pointerView.visibility = View.VISIBLE
        visible = true
        return true
    }

    fun hide() {
        if (pointerAttached && visible) {
            pointerView.visibility = View.GONE
            visible = false
        }
        clearOrigin()
    }

    /** Cambió el tamaño o la orientación de la pantalla: acota el puntero a la nueva. */
    fun onScreenChanged() {
        readScreen()
        clampCoordinates()
        updateLayout()
    }

    /**
     * Punto exacto del clic: la punta tal como se ve en pantalla (o la pedida,
     * si la ventana todavía no se dibujó).
     */
    fun getPosition(): Pair<Float, Float> {
        val loc = intArrayOf(pointerParams.x, pointerParams.y)
        if (pointerAttached && visible && pointerView.isLaidOut) {
            try {
                pointerView.getLocationOnScreen(loc)
            } catch (_: Exception) {}
        }
        val x = (loc[0] + hotPx).toFloat().coerceIn(0f, (screenWidth - 1).toFloat())
        val y = (loc[1] + hotPx).toFloat().coerceIn(0f, (screenHeight - 1).toFloat())
        return Pair(x, y)
    }

    /** Mueve el puntero con la sensibilidad y la curva elegidas. */
    fun moveBy(dx: Float, dy: Float) {
        if (!visible) return
        val (effDx, effDy) = PointerKinematics.apply(dx, dy, sensitivity, accelCurve, density)
        posX += effDx
        posY += effDy
        clampCoordinates()
        updateLayout()
    }

    /** La punta puede llegar a cualquier píxel de la pantalla (también a los bordes). */
    private fun clampCoordinates() {
        if (posX.isNaN()) posX = screenWidth / 2f
        if (posY.isNaN()) posY = screenHeight / 3f
        posX = posX.coerceIn(0f, (screenWidth - 1).coerceAtLeast(0).toFloat())
        posY = posY.coerceIn(0f, (screenHeight - 1).coerceAtLeast(0).toFloat())
    }

    private fun updateLayout() {
        if (!pointerAttached) return
        pointerParams.x = posX.toInt() - hotPx
        pointerParams.y = posY.toInt() - hotPx
        try {
            windowManager.updateViewLayout(pointerView, pointerParams)
        } catch (_: Exception) {}
    }

    /** Flecha: se «aprieta» sobre la punta. En los tres estilos sale un anillo brasa de la punta. */
    fun triggerClickFeedback(long: Boolean = false) {
        if (visible) pointerView.animateClick(long)
    }

    /** Anillo fijo en (x, y): de dónde se agarró el arrastre. */
    fun setOrigin(x: Float, y: Float) {
        markParams.x = x.toInt() - hotPx
        markParams.y = y.toInt() - hotPx
        if (markAttached) {
            try {
                windowManager.updateViewLayout(markView, markParams)
            } catch (_: Exception) {}
            return
        }
        try {
            windowManager.addView(markView, markParams)
            markAttached = true
        } catch (_: Exception) {}
    }

    fun clearOrigin() {
        if (!markAttached) return
        markAttached = false
        try {
            windowManager.removeViewImmediate(markView)
        } catch (_: Exception) {}
    }

    fun destroy() {
        clearOrigin()
        pointerView.release()
        if (pointerAttached) {
            try {
                windowManager.removeViewImmediate(pointerView)
            } catch (_: Exception) {}
            pointerAttached = false
            visible = false
        }
    }

    /**
     * Dibujo del puntero. Flecha «Horizonte» (elegida en el artifact, 2026-11-14):
     * esbelta, tinta casi negra con borde fino claro (se lee sobre cualquier
     * fondo), sombra suave y un punto brasa en la punta, donde cae el clic.
     * La punta, el punto y el centro de la cruz quedan todos en (hot, hot).
     */
    private class PointerView(context: Context, private val hot: Float) : View(context) {

        private val d = resources.displayMetrics.density
        private var style: String = PointerProtocol.STYLE_ARROW
        private val accent = context.getColor(R.color.hz_ember)

        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            color = Color.WHITE
            setShadowLayer(2f * d, 0f, 1.5f * d, 0x59000000)
        }
        private val inkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            color = INK
            setShadowLayer(1.6f * d, 0f, 0.8f * d, 0x47000000)
        }
        private val paperPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.STROKE
            color = PAPER
            strokeWidth = 1.4f * d
            strokeJoin = Paint.Join.ROUND
        }
        private val emberPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            color = EMBER
        }
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.STROKE
            color = Color.BLACK
            strokeJoin = Paint.Join.ROUND
            strokeCap = Paint.Cap.ROUND
        }
        private val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            color = accent
        }
        private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.STROKE
            strokeWidth = 2f * d
            color = accent
        }
        private val rippleFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.FILL
            color = accent
        }

        /** Unidades de la flecha del artifact a píxeles. */
        private val unit = 1.05f * d
        private val arrowPath = Path()
        private var ripple = -1f
        private var rippleLong = false
        private var press = 1f
        private var pressAnim: ValueAnimator? = null
        private var rippleAnim: ValueAnimator? = null

        init {
            // La sombra de un trazo necesita capa por software; la vista es chica.
            setLayerType(LAYER_TYPE_SOFTWARE, null)
            buildArrow()
        }

        /** Flecha esbelta «Horizonte», con la punta en (hot, hot) (unidades del artifact). */
        private fun buildArrow() {
            val pts = floatArrayOf(
                0f, 0f,
                0f, 17.5f,
                4.3f, 13.6f,
                7.3f, 20.4f,
                9.9f, 19.3f,
                7f, 12.6f,
                12.6f, 12.6f,
            )
            arrowPath.reset()
            for (i in pts.indices step 2) {
                val x = hot + pts[i] * unit
                val y = hot + pts[i + 1] * unit
                if (i == 0) arrowPath.moveTo(x, y) else arrowPath.lineTo(x, y)
            }
            arrowPath.close()
        }

        fun setStyle(newStyle: String) {
            style = newStyle
            invalidate()
        }

        fun animateClick(long: Boolean) {
            if (style == PointerProtocol.STYLE_ARROW) {
                pressAnim?.cancel()
                pressAnim = ValueAnimator.ofFloat(1f, if (long) 0.72f else 0.8f, 1f).apply {
                    duration = if (long) 420L else 220L
                    interpolator = DecelerateInterpolator()
                    addUpdateListener {
                        press = it.animatedValue as Float
                        invalidate()
                    }
                    start()
                }
            }
            rippleLong = long
            rippleAnim?.cancel()
            rippleAnim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = if (long) 700L else 450L
                interpolator = DecelerateInterpolator()
                addUpdateListener {
                    ripple = it.animatedValue as Float
                    invalidate()
                }
                addListener(object : AnimatorListenerAdapter() {
                    private var cancelled = false

                    override fun onAnimationCancel(animation: Animator) {
                        cancelled = true
                    }

                    override fun onAnimationEnd(animation: Animator) {
                        if (cancelled) return
                        ripple = -1f
                        invalidate()
                    }
                })
                start()
            }
        }

        /** Corta las animaciones en curso (al sacar la ventana). */
        fun release() {
            pressAnim?.cancel()
            rippleAnim?.cancel()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            if (ripple >= 0f) {
                val r = (4.25f + 16.75f * ripple) * d
                val a = ((1f - ripple) * 255).toInt().coerceIn(0, 255)
                if (rippleLong) {
                    rippleFill.alpha = (a * 0.25f).toInt()
                    canvas.drawCircle(hot, hot, r, rippleFill)
                }
                ripplePaint.alpha = a
                canvas.drawCircle(hot, hot, r, ripplePaint)
            }

            when (style) {
                PointerProtocol.STYLE_DOT -> {
                    // Punto de precisión: centro de acento con aro blanco y borde fino.
                    strokePaint.strokeWidth = 1.2f * d
                    canvas.drawCircle(hot, hot, 7f * d, fillPaint)
                    canvas.drawCircle(hot, hot, 7f * d, strokePaint)
                    canvas.drawCircle(hot, hot, 4f * d, accentPaint)
                }
                PointerProtocol.STYLE_CROSS -> {
                    // Cruz fina con hueco central y punto de acento.
                    val arm = 10f * d
                    val gap = 3f * d
                    strokePaint.strokeWidth = 3.4f * d
                    strokePaint.color = Color.WHITE
                    drawCross(canvas, arm, gap)
                    strokePaint.strokeWidth = 1.4f * d
                    strokePaint.color = Color.BLACK
                    drawCross(canvas, arm, gap)
                    canvas.drawCircle(hot, hot, 1.8f * d, accentPaint)
                }
                else -> { // flecha Horizonte
                    canvas.save()
                    canvas.scale(press, press, hot, hot)
                    canvas.drawPath(arrowPath, inkPaint)
                    canvas.drawPath(arrowPath, paperPaint)
                    // Punto brasa en la punta: crece un poco al hacer clic.
                    val glow = 1f + (1f - press) * 3f
                    canvas.drawCircle(hot + 1.3f * unit, hot + 1.9f * unit, 1.5f * d * glow, emberPaint)
                    canvas.restore()
                }
            }
        }

        private fun drawCross(canvas: Canvas, arm: Float, gap: Float) {
            canvas.drawLine(hot - arm, hot, hot - gap, hot, strokePaint)
            canvas.drawLine(hot + gap, hot, hot + arm, hot, strokePaint)
            canvas.drawLine(hot, hot - arm, hot, hot - gap, strokePaint)
            canvas.drawLine(hot, hot + gap, hot, hot + arm, strokePaint)
        }
    }

    /** Anillo brasa fijo del origen del arrastre, centrado en (hot, hot). */
    private class OriginMarkView(context: Context, private val hot: Float) : View(context) {
        private val d = resources.displayMetrics.density
        private val ember = context.getColor(R.color.hz_ember)
        private val hotColor = context.getColor(R.color.hz_hot)
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            paint.style = Paint.Style.FILL
            paint.color = ember
            paint.alpha = 56
            canvas.drawCircle(hot, hot, 15f * d, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f * d
            paint.color = ember
            canvas.drawCircle(hot, hot, 15f * d, paint)
            paint.style = Paint.Style.FILL
            paint.color = hotColor
            canvas.drawCircle(hot, hot, 2.5f * d, paint)
        }
    }
}

/** Tokens del puntero, iguales en claro y oscuro: se lee sobre cualquier app. */
private const val INK = 0xFF08090E.toInt()
private const val PAPER = 0xFFF7F5F0.toInt()
private const val EMBER = 0xFFFF8A1F.toInt()
