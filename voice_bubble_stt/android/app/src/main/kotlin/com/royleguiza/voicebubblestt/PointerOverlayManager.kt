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
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import androidx.core.content.ContextCompat
import kotlin.math.sqrt

/**
 * Puntero virtual flotante (MEJ-09): ventana TYPE_APPLICATION_OVERLAY con
 * FLAG_NOT_TOUCHABLE, nunca intercepta toques ni roba foco.
 *
 * Coordenadas: [posX]/[posY] son la PUNTA de la flecha en coordenadas de
 * pantalla completa (las mismas que usa el gesto del complemento). La ventana
 * se ubica en pantalla completa (LAYOUT_IN_SCREEN, sin márgenes de barras) y
 * [getPosition] lee dónde quedó dibujada de verdad, así el clic cae justo en
 * la punta que se ve.
 *
 * REGLA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas.
 */
class PointerOverlayManager(private val context: Context) : OverlayPassThrough.Handle {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val density = context.resources.displayMetrics.density

    /** Distancia de la esquina de la ventana a la punta (deja lugar a la onda del clic). */
    private val hotPx = (HOT_DP * density).toInt()
    private val windowPx = (WINDOW_DP * density).toInt()
    private val pointerView = PointerView(context, hotPx.toFloat())
    private var isAttached = false
    private var isVisible = false

    private var screenWidth = context.resources.displayMetrics.widthPixels
    private var screenHeight = context.resources.displayMetrics.heightPixels
    private var keyboardTopY = screenHeight.toFloat()

    // Punta de la flecha, en coordenadas de pantalla completa.
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

    companion object {
        private const val HOT_DP = 22f
        private const val WINDOW_DP = 64f
    }

    private val layoutParams = WindowManager.LayoutParams(
        windowPx,
        windowPx,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        // Pantalla completa: sin correrse por la barra de estado ni el recorte
        // de la cámara (si no, el clic caería más arriba que la flecha).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            fitInsetsTypes = 0
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    init {
        updateScreenMetrics()
        pointerView.setStyle(pointerStyle)
    }

    /** Tamaño real de la pantalla (incluye barra de estado y de navegación). */
    private fun updateScreenMetrics() {
        var w = 0
        var h = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val b = windowManager.currentWindowMetrics.bounds
                w = b.width()
                h = b.height()
            } catch (_: Exception) {}
        }
        if (w <= 0 || h <= 0) {
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(dm)
            w = dm.widthPixels
            h = dm.heightPixels
        }
        screenWidth = w
        screenHeight = h
        if (keyboardTopY <= 0f || keyboardTopY > screenHeight) {
            keyboardTopY = screenHeight.toFloat()
        }
    }

    fun resetBottomLimit() {
        updateScreenMetrics()
        keyboardTopY = screenHeight.toFloat()
    }

    fun updateKeyboardTop(topY: Float) {
        if (topY > 0f) {
            keyboardTopY = topY
            // Si el puntero quedó tapado por el teclado, elevarlo
            val maxY = keyboardTopY - 1f
            if (posY > maxY && maxY > 0f) {
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
        layoutParams.x = posX.toInt() - hotPx
        layoutParams.y = posY.toInt() - hotPx

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
        OverlayPassThrough.register(this)
    }

    // El puntero tapa justo el punto del clic: durante el gesto se vuelve
    // transparente (Android 12+ bloquea toques bajo overlays opacos).
    override fun screenBounds(): IntArray? {
        if (!isAttached || !isVisible) return null
        val loc = drawnOrigin()
        return intArrayOf(loc[0], loc[1], loc[0] + windowPx, loc[1] + windowPx)
    }

    override fun setPassThrough(enabled: Boolean) {
        if (!isAttached) return
        layoutParams.alpha = if (enabled) 0f else 1f
        try {
            windowManager.updateViewLayout(pointerView, layoutParams)
        } catch (_: Exception) {}
    }

    fun hide() {
        if (isAttached && isVisible) {
            pointerView.visibility = View.GONE
            isVisible = false
        }
    }

    /** Esquina de la ventana tal como quedó en pantalla (o la pedida, si aún no se dibujó). */
    private fun drawnOrigin(): IntArray {
        val loc = intArrayOf(layoutParams.x, layoutParams.y)
        if (isAttached && isVisible && pointerView.isLaidOut) {
            try {
                pointerView.getLocationOnScreen(loc)
            } catch (_: Exception) {}
        }
        return loc
    }

    /**
     * Punto exacto del clic: la punta de la flecha (o el centro del punto/cruz)
     * donde se ve en pantalla. tipOffset = distancia de la esquina a la punta.
     */
    fun getPosition(): Pair<Float, Float> {
        val loc = drawnOrigin()
        val tipOffset = hotPx.toFloat()
        val x = (loc[0] + tipOffset).coerceIn(0f, (screenWidth - 1).toFloat())
        val y = (loc[1] + tipOffset).coerceIn(0f, (screenHeight - 1).toFloat())
        return Pair(x, y)
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

    /** La punta puede llegar a cualquier píxel de la pantalla (también a los bordes). */
    private fun clampCoordinates() {
        if (posX.isNaN()) posX = screenWidth / 2f
        if (posY.isNaN()) posY = screenHeight / 3f

        val maxX = (screenWidth - 1).coerceAtLeast(0).toFloat()
        val maxY = (keyboardTopY - 1f).coerceIn(0f, (screenHeight - 1).coerceAtLeast(0).toFloat())

        posX = posX.coerceIn(0f, maxX)
        posY = posY.coerceIn(0f, maxY)
    }

    private fun updateLayout() {
        if (!isAttached) return
        layoutParams.x = posX.toInt() - hotPx
        layoutParams.y = posY.toInt() - hotPx
        try {
            windowManager.updateViewLayout(pointerView, layoutParams)
        } catch (_: Exception) {}
    }

    /** Onda en la punta al hacer clic (como el prototipo). */
    fun triggerClickFeedback(long: Boolean = false) {
        if (isVisible) {
            pointerView.animateClick(long)
        }
    }

    fun destroy() {
        OverlayPassThrough.unregister(this)
        if (isAttached) {
            try {
                windowManager.removeViewImmediate(pointerView)
            } catch (_: Exception) {}
            isAttached = false
            isVisible = false
        }
    }

    /**
     * Dibujo del puntero. La flecha es la del prototipo (estilo macOS): blanca,
     * contorno negro fino y sombra suave; la punta queda en (hot, hot).
     */
    private class PointerView(context: Context, private val hot: Float) : View(context) {

        private val d = resources.displayMetrics.density
        private var style: String = "arrow"
        private val accent = ContextCompat.getColor(context, R.color.kb_key_bg_accent)

        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
            setShadowLayer(2f * d, 0f, 1.5f * d, 0x59000000)
        }
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = Color.BLACK
            strokeJoin = Paint.Join.ROUND
            strokeCap = Paint.Cap.ROUND
        }
        private val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = accent
        }
        private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2f * d
            color = accent
        }
        private val rippleFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = accent
        }

        /** Unidades del SVG del prototipo (22×26) a píxeles. */
        private val unit = 1.1f * d
        private val arrowPath = Path()
        private var ripple = -1f
        private var rippleLong = false

        init {
            // La sombra de un trazo necesita capa por software; la vista es chica.
            setLayerType(LAYER_TYPE_SOFTWARE, null)
            buildArrow()
        }

        /** M2.5 2.2 v18.4 l5 -4.6 l3.6 8.2 l3.3 -1.4 l-3.5 -8 h7.2 z, con la punta en (0,0). */
        private fun buildArrow() {
            val pts = floatArrayOf(
                2.5f, 2.2f,
                2.5f, 20.6f,
                7.5f, 16.0f,
                11.1f, 24.2f,
                14.4f, 22.8f,
                10.9f, 14.8f,
                18.1f, 14.8f,
            )
            arrowPath.reset()
            for (i in pts.indices step 2) {
                val x = hot + (pts[i] - 2.5f) * unit
                val y = hot + (pts[i + 1] - 2.2f) * unit
                if (i == 0) arrowPath.moveTo(x, y) else arrowPath.lineTo(x, y)
            }
            arrowPath.close()
        }

        fun setStyle(newStyle: String) {
            style = newStyle
            invalidate()
        }

        fun animateClick(long: Boolean) {
            rippleLong = long
            ValueAnimator.ofFloat(0f, 1f).apply {
                duration = if (long) 700L else 450L
                interpolator = DecelerateInterpolator()
                addUpdateListener {
                    ripple = it.animatedValue as Float
                    invalidate()
                }
                addListener(object : android.animation.AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: android.animation.Animator) {
                        ripple = -1f
                        invalidate()
                    }
                })
                start()
            }
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
                "dot" -> {
                    // Punto de precisión: centro de acento con aro blanco y borde fino.
                    strokePaint.strokeWidth = 1.2f * d
                    canvas.drawCircle(hot, hot, 7f * d, fillPaint)
                    canvas.drawCircle(hot, hot, 7f * d, strokePaint)
                    canvas.drawCircle(hot, hot, 4f * d, accentPaint)
                }
                "cross" -> {
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
                else -> { // "arrow"
                    strokePaint.strokeWidth = 1.3f * unit
                    strokePaint.color = Color.BLACK
                    canvas.drawPath(arrowPath, fillPaint)
                    canvas.drawPath(arrowPath, strokePaint)
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
}
