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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.WindowManager

/**
 * Servicio en primer plano (micrófono) de la barra flotante. La UI (barra en
 * el borde o burbuja, con micrófono y puntero) vive en [DockController]; acá
 * quedan la notificación, el historial y el puente con Dart.
 *
 * Desde la fase 2A es el RESPALDO de la barra: con el complemento VoiceBubble
 * Puntero activo, la barra la dibuja él (ventanas de Accesibilidad que Android
 * mantiene vivas) y esta se esconde ([DockController.setSuppressed]) para que
 * nunca se vean dos. Sin complemento, o si deja de dibujar, funciona como siempre.
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

        /** Cada cuánto se repite el estado hacia la barra del complemento mientras dura un dictado de la app. */
        private const val MIRROR_REPEAT_MS = 1500L

        /** Plazo para que el complemento conteste que dibuja la barra antes de mostrar la de respaldo. */
        private const val COMPLEMENT_ANSWER_MS = 1200L

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
    private val handler = Handler(Looper.getMainLooper())

    /** Esperando la respuesta del complemento: mientras tanto la barra de respaldo no se muestra. */
    private var waitingComplement = false
    private val complementTimeout = Runnable {
        // Activado en Accesibilidad pero sin contestar: la barra de respaldo es la que vale.
        waitingComplement = false
        applySuppression()
    }

    /** Repite el estado del dictado de la app hacia la barra del complemento (si no, su vigilante lo daría por perdido). */
    private val mirrorRepeat = object : Runnable {
        override fun run() {
            if (!DockLink.complementDrawing || !isBusyState(lastVisualState)) return
            mirrorStateToComplement(lastVisualState)
            handler.postDelayed(this, MIRROR_REPEAT_MS)
        }
    }

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
            return
        }
        // El trackpad del complemento avisa cuando se abre o se cierra: la burbuja se esconde mientras tanto.
        PointerLink.listenTrackpadState(this) { open ->
            // Si el complemento contestó tarde y ya se había abierto el trackpad de
            // respaldo, se cierra: nunca dos trackpads a la vez.
            if (open) FloatingTrackpadService.stop(this)
            dock?.setTrackpadOpen(open)
        }
        syncWithComplement()
    }

    /**
     * Fase 2A: si el complemento está activo, él dibuja la barra. Se le manda la
     * configuración (la barra está encendida: este servicio vive para eso) y
     * hasta que conteste esta barra queda escondida: así nunca hay dos. Si no
     * contesta a tiempo, o dice que no dibuja, se muestra la de respaldo.
     */
    private fun syncWithComplement() {
        DockLink.onDrawingChanged = { drawing ->
            handler.removeCallbacks(complementTimeout)
            waitingComplement = false
            applySuppression()
            if (drawing) mirrorStateToComplement(lastVisualState)
        }
        if (PointerLink.isReady(this) && DockLink.sendConfig(this, enabledOverride = true, ack = true)) {
            waitingComplement = true
            applySuppression()
            handler.postDelayed(complementTimeout, COMPLEMENT_ANSWER_MS)
        } else {
            applySuppression()
        }
    }

    /** La barra de respaldo se esconde si el complemento dibuja (o está por contestar). */
    private fun applySuppression() {
        dock?.setSuppressed(DockLink.complementDrawing || waitingComplement)
    }

    private fun isBusyState(state: String) = state == "recording" || state == "transcribing"

    /**
     * El dictado de la app (Flutter) también se ve en la barra del complemento.
     * Si el servicio nativo de la barra está dictando, él cuenta su propio estado.
     */
    private fun mirrorStateToComplement(state: String) {
        if (!DockLink.complementDrawing || DockDictationService.isActive) return
        val mic = when (state) {
            "recording" -> PointerProtocol.MIC_RECORDING
            "transcribing" -> PointerProtocol.MIC_TRANSCRIBING
            else -> PointerProtocol.MIC_IDLE
        }
        DockLink.sendMicState(this, mic)
        handler.removeCallbacks(mirrorRepeat)
        if (isBusyState(state)) handler.postDelayed(mirrorRepeat, MIRROR_REPEAT_MS)
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
        val initiallySuppressed = DockLink.complementDrawing
        dock = DockController(this, object : DockController.Callbacks {
            override fun onMicTap() {
                onBubbleActionListener?.onBubbleTap()
            }

            override fun onPointerTap(anchorX: Int, anchorY: Int) {
                try {
                    // Primero el trackpad del complemento (por encima de todo); si no
                    // está listo, el de siempre, que explica qué falta instalar o activar.
                    val fallback = { FloatingTrackpadService.open(this@FloatingBubbleService, anchorX, anchorY) }
                    if (!PointerLink.openTrackpad(this@FloatingBubbleService, anchorX, anchorY, onNoAnswer = fallback)) {
                        fallback()
                    }
                } catch (_: Exception) {}
            }

            override fun onHistoryRequested(x: Int, y: Int, size: Int): Boolean =
                showBubbleHistory(x, y, size)
        }).also {
            // Antes de crear las ventanas: si el complemento ya dibuja, esta no llega a verse.
            it.setSuppressed(initiallySuppressed || PointerLink.isReady(this))
            it.start()
        }
    }

    /** Ajustes cambió forma o herramientas de la barra. */
    fun reloadDock() {
        dock?.reloadPrefs()
        DockLink.sendConfig(this, enabledOverride = true, ack = false)
    }

    /** Apagar la barra del complemento al cerrar este servicio, y que no vuelva sola tras reiniciar. */
    private fun closeComplementDock() {
        try {
            getSharedPreferences(FlutterPrefs.PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(FlutterPrefs.key("floating_bubble_enabled"), false).apply()
        } catch (_: Exception) {}
        DockLink.sendConfig(this, enabledOverride = false, ack = true)
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
        mirrorStateToComplement(state)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        lastVisualState = "idle"

        PointerLink.stopListeningTrackpadState(this)
        handler.removeCallbacksAndMessages(null)
        DockLink.onDrawingChanged = null
        // Se cerró la barra (Cerrar en la notificación o Ajustes): el complemento también la saca.
        // Si el sistema mata el proceso esto no corre, y la barra del complemento sigue (es lo que queremos).
        closeComplementDock()
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
