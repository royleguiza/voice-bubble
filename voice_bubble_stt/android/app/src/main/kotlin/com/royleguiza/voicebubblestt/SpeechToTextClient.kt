package com.royleguiza.voicebubblestt

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import java.io.DataOutputStream
import java.io.IOException
import java.net.SocketTimeoutException
import android.os.SystemClock

/**
 * Cliente STT del teclado (K3): WAV PCM16 16kHz + cloud Groq/OpenAI.
 * Contrato único: docs/contrato-stt.md (bóveda + hilos BackgroundWork).
 */
class SpeechToTextClient(
    private val context: Context,
    private val spanishModeProvider: () -> Boolean = { true },
) {

    companion object {
        private val uploadInFlight = AtomicBoolean(false)
        const val SAMPLE_RATE = 16000

        /** Tope de dictado: 5 minutos. Publico: el teclado arma su timeout desde aca. */
        const val MAX_SECONDS = 300

        private const val WAV_HEADER_BYTES = 44

        /** C-11: Tiempos de red parejos con la app (fórmula 60 + bytes/50k con tope 600). */
        const val TIMEOUT_BASE_SECONDS = 60
        const val TIMEOUT_BYTES_PER_SECOND = 50000
        const val TIMEOUT_MIN_SECONDS = 60
        const val TIMEOUT_MAX_SECONDS = 600
        const val TIMEOUT_READ_SECONDS = 60
        const val MAX_AUDIO_BYTES = 25 * 1024 * 1024 // 25 MB
        const val DEFAULT_URL = "https://api.groq.com/openai/v1/audio/transcriptions"

        fun timeoutForBytes(bytes: Int): Int {
            val seconds = TIMEOUT_BASE_SECONDS + (bytes / TIMEOUT_BYTES_PER_SECOND)
            return seconds.coerceIn(TIMEOUT_MIN_SECONDS, TIMEOUT_MAX_SECONDS)
        }

        /**
         * C-42/C-43: valida contenedor WAV recorriendo sub-chunks (tolera
         * extras como JUNK/LIST/fact de grabadores reales). Espejo de
         * CloudSttService.checkWavHeader de Dart. Devuelve 'ok' o el motivo.
         */
        fun isValidWav(wav: ByteArray): Boolean {
            return checkWavHeader(wav, wav.size) == "ok"
        }

        /**
         * Huella de cabecera para diagnóstico (C-44): 4 primeros bytes en
         * hex + ASCII + tamaño. Solo metadatos, jamás contenido.
         */
        internal fun describeHead(bytes: ByteArray, fileLength: Int): String {
            val digits = "0123456789abcdef"
            val hex = StringBuilder()
            val ascii = StringBuilder()
            val n = if (bytes.size < 4) bytes.size else 4
            for (i in 0 until n) {
                val c = bytes[i].toInt() and 0xFF
                hex.append(digits[(c shr 4) and 0x0F])
                hex.append(digits[c and 0x0F])
                ascii.append(if (c >= 32 && c <= 126) bytes[i].toInt().toChar() else '.')
            }
            return hex.toString() + "/" + ascii.toString() + "/" + fileLength
        }

        /**
         * C-45: tapa WAV PCM 16-bit mono 16kHz (formato propio, espejo de
         * Dart `CloudSttService.buildWavHeader`). Solo metadatos de formato.
         */
        fun buildWavHeader(dataSize: Int): ByteArray {
            val out = ByteArrayOutputStream(WAV_HEADER_BYTES)
            fun le16(v: Int) { out.write(v and 0xFF); out.write((v shr 8) and 0xFF) }
            fun le32(v: Int) { le16(v and 0xFFFF); le16((v shr 16) and 0xFFFF) }
            out.write("RIFF".toByteArray()); le32(dataSize + 36)
            out.write("WAVE".toByteArray())
            out.write("fmt ".toByteArray()); le32(16)
            le16(1); le16(1); le32(SAMPLE_RATE); le32(SAMPLE_RATE * 2)
            le16(2); le16(16)
            out.write("data".toByteArray()); le32(dataSize)
            return out.toByteArray()
        }

        /**
         * C-45 (espejo Dart `tryRepairHolePcm`): rescata un PCM nuestro sin
         * tapa (hueco de 44 ceros + audio real detrás por stop anormal).
         * Devuelve los bytes reparados o null (vacío, extranjero o ilegible:
         * se mantiene el error claro). No toca el original.
         */
        fun tryRepairHolePcmBytes(bytes: ByteArray, fileLength: Int = bytes.size): ByteArray? {
            if (fileLength <= WAV_HEADER_BYTES || bytes.size < WAV_HEADER_BYTES) return null
            for (i in 0 until WAV_HEADER_BYTES) if (bytes[i] != 0.toByte()) return null
            var content = false
            for (i in WAV_HEADER_BYTES until bytes.size) {
                if (bytes[i] != 0.toByte()) { content = true; break }
            }
            if (!content) {
                val tailLen = if (fileLength > 8192) 4096 else fileLength
                val from = maxOf(0, bytes.size - tailLen)
                for (i in from until bytes.size) {
                    if (bytes[i] != 0.toByte()) { content = true; break }
                }
            }
            if (!content) return null
            val dataSize = fileLength - WAV_HEADER_BYTES
            if (dataSize <= 0) return null
            if (bytes.size < fileLength) return null
            val body = bytes.copyOfRange(WAV_HEADER_BYTES, WAV_HEADER_BYTES + dataSize)
            return buildWavHeader(dataSize) + body
        }

        internal fun checkWavHeader(bytes: ByteArray, fileLength: Int): String {            if (bytes.size < 12 || fileLength < 44) return "corto"
            fun u32(o: Int): Int {
                if (o + 4 > bytes.size) return -1
                return (bytes[o].toInt() and 0xFF) or
                    ((bytes[o + 1].toInt() and 0xFF) shl 8) or
                    ((bytes[o + 2].toInt() and 0xFF) shl 16) or
                    ((bytes[o + 3].toInt() and 0xFF) shl 24)
            }
            fun magic(o: Int, s: String): Boolean {
                if (s.length != 4 || o + 4 > bytes.size) return false
                for (i in 0..3) if (bytes[o + i] != s[i].code.toByte()) return false
                return true
            }
            if (!magic(0, "RIFF") || !magic(8, "WAVE")) return "no-riff"
            val riffSize = u32(4)
            if (riffSize < 0 || riffSize.toLong() + 8 > fileLength) return "riff-tamano"
            var pos = 12
            var fmtFound = false
            while (pos + 8 <= bytes.size) {
                val size = u32(pos + 4)
                if (size < 0) return "chunk-roto"
                if (magic(pos, "fmt ")) fmtFound = true
                if (magic(pos, "data")) {
                    if (!fmtFound) return "sin-fmt"
                    if (size <= 0) return "vacio"
                    if (size.toLong() > fileLength - pos - 8) return "trunco"
                    return "ok"
                }
                pos += 8 + size + (size % 2)
            }
            return "sin-data"
        }
    }

    data class Config(
        val url: String,
        val apiKey: String,
        val model: String,
        val language: String,
    )

    /** C-34: Validación estricta de HTTPS. Cualquier URL en claro (http://)
     *  o inválida cae de inmediato al endpoint seguro por defecto (Groq HTTPS). */
    private fun resolveUrl(raw: String?): String {
        val trimmed = raw?.trim().orEmpty()
        return if (trimmed.startsWith("https://", ignoreCase = true)) {
            trimmed
        } else {
            DEFAULT_URL
        }
    }

    /** Modelo vigente: Turbo (rápido, misma calidad). Las prefs escritas
     *  por versiones viejas traen `whisper-large-v3`: se migran en lectura
     *  (la app republica el valor nuevo al abrirse vía saveSttMirror). */
    private fun resolveModel(raw: String?): String =
        if (raw == "whisper-large-v3") "whisper-large-v3-turbo"
        else if (raw.isNullOrBlank()) "whisper-large-v3-turbo"
        else raw

    @Volatile
    private var cachedConfig: Config? = null

    /** C-12: Obtiene la configuración cacheada en memoria si está lista, o carga perezosa. */
    fun getConfig(): Config = cachedConfig ?: loadConfig()

    /** C-12: Precalentamiento de la configuración STT y bóveda en segundo plano antes del foco. */
    fun preloadConfig() {
        if (cachedConfig == null) {
            BackgroundWork.execute {
                loadConfig()
            }
        }
    }

    /** C-12: Recarga asíncrona de configuración fuera del hilo principal. */
    fun refreshConfigAsync(onLoaded: ((Config) -> Unit)? = null) {
        BackgroundWork.executeWithResult(
            block = { loadConfig() },
            onResult = { cfg ->
                if (cfg != null) {
                    onLoaded?.invoke(cfg)
                }
            },
        )
    }

    /** Config D7: ver docs/contrato-stt.md (bóveda + prefs planas). */
    fun loadConfig(): Config {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE,
        )
        val loaded = Config(
            url = resolveUrl(
                prefs.getString(
                    "flutter.kb_stt_url",
                    DEFAULT_URL,
                )
            ),
            apiKey = SecureStore.read(context, SecureStore.STT_API_KEY)
                ?: migrateLegacyMirror(prefs).orEmpty(),
            model = resolveModel(prefs.getString("flutter.kb_stt_model", "whisper-large-v3-turbo")),
            language = prefs.getString("flutter.kb_stt_language", "es") ?: "es",
        )
        // C-19: Lectura de presencia de clave configurada en prefs planas
        try {
            prefs.getBoolean("flutter.kb_stt_key_configured", false)
        } catch (_: Exception) {
            false
        }
        cachedConfig = loaded
        return loaded
    }

    /** C-19: Comprobación rápida de presencia de clave según el contrato STT. */
    fun isKeyConfigured(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return try {
            prefs.getBoolean("flutter.kb_stt_key_configured", false)
        } catch (_: Exception) {
            false
        }
    }

    /** Traslada el espejo plano a la bóveda y lo borra. Solo legado. */
    private fun migrateLegacyMirror(prefs: android.content.SharedPreferences): String? {
        val legacy = try {
            prefs.getString("flutter.kb_stt_api_key", null)
                ?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        } ?: return null
        if (SecureStore.write(context, SecureStore.STT_API_KEY, legacy)) {
            try {
                prefs.edit().remove("flutter.kb_stt_api_key").apply()
            } catch (_: Exception) {
            }
        }
        return legacy
    }

    private val pcmBuffer = ByteArrayOutputStream()
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null

    /** Serializa start/stop/cancel (ver contrato de hilos del KDoc). */
    private val audioLock = Any()

    @Volatile
    private var capturing = false

    @Volatile
    private var cancelRequested = false

    fun isCapturing(): Boolean = capturing

    fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

    /** true si la grabacion arranco; false ante permiso o inicializacion fallida.
     * Síncrono y BLOQUEANTE: solo fuera del main (ver contrato de hilos);
     * desde el main envolver con `BackgroundWork.execute`. */
    fun startRecording(): Boolean {
        synchronized(audioLock) {
            if (capturing) return true
            if (!hasMicPermission()) return false
            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minBuf <= 0) return false
            val rec = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf * 2, 8192),
            )
            if (rec.state != AudioRecord.STATE_INITIALIZED) {
                try { rec.release() } catch (_: Exception) {}
                return false
            }
            pcmBuffer.reset()
            cancelRequested = false
            audioRecord = rec
            rec.startRecording()
            capturing = true
            recordThread = Thread { captureLoop(rec) }.apply {
                name = "VbKeyboardRec"
                start()
            }
            return true
        }
    }

    private fun captureLoop(rec: AudioRecord) {
        val buf = ByteArray(2048)
        val deadline = System.currentTimeMillis() + MAX_SECONDS * 1000L
        while (capturing && System.currentTimeMillis() < deadline) {
            val n = try { rec.read(buf, 0, buf.size) } catch (_: Exception) { -1 }
            if (n > 0) {
                synchronized(pcmBuffer) { pcmBuffer.write(buf, 0, n) }
            } else if (n < 0) {
                break
            }
        }
        try { rec.stop() } catch (_: Exception) {}
        try { rec.release() } catch (_: Exception) {}
    }

    /** Detiene la captura y devuelve el WAV completo (cabecera RIFF + PCM).
     * Síncrono y BLOQUEANTE (join hasta 2.5 s): solo fuera del main;
     * desde el main envolver con `BackgroundWork.execute`. */
    fun stopRecording(): ByteArray {
        synchronized(audioLock) {
            capturing = false
            try { recordThread?.join(2500) } catch (_: Exception) {}
            recordThread = null
            audioRecord = null
            val pcm = synchronized(pcmBuffer) {
                val bytes = pcmBuffer.toByteArray()
                pcmBuffer.reset()
                bytes
            }
            val wav = buildWav(pcm)
            pcm.fill(0)
            return wav
        }
    }

    /** Conexión HTTP activa en vuelo (C-09): AtomicReference para corte inmediato sin fugas. */
    internal val activeConnection = AtomicReference<HttpURLConnection?>(null)

    /** Cancela sin transcribir: descarta el audio capturado y corta la red de verdad (C-09).
     * Síncrono y BLOQUEANTE (join hasta 2.5 s): solo fuera del main;
     * desde el main envolver con `BackgroundWork.execute`. Idempotente. */
    fun cancelRecording() {
        synchronized(audioLock) {
            cancelRequested = true
            capturing = false
            try { recordThread?.join(2500) } catch (_: Exception) {}
            recordThread = null
            audioRecord = null
            synchronized(pcmBuffer) { pcmBuffer.reset() }
        }
        try {
            activeConnection.getAndSet(null)?.disconnect()
        } catch (_: Exception) {}
    }

    /** Cabecera RIFF valida (leccion 9.1-13: contenedor WAV real). */
    private fun buildWav(pcm: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(WAV_HEADER_BYTES + pcm.size)
        fun le16(v: Int) { out.write(v and 0xFF); out.write((v shr 8) and 0xFF) }
        fun le32(v: Int) { le16(v and 0xFFFF); le16((v shr 16) and 0xFFFF) }
        out.write("RIFF".toByteArray()); le32(pcm.size + 36)
        out.write("WAVE".toByteArray())
        out.write("fmt ".toByteArray()); le32(16)
        le16(1)              // PCM
        le16(1)              // mono
        le32(SAMPLE_RATE)
        le32(SAMPLE_RATE * 2)
        le16(2)              // block align
        le16(16)             // bits
        out.write("data".toByteArray()); le32(pcm.size)
        out.write(pcm)
        return out.toByteArray()
    }

    /** Umbral de silencio: menos de ~50 ms de audio capturado. */
    fun isEmptyCapture(wav: ByteArray): Boolean =
        wav.size <= WAV_HEADER_BYTES + SAMPLE_RATE / 20 * 2

    /**
     * POST multipart al endpoint configurado. No bloquea: el trabajo corre
     * en [BackgroundWork] (pool canónico único). Callbacks SIEMPRE desde un
     * hilo de fondo: quien llama debe publicar a UI. onDone(null) =
     * cancelacion.
     * C-13: onError reporta el código HTTP (o null en errores de red/IO) junto con el mensaje.
     */
    /**
     * Vuelo único (C-43): una sola subida a la vez en todo el proceso;
     * un segundo intento concurrente recibe ocupado en vez de golpear
     * la cuota de Groq en paralelo. Se transcribe lo seleccionado.
     */
    fun transcribe(
        wav: ByteArray,
        config: Config,
        onDone: (String?) -> Unit,
        onError: (code: Int?, message: String) -> Unit,
    ) {
        if (!uploadInFlight.compareAndSet(false, true)) {
            onError(
                400,
                if (spanishModeProvider()) "Ya hay una transcripción en curso."
                else "Another transcription is already running."
            )
            return
        }
        // C-45: el buffer del llamador (reintento del teclado, encolado
        // offline del widget) NO se cera: se sube una copia y la limpieza
        // forense C-35 corre sobre la copia. Sin esto, el pendiente offline
        // quedaba en puros ceros [no-riff 00000000] y el reintento también.
        // Además se intenta el rescate de PCM sin tapa antes de validar.
        val snapshot = wav.copyOf()
        val upload = tryRepairHolePcmBytes(snapshot) ?: snapshot
        transcribeGuarded(
            upload,
            config,
            onDone = { text ->
                uploadInFlight.set(false)
                onDone(text)
            },
            onError = { code, message ->
                uploadInFlight.set(false)
                onError(code, message)
            },
        )
    }

    private fun transcribeGuarded(
        wav: ByteArray,
        config: Config,
        onDone: (String?) -> Unit,
        onError: (code: Int?, message: String) -> Unit,
    ) {
        if (wav.size > MAX_AUDIO_BYTES) {
            onError(
                400,
                if (spanishModeProvider()) "El audio supera el límite de 25 MB."
                else "Audio exceeds 25 MB limit."
            )
            return
        }
        // C-42: no subir basura que Groq rechaza con 400 "valid media file".
        // El motivo viaja entre corchetes para diagnosticar en dispositivo.
        val motivo = checkWavHeader(wav, wav.size)
        if (motivo != "ok") {
            val huella = describeHead(wav, wav.size)
            onError(
                400,
                if (spanishModeProvider()) "El audio está dañado [$motivo $huella] y no se puede transcribir."
                else "Audio is corrupted [$motivo] and cannot be transcribed."
            )
            return
        }
        BackgroundWork.execute {
            if (cancelRequested) {
                onDone(null)
                return@execute
            }
            var conn: HttpURLConnection? = null
            try {
                val boundary = "vb${System.currentTimeMillis()}"
                val active = URL(config.url).openConnection() as HttpURLConnection
                conn = active
                activeConnection.set(active)

                if (cancelRequested) {
                    active.disconnect()
                    activeConnection.compareAndSet(active, null)
                    onDone(null)
                    return@execute
                }

                val uploadTimeoutSeconds = timeoutForBytes(wav.size)
                active.requestMethod = "POST"
                active.doOutput = true
                active.connectTimeout = 15000
                active.readTimeout = TIMEOUT_READ_SECONDS * 1000
                active.setRequestProperty("Authorization", "Bearer ${config.apiKey}")
                active.setRequestProperty(
                    "Content-Type", "multipart/form-data; boundary=$boundary",
                )

                // C-09: chequear cancelRequested tras connect
                active.connect()
                if (cancelRequested) {
                    active.disconnect()
                    activeConnection.compareAndSet(active, null)
                    onDone(null)
                    return@execute
                }

                DataOutputStream(active.outputStream).use { d ->
                    fun field(name: String, value: String) {
                        d.writeBytes("--$boundary\r\n")
                        d.writeBytes("Content-Disposition: form-data; name=\"$name\"\r\n\r\n")
                        d.writeBytes("$value\r\n")
                    }
                    field("model", config.model)
                    field("language", config.language)
                    d.writeBytes("--$boundary\r\n")
                    d.writeBytes("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
                    d.writeBytes("Content-Type: audio/wav\r\n\r\n")

                    // C-09: escritura por tramos comprobando cancelación
                    val chunk = 4096
                    var offset = 0
                    val uploadDeadline = SystemClock.elapsedRealtime() + uploadTimeoutSeconds * 1000L
                    while (offset < wav.size) {
                        if (cancelRequested) {
                            active.disconnect()
                            activeConnection.compareAndSet(active, null)
                            onDone(null)
                            return@execute
                        }
                        if (SystemClock.elapsedRealtime() > uploadDeadline) {
                            throw SocketTimeoutException(
                                if (spanishModeProvider()) "Tiempo de subida agotado."
                                else "Upload timed out."
                            )
                        }
                        val len = minOf(chunk, wav.size - offset)
                        d.write(wav, offset, len)
                        offset += len
                    }
                    d.writeBytes("\r\n--$boundary--\r\n")
                    d.flush()
                }

                if (cancelRequested) {
                    active.disconnect()
                    activeConnection.compareAndSet(active, null)
                    onDone(null)
                    return@execute
                }

                val code = active.responseCode

                if (cancelRequested) {
                    active.disconnect()
                    activeConnection.compareAndSet(active, null)
                    onDone(null)
                    return@execute
                }

                // C-09: lectura por tramos comprobando cancelRequested en cada tramo
                val stream = if (code in 200..299) active.inputStream else active.errorStream
                val body = if (stream != null) {
                    val reader = stream.bufferedReader()
                    val sb = StringBuilder()
                    val charBuf = CharArray(1024)
                    var charsRead: Int
                    while (reader.read(charBuf).also { charsRead = it } != -1) {
                        if (cancelRequested) {
                            active.disconnect()
                            activeConnection.compareAndSet(active, null)
                            onDone(null)
                            return@execute
                        }
                        sb.append(charBuf, 0, charsRead)
                    }
                    sb.toString()
                } else {
                    ""
                }

                // La respuesta puede llegar despues de que el usuario cancelo:
                // onDone(null) senala cancelacion.
                if (cancelRequested) {
                    onDone(null)
                    return@execute
                }
                if (code in 200..299) {
                    onDone(JSONObject(body).optString("text", ""))
                } else {
                    onError(code, errorDetail(code, body))
                }
            } catch (_: IOException) {
                if (cancelRequested) {
                    onDone(null)
                    return@execute
                }
                onError(
                    null,
                    if (spanishModeProvider()) "Sin conexión a internet."
                    else "No internet connection."
                )
            } catch (_: Exception) {
                if (cancelRequested) {
                    onDone(null)
                    return@execute
                }
                onError(
                    null,
                    if (spanishModeProvider()) "No se pudo procesar la respuesta."
                    else "Could not process the response."
                )
            } finally {
                // C-35: Limpieza de buffers en memoria para evitar retención forense de audio.
                wav.fill(0)
                // La conexión se libera en TODOS los caminos (éxito, error,
                // cancelación a mitad de vuelo y fallo de setup): sin esto el
                // pool de conexiones retiene sockets hasta el GC finalizer.
                activeConnection.compareAndSet(conn, null)
                try {
                    conn?.disconnect()
                } catch (_: Exception) {}
            }
        }
    }

    /**
     * Sobrecarga de compatibilidad: delega en [transcribe] descartando el código HTTP.
     */
    fun transcribe(
        wav: ByteArray,
        config: Config,
        onDone: (String?) -> Unit,
        onError: (String) -> Unit,
    ) {
        transcribe(wav, config, onDone) { _, message -> onError(message) }
    }

    private fun errorDetail(code: Int, body: String): String {
        val remoteMessage = try {
            val raw = JSONObject(body).optJSONObject("error")?.optString("message") ?: ""
            raw.replace(Regex("[\\r\\n]+"), " ").trim().take(200)
        } catch (_: Exception) { "" }
        val es = spanishModeProvider()
        return when {
            code == 401 || code == 403 ->
                if (es) "API key inválida. Verificala en Ajustes."
                else "Invalid API key. Verify it in Settings."
            code == 429 ->
                if (es) "Límite de solicitudes alcanzado. Esperá un momento."
                else "Request limit reached. Wait a moment."
            remoteMessage.isNotBlank() -> "Error $code: $remoteMessage"
            else -> if (es) "Error del servidor ($code)." else "Server error ($code)."
        }
    }
}
