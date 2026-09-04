package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import kotlin.math.sqrt

/**
 * Gestor del cursor / puntero virtual flotante en pantalla vía WindowManager (MEJ-09).
 *
 * Utiliza WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY con FLAG_NOT_TOUCHABLE
 * para garantizar que el puntero visual sea transparente al tacto y nunca intercepte toques
 * ni robe foco de entrada del sistema.
 *
 * REGLA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas.
 */
class PointerOverlayManager(private val context: Context) {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val pointerView = PointerView(context)
    private var isAttached = false
    private var isVisible = false

    // Dimensiones y métricas
    private val density = context.resources.displayMetrics.density
    private val pointerSizePx = (28 * density).toInt()

    private var screenWidth = context.resources.displayMetrics.widthPixels
    private var screenHeight = context.resources.displayMetrics.heightPixels
    private var statusBarHeightPx = (28 * density).toInt()
    private var keyboardTopY = screenHeight.toFloat()

    // Coordenadas actuales del puntero (punto de acción superior-izquierdo o centro)
    var posX = (screenWidth / 2f)
        private set
    var posY = (screenHeight / 3f)
        private set

    // Parámetros de física y estilo
    var sensitivity: Float = 1.2f
    var accelCurve: String = "dynamic" // dynamic, linear, precision
    var pointerStyle: String = "arrow" // arrow, dot, cross
        set(value) {
            field = value
            pointerView.setStyle(value)
        }

    private val layoutParams = WindowManager.LayoutParams(
        pointerSizePx,
        pointerSizePx,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = posX.toInt()
        y = posY.toInt()
    }

    init {
        updateScreenMetrics()
        pointerView.setStyle(pointerStyle)
    }

    private fun updateScreenMetrics() {
        val dm = context.resources.displayMetrics
        screenWidth = dm.widthPixels
        screenHeight = dm.heightPixels

        val resId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resId > 0) {
            statusBarHeightPx = context.resources.getDimensionPixelSize(resId)
        }
        if (keyboardTopY <= 0f || keyboardTopY > screenHeight) {
            keyboardTopY = screenHeight.toFloat()
        }
    }

    fun resetBottomLimit() {
        updateScreenMetrics()
        keyboardTopY = screenHeight.toFloat()
    }

    fun updateKeyboardTop(topY: Float) {
        if (topY > statusBarHeightPx) {
            keyboardTopY = topY
            // Si el puntero quedó tapado por el teclado, elevarlo
            val maxY = keyboardTopY - pointerSizePx
            if (posY > maxY && maxY > statusBarHeightPx) {
                posY = maxY
                updateLayout()
            }
        }
    }

    fun show(initialX: Float? = null, initialY: Float? = null) {
        if (!Settings.canDrawOverlays(context)) return

        updateScreenMetrics()

        if (initialX != null) posX = initialX
        if (initialY != null) posY = initialY

        clampCoordinates()

        layoutParams.x = posX.toInt()
        layoutParams.y = posY.toInt()

        if (!isAttached) {
            try {
                windowManager.addView(pointerView, layoutParams)
                isAttached = true
            } catch (_: Exception) {
                return
            }
        } else {
            updateLayout()
        }

        pointerView.visibility = View.VISIBLE
        isVisible = true
    }

    fun hide() {
        if (isAttached && isVisible) {
            pointerView.visibility = View.GONE
            isVisible = false
        }
    }

    fun isShowing(): Boolean = isVisible && isAttached

    fun getPosition(): Pair<Float, Float> {
        // Devuelve el punto de impacto exacto según el estilo
        return when (pointerStyle) {
            "arrow" -> Pair(posX + 2f * density, posY + 2f * density)
            else -> Pair(posX + (pointerSizePx / 2f), posY + (pointerSizePx / 2f))
        }
    }

    /**
     * Aplica desplazamiento relativo (dx, dy) con el perfil de aceleración cinemática.
     */
    fun moveBy(dx: Float, dy: Float) {
        if (!isVisible) return

        val (effDx, effDy) = applyKinematics(dx, dy)

        posX += effDx
        posY += effDy

        clampCoordinates()
        updateLayout()
    }

    private fun applyKinematics(dx: Float, dy: Float): Pair<Float, Float> {
        return when (accelCurve) {
            "linear" -> {
                Pair(dx * sensitivity, dy * sensitivity)
            }
            "precision" -> {
                val factor = sensitivity * 0.55f
                Pair(dx * factor, dy * factor)
            }
            else -> { // "dynamic"
                val distance = sqrt(dx * dx + dy * dy)
                val baseThreshold = 10f * density
                val dynamicFactor = if (distance > baseThreshold) {
                    1.0f + ((distance - baseThreshold) / (18f * density)) * 0.6f
                } else {
                    1.0f
                }.coerceIn(1.0f, 3.2f)

                Pair(dx * sensitivity * dynamicFactor, dy * sensitivity * dynamicFactor)
            }
        }
    }

    private fun clampCoordinates() {
        if (posX.isNaN()) posX = screenWidth / 2f
        if (posY.isNaN()) posY = screenHeight / 3f

        val minX = 0f
        val maxX = (screenWidth - pointerSizePx).coerceAtLeast(0).toFloat()
        val minY = statusBarHeightPx.toFloat()
        val maxY = (keyboardTopY - pointerSizePx).coerceAtLeast(minY).toFloat()

        posX = posX.coerceIn(minX, maxX)
        posY = posY.coerceIn(minY, maxY)
    }

    private fun updateLayout() {
        if (!isAttached) return
        layoutParams.x = posX.toInt()
        layoutParams.y = posY.toInt()
        try {
            windowManager.updateViewLayout(pointerView, layoutParams)
        } catch (_: Exception) {}
    }

    /**
     * Animación sutil de confirmación visual al disparar un clic.
     */
    fun triggerClickFeedback() {
        if (isVisible) {
            pointerView.animateClick()
        }
    }

    fun destroy() {
        if (isAttached) {
            try {
                windowManager.removeViewImmediate(pointerView)
            } catch (_: Exception) {}
            isAttached = false
            isVisible = false
        }
    }

    /**
     * Vista interna de renderizado vectorial acelerado por hardware para el puntero virtual.
     */
    private class PointerView(context: Context) : View(context) {

        private var style: String = "arrow"
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
        }
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2.2f * resources.displayMetrics.density
            color = Color.parseColor("#1C1C1E") // Borde oscuro de contraste alto
            strokeJoin = Paint.Join.ROUND
            strokeCap = Paint.Cap.ROUND
        }
        private val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#0A84FF") // Azul Apple
        }
        private val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#400A84FF")
        }

        private val arrowPath = Path()
        private var clickScale = 1.0f

        fun setStyle(newStyle: String) {
            style = newStyle
            invalidate()
        }

        fun animateClick() {
            ValueAnimator.ofFloat(1.0f, 0.78f, 1.0f).apply {
                duration = 140
                interpolator = OvershootInterpolator()
                addUpdateListener {
                    clickScale = it.animatedValue as Float
                    scaleX = clickScale
                    scaleY = clickScale
                }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f

            when (style) {
                "dot" -> {
                    // Punto óptico de precisión
                    canvas.drawCircle(cx, cy, w * 0.40f, haloPaint)
                    canvas.drawCircle(cx, cy, w * 0.22f, strokePaint)
                    canvas.drawCircle(cx, cy, w * 0.18f, accentPaint)
                }
                "cross" -> {
                    // Cruz reticular de precisión milimétrica
                    val arm = w * 0.38f
                    val gap = w * 0.12f
                    // Horizontal
                    canvas.drawLine(cx - arm, cy, cx - gap, cy, strokePaint)
                    canvas.drawLine(cx + gap, cy, cx + arm, cy, strokePaint)
                    // Vertical
                    canvas.drawLine(cx, cy - arm, cx, cy - gap, strokePaint)
                    canvas.drawLine(cx, cy + gap, cx, cy + arm, strokePaint)
                    // Centro
                    canvas.drawCircle(cx, cy, 2.5f * resources.displayMetrics.density, accentPaint)
                }
                else -> { // "arrow"
                    // Flecha de mouse clásica refinada con ángulo de 45°
                    val tipOffset = 2f * resources.displayMetrics.density
                    arrowPath.reset()
                    arrowPath.moveTo(tipOffset, tipOffset)
                    arrowPath.lineTo(tipOffset, h * 0.82f)
                    arrowPath.lineTo(w * 0.32f, h * 0.62f)
                    arrowPath.lineTo(w * 0.62f, h * 0.92f)
                    arrowPath.lineTo(w * 0.76f, h * 0.78f)
                    arrowPath.lineTo(w * 0.46f, h * 0.50f)
                    arrowPath.lineTo(w * 0.80f, h * 0.50f)
                    arrowPath.close()

                    canvas.drawPath(arrowPath, fillPaint)
                    canvas.drawPath(arrowPath, strokePaint)
                }
            }
        }
    }
}
