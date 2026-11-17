package com.royleguiza.voicebubblestt

/**
 * Máquina de estados del dictado de la barra flotante (la usa
 * [DockDictationService]). Lógica pura, sin android.*, para testearla en la JVM.
 *
 * Reglas (igual que el dictado de la burbuja por Flutter, que sí aguanta dos
 * toques seguidos):
 * - TOGGLE en reposo empieza; grabando termina; transcribiendo se ignora.
 * - TOGGLE mientras todavía está arrancando el micrófono = «terminar» apenas
 *   arranque (el toque no se pierde).
 * - CANCEL mientras arranca o graba corta y tira el audio; transcribiendo no
 *   se puede cancelar (la red ya salió).
 */
internal class DockDictationLogic {

    enum class Phase { IDLE, STARTING, RECORDING, TRANSCRIBING }

    /** Qué hacer con un TOGGLE. */
    enum class Toggle { START, STOP, QUEUE_STOP, IGNORE }

    /** Qué hacer apenas el micrófono empezó a grabar. */
    enum class AfterStart { KEEP_RECORDING, STOP_NOW, CANCEL_NOW }

    var phase = Phase.IDLE
        private set

    private var stopAfterStart = false
    private var cancelAfterStart = false

    fun onToggle(): Toggle = when (phase) {
        Phase.IDLE -> {
            phase = Phase.STARTING
            stopAfterStart = false
            cancelAfterStart = false
            Toggle.START
        }
        Phase.STARTING -> {
            stopAfterStart = true
            Toggle.QUEUE_STOP
        }
        Phase.RECORDING -> {
            phase = Phase.TRANSCRIBING
            Toggle.STOP
        }
        Phase.TRANSCRIBING -> Toggle.IGNORE
    }

    /** El micrófono ya graba. Devuelve qué hacer con lo que se pidió mientras arrancaba. */
    fun onRecordingStarted(): AfterStart {
        if (phase != Phase.STARTING) return AfterStart.KEEP_RECORDING
        return when {
            cancelAfterStart -> {
                phase = Phase.IDLE
                AfterStart.CANCEL_NOW
            }
            stopAfterStart -> {
                phase = Phase.TRANSCRIBING
                AfterStart.STOP_NOW
            }
            else -> {
                phase = Phase.RECORDING
                AfterStart.KEEP_RECORDING
            }
        }
    }

    /** No arrancó (sin permiso, ocupado, Android lo negó): vuelve a reposo. */
    fun onStartFailed() {
        phase = Phase.IDLE
        stopAfterStart = false
        cancelAfterStart = false
    }

    /**
     * La ✕. true = hay que cortar la grabación ya (estaba grabando); si todavía
     * arrancaba, se corta apenas arranque ([onRecordingStarted]) y devuelve false.
     */
    fun onCancel(): Boolean = when (phase) {
        Phase.RECORDING -> {
            phase = Phase.IDLE
            true
        }
        Phase.STARTING -> {
            cancelAfterStart = true
            false
        }
        else -> false
    }

    /** Terminó todo (transcripción lista o fallida): reposo. */
    fun onFinished() {
        phase = Phase.IDLE
        stopAfterStart = false
        cancelAfterStart = false
    }

    val isBusy: Boolean get() = phase != Phase.IDLE

    companion object {
        /** Audio mínimo útil para transcribir (igual que la app: < 8000 bytes se descarta sin avisar). */
        const val MIN_AUDIO_BYTES = 8000

        // Frases fijas que ve la persona en la barra (nunca texto dictado ni mensajes del servidor):
        // ids de recurso; quien las manda las resuelve con getString (tope: PointerProtocol.MAX_MIC_MESSAGE).
        val MSG_PASTED = R.string.dock_msg_pasted
        val MSG_COPIED = R.string.dock_msg_copied
        val MSG_NO_KEY = R.string.dock_msg_no_key
        val MSG_NO_MIC_PERMISSION = R.string.dock_msg_no_mic_permission
        val MSG_MIC_BUSY = R.string.dock_msg_mic_busy
        val MSG_MIC_FAILED = R.string.dock_msg_mic_failed
        val MSG_NO_NETWORK = R.string.dock_msg_no_network
        val MSG_BAD_KEY = R.string.dock_msg_bad_key
        val MSG_RATE_LIMIT = R.string.dock_msg_rate_limit
        val MSG_FAILED = R.string.dock_msg_failed
        val MSG_NOTHING = R.string.dock_msg_nothing
        val MSG_TOO_BIG = R.string.dock_msg_too_big

        /**
         * Frase corta para un fallo de la transcripción según el código HTTP
         * (null = fallo de red). No se muestra nada del texto del servidor.
         */
        fun errorMessage(code: Int?): Int = when {
            code == null -> MSG_NO_NETWORK
            code == 401 || code == 403 -> MSG_BAD_KEY
            code == 429 -> MSG_RATE_LIMIT
            else -> MSG_FAILED
        }

        /** Frase de éxito: pegado con el teclado propio, o copiado al portapapeles. */
        fun doneMessage(pasted: Boolean): Int = if (pasted) MSG_PASTED else MSG_COPIED

        /** ¿Hay audio suficiente para llamar a la transcripción? */
        fun hasUsableAudio(wavBytes: Int): Boolean = wavBytes >= MIN_AUDIO_BYTES
    }
}
