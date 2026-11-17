package com.royleguiza.voicebubblestt

import android.content.Context
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/** Acciones de IA sobre una nota (título y resumen), sea cual sea el proveedor. */
interface NoteAiClient {
    fun sugerirTitulo(texto: String): String
    fun resumir(texto: String): String

    /** Traducción literal (botón «Traducir» y dictado traducido del teclado). */
    fun traducir(texto: String, idiomaDestino: String): String
}

/**
 * Elige el proveedor de IA de notas para el widget (espejo de
 * `NoteAiResolver` en Dart): preferencia `kb_ai_notes_provider` (`groq` por
 * defecto, o `google`); si el elegido no tiene clave, usa el otro; sin
 * ninguna clave devuelve null.
 */
object NoteAiClients {
    const val PROVIDER_PREF = "flutter.kb_ai_notes_provider"
    const val GROQ = "groq"
    const val GOOGLE = "google"

    internal fun normalize(raw: String?): String =
        if (raw?.trim() == GOOGLE) GOOGLE else GROQ

    /** Proveedor efectivo según la elección y las claves presentes (puro, testeable). */
    internal fun choose(wanted: String, hasGroq: Boolean, hasGoogle: Boolean): String? = when {
        wanted == GROQ && hasGroq -> GROQ
        wanted == GOOGLE && hasGoogle -> GOOGLE
        hasGroq -> GROQ
        hasGoogle -> GOOGLE
        else -> null
    }

    private fun groqKey(context: Context): String? =
        SecureStore.read(context, SecureStore.STT_API_KEY)?.trim()?.takeIf { it.isNotEmpty() }

    /** Bloqueante (lee la bóveda): llamar fuera del hilo principal. */
    fun create(context: Context, timeoutMs: Int = GeminiNoteClient.TIMEOUT_MS): NoteAiClient? {
        val wanted = try {
            normalize(
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString(PROVIDER_PREF, GROQ)
            )
        } catch (_: Exception) {
            GROQ
        }
        val groq = groqKey(context)
        val google = GeminiNoteClient.readKey(context)
        return when (choose(wanted, groq != null, google != null)) {
            GROQ -> GroqNoteClient(groq!!, timeoutMs)
            GOOGLE -> GeminiNoteClient(google!!, timeoutMs)
            else -> null
        }
    }
}

/**
 * Notas con Groq (`openai/gpt-oss-20b`), espejo de `GroqNoteService` en Dart:
 * mismo modelo, prompts (los de [GeminiNoteClient]) y topes. Una sola
 * petición por llamada; la clave va en `Authorization`. Bloqueante.
 * Los errores usan [GeminiNoteClient.GeminiError] (nombre histórico).
 */
class GroqNoteClient(
    private val apiKey: String,
    private val timeoutMs: Int = GeminiNoteClient.TIMEOUT_MS,
) : NoteAiClient {

    companion object {
        const val MODEL = "openai/gpt-oss-20b"
        const val ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
        const val TITLE_MAX_TOKENS = 1024
        const val SUMMARY_MAX_TOKENS = 4096

        /** Igual que `GroqNoteService.tooLongMessage` en Dart. */
        const val TOO_LONG_MESSAGE =
            "La nota es muy larga para Groq gratis (unos 20.000 caracteres como " +
                "máximo). Para notas largas elegí Google en Ajustes › Inteligencia " +
                "artificial."

        internal fun buildBody(
            prompt: String,
            maxTokens: Int,
            system: String = GeminiNoteClient.SYSTEM_INSTRUCTION,
        ): String =
            JSONObject()
                .put("model", MODEL)
                .put(
                    "messages",
                    JSONArray()
                        .put(JSONObject().put("role", "system").put("content", system))
                        .put(JSONObject().put("role", "user").put("content", prompt)),
                )
                .put("max_completion_tokens", maxTokens)
                .put("reasoning_effort", "low")
                .toString()

        internal fun extractText(body: String): String? = try {
            JSONObject(body).optJSONArray("choices")?.optJSONObject(0)
                ?.optJSONObject("message")?.optString("content")
                ?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }

        internal fun errorFor(code: Int, body: String): GeminiNoteClient.GeminiError {
            val detail = GeminiNoteClient.bodyDetail(body)
            return when {
                code == 401 || code == 403 -> GeminiNoteClient.GeminiError(
                    "Clave de Groq inválida ($code) $detail", GeminiNoteClient.ErrorKind.AUTH,
                    GeminiNoteClient.Reason.KEY_INVALID, code, detail, "Groq")
                code == 413 -> GeminiNoteClient.GeminiError(
                    TOO_LONG_MESSAGE, GeminiNoteClient.ErrorKind.BAD_REQUEST,
                    GeminiNoteClient.Reason.TOO_LONG, code)
                code == 429 -> GeminiNoteClient.GeminiError(
                    "Límite de Groq alcanzado: $detail", GeminiNoteClient.ErrorKind.SERVER,
                    GeminiNoteClient.Reason.LIMIT, code, detail, "Groq")
                code >= 500 -> GeminiNoteClient.GeminiError(
                    "Error del servidor ($code): $detail", GeminiNoteClient.ErrorKind.SERVER,
                    GeminiNoteClient.Reason.SERVER, code, detail)
                else -> GeminiNoteClient.GeminiError(
                    "Error $code: $detail", GeminiNoteClient.ErrorKind.BAD_REQUEST,
                    GeminiNoteClient.Reason.HTTP, code, detail)
            }
        }
    }

    override fun sugerirTitulo(texto: String): String =
        GeminiNoteClient.cleanTitle(
            run(GeminiNoteClient.fill(GeminiNoteClient.PROMPT_TITULO, texto), TITLE_MAX_TOKENS)
        )

    override fun resumir(texto: String): String =
        run(GeminiNoteClient.fill(GeminiNoteClient.PROMPT_RESUMEN, texto), SUMMARY_MAX_TOKENS)

    override fun traducir(texto: String, idiomaDestino: String): String =
        KeyboardTranslator.cleanTranslation(
            run(
                KeyboardTranslator.userPrompt(texto),
                KeyboardTranslator.maxOutputTokens(texto),
                KeyboardTranslator.systemPrompt(idiomaDestino),
            )
        )

    private fun run(prompt: String, maxTokens: Int, system: String = GeminiNoteClient.SYSTEM_INSTRUCTION): String {
        val conn: HttpURLConnection
        val code: Int
        val body: String
        try {
            conn = URL(ENDPOINT).openConnection() as HttpURLConnection
        } catch (e: Exception) {
            throw GeminiNoteClient.GeminiError("Error de red: ${e.javaClass.simpleName}", GeminiNoteClient.ErrorKind.NETWORK, GeminiNoteClient.Reason.NETWORK)
        }
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setRequestProperty("Authorization", "Bearer $apiKey")
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use {
                it.write(buildBody(prompt, maxTokens, system))
            }
            code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        } catch (_: SocketTimeoutException) {
            throw GeminiNoteClient.GeminiError("Tiempo de espera agotado", GeminiNoteClient.ErrorKind.NETWORK, GeminiNoteClient.Reason.TIMEOUT)
        } catch (e: Exception) {
            throw GeminiNoteClient.GeminiError("Error de red: ${e.javaClass.simpleName}", GeminiNoteClient.ErrorKind.NETWORK, GeminiNoteClient.Reason.NETWORK)
        } finally {
            try {
                conn.disconnect()
            } catch (_: Exception) {}
        }
        if (code == 200) {
            return extractText(body)
                ?: throw GeminiNoteClient.GeminiError("Respuesta vacía del modelo", GeminiNoteClient.ErrorKind.UNKNOWN, GeminiNoteClient.Reason.EMPTY)
        }
        throw errorFor(code, body)
    }
}
