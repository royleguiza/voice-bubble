package com.royleguiza.voicebubblestt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import android.view.WindowManager

/**
 * Servicio en primer plano (micrófono) de la barra flotante. La UI (barra en
 * el borde o burbuja, con micrófono y puntero) vive en [DockController]; acá
 * quedan la notificación, el historial y el puente con Dart.
 */
class FloatingBubbleService : Service() {

    companion object {
        const val CHANNEL_ID = "voice_bubble_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP"

        var isRunning: Boolean = false
            private set

        /** Ultimo estado visual reportado por la app (idle/recording/transcribing). */
        @Volatile
        var lastVisualState: String = "idle"
            private set

        var onBubbleActionListener: BubbleActionListener? = null

        fun updateState(state: String) {
            val svc = instance
            if (svc == null) {
                // Sin servicio vivo no hay nada que animar: normalizar a idle en
                // vez de retener un estado que dejaría un BUSY zombi visible
                // vía bubbleBusy() en el teclado (M-7).
                lastVisualState = "idle"
                return
            }
            lastVisualState = state
            svc.updateBubbleVisualState(state)
        }

        private var instance: FloatingBubbleService? = null

        /** El trackpad flotante se abrió/cerró: la burbuja se esconde mientras está abierto. */
        fun setTrackpadOpen(open: Boolean) {
            instance?.dock?.setTrackpadOpen(open)
        }

        /** Ajustes cambió forma o herramientas: redibujar la barra viva. */
        fun reloadDock(): Boolean {
            val svc = instance ?: return false
            svc.reloadDock()
            return true
        }
    }

    interface BubbleActionListener {
        fun onBubbleTap()
        fun onBubbleClose()
    }

    private var windowManager: WindowManager? = null
    private var dock: DockController? = null
    private var bubbleHistoryController: BubbleHistoryController? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        // Encarnación nueva = visual idle: sin este reset un "recording"
        // retenido de una vida anterior deja un BUSY zombi (M-7).
        lastVisualState = "idle"
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

        // Causa raíz del NPE histórico (windowManager!!): resolver el servicio
        // UNA vez acá con cast seguro. Si es null o el setup falla, abortar
        // limpiamente sin dejar isRunning colgado (Dart relee isBubbleRunning).
        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        if (wm == null) {
            abortStartup()
            return
        }
        windowManager = wm
        isRunning = true
        try {
            setupBubbleView()
        } catch (_: Exception) {
            abortStartup()
        }
    }

    /**
     * Apagado limpio de un arranque fallido: suelta lo creado, baja
     * isRunning/instance y detiene el servicio. Sin esto el teclado leía
     * bubbleBusy() con una burbuja que jamás mostró nada.
     */
    private fun abortStartup() {
        try {
            dock?.destroy()
        } catch (_: Exception) {}
        dock = null
        windowManager = null
        lastVisualState = "idle"
        isRunning = false
        instance = null
        try {
            stopSelf()
        } catch (_: Exception) {}
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

    private fun setupBubbleView() {
        dock = DockController(this, object : DockController.Callbacks {
            override fun onMicTap() {
                onBubbleActionListener?.onBubbleTap()
            }

            override fun onPointerTap(anchorX: Int, anchorY: Int) {
                try {
                    FloatingTrackpadService.open(this@FloatingBubbleService, anchorX, anchorY)
                } catch (_: Exception) {}
            }

            override fun onHistoryRequested(x: Int, y: Int, size: Int): Boolean =
                showBubbleHistory(x, y, size)
        }).also { it.start() }
    }

    /** Ajustes cambió forma o herramientas de la barra. */
    fun reloadDock() {
        dock?.reloadPrefs()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        try {
            dock?.onConfigurationChanged()
        } catch (_: Exception) {}
    }

    /** Modal de historial anclada a la barra/burbuja (hito B1–B7). */
    private fun showBubbleHistory(x: Int, y: Int, size: Int): Boolean {
        try {
            if (dock == null || bubbleHistoryController?.isOpen() == true) return false
            if (!BubbleHistoryController.isEnabled(this)) return false
            val wm = windowManager ?: return false
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
                            dock?.setHidden(false)
                        } catch (_: Exception) {}
                    }
                )
                bubbleHistoryController = controller
            }
            dock?.setHidden(true)
            controller.showFrom(x, y, size)
            return true
        } catch (_: Exception) {
            try {
                dock?.setHidden(false)
            } catch (_: Exception) {}
            return false
        }
    }

    fun updateBubbleVisualState(state: String) {
        dock?.setDictationState(state)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        lastVisualState = "idle"

        try {
            bubbleHistoryController?.destroy()
        } catch (_: Exception) {}
        bubbleHistoryController = null

        try {
            dock?.destroy()
        } catch (_: Exception) {}
        dock = null
        instance = null
        onBubbleActionListener?.onBubbleClose()
    }
}
