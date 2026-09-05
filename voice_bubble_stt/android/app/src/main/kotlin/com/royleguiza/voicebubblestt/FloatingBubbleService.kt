package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class FloatingBubbleService : Service() {

    companion object {
        const val CHANNEL_ID = "voice_bubble_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP"
        private const val BUBBLE_LONG_PRESS_MS = 500L

        var isRunning: Boolean = false
            private set

        /** Ultimo estado visual reportado por la app (idle/recording/transcribing). */
        @Volatile
        var lastVisualState: String = "idle"
            private set

        var onBubbleActionListener: BubbleActionListener? = null

        /**
         * Isla exacta sobre cámara: cuando el AccessibilityService está activo,
         * él hospeda la isla con TYPE_ACCESSIBILITY_OVERLAY (por encima de la
         * status-bar, con touch). Este servicio conserva solo el FGS + routing.
         */
        @Volatile
        var accessibilityIsland: DynamicIslandController? = null

        fun updateState(state: String) {
            val acc = accessibilityIsland
            if (acc != null) {
                val prevState = lastVisualState
                lastVisualState = state
                instance?.bubbleView?.setState(state)
                when (state) {
                    "recording" -> acc.startRecordingUI()
                    "transcribing" -> acc.showProcessingUI()
                    "success" -> acc.showSuccessUI("")
                    "idle" -> {
                        if (prevState == "transcribing") {
                            acc.showSuccessUI("")
                        } else {
                            acc.collapseToCompact()
                        }
                    }
                    else -> acc.collapseToCompact()
                }
                return
            }
            val prevState = lastVisualState
            lastVisualState = state
            instance?.updateBubbleVisualState(state, prevState)
        }

        fun reloadIsland() {
            accessibilityIsland?.reloadConfiguration()
            instance?.dynamicIslandController?.reloadConfiguration()
        }

        /** Nivel real del mic (0..1) hacia la isla activa para la onda reactiva. */
        fun waveformLevel(level: Float) {
            try {
                accessibilityIsland?.setWaveformLevel(level)
            } catch (_: Exception) {}
            try {
                instance?.dynamicIslandController?.setWaveformLevel(level)
            } catch (_: Exception) {}
        }

        /** La isla de accesibilidad ya está activa: soltar el duplicado local. */
        fun dropLocalIsland() {
            instance?.releaseLocalIslandForAccessibility()
        }

        /** Accesibilidad desconectada: restaurar fallback local si corresponde. */
        fun restoreLocalIsland() {
            instance?.restoreLocalIslandIfNeeded()
        }

        private var instance: FloatingBubbleService? = null
    }

    interface BubbleActionListener {
        fun onBubbleTap()
        fun onBubbleClose()
        /** La ✕ de la isla descarta el audio: Dart debe detener y borrar, no transcribir. */
        fun onBubbleCancel()
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: BubbleCanvasView? = null
    private var dynamicIslandController: DynamicIslandController? = null
    private var bubbleHistoryController: BubbleHistoryController? = null
    private var snapAnimator: ValueAnimator? = null
    private lateinit var windowLayoutParams: WindowManager.LayoutParams
    private val uiHandler = Handler(Looper.getMainLooper())
    private var bubbleLongPress: Runnable? = null
    private var bubbleLongPressFired = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        createNotificationChannel()
        // Android 14+ exige declarar el tipo de FGS en tiempo de inicio para que
        // la burbuja mantenga acceso while-in-use al microfono en background.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification())
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val dockingMode = prefs.getString("flutter.bubble_docking_mode", null)
            ?: prefs.getString("bubble_docking_mode", "dynamic_island") ?: "dynamic_island"
        if (dockingMode == "classic_bubble") {
            setupBubbleView()
        } else {
            setupDynamicIsland()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        // START_NOT_STICKY: un FGS de microfono no debe resucitarse solo desde
        // el fondo (Android 14+); la burbuja se relanza desde la app.
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VoiceBubble Servicio Activo",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene activa la burbuja flotante de transcripción"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingOpenApp = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val stopIntent = Intent(this, FloatingBubbleService::class.java).apply {
            action = ACTION_STOP
        }
        val pendingStop = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("VoiceBubble STT")
            .setContentText("Burbuja flotante activa. Toca para transcribir.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingOpenApp)
            .setOngoing(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            builder.addAction(
                Notification.Action.Builder(
                    null,
                    "Cerrar",
                    pendingStop
                ).build()
            )
        }

        return builder.build()
    }

    private fun setupDynamicIsland() {
        // Si la accesibilidad puede hospedar la isla exacta sobre la cámara,
        // crearla ahí primero; si quedó activa, no duplicar la local.
        try {
            VoiceBubbleAccessibilityService.ensureIsland()
        } catch (_: Exception) {}
        if (accessibilityIsland != null) return
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        dynamicIslandController = DynamicIslandController(
            context = this,
            windowManager = windowManager!!,
            onMicTap = {
                onBubbleActionListener?.onBubbleTap()
            },
            onCancelRecording = {
                updateState("idle")
                try {
                    onBubbleActionListener?.onBubbleCancel()
                } catch (_: Exception) {}
            },
            onStopRecording = {
                onBubbleActionListener?.onBubbleTap()
            }
        )
    }

    /** Suelta la isla local sin detener el FGS (la accesibilidad toma el relevo). */
    fun releaseLocalIslandForAccessibility() {
        try {
            dynamicIslandController?.destroy()
        } catch (_: Exception) {}
        dynamicIslandController = null
    }

    /** Recrea el fallback local si no hay isla de accesibilidad activa. */
    fun restoreLocalIslandIfNeeded() {
        try {
            if (dynamicIslandController != null) return
            if (accessibilityIsland != null) return
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val dockingMode = prefs.getString("flutter.bubble_docking_mode", null)
                ?: prefs.getString("bubble_docking_mode", "dynamic_island") ?: "dynamic_island"
            if (dockingMode == "classic_bubble") return
            setupDynamicIsland()
        } catch (_: Exception) {}
    }

    private fun setupBubbleView() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = resources.displayMetrics.density
        val bubbleSize = (64 * density).toInt()

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        windowLayoutParams = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (resources.displayMetrics.widthPixels - bubbleSize - (16 * density).toInt())
            y = (resources.displayMetrics.heightPixels * 0.45).toInt()
        }

        bubbleView = BubbleCanvasView(this).apply {
            setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f
                private var isClick = false

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            initialX = windowLayoutParams.x
                            initialY = windowLayoutParams.y
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            isClick = true
                            bubbleLongPressFired = false
                            // Toque largo en reposo = historial (el toque
                            // simple siempre graba/detiene en la burbuja).
                            val r = Runnable {
                                if (isClick && !bubbleLongPressFired &&
                                    lastVisualState == "idle" &&
                                    bubbleHistoryController?.isOpen() != true
                                ) {
                                    bubbleLongPressFired = true
                                    isClick = false
                                    showBubbleHistory()
                                }
                            }
                            bubbleLongPress = r
                            uiHandler.postDelayed(r, BUBBLE_LONG_PRESS_MS)
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dx = (event.rawX - initialTouchX).toInt()
                            val dy = (event.rawY - initialTouchY).toInt()
                            if (abs(dx) > 10 || abs(dy) > 10) {
                                isClick = false
                                bubbleLongPress?.let { uiHandler.removeCallbacks(it) }
                                bubbleLongPress = null
                            }
                            windowLayoutParams.x = initialX + dx
                            windowLayoutParams.y = initialY + dy
                            windowManager?.updateViewLayout(bubbleView, windowLayoutParams)
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            bubbleLongPress?.let { uiHandler.removeCallbacks(it) }
                            bubbleLongPress = null
                            if (bubbleLongPressFired) {
                                bubbleLongPressFired = false
                                return true
                            }
                            if (isClick) {
                                onBubbleActionListener?.onBubbleTap()
                            } else {
                                snapToNearestEdge()
                            }
                            return true
                        }
                        MotionEvent.ACTION_CANCEL -> {
                            bubbleLongPress?.let { uiHandler.removeCallbacks(it) }
                            bubbleLongPress = null
                            bubbleLongPressFired = false
                            return true
                        }
                    }
                    return false
                }
            })
        }

        windowManager?.addView(bubbleView, windowLayoutParams)
    }

    /** Modal de historial anclada a la burbuja clásica (hito B1–B7). */
    fun showBubbleHistory() {
        try {
            if (bubbleView == null || bubbleHistoryController?.isOpen() == true) return
            if (!BubbleHistoryController.isEnabled(this)) return
            val wm = windowManager ?: return
            val density = resources.displayMetrics.density
            val size = (64 * density).toInt()
            var controller = bubbleHistoryController
            if (controller == null) {
                controller = BubbleHistoryController(
                    context = this,
                    windowManager = wm,
                    onMicTap = {
                        try {
                            bubbleHistoryController?.close()
                        } catch (_: Exception) {}
                        try {
                            onBubbleActionListener?.onBubbleTap()
                        } catch (_: Exception) {}
                    },
                    onClosed = {
                        try {
                            bubbleView?.visibility = View.VISIBLE
                        } catch (_: Exception) {}
                    }
                )
                bubbleHistoryController = controller
            }
            bubbleView?.visibility = View.GONE
            controller.showFrom(windowLayoutParams.x, windowLayoutParams.y, size)
        } catch (_: Exception) {
            try {
                bubbleView?.visibility = View.VISIBLE
            } catch (_: Exception) {}
        }
    }

    private fun snapToNearestEdge() {
        val screenWidth = resources.displayMetrics.widthPixels
        val density = resources.displayMetrics.density
        val margin = (12 * density).toInt()
        val bubbleSize = bubbleView?.width ?: (64 * density).toInt()

        val targetX = if (windowLayoutParams.x + bubbleSize / 2 < screenWidth / 2) {
            margin
        } else {
            screenWidth - bubbleSize - margin
        }

        val startX = windowLayoutParams.x
        val animator = ValueAnimator.ofInt(startX, targetX).apply {
            duration = 240
            interpolator = DecelerateInterpolator()
            addUpdateListener { animation ->
                windowLayoutParams.x = animation.animatedValue as Int
                windowManager?.updateViewLayout(bubbleView, windowLayoutParams)
            }
        }
        snapAnimator = animator
        animator.start()
    }

    fun updateBubbleVisualState(state: String, prevState: String = lastVisualState) {
        bubbleView?.setState(state)
        when (state) {
            "recording" -> dynamicIslandController?.startRecordingUI()
            "transcribing" -> dynamicIslandController?.showProcessingUI()
            "success" -> dynamicIslandController?.showSuccessUI("")
            "idle" -> {
                if (prevState == "transcribing") {
                    dynamicIslandController?.showSuccessUI("")
                } else {
                    dynamicIslandController?.collapseToCompact()
                }
            }
            else -> dynamicIslandController?.collapseToCompact()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cancelar antes de remover la vista: un frame pendiente del animator
        // sobre una vista desasociada lanza IllegalArgumentException.
        snapAnimator?.cancel()
        snapAnimator = null
        isRunning = false

        dynamicIslandController?.destroy()
        dynamicIslandController = null

        try {
            bubbleHistoryController?.destroy()
        } catch (_: Exception) {}
        bubbleHistoryController = null

        if (bubbleView != null && windowManager != null) {
            try {
                windowManager?.removeView(bubbleView)
            } catch (_: Exception) {}
            bubbleView = null
        }
        // La isla pertenece a la burbuja: al detenerse se va con ella.
        // instance=null ANTES para que el teardown no restaure el fallback local.
        instance = null
        try {
            VoiceBubbleAccessibilityService.removeIsland()
        } catch (_: Exception) {}
        onBubbleActionListener?.onBubbleClose()
    }

    class BubbleCanvasView(context: Context) : View(context) {
        // Paleta via tokens R.color (claro/noche); resolver UNA vez, no por frame.
        private val accentColor = ContextCompat.getColor(context, R.color.kb_key_bg_accent)
        private val recordingColor = ContextCompat.getColor(context, R.color.kb_recording)
        private val recordingBgColor = ContextCompat.getColor(context, R.color.bubble_recording_bg)
        private val transcribingBgColor = ContextCompat.getColor(context, R.color.bubble_transcribing_bg)
        private val idleBgColor = ContextCompat.getColor(context, R.color.bubble_idle_bg)
        private val idleBorderColor = ContextCompat.getColor(context, R.color.bubble_idle_border)
        private val activeBorderColor = ContextCompat.getColor(context, R.color.bubble_active_border)

        private var visualState = "idle"
        private var spinnerAngle = 0f
        private var pulsePhase = 0f

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 2f * resources.displayMetrics.density
        }
        private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.WHITE
        }
        private val spinnerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3.5f * resources.displayMetrics.density
            strokeCap = Paint.Cap.ROUND
            color = Color.WHITE
        }
        private val pulsePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f * resources.displayMetrics.density
            color = recordingColor
        }

        init {
            postInvalidateOnAnimation()
        }

        fun setState(state: String) {
            visualState = state
            invalidate()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val radius = cx.coerceAtMost(cy) - (4f * resources.displayMetrics.density)

            when (visualState) {
                "recording" -> {
                    bgPaint.color = recordingBgColor
                    borderPaint.color = activeBorderColor
                    canvas.drawCircle(cx, cy, radius, bgPaint)
                    canvas.drawCircle(cx, cy, radius, borderPaint)

                    pulsePhase += 0.08f
                    val pulseScale = 1.0f + 0.12f * (0.5f + 0.5f * sin(pulsePhase))
                    val pulseAlpha = (180 * (1f - (pulseScale - 1f) / 0.12f)).toInt().coerceIn(0, 255)
                    pulsePaint.alpha = pulseAlpha
                    canvas.drawCircle(cx, cy, radius * pulseScale, pulsePaint)

                    val stopSize = radius * 0.45f
                    val stopRect = RectF(cx - stopSize, cy - stopSize, cx + stopSize, cy + stopSize)
                    iconPaint.color = Color.WHITE
                    canvas.drawRoundRect(stopRect, 4f * resources.displayMetrics.density, 4f * resources.displayMetrics.density, iconPaint)
                    postInvalidateOnAnimation()
                }
                "transcribing" -> {
                    bgPaint.color = transcribingBgColor
                    borderPaint.color = activeBorderColor
                    canvas.drawCircle(cx, cy, radius, bgPaint)
                    canvas.drawCircle(cx, cy, radius, borderPaint)

                    spinnerAngle = (spinnerAngle + 7f) % 360f
                    val spinnerRadius = radius * 0.52f
                    val spinnerRect = RectF(cx - spinnerRadius, cy - spinnerRadius, cx + spinnerRadius, cy + spinnerRadius)
                    canvas.drawArc(spinnerRect, spinnerAngle, 280f, false, spinnerPaint)
                    postInvalidateOnAnimation()
                }
                else -> {
                    bgPaint.color = idleBgColor
                    borderPaint.color = idleBorderColor
                    canvas.drawCircle(cx, cy, radius, bgPaint)
                    canvas.drawCircle(cx, cy, radius, borderPaint)

                    drawMicIcon(canvas, cx, cy, radius * 0.45f)
                }
            }
        }

        private fun drawMicIcon(canvas: Canvas, cx: Float, cy: Float, size: Float) {
            iconPaint.color = accentColor
            val density = resources.displayMetrics.density

            val capsuleWidth = size * 0.48f
            val capsuleHeight = size * 0.95f
            val capsuleRect = RectF(
                cx - capsuleWidth / 2f,
                cy - capsuleHeight / 2f - size * 0.15f,
                cx + capsuleWidth / 2f,
                cy + capsuleHeight / 2f - size * 0.15f
            )
            canvas.drawRoundRect(capsuleRect, capsuleWidth / 2f, capsuleWidth / 2f, iconPaint)

            val arcPaint = Paint(iconPaint).apply {
                style = Paint.Style.STROKE
                strokeWidth = 2f * density
                strokeCap = Paint.Cap.ROUND
            }
            val arcRadius = capsuleWidth * 0.85f
            val arcRect = RectF(
                cx - arcRadius,
                cy - capsuleHeight * 0.15f,
                cx + arcRadius,
                cy + capsuleHeight * 0.55f
            )
            canvas.drawArc(arcRect, 0f, 180f, false, arcPaint)

            val baseTopY = cy + capsuleHeight * 0.55f
            val baseBottomY = baseTopY + size * 0.35f
            canvas.drawLine(cx, baseTopY, cx, baseBottomY, arcPaint)
            val baseFootWidth = size * 0.45f
            canvas.drawLine(cx - baseFootWidth / 2f, baseBottomY, cx + baseFootWidth / 2f, baseBottomY, arcPaint)
        }
    }
}
