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
import java.io.DataOutputStream

/**
 * Cliente STT del teclado (K3): graba WAV PCM16 mono 16kHz y consulta el
 * motor cloud (Groq/OpenAI) con multipart via HttpURLConnection.
 * Sin dependencias nuevas. JAMAS guarda el audio ni el resultado mas alla
 * del ciclo de dictado; solo escribe en el historial compartido el texto
 * final (via VoiceKeyboardService).
 * K5-T4: los mensajes de error se localizan es/en consultando el idioma
 * activo del teclado via [spanishModeProvider] en el momento del fallo,
 * sin estado propio que pueda quedar desincronizado a mitad de sesion.
 */
class SpeechToTextClient(
    private val context: Context,
    private val spanishModeProvider: () -> Boolean = { true },
) {

    companion object {
        const val SAMPLE_RATE = 16000

        /** Tope de dictado: 5 minutos. Publico: el teclado arma su timeout desde aca. */
        const val MAX_SECONDS = 300

        private const val WAV_HEADER_BYTES = 44
    }

    data class Config(
        val url: String,
        val apiKey: String,
        val model: String,
        val language: String,
    )

    /** Contrato D7: los Ajustes (Flutter) escriben estas claves espejo. */
    fun loadConfig(): Config {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE,
        )
        return Config(
            url = prefs.getString(
                "flutter.kb_stt_url",
                "https://api.groq.com/openai/v1/audio/transcriptions",
            ) ?: "https://api.groq.com/openai/v1/audio/transcriptions",
            apiKey = prefs.getString("flutter.kb_stt_api_key", "") ?: "",
            model = prefs.getString("flutter.kb_stt_model", "whisper-large-v3")
                ?: "whisper-large-v3",
            language = prefs.getString("flutter.kb_stt_language", "es") ?: "es",
        )
    }

    private val pcmBuffer = ByteArrayOutputStream()
    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null

    @Volatile
    private var capturing = false

    @Volatile
    private var cancelRequested = false

    fun isCapturing(): Boolean = capturing

    fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

    /** true si la grabacion arranco; false ante permiso o inicializacion fallida. */
    fun startRecording(): Boolean {
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

    /** Detiene la captura y devuelve el WAV completo (cabecera RIFF + PCM). */
    fun stopRecording(): ByteArray {
        capturing = false
        try { recordThread?.join(2500) } catch (_: Exception) {}
        recordThread = null
        audioRecord = null
        val pcm = synchronized(pcmBuffer) { pcmBuffer.toByteArray() }
        return buildWav(pcm)
    }

    /** Cancela sin transcribir: descarta el audio capturado. */
    fun cancelRecording() {
        cancelRequested = true
        capturing = false
        try { recordThread?.join(2500) } catch (_: Exception) {}
        recordThread = null
        audioRecord = null
        synchronized(pcmBuffer) { pcmBuffer.reset() }
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
     * POST multipart al endpoint configurado. Callbacks SIEMPRE desde un hilo
     * de fondo: quien llama debe publicar a UI. onDone(null) = cancelacion.
     */
    fun transcribe(
        wav: ByteArray,
        config: Config,
        onDone: (String?) -> Unit,
        onError: (String) -> Unit,
    ) {
        Thread {
            if (cancelRequested) {
                onDone(null)
                return@Thread
            }
            try {
                val boundary = "vb${System.currentTimeMillis()}"
                val conn = URL(config.url).openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.connectTimeout = 15000
                conn.readTimeout = 240000
                conn.setRequestProperty("Authorization", "Bearer ${config.apiKey}")
                conn.setRequestProperty(
                    "Content-Type", "multipart/form-data; boundary=$boundary",
                )
                DataOutputStream(conn.outputStream).use { d ->
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
                    d.write(wav)
                    d.writeBytes("\r\n--$boundary--\r\n")
                    d.flush()
                }
                val code = conn.responseCode
                val body = (if (code in 200..299) conn.inputStream else conn.errorStream)
                    ?.bufferedReader()?.use { it.readText() } ?: ""
                if (code in 200..299) {
                    onDone(JSONObject(body).optString("text", ""))
                } else {
                    onError(errorDetail(code, body))
                }
            } catch (_: Exception) {
                onError(
                    if (spanishModeProvider()) "Sin conexión a internet."
                    else "No internet connection."
                )
            }
        }.apply {
            name = "VbKeyboardStt"
            start()
        }
    }

    /**
     * Espeja la clasificacion de errores de CloudSttService (Dart), con la
     * variante es/en segun el idioma activo del teclado (K5-T4).
     */
    private fun errorDetail(code: Int, body: String): String {
        val remoteMessage = try {
            JSONObject(body).optJSONObject("error")?.optString("message") ?: ""
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
