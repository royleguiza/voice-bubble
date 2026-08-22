package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

class FloatingBubbleService : Service() {

    companion object {
        const val CHANNEL_ID = "voice_bubble_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP"

        var isRunning: Boolean = false
            private set

        var onBubbleActionListener: BubbleActionListener? = null

        fun updateState(state: String) {
            instance?.updateBubbleVisualState(state)
        }

        private var instance: FloatingBubbleService? = null
    }

    interface BubbleActionListener {
        fun onBubbleTap()
        fun onBubbleClose()
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: BubbleCanvasView? = null
    private lateinit var windowLayoutParams: WindowManager.LayoutParams

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        setupBubbleView()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
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
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dx = (event.rawX - initialTouchX).toInt()
                            val dy = (event.rawY - initialTouchY).toInt()
                            if (abs(dx) > 10 || abs(dy) > 10) {
                                isClick = false
                            }
                            windowLayoutParams.x = initialX + dx
                            windowLayoutParams.y = initialY + dy
                            windowManager?.updateViewLayout(bubbleView, windowLayoutParams)
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            if (isClick) {
                                onBubbleActionListener?.onBubbleTap()
                            } else {
                                snapToNearestEdge()
                            }
                            return true
                        }
                    }
                    return false
                }
            })
        }

        windowManager?.addView(bubbleView, windowLayoutParams)
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
        animator.start()
    }

    fun updateBubbleVisualState(state: String) {
        bubbleView?.setState(state)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        if (bubbleView != null && windowManager != null) {
            try {
                windowManager?.removeView(bubbleView)
            } catch (_: Exception) {}
            bubbleView = null
        }
        onBubbleActionListener?.onBubbleClose()
        instance = null
    }

    class BubbleCanvasView(context: Context) : View(context) {
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
            color = Color.parseColor("#FFFF3B30")
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
                    bgPaint.color = Color.parseColor("#E6FF3B30")
                    borderPaint.color = Color.parseColor("#80FFFFFF")
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
                    bgPaint.color = Color.parseColor("#D9007AFF")
                    borderPaint.color = Color.parseColor("#80FFFFFF")
                    canvas.drawCircle(cx, cy, radius, bgPaint)
                    canvas.drawCircle(cx, cy, radius, borderPaint)

                    spinnerAngle = (spinnerAngle + 7f) % 360f
                    val spinnerRadius = radius * 0.52f
                    val spinnerRect = RectF(cx - spinnerRadius, cy - spinnerRadius, cx + spinnerRadius, cy + spinnerRadius)
                    canvas.drawArc(spinnerRect, spinnerAngle, 280f, false, spinnerPaint)
                    postInvalidateOnAnimation()
                }
                else -> {
                    bgPaint.color = Color.parseColor("#CC1C1C1E")
                    borderPaint.color = Color.parseColor("#4DFFFFFF")
                    canvas.drawCircle(cx, cy, radius, bgPaint)
                    canvas.drawCircle(cx, cy, radius, borderPaint)

                    drawMicIcon(canvas, cx, cy, radius * 0.45f)
                }
            }
        }

        private fun drawMicIcon(canvas: Canvas, cx: Float, cy: Float, size: Float) {
            iconPaint.color = Color.parseColor("#0A84FF")
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
