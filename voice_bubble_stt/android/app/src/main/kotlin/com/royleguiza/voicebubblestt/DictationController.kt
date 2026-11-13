package com.royleguiza.voicebubblestt

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.os.Handler
import android.os.SystemClock
import android.transition.ChangeBounds
import android.transition.Fade
import android.transition.TransitionManager
import android.transition.TransitionSet
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat

/**
 * Dictado por voz (SPK-05, módulo 5 de N): tecla mic, máquina de estados,
 * píldora M4, timers, audio focus e historial compartido, extraído de
 * VoiceKeyboardService sin cambiar conducta. Todo lo que necesita del
 * teclado entra por [service], [handler] y [host]; el estado (vistas,
 * cliente STT, generación, foco) es suyo. La ventana de historial vive en
 * HistoryLayer (SPK-05 módulo 9, comparte popup con acentos vía takePopup)
 * y los avisos vía [UiHost.showNotice].
 */
/**
 * Snapshot de feedback del micrófono (prefs del puente, lectura en vivo
 * por evento): hápticas independientes de las teclas + sonidos opt-in.
 *
 * Contrato C-20: [hapticStart] y [hapticStop] son flags independientes.
 * Apagar [hapticStart] no debe apagar [hapticStop] ni viceversa (resolviendo
 * la ambigüedad histórica donde STOP usaba hapticStart).
 */
data class MicFeedback(
    val hapticsEnabled: Boolean,
    val hapticStart: Boolean,
    val hapticStop: Boolean = true,
    val hapticRecording: Boolean,
    val hapticPaste: Boolean,
    val hapticCancel: Boolean,
    val soundsEnabled: Boolean,
)

/** Micrófono ocupado (la burbuja graba): el agujero de reposo atenuado. */
internal const val MIC_BUSY_ALPHA = 0.5f

class DictationController(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {

    /** Lo mínimo que el dictado exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun tapFeedback()
        fun pressHaptic(view: View)
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun standardKeyHeightPx(): Int
        fun showNotice(message: String, openSettingsOnClick: Boolean = false, onClick: (() -> Unit)? = null)
        fun showHistoryPopup(anchor: View)
        fun isServiceAlive(): Boolean
        fun setRecordingActive(active: Boolean)
        fun isRecordingActive(): Boolean
        fun micFeedback(): MicFeedback
        fun micBuzz(durationMs: Long, amplitude: Int)
    }

    private lateinit var sttClient: SpeechToTextClient
    private val repo = TranscriptionHistoryRepository(service)
    private var micState = MicState.IDLE
    private var micKeyView: View? = null
    private var micNormalView: ImageView? = null
    private var micProcView: View? = null
    private var micProcHorizon: HorizonView? = null
    private var micPillView: View? = null
    private var micPillHorizon: HorizonView? = null
    private var micPillTimer: TextView? = null
    private var micPillCancel: TextView? = null
    private var timeoutRunnable: Runnable? = null
    private var recordingTimerRunnable: Runnable? = null
    private var micTickRunnable: Runnable? = null
    private var recordingStartMs: Long = 0L
    private var soundPool: SoundPool? = null
    private var soundStart = 0
    private var soundStop = 0
    private var soundPaste = 0
    private var soundCancel = 0
    private var transcriptionGeneration = 0
    private var focusRequest: AudioFocusRequest? = null
    private var dictationStartPending = false
    @Volatile
    private var microphoneClaimToken = 0L
    @Volatile
    private var audioFocusLost = false

    /** C-10: Retención de último WAV + config para reintento manual sin regrabar. */
    data class LastDictationSlot(
        val wav: ByteArray,
        val config: SpeechToTextClient.Config,
    )

    internal var lastDictationSlot: LastDictationSlot? = null

    private fun isRetryableError(message: String): Boolean {
        if (message.contains("API key", ignoreCase = true) ||
            message.contains("inválida", ignoreCase = true) ||
            message.contains("invalid", ignoreCase = true)) {
            return false
        }
        return message.contains("conexión", ignoreCase = true) ||
            message.contains("connection", ignoreCase = true) ||
            message.contains("servidor", ignoreCase = true) ||
            message.contains("server", ignoreCase = true) ||
            message.contains("500") || message.contains("502") ||
            message.contains("503") || message.contains("504") ||
            message.contains("429") || message.contains("límite", ignoreCase = true) ||
            message.contains("limit", ignoreCase = true) ||
            message.contains("timeout", ignoreCase = true) ||
            message.contains("espera", ignoreCase = true)
    }

    /**
     * K5-T5: recreacion de vista (ej. rotacion) nunca debe dejar una
     * grabacion fantasma del cliente anterior colgada.
     */
    fun onCreateInputView() {
        cancelDictationIfActive()
        sttClient = SpeechToTextClient(service) { host.isSpanish() }
        preloadSttConfig()
        BackgroundWork.execute {
            initMicSounds()
        }
    }

    /** C-12: Precalentamiento de la configuración STT y bóveda fuera del hilo principal. */
    fun preloadSttConfig() {
        sttClient.preloadConfig()
    }

    /** K5-T5: destruccion del servicio con dictado vivo = grabacion fantasma. */
    fun onDestroy() {
        stopRecordingTimer()
        stopMicTicker()
        releaseMicSounds()
        stopVoiceAnimations()
        cancelDictationIfActive()
    }

    /** Rebuild suelta las vistas: parar timer/UI y olvidarlas (la grabación sigue). */
    fun onViewsDiscarded() {
        stopRecordingTimer()
        stopVoiceAnimations()
        clearViews()
    }

    /** Detiene los cuadros de las vistas de voz (fase 1): sin animador colgado. */
    private fun stopVoiceAnimations() {
        micPillHorizon?.setPhase(HorizonView.Phase.IDLE)
        micProcHorizon?.setPhase(HorizonView.Phase.IDLE)
    }

    /** Olvida las vistas del mic (campo de contraseña o rebuild). */
    fun clearViews() {
        micKeyView = null
        micNormalView = null
        micProcView = null
        micProcHorizon = null
        micPillView = null
        micPillHorizon = null
        micPillTimer = null
        micPillCancel = null
    }

    /** AT-A4: BUSY es espejo de la burbuja; si ya soltó el micrófono, IDLE. */
    fun syncBubbleState() {
        if (micState == MicState.BUSY && !bubbleBusy()) micIdle()
    }

    fun makeMicKey(): View {
        val container = FrameLayout(service)
        val lp = LinearLayout.LayoutParams(0, host.standardKeyHeightPx(), 1f)
        val m = service.dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        container.layoutParams = lp

        // Vista normal en reposo / ocupado: el agujero (Horizonte) con el
        // glifo kb_ic_mic en on-hole; ocupado = el mismo agujero atenuado.
        val normal = ImageView(service)
        normal.scaleType = ImageView.ScaleType.FIT_CENTER
        normal.setImageResource(R.drawable.kb_ic_mic)
        normal.isClickable = true
        normal.isFocusable = true
        normal.minimumWidth = 0
        normal.minimumHeight = 0
        val glyphPad = dp(8f)
        normal.setPadding(0, glyphPad, 0, glyphPad)
        normal.background = HoleDrawable(service)
        normal.setColorFilter(ContextCompat.getColor(service, R.color.hz_on_hole))
        normal.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        host.attachPress(
            normal,
            onLongPress = {
                host.pressHaptic(normal)
                when (micState) {
                    MicState.RECORDING -> cancelDictation(announce = true)
                    MicState.IDLE, MicState.BUSY -> host.showHistoryPopup(container)
                    MicState.PROCESSING -> cancelDictation()
                }
            },
            onTapUp = { handleMicTap() },
        )
        container.addView(normal)

        // Nivel vivo del micrófono: lectura volátil del hilo de captura
        // (SpeechToTextClient.currentLevel), una vez por cuadro.
        val level = HorizonView.LevelSource {
            if (::sttClient.isInitialized) sttClient.currentLevel() else 0f
        }

        // Vista de procesamiento: pastilla A en modo pensando (arco + renglones).
        val proc = FrameLayout(service)
        proc.setBackgroundResource(R.drawable.kb_mic_pill)
        proc.isClickable = true
        proc.isFocusable = true
        proc.setOnClickListener {
            host.pressHaptic(proc)
            cancelDictation()
        }
        proc.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        val procHorizon = HorizonView(service, HorizonView.Mode.ACCRETION)
        proc.addView(
            procHorizon,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        container.addView(proc)

        // Vista pastilla (M4 Pill) en grabación: A (Acreción) + cronómetro + ✕
        val pill = FrameLayout(service)
        pill.setBackgroundResource(R.drawable.kb_mic_pill)
        pill.isClickable = true
        pill.isFocusable = true
        pill.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        host.attachPress(
            pill,
            onLongPress = {
                host.pressHaptic(pill)
                cancelDictation(announce = true)
            },
            onTapUp = {
                host.pressHaptic(pill)
                finishDictation()
            },
        )

        val pillHorizon = HorizonView(service, HorizonView.Mode.ACCRETION)
        pillHorizon.levelSource = level
        pill.addView(
            pillHorizon,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )

        // Cronómetro en vivo: mono sobre su propio fondo negro (las
        // partículas pasan por detrás sin taparlo).
        val onHole = ContextCompat.getColor(service, R.color.hz_on_hole)
        val timer = TextView(service)
        timer.text = "0:00"
        timer.gravity = Gravity.CENTER
        timer.setTextColor(onHole)
        timer.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
        timer.typeface = try {
            ResourcesCompat.getFont(service, R.font.jetbrains_mono)
        } catch (_: Exception) {
            null
        } ?: android.graphics.Typeface.MONOSPACE
        timer.setBackgroundResource(R.drawable.kb_mic_timer_bg)
        timer.setPadding(dp(5f), dp(1f), dp(5f), dp(1f))
        val timerLp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.START or Gravity.CENTER_VERTICAL,
        )
        timerLp.marginStart = dp(30f)
        pill.addView(timer, timerLp)

        // Botón cancelar ✕
        val cancel = TextView(service)
        cancel.text = "✕"
        cancel.gravity = Gravity.CENTER
        cancel.setTextColor(onHole)
        cancel.alpha = 0.8f
        cancel.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14f)
        cancel.isClickable = true
        cancel.isFocusable = true
        cancel.minimumWidth = dp(44f)
        val cancelPad = dp(8f)
        cancel.setPadding(cancelPad, 0, cancelPad, 0)
        val cancelLp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
            Gravity.END or Gravity.CENTER_VERTICAL,
        )
        cancel.setOnClickListener {
            host.pressHaptic(cancel)
            cancelDictation(announce = true)
        }
        pill.addView(cancel, cancelLp)

        container.addView(pill)

        micKeyView = container
        micNormalView = normal
        micProcView = proc
        micProcHorizon = procHorizon
        micPillView = pill
        micPillHorizon = pillHorizon
        micPillTimer = timer
        micPillCancel = cancel

        applyMicVisual()
        return container
    }

    private fun dp(value: Float): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value, service.resources.displayMetrics,
    ).toInt()

    /** Eventos de feedback del micrófono (hápticas + sonidos UI). */
    private enum class MicEvent { START, STOP, PASTE, CANCEL }

    /**
     * Feedback del micrófono, independiente de la vibración de teclas:
     * cada evento vibra corto (estilo tecla) y/o suena según prefs.
     * Sin contenido en juego: solo confirma la acción. Todo tolerante.
     */
    private fun micEvent(kind: MicEvent) {
        val fb = try {
            host.micFeedback()
        } catch (_: Exception) {
            return
        }
        try {
            if (fb.hapticsEnabled) {
                when (kind) {
                    MicEvent.START -> if (fb.hapticStart) host.micBuzz(12L, 255)
                    MicEvent.STOP -> if (fb.hapticStop) host.micBuzz(20L, 200)
                    MicEvent.PASTE -> if (fb.hapticPaste) host.micBuzz(15L, 180)
                    MicEvent.CANCEL -> if (fb.hapticCancel) host.micBuzz(30L, 160)
                }
            }
            if (fb.soundsEnabled) {
                val id = when (kind) {
                    MicEvent.START -> soundStart
                    MicEvent.STOP -> soundStop
                    MicEvent.PASTE -> soundPaste
                    MicEvent.CANCEL -> soundCancel
                }
                if (id != 0) soundPool?.play(id, 1f, 1f, 1, 0, 1f)
            }
        } catch (_: Exception) {}
    }

    /** Pulso suave cada 3 s mientras graba (solo háptico, nunca sonido). */
    private fun startMicTicker() {
        stopMicTicker()
        val r = object : Runnable {
            override fun run() {
                if (micState != MicState.RECORDING) return
                try {
                    val fb = host.micFeedback()
                    if (fb.hapticsEnabled && fb.hapticRecording) host.micBuzz(10L, 120)
                } catch (_: Exception) {}
                handler.postDelayed(this, 3000L)
            }
        }
        micTickRunnable = r
        handler.postDelayed(r, 3000L)
    }

    private fun stopMicTicker() {
        micTickRunnable?.let { handler.removeCallbacks(it) }
        micTickRunnable = null
    }

    private fun initMicSounds() {
        releaseMicSounds()
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val pool = SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(attrs)
                .build()
            // Estilos elegidos en Ajustes (mic_start_<n>/mic_stop_<n>).
            val prefs = service.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val startStyle = prefs.getString("flutter.kb_mic_start_style", "3")
                ?.takeIf { it == "1" || it == "2" || it == "3" || it == "4" } ?: "3"
            val stopStyle = prefs.getString("flutter.kb_mic_stop_style", "3")
                ?.takeIf { it == "1" || it == "2" || it == "3" || it == "4" } ?: "3"
            val pkg = service.packageName
            val res = service.resources
            soundStart = pool.load(service, res.getIdentifier("mic_start_$startStyle", "raw", pkg), 1)
            soundStop = pool.load(service, res.getIdentifier("mic_stop_$stopStyle", "raw", pkg), 1)
            soundPaste = pool.load(service, R.raw.mic_paste, 1)
            soundCancel = pool.load(service, R.raw.mic_cancel, 1)
            soundPool = pool
        } catch (_: Exception) {
            soundPool = null
        }
    }

    private fun releaseMicSounds() {
        try {
            soundPool?.release()
        } catch (_: Exception) {}
        soundPool = null
        soundStart = 0
        soundStop = 0
        soundPaste = 0
        soundCancel = 0
    }

    private fun handleMicTap() {
        host.tapFeedback()
        when (micState) {
            MicState.IDLE, MicState.BUSY -> startDictation()
            MicState.RECORDING -> finishDictation()
            MicState.PROCESSING -> cancelDictation()
        }
    }

    private fun bubbleBusy(): Boolean =
        FloatingBubbleService.isRunning && FloatingBubbleService.lastVisualState != "idle"

    private fun startDictation() {
        if (dictationStartPending || micState == MicState.RECORDING || micState == MicState.PROCESSING) {
            return
        }
        lastDictationSlot = null
        if (!gainAudioFocus()) {
            micState = MicState.IDLE
            refreshMicVisual()
            host.showNotice(
                if (host.isSpanish()) "No se pudo obtener el foco de audio."
                else "Could not obtain audio focus.",
            )
            return
        }
        if (bubbleBusy()) {
            abandonAudioFocus()
            micState = MicState.BUSY
            refreshMicVisual()
            host.showNotice(if (host.isSpanish()) "Ocupado: la burbuja está grabando." else "Busy: the bubble is recording.")
            return
        }
        // C-12: Configuración cacheada en memoria preparada en segundo plano
        val config = sttClient.getConfig()
        if (config.apiKey.isBlank()) {
            abandonAudioFocus()
            micState = MicState.IDLE
            refreshMicVisual()
            host.showNotice(
                if (host.isSpanish()) "Falta la API key. Toca este aviso para abrir Ajustes."
                else "Missing API key. Tap this notice to open Settings.",
                openSettingsOnClick = true,
            )
            return
        }
        if (!sttClient.hasMicPermission()) {
            abandonAudioFocus()
            host.showNotice(
                if (host.isSpanish()) "Permiso de micrófono denegado. Concedelo desde Ajustes."
                else "Microphone permission denied. Allow it from Settings.",
                openSettingsOnClick = true,
            )
            return
        }
        val claimToken = BackgroundWork.tryClaimMicrophone()
        if (claimToken == 0L) {
            abandonAudioFocus()
            micState = MicState.BUSY
            refreshMicVisual()
            host.showNotice(if (host.isSpanish()) "Ocupado: el micrófono está en uso." else "Busy: the microphone is in use.")
            return
        }
        microphoneClaimToken = claimToken
        dictationStartPending = true
        host.setRecordingActive(true)
        if (audioFocusLost) {
            cancelDictation()
            return
        }
        // El setup de AudioRecord bloquea (contrato SpeechToTextClient):
        // jamás en el main. El resultado vuelve por callback al main.
        val startGeneration = transcriptionGeneration
        BackgroundWork.execute {
            val started = try {
                sttClient.startRecording()
            } catch (_: Exception) {
                false
            }
            BackgroundWork.postMain {
                onDictationStartResult(started, startGeneration, claimToken)
            }
        }
    }

    /**
     * Cierre del arranque asíncrono en el main. Si el usuario cambió de
     * campo o se destruyó el servicio mientras tanto (generación avanzada),
     * la captura que haya llegado a arrancar se aborta en fondo: sin
     * grabación fantasma ni píldora zombi.
     */
    private fun onDictationStartResult(started: Boolean, startGeneration: Int, claimToken: Long) {
        val isCurrentStart = startGeneration == transcriptionGeneration
        val ownsClaim = BackgroundWork.isMicrophoneClaimedBy(claimToken)
        val serviceAlive = host.isServiceAlive()
        if (isCurrentStart) dictationStartPending = false
        if (!serviceAlive || !started || !isCurrentStart || !ownsClaim) {
            if (isCurrentStart) host.setRecordingActive(false)
            if (started) {
                BackgroundWork.execute {
                    var cancelled = false
                    try {
                        sttClient.cancelRecording()
                        cancelled = true
                    } catch (_: Exception) {}
                    if (cancelled) BackgroundWork.postMain { host.setRecordingActive(false) }
                    abandonAudioFocus()
                    releaseMicrophoneClaim(claimToken)
                }
            } else {
                abandonAudioFocus()
                releaseMicrophoneClaim(claimToken)
            }
            if (!serviceAlive) return
            if (!started && isCurrentStart && micState == MicState.IDLE) {
                host.showNotice(if (host.isSpanish()) "No se pudo iniciar la grabación." else "Could not start recording.")
            } else {
                refreshMicVisual()
            }
            return
        }
        micState = MicState.RECORDING
        recordingStartMs = SystemClock.elapsedRealtime()
        micPillTimer?.text = "0:00"
        refreshMicVisual()
        startRecordingTimer()
        startMicTicker()
        micEvent(MicEvent.START)
        val t = Runnable { if (micState == MicState.RECORDING) finishDictation() }
        timeoutRunnable = t
        handler.postDelayed(t, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun finishDictation() {
        stopRecordingTimer()
        stopMicTicker()
        micEvent(MicEvent.STOP)
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.PROCESSING
        refreshMicVisual()
        // C-12: Configuración cacheada en memoria
        val config = sttClient.getConfig()
        // AT-A1: los callbacks capturan la generacion vigente; si una
        // cancelacion la avanza mientras transcribiamos, se abortan solos.
        val generation = transcriptionGeneration
        val claimToken = microphoneClaimToken
        BackgroundWork.execute {
            val wav = try {
                sttClient.stopRecording()
            } finally {
                abandonAudioFocus()
                releaseMicrophoneClaim(claimToken)
                host.setRecordingActive(false)
            }
            if (sttClient.isEmptyCapture(wav)) {
                runOnMain {
                    if (generation != transcriptionGeneration) return@runOnMain
                    micIdle()
                    host.showNotice(if (host.isSpanish()) "No se detectó voz." else "No voice detected.")
                }
                return@execute
            }
            lastDictationSlot = LastDictationSlot(wav, config)
            if (generation != transcriptionGeneration) return@execute
            sttClient.transcribe(
                wav,
                config,
                onDone = { text ->
                    // C-09: text == null indica cancelación inmediata
                    if (text == null) {
                        runOnMain {
                            if (generation != transcriptionGeneration) return@runOnMain
                            micIdle()
                        }
                        return@transcribe
                    }
                    lastDictationSlot = null
                    // AT-A3: historial (lectura de disco + XML + prefs) en el
                    // hilo de fondo del cliente; sus callbacks jamas llegan
                    // por el hilo principal.
                    if (!text.isNullOrBlank()) addToSharedHistory(text)
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        if (text.isNullOrBlank()) {
                            host.showNotice(if (host.isSpanish()) "No se detectó voz." else "No voice detected.")
                        } else {
                            // AT-A10: el dictado se comete directo en el campo
                            // destino; jamas alimenta el query de snippets.
                            if (commitOrWarn(text)) {
                                micEvent(MicEvent.PASTE)
                            }
                        }
                    }
                },
                onError = { message ->
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        if (isRetryableError(message) && lastDictationSlot != null) {
                            val retryMsg = if (host.isSpanish()) "$message Toca para reintentar." else "$message Tap to retry."
                            host.showNotice(retryMsg, onClick = { retryLastDictation() })
                        } else {
                            lastDictationSlot = null
                            host.showNotice(message)
                        }
                    }
                },
            )
        }
    }

    private fun commitOrWarn(text: CharSequence): Boolean {
        return com.royleguiza.voicebubblestt.commitOrWarn(service, text, host.isSpanish()) {
            host.showNotice(if (host.isSpanish()) StatusLayer.NOTICE_DEAD_CONNECTION_ES else StatusLayer.NOTICE_DEAD_CONNECTION_EN)
        }
    }

    /**
     * C-10: Reintento manual del último dictado sin volver a grabar el audio.
     * Utiliza el mismo buffer WAV y la misma configuración capturados en [lastDictationSlot].
     */
    fun retryLastDictation() {
        val slot = lastDictationSlot ?: return
        if (dictationStartPending || micState != MicState.IDLE) return
        micState = MicState.PROCESSING
        refreshMicVisual()
        val generation = ++transcriptionGeneration
        BackgroundWork.execute {
            if (generation != transcriptionGeneration) return@execute
            sttClient.transcribe(
                slot.wav,
                slot.config,
                onDone = { text ->
                    if (text == null) {
                        runOnMain {
                            if (generation != transcriptionGeneration) return@runOnMain
                            micIdle()
                        }
                        return@transcribe
                    }
                    lastDictationSlot = null
                    if (!text.isNullOrBlank()) addToSharedHistory(text)
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        if (text.isNullOrBlank()) {
                            host.showNotice(if (host.isSpanish()) "No se detectó voz." else "No voice detected.")
                        } else {
                            if (commitOrWarn(text)) {
                                micEvent(MicEvent.PASTE)
                            }
                        }
                    }
                },
                onError = { message ->
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        if (isRetryableError(message) && lastDictationSlot != null) {
                            val retryMsg = if (host.isSpanish()) "$message Toca para reintentar." else "$message Tap to retry."
                            host.showNotice(retryMsg, onClick = { retryLastDictation() })
                        } else {
                            lastDictationSlot = null
                            host.showNotice(message)
                        }
                    }
                },
            )
        }
    }

    /**
     * Cancela el dictado. [announce]=true solo en gesto explícito del
     * usuario (toque largo / X): las cancelaciones del sistema (foco,
     * rotación) son silenciosas.
     */
    private fun cancelDictation(announce: Boolean = false) {
        stopRecordingTimer()
        stopMicTicker()
        if (announce) micEvent(MicEvent.CANCEL)
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        dictationStartPending = false
        transcriptionGeneration++
        lastDictationSlot = null
        micState = MicState.IDLE
        refreshMicVisual()
        val claimToken = microphoneClaimToken
        BackgroundWork.execute {
            try {
                sttClient.cancelRecording()
            } finally {
                abandonAudioFocus()
                releaseMicrophoneClaim(claimToken)
                host.setRecordingActive(false)
            }
        }
    }

    /**
     * K5-T5: apagado defensivo del dictado para los escenarios hostiles
     * (recreacion de vista, cambio de campo/app, destruccion). Idempotente:
     * sin dictado activo no hace nada. La parte que puede bloquear (corte de
     * captura y audio focus) corre en hilo de fondo con la referencia local
     * del cliente, igual que cancelDictation.
     */
    fun cancelDictationIfActive() {
        stopRecordingTimer()
        if (micState == MicState.IDLE && !dictationStartPending && microphoneClaimToken == 0L && !host.isRecordingActive()) return
        val client = if (::sttClient.isInitialized) sttClient else null
        val claimToken = microphoneClaimToken
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        dictationStartPending = false
        transcriptionGeneration++
        lastDictationSlot = null
        micIdle()
        if (client != null) {
            BackgroundWork.execute {
                try {
                    client.cancelRecording()
                } catch (_: Exception) {
                } finally {
                    abandonAudioFocus()
                    host.setRecordingActive(false)
                    releaseMicrophoneClaim(claimToken)
                }
            }
        } else {
            abandonAudioFocus()
            host.setRecordingActive(false)
            releaseMicrophoneClaim(claimToken)
        }
    }

    private fun releaseMicrophoneClaim(claimToken: Long) {
        BackgroundWork.releaseMicrophone(claimToken)
        if (microphoneClaimToken == claimToken) microphoneClaimToken = 0L
    }

    private fun micIdle() {
        stopRecordingTimer()
        micState = MicState.IDLE
        refreshMicVisual()
    }

    private fun startRecordingTimer() {
        stopRecordingTimer()
        val r = object : Runnable {
            override fun run() {
                if (micState != MicState.RECORDING) return
                val elapsedSec = (SystemClock.elapsedRealtime() - recordingStartMs) / 1000
                val m = elapsedSec / 60
                val s = elapsedSec % 60
                micPillTimer?.text = String.format(java.util.Locale.US, "%d:%02d", m, s)
                handler.postDelayed(this, 1000L)
            }
        }
        recordingTimerRunnable = r
        handler.postDelayed(r, 1000L)
    }

    private fun stopRecordingTimer() {
        recordingTimerRunnable?.let { handler.removeCallbacks(it) }
        recordingTimerRunnable = null
    }

    /** Sincroniza el visual del mic tras reconstruir la vista (lo llama VKS). */
    fun refreshMicVisual() {
        // AT-A4: sin cambio de campo no hay otro punto que reevalue la
        // burbuja; si ella dejo de grabar, BUSY zombi vuelve a IDLE.
        if (micState == MicState.BUSY && !bubbleBusy()) {
            micState = MicState.IDLE
        }
        applyMicVisual()
    }

    private fun applyMicVisual() {
        val container = micKeyView ?: return
        val normal = micNormalView
        val proc = micProcView
        val pill = micPillView
        val parentRow = container.parent as? ViewGroup

        val isRecording = (micState == MicState.RECORDING)
        // Pensando también es pastilla: A necesita ancho para los renglones.
        val isPill = isRecording || micState == MicState.PROCESSING
        val rm = service.reducedMotion()

        if (!rm && parentRow != null) {
            try {
                val transition = TransitionSet().apply {
                    ordering = TransitionSet.ORDERING_TOGETHER
                    addTransition(ChangeBounds().apply {
                        duration = 200L
                        interpolator = DecelerateInterpolator()
                    })
                    addTransition(Fade().apply {
                        duration = 150L
                    })
                }
                TransitionManager.beginDelayedTransition(parentRow, transition)
            } catch (_: Exception) {}
        }

        val lp = container.layoutParams as? LinearLayout.LayoutParams
        val weight = if (isPill) 5.0f else 1.0f
        if (lp != null && lp.weight != weight) {
            // Un peso más grande empuja y comprime a los demás íconos suavemente.
            lp.weight = weight
            container.layoutParams = lp
        }
        container.background = null

        // Fase de las vistas de voz: el animador de cada una arranca/para solo.
        micPillHorizon?.setPhase(if (isRecording) HorizonView.Phase.RECORDING else HorizonView.Phase.IDLE)
        micProcHorizon?.setPhase(
            if (micState == MicState.PROCESSING) HorizonView.Phase.THINKING else HorizonView.Phase.IDLE,
        )

        when (micState) {
            MicState.RECORDING -> {
                normal?.visibility = View.GONE
                proc?.visibility = View.GONE
                pill?.visibility = View.VISIBLE
                container.contentDescription = if (host.isSpanish()) "grabando dictado" else "recording dictation"

                val elapsed = (SystemClock.elapsedRealtime() - recordingStartMs) / 1000
                micPillTimer?.text = String.format("%d:%02d", elapsed / 60, elapsed % 60)
                if (recordingTimerRunnable == null) {
                    startRecordingTimer()
                }
            }
            MicState.IDLE -> {
                pill?.visibility = View.GONE
                proc?.visibility = View.GONE
                normal?.visibility = View.VISIBLE
                if (normal?.background !is HoleDrawable) normal?.background = HoleDrawable(service)
                normal?.setImageResource(R.drawable.kb_ic_mic)
                normal?.setColorFilter(ContextCompat.getColor(service, R.color.hz_on_hole))
                normal?.alpha = 1f
                normal?.contentDescription = if (host.isSpanish()) "dictar" else "dictate"
                container.contentDescription = if (host.isSpanish()) "dictar" else "dictate"
            }
            MicState.PROCESSING -> {
                pill?.visibility = View.GONE
                normal?.visibility = View.GONE
                proc?.visibility = View.VISIBLE
                proc?.contentDescription = if (host.isSpanish()) "procesando" else "processing"
                container.contentDescription = if (host.isSpanish()) "procesando" else "processing"
            }
            MicState.BUSY -> {
                pill?.visibility = View.GONE
                proc?.visibility = View.GONE
                normal?.visibility = View.VISIBLE
                // Horizonte fase 2: ocupado = el mismo agujero, atenuado.
                if (normal?.background !is HoleDrawable) normal?.background = HoleDrawable(service)
                normal?.setImageResource(R.drawable.kb_ic_mic)
                normal?.setColorFilter(ContextCompat.getColor(service, R.color.hz_on_hole))
                normal?.alpha = MIC_BUSY_ALPHA
                normal?.contentDescription = if (host.isSpanish()) "micrófono ocupado" else "microphone busy"
                container.contentDescription = if (host.isSpanish()) "micrófono ocupado" else "microphone busy"
            }
        }
    }

    private fun gainAudioFocus(): Boolean {
        try {
            val am = service.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val request = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
            ).setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            ).setOnAudioFocusChangeListener { change ->
                // K5-T5: llamada entrante u otro foco de audio. Perder el
                // foco cancela el dictado y devuelve el microfono a IDLE
                // (el listener llega en el looper del hilo que registro).
                if (change == AudioManager.AUDIOFOCUS_LOSS ||
                    change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                ) {
                    audioFocusLost = true
                    if (micState == MicState.RECORDING || dictationStartPending) {
                        cancelDictation()
                    }
                }
            }.build()
            audioFocusLost = false
            val granted = am.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            if (granted) focusRequest = request
            return granted
        } catch (_: Exception) {
            return false
        }
    }

    private fun abandonAudioFocus() {
        try {
            focusRequest?.let { request ->
                val am = service.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.abandonAudioFocusRequest(request)
            }
        } catch (_: Exception) {}
        focusRequest = null
        audioFocusLost = false
    }

    /**
     * Alta en el historial FIFO-20 compartido con la app mediante el repositorio atómico.
     */
    private fun addToSharedHistory(text: String) {
        try {
            repo.addTranscription(text)
        } catch (_: Exception) {}
    }
}
