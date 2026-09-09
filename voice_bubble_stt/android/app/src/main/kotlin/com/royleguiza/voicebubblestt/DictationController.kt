package com.royleguiza.voicebubblestt

import android.animation.ObjectAnimator
import android.content.Context
import android.graphics.Typeface
import android.inputmethodservice.InputMethodService
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
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

/**
 * Dictado por voz (SPK-05, módulo 5 de N): tecla mic, máquina de estados,
 * píldora M4, timers, audio focus e historial compartido, extraído de
 * VoiceKeyboardService sin cambiar conducta. Todo lo que necesita del
 * teclado entra por [service], [handler] y [host]; el estado (vistas,
 * cliente STT, generación, foco) es suyo. La ventana de historial vive en
 * HistoryLayer (SPK-05 módulo 9, comparte popup con acentos vía takePopup)
 * y los avisos vía [UiHost.showNotice].
 */
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
        fun showNotice(message: String, openSettingsOnClick: Boolean = false)
        fun showHistoryPopup(anchor: View)
        fun isServiceAlive(): Boolean
        fun setRecordingActive(active: Boolean)
        fun isRecordingActive(): Boolean
    }

    private lateinit var sttClient: SpeechToTextClient
    private val repo = TranscriptionHistoryRepository(service)
    private var micState = MicState.IDLE
    private var micKeyView: View? = null
    private var micNormalView: ImageView? = null
    private var micProcView: View? = null
    private var micProcDots: List<View> = emptyList()
    private var micPillView: View? = null
    private var micPillDot: TextView? = null
    private var micPillTimer: TextView? = null
    private var micPillCancel: TextView? = null
    private var timeoutRunnable: Runnable? = null
    private var recordingTimerRunnable: Runnable? = null
    private var recordingStartMs: Long = 0L
    private var transcriptionGeneration = 0
    private var focusRequest: AudioFocusRequest? = null
    private var pulseAnimators: List<ObjectAnimator> = emptyList()
    private var dictationStartPending = false

    /**
     * K5-T5: recreacion de vista (ej. rotacion) nunca debe dejar una
     * grabacion fantasma del cliente anterior colgada.
     */
    fun onCreateInputView() {
        cancelDictationIfActive()
        sttClient = SpeechToTextClient(service) { host.isSpanish() }
    }

    /** K5-T5: destruccion del servicio con dictado vivo = grabacion fantasma. */
    fun onDestroy() {
        stopRecordingTimer()
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()
        cancelDictationIfActive()
    }

    /** Rebuild suelta las vistas: parar timer/UI y olvidarlas (la grabación sigue). */
    fun onViewsDiscarded() {
        stopRecordingTimer()
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()
        clearViews()
    }

    /** Olvida las vistas del mic (campo de contraseña o rebuild). */
    fun clearViews() {
        micKeyView = null
        micNormalView = null
        micProcView = null
        micProcDots = emptyList()
        micPillView = null
        micPillDot = null
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

        // Vista normal en reposo / ocupado (icono vectorial kb_ic_mic)
        val normal = ImageView(service)
        normal.scaleType = ImageView.ScaleType.CENTER_INSIDE
        normal.setImageResource(R.drawable.kb_ic_mic)
        normal.isClickable = true
        normal.isFocusable = true
        normal.minimumWidth = 0
        normal.minimumHeight = 0
        normal.setPadding(0, 0, 0, 0)
        normal.setBackgroundResource(R.drawable.kb_key_bg)
        normal.setColorFilter(ContextCompat.getColor(service, R.color.kb_label))
        normal.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        host.attachPress(
            normal,
            onLongPress = {
                host.pressHaptic(normal)
                when (micState) {
                    MicState.RECORDING -> cancelDictation()
                    MicState.IDLE, MicState.BUSY -> host.showHistoryPopup(container)
                    MicState.PROCESSING -> { /* transcribiendo: ignorar */ }
                }
            },
            onTapUp = { handleMicTap() },
        )
        container.addView(normal)

        // Vista de procesamiento / transcripción (3 puntos suspensivos pulsantes)
        val proc = LinearLayout(service)
        proc.orientation = LinearLayout.HORIZONTAL
        proc.gravity = Gravity.CENTER
        proc.setBackgroundResource(R.drawable.kb_key_alt)
        proc.isClickable = true
        proc.isFocusable = true
        proc.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        val dotSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 5f, service.resources.displayMetrics,
        ).toInt()
        val dotGapPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 4f, service.resources.displayMetrics,
        ).toInt()
        val dots = mutableListOf<View>()
        for (i in 0 until 3) {
            val dot = View(service)
            dot.setBackgroundResource(R.drawable.kb_proc_dot)
            val dotLp = LinearLayout.LayoutParams(dotSizePx, dotSizePx)
            if (i > 0) {
                dotLp.leftMargin = dotGapPx
            }
            proc.addView(dot, dotLp)
            dots.add(dot)
        }
        container.addView(proc)

        // Vista pastilla (M4 Pill) en grabación
        val pill = LinearLayout(service)
        pill.orientation = LinearLayout.HORIZONTAL
        pill.gravity = Gravity.CENTER_VERTICAL
        pill.setBackgroundResource(R.drawable.kb_mic_pill)
        val padH = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 12f, service.resources.displayMetrics,
        ).toInt()
        pill.setPadding(padH, 0, padH, 0)
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
                cancelDictation()
            },
            onTapUp = {
                host.pressHaptic(pill)
                finishDictation()
            },
        )

        // Punto pulsante ●
        val dot = TextView(service)
        dot.text = "●"
        dot.gravity = Gravity.CENTER
        dot.setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
        dot.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10f)
        val dotLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        pill.addView(dot, dotLp)

        // Cronómetro en vivo
        val timer = TextView(service)
        timer.text = "0:00"
        timer.gravity = Gravity.CENTER_VERTICAL
        timer.setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
        timer.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
        timer.setTypeface(null, Typeface.BOLD)
        val timerLp = LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1f,
        )
        val timerMargin = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 6f, service.resources.displayMetrics,
        ).toInt()
        timerLp.setMargins(timerMargin, 0, timerMargin, 0)
        pill.addView(timer, timerLp)

        // Botón cancelar ✕
        val cancel = TextView(service)
        cancel.text = "✕"
        cancel.gravity = Gravity.CENTER
        cancel.setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
        cancel.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14f)
        cancel.setTypeface(null, Typeface.BOLD)
        cancel.isClickable = true
        cancel.isFocusable = true
        cancel.minimumWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 44f, service.resources.displayMetrics,
        ).toInt()
        val cancelPad = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 8f, service.resources.displayMetrics,
        ).toInt()
        cancel.setPadding(cancelPad, 0, cancelPad, 0)
        val cancelLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        cancel.setOnClickListener {
            host.pressHaptic(cancel)
            cancelDictation()
        }
        pill.addView(cancel, cancelLp)

        container.addView(pill)

        micKeyView = container
        micNormalView = normal
        micProcView = proc
        micProcDots = dots
        micPillView = pill
        micPillDot = dot
        micPillTimer = timer
        micPillCancel = cancel

        applyMicVisual()
        return container
    }

    private fun handleMicTap() {
        host.tapFeedback()
        when (micState) {
            MicState.IDLE, MicState.BUSY -> startDictation()
            MicState.RECORDING -> finishDictation()
            MicState.PROCESSING -> { /* en curso: ignorar toques */ }
        }
    }

    private fun bubbleBusy(): Boolean =
        FloatingBubbleService.isRunning && FloatingBubbleService.lastVisualState != "idle"

    private fun startDictation() {
        if (bubbleBusy()) {
            micState = MicState.BUSY
            refreshMicVisual()
            host.showNotice(if (host.isSpanish()) "Ocupado: la burbuja está grabando." else "Busy: the bubble is recording.")
            return
        }
        val config = sttClient.loadConfig()
        if (config.apiKey.isBlank()) {
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
            host.showNotice(
                if (host.isSpanish()) "Permiso de micrófono denegado. Concedelo desde Ajustes."
                else "Microphone permission denied. Allow it from Settings.",
                openSettingsOnClick = true,
            )
            return
        }
        // Segundo tap mientras el arranque sigue en vuelo: ignorar en vez de
        // duplicar la captura (el primero resolverá por callback).
        if (dictationStartPending || micState == MicState.RECORDING || micState == MicState.PROCESSING) {
            return
        }
        dictationStartPending = true
        host.setRecordingActive(true)
        gainAudioFocus()
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
                onDictationStartResult(started, startGeneration)
            }
        }
    }

    /**
     * Cierre del arranque asíncrono en el main. Si el usuario cambió de
     * campo o se destruyó el servicio mientras tanto (generación avanzada),
     * la captura que haya llegado a arrancar se aborta en fondo: sin
     * grabación fantasma ni píldora zombi.
     */
    private fun onDictationStartResult(started: Boolean, startGeneration: Int) {
        dictationStartPending = false
        if (!host.isServiceAlive()) {
            host.setRecordingActive(false)
            if (started) {
                BackgroundWork.execute {
                    try {
                        sttClient.cancelRecording()
                    } catch (_: Exception) {}
                    abandonAudioFocus()
                }
            }
            return
        }
        if (!started || startGeneration != transcriptionGeneration) {
            host.setRecordingActive(false)
            if (started) {
                BackgroundWork.execute {
                    try {
                        sttClient.cancelRecording()
                    } catch (_: Exception) {}
                    abandonAudioFocus()
                }
            } else {
                abandonAudioFocus()
            }
            if (!started && startGeneration == transcriptionGeneration && micState == MicState.IDLE) {
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
        val t = Runnable { if (micState == MicState.RECORDING) finishDictation() }
        timeoutRunnable = t
        handler.postDelayed(t, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun finishDictation() {
        stopRecordingTimer()
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.PROCESSING
        refreshMicVisual()
        val config = sttClient.loadConfig()
        // AT-A1: los callbacks capturan la generacion vigente; si una
        // cancelacion la avanza mientras transcribiamos, se abortan solos.
        val generation = transcriptionGeneration
        BackgroundWork.execute {
            val wav = sttClient.stopRecording()
            abandonAudioFocus()
            host.setRecordingActive(false)
            if (sttClient.isEmptyCapture(wav)) {
                runOnMain {
                    if (generation != transcriptionGeneration) return@runOnMain
                    micIdle()
                    host.showNotice(if (host.isSpanish()) "No se detectó voz." else "No voice detected.")
                }
                return@execute
            }
            sttClient.transcribe(
                wav,
                config,
                onDone = { text ->
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
                            service.currentInputConnection?.commitText(text, 1)
                        }
                    }
                },
                onError = { message ->
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        host.showNotice(message)
                    }
                },
            )
        }
    }

    private fun cancelDictation() {
        stopRecordingTimer()
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.IDLE
        refreshMicVisual()
        BackgroundWork.execute {
            sttClient.cancelRecording()
            abandonAudioFocus()
            host.setRecordingActive(false)
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
        if (micState == MicState.IDLE && !host.isRecordingActive()) return
        val client = if (::sttClient.isInitialized) sttClient else null
        host.setRecordingActive(false)
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        transcriptionGeneration++
        micIdle()
        if (client != null) {
            BackgroundWork.execute {
                try {
                    client.cancelRecording()
                } catch (_: Exception) {}
                abandonAudioFocus()
            }
        }
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

    private fun refreshMicVisual() {
        // AT-A4: sin cambio de campo no hay otro punto que reevalue la
        // burbuja; si ella dejo de grabar, BUSY zombi vuelve a IDLE.
        if (micState == MicState.BUSY && !bubbleBusy()) {
            micState = MicState.IDLE
        }
        applyMicVisual()
    }

    private fun applyMicVisual() {
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()

        val container = micKeyView ?: return
        val normal = micNormalView
        val proc = micProcView
        val pill = micPillView
        val dot = micPillDot
        val timer = micPillTimer
        val parentRow = container.parent as? ViewGroup

        val isRecording = (micState == MicState.RECORDING)
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
        if (isRecording) {
            // Ya no ocultamos la barra espaciadora porque el mic no está en la misma fila!
            if (lp != null && lp.weight != 5.0f) {
                lp.weight = 5.0f // Un peso más grande para empujar y comprimir a los demás iconos suavemente
                container.layoutParams = lp
            }
            container.background = null
            normal?.visibility = View.GONE
            proc?.visibility = View.GONE
            pill?.visibility = View.VISIBLE
            container.contentDescription = if (host.isSpanish()) "grabando dictado" else "recording dictation"

            val elapsed = (SystemClock.elapsedRealtime() - recordingStartMs) / 1000
            micPillTimer?.text = String.format("%d:%02d", elapsed / 60, elapsed % 60)
            if (recordingTimerRunnable == null) {
                startRecordingTimer()
            }

            if (dot != null) {
                dot.scaleX = 1f
                dot.scaleY = 1f
                dot.alpha = 1f
                if (!rm) {
                    val sx = ObjectAnimator.ofFloat(dot, View.SCALE_X, 1f, 1.35f)
                    val sy = ObjectAnimator.ofFloat(dot, View.SCALE_Y, 1f, 1.35f)
                    val alpha = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.4f)
                    listOf(sx, sy, alpha).forEach { a ->
                        a.repeatCount = ObjectAnimator.INFINITE
                        a.repeatMode = ObjectAnimator.REVERSE
                        a.duration = 600
                        a.start()
                    }
                    pulseAnimators = listOf(sx, sy, alpha)
                }
            }
        } else {
            if (lp != null && lp.weight != 1.0f) {
                lp.weight = 1.0f
                container.layoutParams = lp
            }
            pill?.visibility = View.GONE

            when (micState) {
                MicState.IDLE -> {
                    container.background = null
                    proc?.visibility = View.GONE
                    normal?.visibility = View.VISIBLE
                    normal?.setBackgroundResource(R.drawable.kb_key_bg)
                    normal?.setImageResource(R.drawable.kb_ic_mic)
                    normal?.setColorFilter(ContextCompat.getColor(service, R.color.kb_label))
                    normal?.alpha = 1f
                    normal?.contentDescription = if (host.isSpanish()) "dictar" else "dictate"
                    container.contentDescription = if (host.isSpanish()) "dictar" else "dictate"
                }
                MicState.PROCESSING -> {
                    normal?.visibility = View.GONE
                    proc?.visibility = View.VISIBLE
                    proc?.setBackgroundResource(R.drawable.kb_key_alt)
                    container.setBackgroundResource(R.drawable.kb_key_alt)
                    proc?.contentDescription = if (host.isSpanish()) "procesando" else "processing"
                    container.contentDescription = if (host.isSpanish()) "procesando" else "processing"

                    if (!rm) {
                        val animators = mutableListOf<ObjectAnimator>()
                        micProcDots.forEachIndexed { index, dotView ->
                            dotView.scaleX = 0.8f
                            dotView.scaleY = 0.8f
                            dotView.alpha = 0.25f

                            val alphaAnim = ObjectAnimator.ofFloat(dotView, View.ALPHA, 0.25f, 1.0f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            val scaleXAnim = ObjectAnimator.ofFloat(dotView, View.SCALE_X, 0.8f, 1.25f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            val scaleYAnim = ObjectAnimator.ofFloat(dotView, View.SCALE_Y, 0.8f, 1.25f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            alphaAnim.start()
                            scaleXAnim.start()
                            scaleYAnim.start()
                            animators.add(alphaAnim)
                            animators.add(scaleXAnim)
                            animators.add(scaleYAnim)
                        }
                        pulseAnimators = animators
                    } else {
                        micProcDots.forEach { dotView ->
                            dotView.scaleX = 1.0f
                            dotView.scaleY = 1.0f
                            dotView.alpha = 1.0f
                        }
                    }
                }
                MicState.BUSY -> {
                    container.background = null
                    proc?.visibility = View.GONE
                    normal?.visibility = View.VISIBLE
                    normal?.setBackgroundResource(R.drawable.kb_key_alt)
                    normal?.setImageResource(R.drawable.kb_ic_mic)
                    normal?.setColorFilter(ContextCompat.getColor(service, R.color.kb_label))
                    normal?.alpha = 0.5f
                    normal?.contentDescription = if (host.isSpanish()) "micrófono ocupado" else "microphone busy"
                    container.contentDescription = if (host.isSpanish()) "micrófono ocupado" else "microphone busy"
                }
                MicState.RECORDING -> { /* no-op */ }
            }
        }
    }

    private fun gainAudioFocus() {
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
                    if (micState == MicState.RECORDING) {
                        cancelDictation()
                    }
                }
            }.build()
            am.requestAudioFocus(request)
            focusRequest = request
        } catch (_: Exception) {}
    }

    private fun abandonAudioFocus() {
        try {
            focusRequest?.let { request ->
                val am = service.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.abandonAudioFocusRequest(request)
            }
        } catch (_: Exception) {}
        focusRequest = null
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
