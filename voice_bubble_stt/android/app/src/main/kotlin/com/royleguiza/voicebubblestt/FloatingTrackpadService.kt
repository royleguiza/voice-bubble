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
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * Servicio de superposicion para la Burbuja Flotante de Trackpad Independiente (Mouse Virtual).
 *
 * Permite utilizar un mouse virtual en cualquier aplicacion o pantalla de Android
 * sin depender de un cuadro de texto (EditText) ni del teclado del sistema.
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni persistencia de coordenadas o eventos tactiles.
 */
class FloatingTrackpadService : Service() {

    companion object {
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP_TRACKPAD"
        const val ACTION_SHOW_DOCK = "com.royleguiza.voicebubblestt.ACTION_SHOW_DOCK"
        const val ACTION_SHOW_MINIPAD = "com.royleguiza.voicebubblestt.ACTION_SHOW_MINIPAD"

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

        fun showDock() {
            instance?.expandToDock()
        }

        fun showMiniPad() {
            instance?.expandToMiniPad()
        }

        fun minimize() {
            instance?.minimizeToBubble()
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
            ACTION_SHOW_MINIPAD -> expandToMiniPad()
        }
        return START_STICKY
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
                setImageResource(R.drawable.ic_trackpad)
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
        ValueAnimator.ofInt(startX, targetX).apply {
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

        val dockH = (246 * density).toInt() // 36dp header + 210dp trackpad
        expandedLayoutParams = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dockH,
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
                setColor(if (isNight) Color.parseColor("#F21C1C1E") else Color.parseColor("#F2F2F2F7"))
                cornerRadii = floatArrayOf(
                    16f * density, 16f * density,
                    16f * density, 16f * density,
                    0f, 0f, 0f, 0f
                )
                setStroke((1.2f * density).toInt(), if (isNight) Color.parseColor("#33FFFFFF") else Color.parseColor("#26000000"))
            }
            background = bg
            elevation = 12f * density
        }

        // --- Barra Superior / Header (36dp) ---
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val headerH = (36 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, headerH)
            setPadding((8 * density).toInt(), 0, (8 * density).toInt(), 0)

            // Boton Minimizar [—]
            val btnMin = TextView(context).apply {
                text = "—"
                textSize = 18f
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                val w = (36 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(w, w)
                setOnClickListener {
                    minimizeToBubble()
                }
            }
            addView(btnMin)

            // Boton Alternar Modo [⇄ Dock / Pad]
            val btnToggleMode = TextView(context).apply {
                text = "⇄ MiniPad"
                textSize = 12f
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(context, R.color.kb_key_bg_accent))
                setPadding((6 * density).toInt(), (4 * density).toInt(), (6 * density).toInt(), (4 * density).toInt())
                setOnClickListener {
                    toggleMode()
                    text = if (currentMode == "dock") "⇄ MiniPad" else "⇄ Dock"
                }
            }
            addView(btnToggleMode)

            // Titulo / Drag Handle Central
            val title = TextView(context).apply {
                text = "MOUSE VIRTUAL"
                textSize = 11f
                gravity = Gravity.CENTER
                setTextColor(if (isNight) Color.parseColor("#8E8E93") else Color.parseColor("#6C6C70"))
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            }
            addView(title)

            // Drag handle para mover en modo minipad
            setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var touchX = 0f
                private var touchY = 0f

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    if (currentMode != "minipad") return false
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            initialX = expandedLayoutParams.x
                            initialY = expandedLayoutParams.y
                            touchX = event.rawX
                            touchY = event.rawY
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            expandedLayoutParams.x = initialX + (event.rawX - touchX).toInt()
                            expandedLayoutParams.y = initialY + (event.rawY - touchY).toInt()
                            try {
                                wm.updateViewLayout(expandedContainer, expandedLayoutParams)
                            } catch (_: Exception) {}
                            return true
                        }
                    }
                    return false
                }
            })

            // Boton Cerrar [✕]
            val btnClose = TextView(context).apply {
                text = "✕"
                textSize = 16f
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                val w = (36 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(w, w)
                setOnClickListener {
                    stopSelf()
                }
            }
            addView(btnClose)
        }
        container.addView(header)

        // --- Cuerpo: VirtualTrackpadView ---
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val scrollPos = prefs.getString("flutter.kb_trackpad_scroll_position", "right") ?: "right"
        val tapClick = prefs.getBoolean("flutter.kb_trackpad_tap_to_click", true)
        val secClick = prefs.getString("flutter.kb_trackpad_secondary_click", "2fingers") ?: "2fingers"
        val scrollDir = prefs.getString("flutter.kb_trackpad_scroll_direction", "natural") ?: "natural"
        val autoReturn = when (val raw = prefs.all["flutter.kb_trackpad_auto_return"]) {
            is Int -> raw
            is Long -> raw.toInt()
            else -> 0
        }
        val sens = try {
            prefs.getFloat("flutter.kb_trackpad_sensitivity", 1.2f)
        } catch (_: Exception) {
            1.2f
        }
        val accel = prefs.getString("flutter.kb_trackpad_accel_curve", "dynamic") ?: "dynamic"
        val style = prefs.getString("flutter.kb_trackpad_pointer_style", "arrow") ?: "arrow"
        val hapticEnabled = prefs.getBoolean("flutter.kb_trackpad_haptic", true)

        pointerManager?.apply {
            sensitivity = sens
            accelCurve = accel
            pointerStyle = style
        }

        val tpHeight = (210 * density).toInt()
        val tpView = VirtualTrackpadView(
            context = this,
            scrollPosition = scrollPos,
            tapToClick = tapClick,
            secondaryClickMode = secClick,
            scrollDirection = scrollDir,
            autoReturnSeconds = autoReturn,
            trackpadHeightPx = tpHeight,
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
                    if (!hapticEnabled) return
                    try {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                        if (vibrator?.hasVibrator() == true) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val effect = if (isFirm) {
                                    VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
                                } else {
                                    VibrationEffect.createOneShot(18L, 90)
                                }
                                vibrator.vibrate(effect)
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(if (isFirm) 35L else 18L)
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        )
        container.addView(
            tpView,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, tpHeight)
        )

        trackpadView = tpView
        expandedContainer = container
    }

    private fun expandToDock() {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return
        val density = resources.displayMetrics.density

        currentMode = "dock"
        val dockH = (246 * density).toInt()

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

    private fun expandToMiniPad() {
        val wm = windowManager ?: return
        val container = expandedContainer ?: return
        val density = resources.displayMetrics.density

        currentMode = "minipad"
        val padW = (260 * density).toInt()
        val padH = (246 * density).toInt()

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

    private fun toggleMode() {
        if (currentMode == "dock") {
            expandToMiniPad()
        } else {
            expandToDock()
        }
    }

    private fun minimizeToBubble() {
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
