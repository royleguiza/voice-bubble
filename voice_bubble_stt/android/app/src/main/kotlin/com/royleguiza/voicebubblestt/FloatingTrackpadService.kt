package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * Servicio de superposición local para la Burbuja Flotante de Trackpad Independiente (Mouse Virtual).
 *
 * Servicio NORMAL bajo demanda (START_NOT_STICKY, sin foreground, sin accesibilidad):
 * lo arranca quien lo necesita (MainActivity/DynamicIsland) y el sistema no lo
 * resucita solo si el proceso muere.
 *
 * Realidad del movimiento (perfil anti-Play-Protect, sin AccessibilityService
 * declarado): el puntero se mueve SOLO dentro de nuestro propio overlay
 * (PointerOverlayManager sobre TYPE_APPLICATION_OVERLAY) y los clics/scrolls
 * hacia otra app están dormidos — VoiceBubbleAccessibilityService.isConnected()
 * es siempre falso sin declaración en el manifest, así que dispatchTap/
 * dispatchLongPress/dispatchScroll son no-ops. Movimiento local sí, dispatch
 * en otra app no sin accesibilidad.
 *
 * Características (MEJ-09 / MEJORAS-SEPTIEMBRE):
 * - Rayita superior interactiva (drag handle):
 *   * 1 tap cierra / minimiza directamente.
 *   * Swipe-down cierra (o contrae si está extendido).
 *   * Swipe-up extiende la altura de 240dp a 380dp.
 * - Modo bimodal: Dock inferior y MiniPad flotante con snap a bordes.
 * - Soporte de distribución bimodal (Top 50/50 y Wings).
 * - Iconos de mouse limpios con CERO etiquetas de texto.
 * - Temas: Liquid Glass, Modo Oscuro, Modo Claro.
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas o eventos táctiles.
 */
class FloatingTrackpadService : Service() {

    companion object {
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP_TRACKPAD"
        const val ACTION_SHOW_DOCK = "com.royleguiza.voicebubblestt.ACTION_SHOW_DOCK"

        @Volatile
        var isRunning: Boolean = false
            private set

        private var instance: FloatingTrackpadService? = null

        fun start(context: Context) {
            val intent = Intent(context, FloatingTrackpadService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, FloatingTrackpadService::class.java)
            context.stopService(intent)
        }
    }

    private var windowManager: WindowManager? = null
    private var pointerManager: PointerOverlayManager? = null

    private var bubbleView: View? = null
    private lateinit var bubbleLayoutParams: WindowManager.LayoutParams

    private var expandedContainer: LinearLayout? = null
    private var trackpadView: VirtualTrackpadView? = null
    private lateinit var expandedLayoutParams: WindowManager.LayoutParams

    private var isExpanded = false
    private var currentMode = "dock" // "dock" o "minipad"
    private var isExtendedHeight = false
    private var snapAnimator: ValueAnimator? = null

    private val handler = Handler(Looper.getMainLooper())
    private val idleDimRunnable = Runnable {
        bubbleView?.animate()?.alpha(0.35f)?.setDuration(300L)?.start()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        pointerManager = PointerOverlayManager(this)

        setupBubbleView()
        setupExpandedView()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_SHOW_DOCK -> expandToDock()
        }
        // START_NOT_STICKY: servicio de UI bajo demanda, sin foreground ni
        // estado que rescatar. Si el proceso muere, el sistema NO lo resucita
        // solo (evita burbujas fantasma y loops de reinicio); quien lo necesite
        // (MainActivity/DynamicIsland) lo vuelve a arrancar explícitamente.
        return START_NOT_STICKY
    }

    private fun isNightMode(): Boolean {
        return (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    private fun setupBubbleView() {
        val wm = windowManager ?: return
        val density = resources.displayMetrics.density
        val bubbleSize = (52 * density).toInt()

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        bubbleLayoutParams = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (resources.displayMetrics.widthPixels - bubbleSize - (12 * density).toInt())
            y = (resources.displayMetrics.heightPixels * 0.52).toInt()
        }

        val bubble = FrameLayout(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                val isNight = isNightMode()
                setColor(if (isNight) Color.parseColor("#E61C1C1E") else Color.parseColor("#E6FFFFFF"))
                setStroke((1.5f * density).toInt(), Color.parseColor("#38BDF8"))
            }
            background = bg
            elevation = 6f * density

            val icon = ImageView(context).apply {
                try {
                    setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_trackpad))
                } catch (_: Throwable) {
                    try { setImageResource(R.drawable.ic_trackpad) } catch (_: Throwable) {}
                }
                setColorFilter(ContextCompat.getColor(context, R.color.kb_label))
                val pad = (12 * density).toInt()
                setPadding(pad, pad, pad, pad)
            }
            addView(
                icon,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )

            setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f
                private var isClick = false

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    resetIdleTimer()
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            initialX = bubbleLayoutParams.x
                            initialY = bubbleLayoutParams.y
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            isClick = true
                            v.animate().alpha(1.0f).setDuration(100L).start()
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dx = (event.rawX - initialTouchX).toInt()
                            val dy = (event.rawY - initialTouchY).toInt()
                            if (abs(dx) > 10 || abs(dy) > 10) {
                                isClick = false
                            }
                            bubbleLayoutParams.x = initialX + dx
                            bubbleLayoutParams.y = initialY + dy
                            try {
                                wm.updateViewLayout(bubbleView, bubbleLayoutParams)
                            } catch (_: Exception) {}
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            if (isClick) {
                                expandToDock()
                            } else {
                                snapBubbleToEdge()
                            }
                            return true
                        }
                    }
                    return false
                }
            })
        }

        bubbleView = bubble
        wm.addView(bubble, bubbleLayoutParams)
        resetIdleTimer()
    }

    private fun resetIdleTimer() {
        handler.removeCallbacks(idleDimRunnable)
        bubbleView?.alpha = 1.0f
        handler.postDelayed(idleDimRunnable, 4000L)
    }

    private fun snapBubbleToEdge() {
        val wm = windowManager ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val density = resources.displayMetrics.density
        val margin = (12 * density).toInt()
        val bubbleSize = bubbleView?.width ?: (52 * density).toInt()

        val targetX = if (bubbleLayoutParams.x + bubbleSize / 2 < screenWidth / 2) {
            margin
        } else {
            screenWidth - bubbleSize - margin
        }

        val startX = bubbleLayoutParams.x
        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(startX, targetX).apply {
            duration = 240L
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                bubbleLayoutParams.x = anim.animatedValue as Int
                try {
                    wm.updateViewLayout(bubbleView, bubbleLayoutParams)
                } catch (_: Exception) {}
            }
            start()
        }
    }

    private fun setupExpandedView() {
        val wm = windowManager ?: return
        val density = resources.displayMetrics.density
        val isNight = isNightMode()

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val standardH = (240 * density).toInt()
        expandedLayoutParams = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            standardH,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                setColor(if (isNight) Color.parseColor("#E6171A24") else Color.parseColor("#E6F2F4F8"))
                cornerRadii = floatArrayOf(
                    18f * density, 18f * density,
                    18f * density, 18f * density,
                    0f, 0f, 0f, 0f
                )
                setStroke((1.2f * density).toInt(), if (isNight) Color.parseColor("#33FFFFFF") else Color.parseColor("#26000000"))
            }
            background = bg
            elevation = 12f * density
        }

        // --- ZONA RAYITA INTERACTIVA SUPERIOR (DRAG HANDLE ZONE) ---
        val handleZone = FrameLayout(this).apply {
            val h = (28 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, h)

            // Rayita de cápsula central (44dp x 5dp)
            val rayita = View(context).apply {
                val rW = (44 * density).toInt()
                val rH = (5 * density).toInt()
                layoutParams = FrameLayout.LayoutParams(rW, rH).apply {
                    gravity = Gravity.CENTER
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 3f * density
                    setColor(if (isNight) Color.parseColor("#E6FFFFFF") else Color.parseColor("#CC1D1D1F"))
                }
            }
            addView(rayita)

            // GESTOS EN LA RAYITA:
            // 1. Toque simple (click): Cierra directamente (minimizeToBubble).
            // 2. Deslizar abajo: Cierra (o baja a estándar si estaba extendido).
            // 3. Deslizar arriba: Amplía a 380dp.
            // 4. En modo minipad: Mueve la ventana libremente en 2D por la pantalla.
            setOnTouchListener(object : View.OnTouchListener {
                private var startX = 0f
                private var startY = 0f
                private var initialX = 0
                private var initialY = 0
                private var startHeight = standardH
                private var didDrag = false
                private var wasExtended = false

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    when (event.actionMasked) {
                        MotionEvent.ACTION_DOWN -> {
                            startX = event.rawX
                            startY = event.rawY
                            initialX = expandedLayoutParams.x
                            initialY = expandedLayoutParams.y
                            startHeight = expandedLayoutParams.height
                            didDrag = false
                            wasExtended = isExtendedHeight || (startHeight > (280 * density).toInt())
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dx = (event.rawX - startX).toInt()
                            val dy = (event.rawY - startY).toInt()
                            if (abs(dx) > (6 * density) || abs(dy) > (6 * density)) {
                                didDrag = true
                            }

                            if (currentMode == "minipad") {
                                // En modo minipad permite mover la ventana flotante libremente en 2D
                                val screenW = resources.displayMetrics.widthPixels
                                val screenH = resources.displayMetrics.heightPixels
                                expandedLayoutParams.x = (initialX + dx).coerceIn(0, (screenW - expandedLayoutParams.width).coerceAtLeast(0))
                                expandedLayoutParams.y = (initialY + dy).coerceIn(0, (screenH - expandedLayoutParams.height).coerceAtLeast(0))
                                try {
                                    wm.updateViewLayout(expandedContainer, expandedLayoutParams)
                                } catch (_: Exception) {}
                                return true
                            }

                            // En modo dock:
                            if (wasExtended) {
                                // Arrastrar hacia abajo baja la altura
                                if (dy > 0) {
                                    val newH = (startHeight - dy).toInt().coerceAtLeast(standardH)
                                    expandedLayoutParams.height = newH
                                    try {
                                        wm.updateViewLayout(expandedContainer, expandedLayoutParams)
                                    } catch (_: Exception) {}
                                    // Swipe down profundo (> 70dp de exceso) cierra el trackpad
                                    if (dy > (startHeight - standardH + (70 * density))) {
                                        minimizeToBubble()
                                        return true
                                    }
                                }
                            } else {
                                // Modo estándar (240dp):
                                if (dy > 0) {
                                    // Arrastre hacia abajo: swipe-down cierra
                                    if (dy > (55 * density)) {
                                        minimizeToBubble()
                                        return true
                                    }
                                } else if (dy < 0) {
                                    // Arrastre hacia arriba: amplía la altura
                                    val maxH = (380 * density).toInt()
                                    val newH = (startHeight - dy).toInt().coerceAtMost(maxH)
                                    expandedLayoutParams.height = newH
                                    try {
                                        wm.updateViewLayout(expandedContainer, expandedLayoutParams)
                                    } catch (_: Exception) {}
                                }
                            }
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            if (!didDrag) {
                                // Toque simple en la rayita: cierra directamente
                                minimizeToBubble()
                                return true
                            }
                            if (currentMode == "minipad") {
                                return true
                            }
                            val dy = event.rawY - startY
                            if (wasExtended) {
                                if (dy > (30 * density)) {
                                    setExtendedHeight(false)
                                } else {
                                    setExtendedHeight(true)
                                }
                            } else {
                                if (dy > (20 * density)) {
                                    minimizeToBubble()
                                } else if (dy < -(25 * density)) {
                                    setExtendedHeight(true)
                                } else {
                                    setExtendedHeight(false)
                                }
                            }
                            return true
                        }
                    }
                    return false
                }
            })
        }
        container.addView(handleZone)

        // --- CUERPO: VirtualTrackpadView ---
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val scrollPos = prefs.getString("flutter.kb_trackpad_scroll_position", "right") ?: "right"
        val tapClick = prefs.getBoolean("flutter.kb_trackpad_tap_to_click", true)
        val secClick = prefs.getString("flutter.kb_trackpad_secondary_click", "2fingers") ?: "2fingers"
        val scrollDir = prefs.getString("flutter.kb_trackpad_scroll_direction", "natural") ?: "natural"
        val autoReturn = try {
            when (val raw = prefs.all["flutter.kb_trackpad_auto_return"]) {
                is Number -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
        val sens = try {
            when (val raw = prefs.all["flutter.kb_trackpad_sensitivity"]) {
                is Float -> raw
                is Double -> raw.toFloat()
                is Number -> raw.toFloat()
                is String -> raw.toFloatOrNull() ?: 1.2f
                else -> 1.2f
            }
        } catch (_: Exception) {
            1.2f
        }
        val accel = prefs.getString("flutter.kb_trackpad_accel_curve", "dynamic") ?: "dynamic"
        val style = prefs.getString("flutter.kb_trackpad_pointer_style", "arrow") ?: "arrow"
        // Contrato kb_trackpad_haptic: el lado Dart guarda String ("subtle"/"none"/"firm").
        // Leer con getString + default seguro: getBoolean lanzaría ClassCastException
        // cuando el valor almacenado es String. Solo estos tres valores son válidos.
        val hapticMode = try {
            (prefs.getString("flutter.kb_trackpad_haptic", "subtle") ?: "subtle").takeIf {
                it == "subtle" || it == "none" || it == "firm"
            } ?: "subtle"
        } catch (_: Exception) {
            "subtle"
        }
        val buttonLayout = prefs.getString("flutter.kb_trackpad_button_layout", "top") ?: "top"

        pointerManager?.apply {
            sensitivity = sens
            accelCurve = accel
            pointerStyle = style
        }

        val tpHeight = (208 * density).toInt()
        val tpView = VirtualTrackpadView(
            context = this,
            scrollPosition = scrollPos,
            tapToClick = tapClick,
            secondaryClickMode = secClick,
            scrollDirection = scrollDir,
            autoReturnSeconds = autoReturn,
            trackpadHeightPx = tpHeight,
            buttonLayout = buttonLayout,
            theme = "glass",
            listener = object : VirtualTrackpadView.TrackpadListener {
                override fun onPointerMove(dx: Float, dy: Float) {
                    pointerManager?.moveBy(dx, dy)
                }

                override fun onLeftClick() {
                    pointerManager?.triggerClickFeedback()
                    val pos = pointerManager?.getPosition() ?: return
                    VoiceBubbleAccessibilityService.dispatchTap(pos.first, pos.second)
                }

                override fun onRightClick() {
                    pointerManager?.triggerClickFeedback()
                    val pos = pointerManager?.getPosition() ?: return
                    VoiceBubbleAccessibilityService.dispatchLongPress(pos.first, pos.second)
                }

                override fun onScroll(deltaY: Float) {
                    val pos = pointerManager?.getPosition() ?: return
                    VoiceBubbleAccessibilityService.dispatchScroll(pos.first, pos.second, deltaY)
                }

                override fun onAutoReturn() {
                    minimizeToBubble()
                }

                override fun performHaptic(isFirm: Boolean) {
                    if (hapticMode == "none") return
                    val useFirm = isFirm || hapticMode == "firm"
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                        if (vibrator?.hasVibrator() == true) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val effect = if (useFirm) {
                                    VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
                                } else {
                                    VibrationEffect.createOneShot(18L, 90)
                                }
                                vibrator.vibrate(effect)
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(if (useFirm) 35L else 18L)
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        )
        container.addView(
            tpView,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1.0f)
        )

        trackpadView = tpView
        expandedContainer = container
    }

    private fun setExtendedHeight(extended: Boolean) {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return
        val density = resources.displayMetrics.density
        isExtendedHeight = extended

        val targetH = if (extended) (380 * density).toInt() else (240 * density).toInt()
        expandedLayoutParams.height = targetH

        if (currentMode == "dock") {
            pointerManager?.updateKeyboardTop(resources.displayMetrics.heightPixels.toFloat() - targetH)
        }

        try {
            wm.updateViewLayout(container, expandedLayoutParams)
        } catch (_: Exception) {}
    }

    fun expandToDock() {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return
        val density = resources.displayMetrics.density

        currentMode = "dock"
        val dockH = if (isExtendedHeight) (380 * density).toInt() else (240 * density).toInt()

        expandedLayoutParams.width = ViewGroup.LayoutParams.MATCH_PARENT
        expandedLayoutParams.height = dockH
        expandedLayoutParams.gravity = Gravity.BOTTOM
        expandedLayoutParams.x = 0
        expandedLayoutParams.y = 0

        pointerManager?.updateKeyboardTop(resources.displayMetrics.heightPixels.toFloat() - dockH)
        pointerManager?.show()

        if (!isExpanded) {
            wm.addView(container, expandedLayoutParams)
            isExpanded = true
        } else {
            wm.updateViewLayout(container, expandedLayoutParams)
        }

        bubbleView?.visibility = View.GONE
        handler.removeCallbacks(idleDimRunnable)
    }

    fun expandToMiniPad() {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return
        val density = resources.displayMetrics.density

        currentMode = "minipad"
        val padW = (280 * density).toInt()
        val padH = if (isExtendedHeight) (380 * density).toInt() else (240 * density).toInt()

        expandedLayoutParams.width = padW
        expandedLayoutParams.height = padH
        expandedLayoutParams.gravity = Gravity.TOP or Gravity.START
        expandedLayoutParams.x = (resources.displayMetrics.widthPixels - padW) / 2
        expandedLayoutParams.y = (resources.displayMetrics.heightPixels * 0.45).toInt()

        pointerManager?.resetBottomLimit()
        pointerManager?.show()

        if (!isExpanded) {
            wm.addView(container, expandedLayoutParams)
            isExpanded = true
        } else {
            wm.updateViewLayout(container, expandedLayoutParams)
        }

        bubbleView?.visibility = View.GONE
        handler.removeCallbacks(idleDimRunnable)
    }

    fun minimizeToBubble() {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return

        pointerManager?.hide()

        if (isExpanded) {
            try {
                wm.removeViewImmediate(container)
            } catch (_: Exception) {}
            isExpanded = false
        }

        bubbleView?.visibility = View.VISIBLE
        resetIdleTimer()
    }

    override fun onDestroy() {
        val wm = windowManager
        handler.removeCallbacks(idleDimRunnable)
        snapAnimator?.cancel()
        snapAnimator = null

        pointerManager?.destroy()
        pointerManager = null

        if (isExpanded && expandedContainer != null) {
            try {
                wm?.removeViewImmediate(expandedContainer)
            } catch (_: Exception) {}
            isExpanded = false
        }

        if (bubbleView != null) {
            try {
                wm?.removeViewImmediate(bubbleView)
            } catch (_: Exception) {}
            bubbleView = null
        }

        instance = null
        isRunning = false
        super.onDestroy()
    }
}
