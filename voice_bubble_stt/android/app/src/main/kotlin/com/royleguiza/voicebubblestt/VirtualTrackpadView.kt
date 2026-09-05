package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.res.Configuration
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
import android.view.animation.DecelerateInterpolator
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * Capa de interfaz nativa del Trackpad Universal y Puntero Virtual (MEJ-09 / MEJORAS-SEPTIEMBRE).
 *
 * Modos de distribución bimodal (buttonLayout):
 * 1. "top": Distribución superior 50/50. Clic Izquierdo y Clic Derecho ocupan el 50% cada uno
 *           en la fila superior, con iconos de mouse limpios y CERO etiquetas de texto visibles.
 *           La mitad inferior aloja la superficie táctil 2D de ancho completo (100% de ancho).
 * 2. "wings": Distribución de 3 columnas laterales (Split Wings).
 *           Ala izquierda (68dp) con Clic Izquierdo, Pad táctil central (flex: 1),
 *           Ala derecha (68dp) con Clic Derecho.
 *
 * Opciones de la barra de desplazamiento (scrollPosition):
 * - "right": Tira de scroll en el lateral derecho (flex 1.4) + botón compartido (flex 0.8 en wings).
 * - "left":  Tira de scroll en el lateral izquierdo (flex 1.4) + botón compartido.
 * - "disabled" / "none": Sin barra de scroll; la superficie táctil 2D se auto-expande al 100% de ancho.
 *
 * Iconos de mouse limpios sin texto:
 * Botones con ic_mouse_left e ic_mouse_right vector drawables y cero etiquetas de texto visibles.
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas o eventos táctiles.
 */
class VirtualTrackpadView(
    context: Context,
    private val scrollPosition: String = "right", // right, left, disabled, none
    private val tapToClick: Boolean = true,
    private val secondaryClickMode: String = "2fingers", // 2fingers, button, hold
    private val scrollDirection: String = "natural", // natural, standard
    private val autoReturnSeconds: Int = 0,
    private val trackpadHeightPx: Int = 0,
    private val buttonLayout: String = "top", // top, wings
    private val theme: String = "glass", // glass, dark, light
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
    private val effectiveHeightPx: Int = if (trackpadHeightPx > 0) trackpadHeightPx else (210 * density).toInt()

    private val isNight: Boolean
        get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private val handler = Handler(Looper.getMainLooper())
    private val autoReturnRunnable = Runnable {
        listener.onAutoReturn()
    }

    init {
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, effectiveHeightPx).apply {
            setMargins(gapPx, gapPx, gapPx, gapPx)
        }
        if (buttonLayout == "wings") {
            orientation = HORIZONTAL
            setupWingsLayout()
        } else {
            orientation = VERTICAL
            setupTopButtonsLayout()
        }
        resetAutoReturnTimer()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val parentHeight = MeasureSpec.getSize(heightMeasureSpec)
        val heightMode = MeasureSpec.getMode(heightMeasureSpec)
        val targetH = when {
            heightMode == MeasureSpec.EXACTLY && parentHeight > 0 -> parentHeight
            effectiveHeightPx > 0 -> effectiveHeightPx
            layoutParams != null && layoutParams.height > 0 -> layoutParams.height
            else -> (210 * density).toInt()
        }
        val exactHeightSpec = MeasureSpec.makeMeasureSpec(targetH, MeasureSpec.EXACTLY)
        super.onMeasure(widthMeasureSpec, exactHeightSpec)
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), targetH)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (alpha == 0f) {
            animate().alpha(1f).setDuration(160L).setInterpolator(DecelerateInterpolator()).start()
        }
    }

    private fun resetAutoReturnTimer() {
        if (autoReturnSeconds > 0) {
            handler.removeCallbacks(autoReturnRunnable)
            handler.postDelayed(autoReturnRunnable, autoReturnSeconds * 1000L)
        }
    }

    /**
     * Configura la distribución "top": Fila superior 50/50 con iconos de mouse,
     * fila inferior con superficie táctil 2D al 100% de ancho (o tira de scroll).
     */
    private fun setupTopButtonsLayout() {
        removeAllViews()

        // 1. Fila Superior 50/50
        val topButtonsRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val h = (44 * density).toInt()
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, h).apply {
                setMargins(0, 0, 0, gapPx)
            }
        }

        val btnLeft = createIconButton(
            title = "CLIC",
            subtitle = "IZQ",
            iconRes = R.drawable.ic_mouse_left,
            isPrimary = true,
            weight = 1.0f,
            onClick = {
                resetAutoReturnTimer()
                listener.performHaptic(isFirm = false)
                listener.onLeftClick()
            }
        )

        val btnRight = createIconButton(
            title = "CLIC",
            subtitle = "DER",
            iconRes = R.drawable.ic_mouse_right,
            isPrimary = false,
            weight = 1.0f,
            onClick = {
                resetAutoReturnTimer()
                listener.performHaptic(isFirm = true)
                listener.onRightClick()
            }
        )

        topButtonsRow.addView(btnLeft)
        topButtonsRow.addView(btnRight)
        addView(topButtonsRow)

        // 2. Fila Inferior: Superficie 2D + Tira de Scroll opcional
        val surfaceRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, 1.0f)
        }

        val centerPad = createCenterPadView()

        val isScrollDisabled = (scrollPosition == "disabled" || scrollPosition == "none")

        if (isScrollDisabled) {
            // Auto-expansión al 100% de ancho
            surfaceRow.addView(centerPad)
        } else if (scrollPosition == "left") {
            val scrollStrip = createScrollStripView(weight = 1.4f).apply {
                layoutParams = LayoutParams((50 * density).toInt(), LayoutParams.MATCH_PARENT).apply {
                    setMargins(0, 0, gapPx, 0)
                }
            }
            surfaceRow.addView(scrollStrip)
            surfaceRow.addView(centerPad)
        } else { // "right"
            val scrollStrip = createScrollStripView(weight = 1.4f).apply {
                layoutParams = LayoutParams((50 * density).toInt(), LayoutParams.MATCH_PARENT).apply {
                    setMargins(gapPx, 0, 0, 0)
                }
            }
            surfaceRow.addView(centerPad)
            surfaceRow.addView(scrollStrip)
        }

        addView(surfaceRow)
    }

    /**
     * Configura la distribución "wings": Ala Izquierda, Pad Central (flex: 1), Ala Derecha.
     */
    private fun setupWingsLayout() {
        removeAllViews()

        // 1. Ala Izquierda
        val leftWing = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(wingWidthPx, LayoutParams.MATCH_PARENT).apply {
                setMargins(gapPx / 2, 0, gapPx / 2, 0)
            }
        }

        // 2. Pad Central
        val centerPad = createCenterPadView()

        // 3. Ala Derecha
        val rightWing = LinearLayout(context).apply {
            orientation = VERTICAL
            layoutParams = LayoutParams(wingWidthPx, LayoutParams.MATCH_PARENT).apply {
                setMargins(gapPx / 2, 0, gapPx / 2, 0)
            }
        }

        when (scrollPosition) {
            "left" -> {
                val scrollStrip = createScrollStripView(weight = 1.4f)
                val btnLeft = createIconButton(
                    title = "CLIC",
                    subtitle = "IZQ",
                    iconRes = R.drawable.ic_mouse_left,
                    isPrimary = true,
                    weight = 0.8f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = false)
                        listener.onLeftClick()
                    }
                )
                leftWing.addView(scrollStrip)
                leftWing.addView(btnLeft)

                val btnRight = createIconButton(
                    title = "CLIC",
                    subtitle = "DER",
                    iconRes = R.drawable.ic_mouse_right,
                    isPrimary = false,
                    weight = 1.0f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = true)
                        listener.onRightClick()
                    }
                )
                rightWing.addView(btnRight)
            }
            "disabled", "none" -> {
                val btnLeft = createIconButton(
                    title = "CLIC",
                    subtitle = "IZQ",
                    iconRes = R.drawable.ic_mouse_left,
                    isPrimary = true,
                    weight = 1.0f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = false)
                        listener.onLeftClick()
                    }
                )
                leftWing.addView(btnLeft)

                val btnRight = createIconButton(
                    title = "CLIC",
                    subtitle = "DER",
                    iconRes = R.drawable.ic_mouse_right,
                    isPrimary = false,
                    weight = 1.0f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = true)
                        listener.onRightClick()
                    }
                )
                rightWing.addView(btnRight)
            }
            else -> { // "right" (default)
                val btnLeft = createIconButton(
                    title = "CLIC",
                    subtitle = "IZQ",
                    iconRes = R.drawable.ic_mouse_left,
                    isPrimary = true,
                    weight = 1.0f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = false)
                        listener.onLeftClick()
                    }
                )
                leftWing.addView(btnLeft)

                val scrollStrip = createScrollStripView(weight = 1.4f)
                val btnRight = createIconButton(
                    title = "CLIC",
                    subtitle = "DER",
                    iconRes = R.drawable.ic_mouse_right,
                    isPrimary = false,
                    weight = 0.8f,
                    onClick = {
                        resetAutoReturnTimer()
                        listener.performHaptic(isFirm = true)
                        listener.onRightClick()
                    }
                )
                rightWing.addView(scrollStrip)
                rightWing.addView(btnRight)
            }
        }

        addView(leftWing)
        addView(centerPad)
        addView(rightWing)
    }

    private fun createCenterPadView(): View {
        return TrackpadSurfaceView(
            context = context,
            tapToClick = tapToClick,
            secondaryClickMode = secondaryClickMode,
            scrollDirection = scrollDirection,
            theme = theme,
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
    }

    /**
     * Botón de mouse con icono SVG vectorial y CERO texto visible.
     * Mantiene accesible contrastes: acento primario (kb_key_bg_accent) para clic izquierdo
     * y neutro sólido (#FFEBEBF5 / #FF3C3C43) para clic secundario.
     */
    private fun createIconButton(
        title: String,
        subtitle: String,
        iconRes: Int,
        isPrimary: Boolean,
        weight: Float,
        onClick: () -> Unit
    ): View {
        val night = isNight
        val isGlass = (theme == "glass")

        val normalBgColor = if (isGlass) {
            if (night) Color.parseColor("#B31C1D26") else Color.parseColor("#B3E2E6EF")
        } else {
            ContextCompat.getColor(context, R.color.kb_key_bg)
        }

        val strokeColor = if (isGlass) {
            if (night) Color.parseColor("#33FFFFFF") else Color.parseColor("#26000000")
        } else {
            ContextCompat.getColor(context, R.color.kb_key_stroke)
        }

        val pressedBgColor = ContextCompat.getColor(context, R.color.kb_key_pressed)

        // Contraste óptimo accesible:
        // Clic Izquierdo (isPrimary = true): Azul acento accesible (kb_key_bg_accent).
        // Clic Derecho (isPrimary = false): Neutro sólido (#FFEBEBF5 en noche, #FF3C3C43 en claro).
        val subtitleColor = if (isPrimary) {
            ContextCompat.getColor(context, R.color.kb_key_bg_accent)
        } else {
            if (night) Color.parseColor("#FFEBEBF5") else Color.parseColor("#FF3C3C43")
        }

        val strokeActiveColor = if (isPrimary) {
            ContextCompat.getColor(context, R.color.kb_key_bg_accent)
        } else {
            if (night) Color.parseColor("#8E8E93") else Color.parseColor("#636366")
        }

        val activeBgColor = if (isPrimary) {
            if (night) Color.parseColor("#330A84FF") else Color.parseColor("#26007AFF")
        } else {
            pressedBgColor
        }

        val button = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER
            if (buttonLayout == "wings") {
                layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, 0, weight).apply {
                    setMargins(0, gapPx / 2, 0, gapPx / 2)
                }
            } else {
                layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, weight).apply {
                    setMargins(gapPx / 2, 0, gapPx / 2, 0)
                }
            }
            elevation = 2f * density

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 14f * density
                setColor(normalBgColor)
                setStroke((1.2f * density).toInt(), strokeColor)
            }
            background = bg

            // Icono de mouse limpio con cero etiquetas de texto visibles
            val iconView = ImageView(context).apply {
                setImageResource(iconRes)
                setColorFilter(subtitleColor)
                val iconSize = (24 * density).toInt()
                layoutParams = LayoutParams(iconSize, iconSize).apply {
                    gravity = Gravity.CENTER
                }
                contentDescription = "$title $subtitle"
            }
            addView(iconView)

            setOnTouchListener { v, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        resetAutoReturnTimer()
                        v.isPressed = true
                        bg.setColor(activeBgColor)
                        bg.setStroke((1.5f * density).toInt(), strokeActiveColor)
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val inside = event.x >= 0 && event.x <= v.width && event.y >= 0 && event.y <= v.height
                        if (v.isPressed != inside) {
                            v.isPressed = inside
                            bg.setColor(if (inside) activeBgColor else normalBgColor)
                            bg.setStroke(
                                (if (inside) 1.5f else 1.2f * density).toInt(),
                                if (inside) strokeActiveColor else strokeColor
                            )
                        }
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        bg.setColor(normalBgColor)
                        bg.setStroke((1.2f * density).toInt(), strokeColor)
                        if (v.isPressed) {
                            v.isPressed = false
                            onClick()
                        }
                        true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        bg.setColor(normalBgColor)
                        bg.setStroke((1.2f * density).toInt(), strokeColor)
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
        private val theme: String,
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

        private val isNight: Boolean
            get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        private val surfaceBgColor: Int
            get() = if (theme == "glass") {
                if (isNight) Color.parseColor("#9910121A") else Color.parseColor("#B3F2F4F8")
            } else {
                if (isNight) Color.parseColor("#140F172A") else Color.parseColor("#0F007AFF")
            }

        private val strokeNormalColor: Int
            get() = if (theme == "glass") {
                if (isNight) Color.parseColor("#33FFFFFF") else Color.parseColor("#26000000")
            } else {
                if (isNight) Color.parseColor("#4738BDF8") else Color.parseColor("#66007AFF")
            }

        private val strokeActiveColor: Int
            get() = if (isNight) Color.parseColor("#8038BDF8") else Color.parseColor("#CC007AFF")

        private val gridColor: Int
            get() = if (theme == "glass") {
                if (isNight) Color.parseColor("#1AFFFFFF") else Color.parseColor("#1A000000")
            } else {
                if (isNight) Color.parseColor("#0D38BDF8") else Color.parseColor("#26007AFF")
            }

        private val surfaceBg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 16f * density
            setColor(surfaceBgColor)
            setStroke((1.2f * density).toInt(), strokeNormalColor)
        }

        private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1f * density
            color = gridColor
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
            gridPaint.color = gridColor
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
                    hadMultiTouch = false
                    isMultiTouchScroll = false
                    isHoldTriggered = false
                    lastX = event.x
                    lastY = event.y
                    downX = event.x
                    downY = event.y
                    downTime = System.currentTimeMillis()

                    surfaceBg.setStroke((1.5f * density).toInt(), strokeActiveColor)

                    if (secondaryClickMode == "hold") {
                        surfaceHandler.postDelayed(holdRunnable, 450L)
                    }
                    return true
                }

                MotionEvent.ACTION_POINTER_DOWN -> {
                    hadMultiTouch = true
                    surfaceHandler.removeCallbacks(holdRunnable)
                    if (event.pointerCount == 2) {
                        isMultiTouchScroll = true
                        twoFingerStartY = (event.getY(0) + event.getY(1)) / 2f
                    }
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    if (isMultiTouchScroll && event.pointerCount >= 2) {
                        val currentTwoFingerY = (event.getY(0) + event.getY(1)) / 2f
                        val dy = currentTwoFingerY - twoFingerStartY
                        if (abs(dy) > 4f * density) {
                            val factor = if (scrollDirection == "natural") -1f else 1f
                            onTwoFingerScroll(dy * factor)
                            twoFingerStartY = currentTwoFingerY
                        }
                    } else if (event.pointerCount == 1 && !hadMultiTouch) {
                        val dx = event.x - lastX
                        val dy = event.y - lastY
                        if (abs(dx) > 0.5f || abs(dy) > 0.5f) {
                            onMove(dx, dy)
                            lastX = event.x
                            lastY = event.y
                        }
                        val distFromDown = abs(event.x - downX) + abs(event.y - downY)
                        if (distFromDown > touchSlop) {
                            surfaceHandler.removeCallbacks(holdRunnable)
                        }
                    }
                    return true
                }

                MotionEvent.ACTION_POINTER_UP -> {
                    val remainingPointers = event.pointerCount - 1
                    if (remainingPointers == 1) {
                        val remainingIndex = if (event.actionIndex == 0) 1 else 0
                        lastX = event.getX(remainingIndex)
                        lastY = event.getY(remainingIndex)
                    }
                    isMultiTouchScroll = false
                    return true
                }

                MotionEvent.ACTION_UP -> {
                    surfaceHandler.removeCallbacks(holdRunnable)
                    surfaceBg.setStroke((1.2f * density).toInt(), strokeNormalColor)

                    val duration = System.currentTimeMillis() - downTime
                    val dist = abs(event.x - downX) + abs(event.y - downY)

                    if (!hadMultiTouch && !isHoldTriggered && dist < touchSlop && duration < 250L) {
                        if (tapToClick) {
                            onTap()
                        }
                    }
                    return true
                }

                MotionEvent.ACTION_CANCEL -> {
                    surfaceHandler.removeCallbacks(holdRunnable)
                    surfaceBg.setStroke((1.2f * density).toInt(), strokeNormalColor)
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }

    /**
     * Tira táctil de desplazamiento vertical con inercia háptica.
     */
    private class VerticalScrollStripView(
        context: Context,
        private val scrollDirection: String,
        private val onInteraction: () -> Unit,
        private val onScroll: (Float) -> Unit,
        private val onHapticTick: () -> Unit
    ) : View(context) {

        private val density = resources.displayMetrics.density
        private var lastTouchY = 0f
        private var accumulatedDelta = 0f

        private val isNight: Boolean
            get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        private val stripBgColor: Int
            get() = if (isNight) Color.parseColor("#1A1C1C1E") else Color.parseColor("#14000000")
        private val pressedBgColor: Int
            get() = if (isNight) Color.parseColor("#330A84FF") else Color.parseColor("#26007AFF")
        private val strokeColor: Int
            get() = if (isNight) Color.parseColor("#33FFFFFF") else Color.parseColor("#26000000")
        private val handleColor: Int
            get() = ContextCompat.getColor(context, R.color.kb_key_bg_accent)

        private val bgDrawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 12f * density
            setColor(stripBgColor)
            setStroke((1.2f * density).toInt(), strokeColor)
        }

        private val handlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2.5f * density
            strokeCap = Paint.Cap.ROUND
            color = handleColor
        }

        init {
            background = bgDrawable
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            handlePaint.color = handleColor
            val cx = width / 2f
            val cy = height / 2f
            val len = 12f * density
            canvas.drawLine(cx, cy - len, cx, cy + len, handlePaint)
            canvas.drawLine(cx - 5f * density, cy - 4f * density, cx, cy - len, handlePaint)
            canvas.drawLine(cx + 5f * density, cy - 4f * density, cx, cy - len, handlePaint)
            canvas.drawLine(cx - 5f * density, cy + 4f * density, cx, cy + len, handlePaint)
            canvas.drawLine(cx + 5f * density, cy + 4f * density, cx, cy + len, handlePaint)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            onInteraction()
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastTouchY = event.y
                    accumulatedDelta = 0f
                    bgDrawable.setColor(pressedBgColor)
                    bgDrawable.setStroke((1.5f * density).toInt(), handleColor)
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dy = event.y - lastTouchY
                    lastTouchY = event.y
                    val dirFactor = if (scrollDirection == "natural") -1f else 1f
                    val effectiveDy = dy * dirFactor
                    onScroll(effectiveDy)

                    accumulatedDelta += abs(dy)
                    if (accumulatedDelta > 16f * density) {
                        onHapticTick()
                        accumulatedDelta = 0f
                    }
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    bgDrawable.setColor(stripBgColor)
                    bgDrawable.setStroke((1.2f * density).toInt(), strokeColor)
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }
}
