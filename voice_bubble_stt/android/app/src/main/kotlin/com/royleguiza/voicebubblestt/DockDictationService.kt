package com.royleguiza.voicebubblestt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Dictado NATIVO de la barra flotante (fase 2A), sin Flutter: graba, transcribe
 * y deja el resultado como lo deja la burbuja de siempre (historial nativo +
 * portapapeles, y pegado si el teclado activo es el de VoiceBubble). Así tocar
 * el micrófono de la barra del complemento dicta aunque VoiceBubble esté cerrada.
 *
 * - Servicio en primer plano (micrófono), modelado sobre [WidgetDictationService].
 *   Exportado SOLO para quien tenga el permiso de firma del puntero (manifiesto):
 *   lo arranca el complemento, que tiene una ventana visible (eso habilita el
 *   micrófono «mientras se usa»). Si Android igual lo niega al hacer
 *   `startForeground`, avisa con `needs_ui` y el complemento abre la actividad
 *   trampolín [DockTrampolineActivity].
 * - Acciones: TOGGLE (empezar / terminar) y CANCEL ([PointerProtocol]). La
 *   máquina de estados es [DockDictationLogic] (pura, con test JVM).
 * - Cuenta el estado a la barra con MIC_STATE ([DockLink.sendMicState]): reposo,
 *   grabando (con el nivel de voz, como mucho 15 veces por segundo), transcribiendo
 *   (con un latido para que el complemento no lo dé por perdido), listo o error con
 *   una frase corta FIJA. El audio y el texto nunca viajan a la barra.
 * - Misma configuración y clave que el teclado y el widget ([SpeechToTextClient]) y
 *   misma exclusión del micrófono ([BackgroundWork.tryClaimMicrophone]).
 * - Cero logs. Todo temporizador se cancela en [onDestroy].
 */
class DockDictationService : Service() {

    // Etapa 4: Android 9–12 toma el idioma elegido en la app (13+ lo pone el sistema).
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    companion object {
        private const val CHANNEL_ID = "dock_dictation_channel"
        private const val NOTIF_ID = 2003

        /** Latido del estado «transcribiendo» (el vigilante del complemento espera noticias cada ≤ 6 s). */
        private const val THINKING_BEAT_MS = 1500L

        /** true mientras este servicio dicta: la burbuja de respaldo no pisa su estado. */
        @Volatile
        var isActive = false
            private set
    }

    private val logic = DockDictationLogic()
    private val main = Handler(Looper.getMainLooper())
    private var client: SpeechToTextClient? = null
    private var feedback: DockMicFeedback? = null
    private var micClaim = 0L
    private var foregrounded = false
    private var fromTrampoline = false

    /** El último pase a primer plano quedó con tipo micrófono. */
    private var micForeground = false

    private val levelPoll = object : Runnable {
        override fun run() {
            val c = client ?: return
            if (logic.phase != DockDictationLogic.Phase.RECORDING) return
            DockLink.sendMicState(this@DockDictationService, PointerProtocol.MIC_RECORDING, c.currentLevel())
            main.postDelayed(this, PointerProtocol.MIC_LEVEL_EVERY_MS)
        }
    }
    private val thinkingBeat = object : Runnable {
        override fun run() {
            if (logic.phase != DockDictationLogic.Phase.TRANSCRIBING) return
            DockLink.sendMicState(this@DockDictationService, PointerProtocol.MIC_TRANSCRIBING)
            main.postDelayed(this, THINKING_BEAT_MS)
        }
    }
    private val autoStop = Runnable {
        // Tope de 5 minutos: se cierra como si la persona hubiera tocado «terminar».
        if (logic.phase == DockDictationLogic.Phase.RECORDING && logic.onToggle() == DockDictationLogic.Toggle.STOP) {
            stopAndTranscribe()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            PointerProtocol.ACTION_DICTATION_TOGGLE -> {
                fromTrampoline = intent.getBooleanExtra(PointerProtocol.EXTRA_FROM_TRAMPOLINE, false)
                // Llega por startForegroundService: la promesa de pasar a primer
                // plano se cumple SIEMPRE y antes que nada (también si después el
                // arranque falla), o Android mata la app.
                micForeground = enterForeground()
                toggle()
            }
            PointerProtocol.ACTION_DICTATION_CANCEL -> cancel()
        }
        // Arrancado en primer plano sin haber llegado a grabar: no quedarse colgado.
        if (!logic.isBusy) finishService()
        // Un servicio de micrófono no se resucita solo desde el fondo (Android 14+).
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        val wasBusy = logic.isBusy
        try {
            client?.cancelRecording()
        } catch (_: Exception) {}
        client = null
        releaseMicrophone()
        feedback?.release()
        feedback = null
        isActive = false
        // Si se cae a mitad del dictado, que la barra no espere: vuelve a reposo.
        if (wasBusy) DockLink.sendMicState(this, PointerProtocol.MIC_IDLE)
        super.onDestroy()
    }

    // ---------------------------------------------------------------- acciones

    private fun toggle() {
        when (logic.onToggle()) {
            DockDictationLogic.Toggle.START -> startRecording()
            DockDictationLogic.Toggle.STOP -> stopAndTranscribe()
            DockDictationLogic.Toggle.QUEUE_STOP, DockDictationLogic.Toggle.IGNORE -> {}
        }
    }

    private fun cancel() {
        if (logic.onCancel()) cancelRecording()
    }

    private fun startRecording() {
        isActive = true
        val speech = SpeechToTextClient(this)
        client = speech
        if (!speech.hasMicPermission()) {
            fail(DockDictationLogic.MSG_NO_MIC_PERMISSION)
            return
        }
        // T15: pasada la prueba, 10 dictados por día sin Pro.
        if (!ProGate.tryStartDictation(this)) {
            fail(DockDictationLogic.MSG_PRO_LIMIT)
            return
        }
        micClaim = BackgroundWork.tryClaimMicrophone()
        if (micClaim == 0L) {
            fail(DockDictationLogic.MSG_MIC_BUSY)
            return
        }
        // Android negó el primer plano con micrófono (arranque en segundo plano
        // sin ventana): se pide la actividad trampolín.
        if (!micForeground) {
            fail(DockDictationLogic.MSG_MIC_FAILED, needsUi = !fromTrampoline)
            return
        }
        feedback = DockMicFeedback(this)
        BackgroundWork.execute {
            // La clave primero: sin ella no vale la pena grabar.
            val config = try {
                speech.loadConfig()
            } catch (_: Exception) {
                null
            }
            if (config == null || config.apiKey.isBlank()) {
                BackgroundWork.postMain { fail(DockDictationLogic.MSG_NO_KEY) }
                return@execute
            }
            val ok = try {
                speech.startRecording()
            } catch (_: Exception) {
                false
            }
            BackgroundWork.postMain {
                if (!ok) {
                    fail(DockDictationLogic.MSG_MIC_FAILED)
                } else {
                    onRecordingStarted()
                }
            }
        }
    }

    private fun onRecordingStarted() {
        when (logic.onRecordingStarted()) {
            DockDictationLogic.AfterStart.CANCEL_NOW -> {
                cancelRecording()
                return
            }
            DockDictationLogic.AfterStart.STOP_NOW -> {
                // Le pidieron terminar mientras arrancaba: ya mismo, sin perder el toque.
                feedback?.play(DockMicFeedback.Event.START)
                stopAndTranscribe(alreadyMarked = true)
                return
            }
            DockDictationLogic.AfterStart.KEEP_RECORDING -> {}
        }
        feedback?.play(DockMicFeedback.Event.START)
        DockLink.sendMicState(this, PointerProtocol.MIC_RECORDING, 0f)
        main.removeCallbacks(levelPoll)
        main.postDelayed(levelPoll, PointerProtocol.MIC_LEVEL_EVERY_MS)
        // Mismo tope que el teclado y el widget: 5 minutos.
        main.removeCallbacks(autoStop)
        main.postDelayed(autoStop, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun cancelRecording() {
        main.removeCallbacks(levelPoll)
        main.removeCallbacks(autoStop)
        feedback?.play(DockMicFeedback.Event.CANCEL)
        val speech = client
        BackgroundWork.execute {
            try {
                speech?.cancelRecording()
            } catch (_: Exception) {}
        }
        client = null
        releaseMicrophone()
        DockLink.sendMicState(this, PointerProtocol.MIC_IDLE)
        logic.onFinished()
        finishService()
    }

    /** [alreadyMarked]: la máquina ya pasó a «transcribiendo» (el toque llegó mientras arrancaba). */
    private fun stopAndTranscribe(alreadyMarked: Boolean = false) {
        if (!alreadyMarked && logic.phase != DockDictationLogic.Phase.TRANSCRIBING) return
        val speech = client ?: run {
            finishWith(PointerProtocol.MIC_IDLE, null)
            return
        }
        main.removeCallbacks(levelPoll)
        main.removeCallbacks(autoStop)
        feedback?.play(DockMicFeedback.Event.STOP)
        DockLink.sendMicState(this, PointerProtocol.MIC_TRANSCRIBING)
        main.removeCallbacks(thinkingBeat)
        main.postDelayed(thinkingBeat, THINKING_BEAT_MS)
        runCatching { updateNotification(getString(R.string.notif_dock_transcribing)) }
        BackgroundWork.execute {
            val wav = try {
                speech.stopRecording()
            } catch (_: Exception) {
                ByteArray(0)
            } finally {
                // El micrófono queda libre apenas termina la captura (como el widget).
                BackgroundWork.postMain { releaseMicrophone() }
            }
            if (speech.isEmptyCapture(wav) || !DockDictationLogic.hasUsableAudio(wav.size)) {
                // Audio vacío o demasiado corto: se descarta sin avisar, igual que la burbuja de siempre.
                BackgroundWork.postMain { finishWith(PointerProtocol.MIC_IDLE, null) }
                return@execute
            }
            if (wav.size > SpeechToTextClient.MAX_AUDIO_BYTES) {
                BackgroundWork.postMain { finishWith(PointerProtocol.MIC_ERROR, DockDictationLogic.MSG_TOO_BIG) }
                return@execute
            }
            val config = speech.loadConfig()
            if (config.apiKey.isBlank()) {
                BackgroundWork.postMain { finishWith(PointerProtocol.MIC_ERROR, DockDictationLogic.MSG_NO_KEY) }
                return@execute
            }
            val persist = SpeechToTextClient.tryRepairHolePcmBytes(wav) ?: wav
            speech.transcribe(persist, config, onDone = { text ->
                onTranscribed(text)
            }, onError = { code, _ ->
                BackgroundWork.postMain { finishWith(PointerProtocol.MIC_ERROR, DockDictationLogic.errorMessage(code)) }
            })
        }
    }

    /** Hilo de fondo (el del cliente): historial en disco acá; portapapeles y pegado en el principal. */
    private fun onTranscribed(text: String?) {
        val clean = text?.trim().orEmpty()
        if (clean.isEmpty()) {
            BackgroundWork.postMain { finishWith(PointerProtocol.MIC_ERROR, DockDictationLogic.MSG_NOTHING) }
            return
        }
        try {
            TranscriptionHistoryRepository(this).addTranscription(clean)
        } catch (_: Exception) {}
        BackgroundWork.postMain {
            // Igual que la burbuja: al portapapeles, y pegado si el teclado activo es el de VoiceBubble.
            copyToClipboard(clean)
            val pasted = try {
                VoiceKeyboardService.commitFromExternal(clean)
            } catch (_: Exception) {
                false
            }
            feedback?.play(DockMicFeedback.Event.PASTE)
            finishWith(PointerProtocol.MIC_DONE, DockDictationLogic.doneMessage(pasted))
        }
    }

    private fun copyToClipboard(text: String) {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
            cm.setPrimaryClip(ClipData.newPlainText("Orison", text))
        } catch (_: Exception) {}
    }

    // ---------------------------------------------------------------- cierre

    /** No arrancó: avisa con una frase corta y cierra. [needsUi]: que el complemento pruebe con la actividad trampolín. */
    private fun fail(@androidx.annotation.StringRes message: Int, needsUi: Boolean = false) {
        logic.onStartFailed()
        releaseMicrophone()
        client = null
        DockLink.sendMicState(this, PointerProtocol.MIC_ERROR, message = getString(message), needsUi = needsUi)
        finishService()
    }

    private fun finishWith(state: String, @androidx.annotation.StringRes message: Int?) {
        main.removeCallbacks(thinkingBeat)
        main.removeCallbacks(levelPoll)
        releaseMicrophone()
        client = null
        logic.onFinished()
        DockLink.sendMicState(this, state, message = message?.let { getString(it) })
        finishService()
    }

    /**
     * Pasa a primer plano. true = con tipo micrófono (se puede grabar). Si
     * Android lo niega (Android 14+: segundo plano o sin permiso de micrófono),
     * cumple igual la promesa con el tipo «servicio corto», que no pide nada,
     * y devuelve false: el que llama avisa y termina.
     */
    private fun enterForeground(): Boolean {
        val n = notification(if (logic.phase == DockDictationLogic.Phase.TRANSCRIBING) getString(R.string.notif_dock_transcribing) else getString(R.string.notif_dock_recording))
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIF_ID, n)
            }
            foregrounded = true
            return true
        } catch (_: Exception) {}
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
                foregrounded = true
            } catch (_: Exception) {}
        }
        return false
    }

    private fun finishService() {
        main.removeCallbacks(thinkingBeat)
        isActive = false
        if (foregrounded) {
            foregrounded = false
            try {
                stopForeground(true)
            } catch (_: Exception) {}
        }
        try {
            stopSelf()
        } catch (_: Exception) {}
    }

    private fun releaseMicrophone() {
        val claim = micClaim
        micClaim = 0L
        BackgroundWork.releaseMicrophone(claim)
    }

    // ---------------------------------------------------------- notificación

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, getString(R.string.notif_dock_channel_name), NotificationManager.IMPORTANCE_LOW)
                .apply { description = getString(R.string.notif_dock_channel_desc) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
    }

    private fun notification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder.setContentTitle("Orison")
            .setContentText(text)
            .setSmallIcon(R.drawable.kb_ic_mic)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(text: String) {
        if (!foregrounded) return
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, notification(text))
    }
}
