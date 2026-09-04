package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Capa de interfaz nativa del Trackpad Split Wings (Opción 2) para VoiceKeyboardService.
 *
 * Geometría de 3 columnas:
 * - Ala Izquierda (68dp)
 * - Centro: Superficie táctil de ultra-precisión (flex: 1)
 * - Ala Derecha (68dp)
 *
 * Comportamiento dinámico de la barra de scroll (scrollPosition):
 * - "right": Flanco izquierdo contiene botón L (100% alto, flex 1). Flanco derecho contiene
 *            scroll strip (flex 1.4) + botón R (flex 0.8).
 * - "left":  Flanco izquierdo contiene scroll strip (flex 1.4) + botón L (flex 0.8). Flanco
 *            derecho contiene botón R (100% alto, flex 1).
 * - "disabled": Flanco izquierdo contiene botón L (100% alto, flex 1). Flanco derecho
 *               contiene botón R (100% alto, flex 1).
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni persistencia de eventos táctiles.
 */
class VirtualTrackpadView(
    context: Context,
    private val scrollPosition: String = "right", // right, left, disabled
    private val tapToClick: Boolean = true,
    private val secondaryClickMode: String = "2fingers", // 2fingers, button, hold
    private val scrollDirection: String = "natural", // natural, standard
    private val autoReturnSeconds: Int = 0,
    private val listener: TrackpadListener
) : LinearLayout(context) {

    interface TrackpadListener {
        fun onPointerMove(dx: Float, dy: Float)
        fun onLeftClick()
        fun onRightClick()
        fun onScroll(deltaY: Float)
        fun onAutoReturn()
        fun performHaptic(isFirm: Boolean = false)
    }

    private val density = context.resources.displayMetrics.density
    private val wingWidthPx = (68 * density).toInt()
    private val gapPx = (4 * density).toInt()
    private val trackpadHeightPx = (200 * density).toInt()

    private val handler = Handler(Looper.getMainLooper())
    private val autoReturnRunnable = Runnable {
        listener.onAutoReturn()
    }

    init {
        orientation = HORIZONTAL
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, trackpadHeightPx).apply {
            setMargins(gapPx, gapPx, gapPx, gapPx)
        }
        setupWings()
        resetAutoReturnTimer()
    }

    private fun resetAutoReturnTimer() {
        if (autoReturnSeconds > 0) {
            handler.removeCallbacks(autoReturnRunnable)
            handler.postDelayed(autoReturnRunnable, autoReturnSeconds * 1000L)
        }
    }

    private fun setupWings() {
        removeAllViews()

        // 1. Ala Izquierda
        val leftWing = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(wingWidthPx, LayoutParams.MATCH_PARENT).apply {
                setMargins(gapPx / 2, 0, gapPx / 2, 0)
            }
        }

        // 2. Pad Central
        val centerPad = TrackpadSurfaceView(
            context = context,
            tapToClick = tapToClick,
            secondaryClickMode = secondaryClickMode,
            scrollDirection = scrollDirection,
            onMove = { dx, dy ->
                resetAutoReturnTimer()
                listener.onPointerMove(dx, dy)
            },
            onTap = {
                resetAutoReturnTimer()
                listener.performHaptic(isFirm = false)
                listener.onLeftClick()
            },
            onSecondaryTap = {
                resetAutoReturnTimer()
                listener.performHaptic(isFirm = true)
                listener.onRightClick()
            },
            onTwoFingerScroll = { deltaY ->
                resetAutoReturnTimer()
                listener.onScroll(deltaY)
            },
            onTouchInteraction = {
                resetAutoReturnTimer()
            }
        ).apply {
            layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f).apply {
                setMargins(gapPx / 2, 0, gapPx / 2, 0)
            }
        }

        // 3. Ala Derecha
        val rightWing = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(wingWidthPx, LayoutParams.MATCH_PARENT).apply {
                setMargins(gapPx / 2, 0, gapPx / 2, 0)
            }
        }

        when (scrollPosition) {
            "left" -> {
                // Scroll en ala izquierda + botón L (flex 0.8); botón R en ala derecha al 100%
                val scrollStrip = createScrollStripView(weight = 1.4f)
                val btnLeft = createWingButton("CLIC", "IZQ", weight = 0.8f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = false)
                    listener.onLeftClick()
                }
                leftWing.addView(scrollStrip)
                leftWing.addView(btnLeft)

                val btnRight = createWingButton("CLIC", "DER", weight = 1.0f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = true)
                    listener.onRightClick()
                }
                rightWing.addView(btnRight)
            }
            "disabled" -> {
                // Ambos botones expandidos al 100% de la altura (flex 1.0)
                val btnLeft = createWingButton("CLIC", "IZQ", weight = 1.0f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = false)
                    listener.onLeftClick()
                }
                leftWing.addView(btnLeft)

                val btnRight = createWingButton("CLIC", "DER", weight = 1.0f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = true)
                    listener.onRightClick()
                }
                rightWing.addView(btnRight)
            }
            else -> { // "right" (default)
                // Botón L en ala izquierda al 100%; scroll (flex 1.4) + botón R (flex 0.8) en ala derecha
                val btnLeft = createWingButton("CLIC", "IZQ", weight = 1.0f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = false)
                    listener.onLeftClick()
                }
                leftWing.addView(btnLeft)

                val scrollStrip = createScrollStripView(weight = 1.4f)
                val btnRight = createWingButton("CLIC", "DER", weight = 0.8f) {
                    resetAutoReturnTimer()
                    listener.performHaptic(isFirm = true)
                    listener.onRightClick()
                }
                rightWing.addView(scrollStrip)
                rightWing.addView(btnRight)
            }
        }

        addView(leftWing)
        addView(centerPad)
        addView(rightWing)
    }

    private fun createWingButton(
        title: String,
        subtitle: String,
        weight: Float,
        onClick: () -> Unit
    ): View {
        val button = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, weight).apply {
                setMargins(0, gapPx / 2, 0, gapPx / 2)
            }

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 14f * density
                setColor(Color.parseColor("#1FFFFFFF")) // Translucidez Liquid Glass
                setStroke((1f * density).toInt(), Color.parseColor("#33FFFFFF"))
            }
            background = bg

            val tvTitle = TextView(context).apply {
                text = title
                textSize = 13f
                gravity = Gravity.CENTER
                setTextColor(Color.WHITE)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            val tvSub = TextView(context).apply {
                text = subtitle
                textSize = 10f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#B3FFFFFF"))
            }

            addView(tvTitle)
            addView(tvSub)

            setOnTouchListener { v, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        resetAutoReturnTimer()
                        v.isPressed = true
                        bg.setColor(Color.parseColor("#330A84FF"))
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val inside = event.x >= 0 && event.x <= v.width && event.y >= 0 && event.y <= v.height
                        if (v.isPressed != inside) {
                            v.isPressed = inside
                            bg.setColor(if (inside) Color.parseColor("#330A84FF") else Color.parseColor("#1FFFFFFF"))
                        }
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        bg.setColor(Color.parseColor("#1FFFFFFF"))
                        if (v.isPressed) {
                            v.isPressed = false
                            onClick()
                        }
                        true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        bg.setColor(Color.parseColor("#1FFFFFFF"))
                        v.isPressed = false
                        true
                    }
                    else -> false
                }
            }
        }
        return button
    }

    private fun createScrollStripView(weight: Float): View {
        return VerticalScrollStripView(
            context = context,
            scrollDirection = scrollDirection,
            onInteraction = { resetAutoReturnTimer() },
            onScroll = { delta ->
                resetAutoReturnTimer()
                listener.onScroll(delta)
            },
            onHapticTick = {
                listener.performHaptic(isFirm = false)
            }
        ).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, weight).apply {
                setMargins(0, gapPx / 2, 0, gapPx / 2)
            }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        handler.removeCallbacks(autoReturnRunnable)
    }

    /**
     * Superficie táctil central expansiva con detección cinemática de precisión y multi-touch.
     */
    private class TrackpadSurfaceView(
        context: Context,
        private val tapToClick: Boolean,
        private val secondaryClickMode: String, // 2fingers, button, hold
        private val scrollDirection: String,
        private val onMove: (Float, Float) -> Unit,
        private val onTap: () -> Unit,
        private val onSecondaryTap: () -> Unit,
        private val onTwoFingerScroll: (Float) -> Unit,
        private val onTouchInteraction: () -> Unit
    ) : View(context) {

        private val density = resources.displayMetrics.density
        private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()

        private var lastX = 0f
        private var lastY = 0f
        private var downX = 0f
        private var downY = 0f
        private var downTime = 0L

        private var pointerCount = 0
        private var twoFingerStartY = 0f
        private var isMultiTouchScroll = false
        private var hadMultiTouch = false
        private var isHoldTriggered = false

        private val surfaceHandler = Handler(Looper.getMainLooper())
        private val holdRunnable = Runnable {
            if (pointerCount == 1 && !hadMultiTouch && !isMultiTouchScroll) {
                isHoldTriggered = true
                onSecondaryTap()
            }
        }

        private val surfaceBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 16f * density
            setColor(Color.parseColor("#140F172A")) // Translucidez oscura elegante
            setStroke((1.2f * density).toInt(), Color.parseColor("#4738BDF8")) // Borde cian cristal
        }

        private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1f * density
            color = Color.parseColor("#0D38BDF8") // Cuadrícula tenue
        }

        init {
            background = surfaceBg
        }

        override fun onDetachedFromWindow() {
            super.onDetachedFromWindow()
            surfaceHandler.removeCallbacks(holdRunnable)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            // Dibuja guías sutiles de cuadrícula Liquid Glass
            val w = width.toFloat()
            val h = height.toFloat()
            val step = 32f * density
            var x = step
            while (x < w) {
                canvas.drawLine(x, 10f * density, x, h - 10f * density, gridPaint)
                x += step
            }
            var y = step
            while (y < h) {
                canvas.drawLine(10f * density, y, w - 10f * density, y, gridPaint)
                y += step
            }
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            onTouchInteraction()
            pointerCount = event.pointerCount

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downTime = System.currentTimeMillis()
                    downX = event.x
                    downY = event.y
                    lastX = event.x
                    lastY = event.y
                    isMultiTouchScroll = false
                    hadMultiTouch = false
                    isHoldTriggered = false

                    if (secondaryClickMode == "hold") {
                        surfaceHandler.removeCallbacks(holdRunnable)
                        surfaceHandler.postDelayed(holdRunnable, ViewConfiguration.getLongPressTimeout().toLong())
                    }

                    surfaceBg.setStroke((1.5f * density).toInt(), Color.parseColor("#8038BDF8"))
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_POINTER_DOWN -> {
                    hadMultiTouch = true
                    surfaceHandler.removeCallbacks(holdRunnable)
                    if (pointerCount == 2) {
                        twoFingerStartY = (event.getY(0) + event.getY(1)) / 2f
                        isMultiTouchScroll = true
                    }
                }
                MotionEvent.ACTION_MOVE -> {
                    val distX = abs(event.x - downX)
                    val distY = abs(event.y - downY)
                    if (distX > touchSlop || distY > touchSlop) {
                        surfaceHandler.removeCallbacks(holdRunnable)
                    }

                    if (pointerCount >= 2 && isMultiTouchScroll) {
                        val currentTwoFingerY = (event.getY(0) + event.getY(1)) / 2f
                        val dy = currentTwoFingerY - twoFingerStartY
                        twoFingerStartY = currentTwoFingerY

                        val effectiveDy = if (scrollDirection == "standard") -dy else dy
                        onTwoFingerScroll(effectiveDy * 2.2f)
                    } else if (pointerCount == 1 && !isHoldTriggered) {
                        val dx = event.x - lastX
                        val dy = event.y - lastY
                        lastX = event.x
                        lastY = event.y
                        onMove(dx, dy)
                    }
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    surfaceHandler.removeCallbacks(holdRunnable)
                    if (pointerCount == 2) {
                        if (secondaryClickMode == "2fingers") {
                            val duration = System.currentTimeMillis() - downTime
                            if (duration < 280) {
                                onSecondaryTap()
                            }
                        }
                        // Re-anclar las coordenadas al puntero restante para evitar saltos del cursor
                        val upIndex = event.actionIndex
                        val remainingIndex = if (upIndex == 0) 1 else 0
                        lastX = event.getX(remainingIndex)
                        lastY = event.getY(remainingIndex)
                        downX = lastX
                        downY = lastY
                    }
                }
                MotionEvent.ACTION_UP -> {
                    surfaceHandler.removeCallbacks(holdRunnable)
                    surfaceBg.setStroke((1.2f * density).toInt(), Color.parseColor("#4738BDF8"))
                    invalidate()

                    val duration = System.currentTimeMillis() - downTime
                    val distX = abs(event.x - downX)
                    val distY = abs(event.y - downY)

                    // Solo disparar tap-to-click si fue toque primario único y no fue hold ni multitouch
                    if (tapToClick && !hadMultiTouch && !isHoldTriggered && duration < 220 && distX < touchSlop && distY < touchSlop) {
                        onTap()
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    surfaceHandler.removeCallbacks(holdRunnable)
                    surfaceBg.setStroke((1.2f * density).toInt(), Color.parseColor("#4738BDF8"))
                    invalidate()
                }
            }
            return true
        }
    }

    /**
     * Barra táctil de scroll vertical con microrrelieves y flechas guía.
     */
    private class VerticalScrollStripView(
        context: Context,
        private val scrollDirection: String,
        private val onInteraction: () -> Unit,
        private val onScroll: (Float) -> Unit,
        private val onHapticTick: () -> Unit
    ) : View(context) {

        private val density = resources.displayMetrics.density
        private var lastY = 0f
        private var accumulatedDistance = 0f

        private val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 14f * density
            setColor(Color.parseColor("#1FFFFFFF"))
            setStroke((1f * density).toInt(), Color.parseColor("#33FFFFFF"))
        }

        private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2f * density
            strokeCap = Paint.Cap.ROUND
            color = Color.parseColor("#B3FFFFFF")
        }

        init {
            background = bg
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f

            // Flecha superior ▲
            canvas.drawLine(cx - 6f * density, 18f * density, cx, 12f * density, iconPaint)
            canvas.drawLine(cx, 12f * density, cx + 6f * density, 18f * density, iconPaint)

            // Microrrelieves centrales
            val cy = h / 2f
            canvas.drawLine(cx - 8f * density, cy - 8f * density, cx + 8f * density, cy - 8f * density, iconPaint)
            canvas.drawLine(cx - 8f * density, cy, cx + 8f * density, cy, iconPaint)
            canvas.drawLine(cx - 8f * density, cy + 8f * density, cx + 8f * density, cy + 8f * density, iconPaint)

            // Flecha inferior ▼
            canvas.drawLine(cx - 6f * density, h - 18f * density, cx, h - 12f * density, iconPaint)
            canvas.drawLine(cx, h - 12f * density, cx + 6f * density, h - 18f * density, iconPaint)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            onInteraction()
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    lastY = event.y
                    accumulatedDistance = 0f
                    bg.setColor(Color.parseColor("#330A84FF"))
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.y - lastY
                    lastY = event.y

                    val effectiveDy = if (scrollDirection == "standard") -dy else dy
                    onScroll(effectiveDy * 3.5f)

                    accumulatedDistance += abs(dy)
                    if (accumulatedDistance >= 30f * density) {
                        onHapticTick()
                        accumulatedDistance = 0f
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    bg.setColor(Color.parseColor("#1FFFFFFF"))
                    invalidate()
                }
            }
            return true
        }
    }
}
