package com.royleguiza.voicebubblestt

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.sqrt

/**
 * Dictado por tramos (Ruta IA, etapa 3): en un dictado largo el audio se
 * transcribe de a partes MIENTRAS el usuario habla, así un corte de red o
 * un error no hace perder todo y al soltar solo falta el último pedazo.
 *
 * - [SpeechToTextClient] corta un tramo cuando el tramo actual pasa de
 *   [MIN_SEGMENT_SECONDS] y hay una pausa de [SILENCE_MS], o al llegar a
 *   [MAX_SEGMENT_SECONDS] sin pausa ([shouldCut]). Dictados más cortos no
 *   se cortan: siguen siendo UN pedido, igual que antes.
 * - Los tramos se suben de a uno, en orden (un solo hilo): nunca en
 *   paralelo, así se respeta el vuelo único del cliente y el límite de
 *   pedidos por minuto de Groq (≈ 1 por minuto mientras se habla).
 * - A cada tramo se le pasa el final del texto anterior como `prompt`
 *   (Whisper mantiene la puntuación y el sentido entre tramos).
 * - Un tramo que falla por red, límite (429) o servidor se reintenta hasta
 *   [MAX_RETRIES] veces. Si igual falla, al terminar se sube el audio
 *   COMPLETO como siempre; si eso falla, queda el «Reintentar» del teclado
 *   con el audio entero. Nada se pierde.
 */
internal class DictationTranches(private val client: SpeechToTextClient) {

    companion object {
        // Pedido del dueño tras probar r332: tramos largos y pocas uniones.
        // Hasta un minuto el dictado es idéntico a antes (un solo pedido).
        const val MIN_SEGMENT_SECONDS = 60
        const val MAX_SEGMENT_SECONDS = 90
        const val SILENCE_MS = 400

        /** RMS (escala PCM16) por debajo del cual un cuadro cuenta como pausa. */
        const val SILENCE_RMS = 600.0

        const val MAX_RETRIES = 2
        private val BACKOFF_MS = longArrayOf(1500L, 4000L)

        /** Cuánto del texto anterior viaja como `prompt` (Whisper admite ~224 tokens). */
        const val PROMPT_CHARS = 200

        private const val BYTES_PER_SECOND = SpeechToTextClient.SAMPLE_RATE * 2

        /** ¿Cortar el tramo actual? [segmentBytes] PCM del tramo, [quietMs] pausa en curso. */
        fun shouldCut(segmentBytes: Int, quietMs: Int): Boolean {
            val seconds = segmentBytes / BYTES_PER_SECOND
            return seconds >= MAX_SEGMENT_SECONDS ||
                (seconds >= MIN_SEGMENT_SECONDS && quietMs >= SILENCE_MS)
        }

        /** RMS de un cuadro PCM16 little-endian ([n] bytes válidos). */
        fun rms(buf: ByteArray, n: Int): Double {
            val samples = n / 2
            if (samples <= 0) return 0.0
            var sum = 0.0
            var i = 0
            while (i + 1 < n) {
                val s = ((buf[i + 1].toInt() shl 8) or (buf[i].toInt() and 0xFF)).toShort().toDouble()
                sum += s * s
                i += 2
            }
            return sqrt(sum / samples)
        }

        fun isQuietFrame(buf: ByteArray, n: Int): Boolean = rms(buf, n) < SILENCE_RMS

        /** Milisegundos de audio en [n] bytes PCM16 mono a 16 kHz. */
        fun frameMs(n: Int): Int = n * 1000 / BYTES_PER_SECOND

        /** Une los textos de los tramos en orden, sin dobles espacios ni vacíos. */
        fun joinTexts(parts: List<String>): String =
            parts.map { it.trim() }.filter { it.isNotEmpty() }.joinToString(" ")

        /** Final del texto ya transcripto, cortado en un límite de palabra. */
        fun promptFrom(text: String): String? {
            val t = text.trim()
            if (t.isEmpty()) return null
            if (t.length <= PROMPT_CHARS) return t
            val tail = t.substring(t.length - PROMPT_CHARS)
            val space = tail.indexOf(' ')
            return (if (space in 0 until tail.length - 1) tail.substring(space + 1) else tail).trim()
        }

        /** Reintentable: sin conexión (null), límite (429) o servidor (5xx). */
        fun isRetryable(code: Int?): Boolean = code == null || code == 429 || code >= 500
    }

    private val worker = Executors.newSingleThreadExecutor { r ->
        Thread(r, "VbTranches").apply { isDaemon = true }
    }

    /** Textos de los tramos ya transcriptos (solo los toca el hilo [worker]). */
    private val texts = ArrayList<String>()

    @Volatile
    private var generation = 0

    @Volatile
    private var segments = 0

    @Volatile
    private var failed = false

    @Volatile
    private var config: SpeechToTextClient.Config? = null

    /** Empezó una grabación: tramos nuevos. */
    fun begin(config: SpeechToTextClient.Config) {
        val g = ++generation
        segments = 0
        failed = false
        this.config = config
        worker.execute { if (g == generation) texts.clear() }
    }

    /** Cancelación o dictado corto: se descarta lo que esté en curso. */
    fun cancel() {
        generation++
        segments = 0
    }

    fun hasSegments(): Boolean = segments > 0

    /** El cliente se reemplaza (vista recreada): se corta y se libera el hilo. */
    fun close() {
        cancel()
        worker.shutdown()
    }

    /** Tramo recién cortado (hilo de captura): se encola y se sube en orden. */
    fun onSegment(pcm: ByteArray) {
        val g = generation
        val cfg = config ?: return
        segments++
        worker.execute {
            try {
                if (g != generation || failed) return@execute
                val text = transcribeWithRetries(SpeechToTextClient.wavFromPcm(pcm), cfg, g)
                if (g != generation) return@execute
                if (text == null) failed = true else texts.add(text)
            } finally {
                pcm.fill(0)
            }
        }
    }

    /**
     * Fin del dictado: transcribe el último pedazo ([tailWav]) y entrega el
     * texto completo. Si algún tramo no salió, sube [fullWav] entero (camino
     * de siempre). onDone(null) = cancelado; los callbacks llegan desde un
     * hilo de fondo, como los de [SpeechToTextClient.transcribe].
     */
    fun finish(
        fullWav: ByteArray,
        tailWav: ByteArray?,
        onDone: (String?) -> Unit,
        onError: (code: Int?, message: String) -> Unit,
    ) {
        val g = generation
        val cfg = config ?: run {
            client.transcribe(fullWav, client.getConfig(), onDone, onError)
            return
        }
        worker.execute {
            if (g != generation) {
                onDone(null)
                return@execute
            }
            var ok = !failed
            if (ok && tailWav != null && !client.isEmptyCapture(tailWav)) {
                val tail = transcribeWithRetries(tailWav, cfg, g)
                if (tail == null) ok = false else texts.add(tail)
            }
            if (g != generation) {
                onDone(null)
                return@execute
            }
            if (ok) {
                onDone(joinTexts(texts))
                return@execute
            }
            // Respaldo: el audio completo, como antes de los tramos.
            client.transcribe(fullWav, cfg, onDone, onError)
        }
    }

    private sealed class Outcome {
        data class Ok(val text: String) : Outcome()
        object Cancelled : Outcome()
        data class Failed(val code: Int?) : Outcome()
    }

    private fun transcribeWithRetries(
        wav: ByteArray,
        cfg: SpeechToTextClient.Config,
        g: Int,
    ): String? {
        var attempt = 0
        while (true) {
            if (g != generation) return null
            val prompt = promptFrom(joinTexts(texts))
            when (val r = blockingTranscribe(wav.copyOf(), cfg.copy(prompt = prompt))) {
                is Outcome.Ok -> return r.text
                Outcome.Cancelled -> return null
                is Outcome.Failed -> {
                    if (!isRetryable(r.code) || attempt >= MAX_RETRIES) return null
                    try {
                        Thread.sleep(BACKOFF_MS[attempt])
                    } catch (_: InterruptedException) {
                        return null
                    }
                    attempt++
                }
            }
        }
    }

    /** Envuelve la subida asíncrona del cliente: el hilo [worker] espera su resultado. */
    private fun blockingTranscribe(wav: ByteArray, cfg: SpeechToTextClient.Config): Outcome {
        val latch = CountDownLatch(1)
        var result: Outcome = Outcome.Failed(null)
        client.transcribe(
            wav,
            cfg,
            onDone = { text ->
                result = if (text == null) Outcome.Cancelled else Outcome.Ok(text)
                latch.countDown()
            },
            onError = { code, _ ->
                result = Outcome.Failed(code)
                latch.countDown()
            },
        )
        val waitSeconds = (SpeechToTextClient.TIMEOUT_MAX_SECONDS + SpeechToTextClient.TIMEOUT_READ_SECONDS + 30).toLong()
        if (!latch.await(waitSeconds, TimeUnit.SECONDS)) return Outcome.Failed(null)
        return result
    }
}
