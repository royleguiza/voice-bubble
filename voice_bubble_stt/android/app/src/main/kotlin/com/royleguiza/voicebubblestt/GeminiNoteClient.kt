package com.royleguiza.voicebubblestt

import android.content.Context
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/**
 * Acciones IA (Gemini) para el editor del widget, sin abrir la app.
 *
 * Espejo de `app_source/lib/services/gemini_note_service.dart`: mismo
 * modelo, prompts, timeout y clasificación de errores. Si se cambia uno,
 * cambiar el otro (el guard de C-48 compara los dos).
 * - Una sola petición por llamada, sin reintentos.
 * - La key viaja en el header `x-goog-api-key`, nunca en la URL ni en logs.
 * - Bloqueante: llamar siempre fuera del hilo principal.
 */
class GeminiNoteClient(
    private val apiKey: String,
    private val timeoutMs: Int = TIMEOUT_MS,
) : NoteAiClient {

    enum class ErrorKind { NETWORK, SERVER, AUTH, BAD_REQUEST, UNKNOWN }

    /** Motivo para mostrar el error en el idioma de la app (Ruta IA, etapa 4). */
    enum class Reason { TIMEOUT, NETWORK, EMPTY, KEY_INVALID, MODEL_UNAVAILABLE, LIMIT, SERVER, HTTP, TOO_LONG }

    /**
     * Error de IA. [message] queda en español para registros; la UI muestra
     * [localized], que usa [reason] con [code], [detail] y [provider].
     */
    class GeminiError(
        message: String,
        val kind: ErrorKind,
        val reason: Reason? = null,
        val code: Int = 0,
        val detail: String = "",
        val provider: String = "",
    ) : Exception(message) {
        fun localized(context: Context): String = when (reason) {
            Reason.TIMEOUT -> context.getString(R.string.ai_err_timeout)
            Reason.NETWORK -> context.getString(R.string.ai_err_network)
            Reason.EMPTY -> context.getString(R.string.ai_err_empty)
            Reason.KEY_INVALID -> context.getString(R.string.ai_err_key_invalid, provider, code.toString(), detail).trim()
            Reason.MODEL_UNAVAILABLE -> context.getString(R.string.ai_err_model_unavailable, detail)
            Reason.LIMIT -> context.getString(R.string.ai_err_limit, provider, detail)
            Reason.SERVER -> context.getString(R.string.ai_err_server, code.toString(), detail)
            Reason.HTTP -> context.getString(R.string.ai_err_http, code.toString(), detail)
            Reason.TOO_LONG -> context.getString(R.string.ai_err_too_long)
            null -> message ?: context.getString(R.string.ai_err_network)
        }
    }

    companion object {
        const val MODEL = "gemini-3.5-flash-lite"
        const val TIMEOUT_MS = 30_000
        private const val MODELS_ENDPOINT =
            "https://generativelanguage.googleapis.com/v1beta/models"

        /** Misma clave que `GeminiKeyStore.secureKey` en Dart. */
        const val SECURE_KEY = "kb_gemini_api_key_v1"

        const val SYSTEM_INSTRUCTION =
            "Respondé siempre en el mismo idioma en que esté escrita la nota. Salvo " +
                "que se indique lo contrario, devolvé texto plano sin markdown ni emojis. " +
                "No inventes información que no esté en la nota."

        val PROMPT_TITULO = """Analizá la siguiente nota dictada por voz y proponé UN título en el mismo
idioma de la nota.
Reglas:
- Máximo 6 palabras y 60 caracteres.
- Sin comillas, sin punto final, sin emojis.
- Debe capturar el tema principal, no una palabra suelta: no respondas con
  una categoría genérica ni con el idioma objetivo del dictado.
- Respondé ÚNICAMENTE el título, sin prefijos ni explicaciones.
- Si la nota no tiene tema claro, devolvé "Nota sin título".

Nota:
""${'"'}{texto}""${'"'}"""

        val PROMPT_RESUMEN = """Resumí la siguiente nota dictada por voz.
Reglas estrictas:
- El resumen debe ser mucho más corto que la nota original (objetivo <= 30%
  del texto, sin extenderse si no hace falta).
- Mencioná solo lo más importante: hechos, decisiones, fechas y nombres que
  aparezcan en la nota. NO inventes datos ni conclusiones.
- Usá viñetas cortas para los puntos clave; una línea inicial con el tema.
- Mantené el idioma de la nota original.
- Texto plano, sin encabezados inventados.

Nota:
""${'"'}{texto}""${'"'}"""

        /** Key de Gemini guardada por la app, o null si no hay. */
        fun readKey(context: Context): String? =
            SecureStore.read(context, SECURE_KEY)?.trim()?.takeIf { it.isNotEmpty() }

        internal fun fill(template: String, texto: String): String =
            template.replace("{texto}", texto)

        internal fun buildBody(
            prompt: String,
            maxOutputTokens: Int,
            system: String = SYSTEM_INSTRUCTION,
        ): String =
            JSONObject()
                .put(
                    "system_instruction",
                    JSONObject().put("parts", JSONArray().put(JSONObject().put("text", system))),
                )
                .put(
                    "contents",
                    JSONArray().put(JSONObject().put("parts", JSONArray().put(JSONObject().put("text", prompt)))),
                )
                .put(
                    "generationConfig",
                    JSONObject()
                        .put("maxOutputTokens", maxOutputTokens)
                        .put("thinkingConfig", JSONObject().put("thinkingLevel", "minimal")),
                )
                .toString()

        internal fun extractText(body: String): String? = try {
            JSONObject(body).optJSONArray("candidates")?.optJSONObject(0)
                ?.optJSONObject("content")?.optJSONArray("parts")?.optJSONObject(0)
                ?.optString("text", "")?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }

        /** Limpia el título: una línea, sin comillas ni punto final. */
        internal fun cleanTitle(raw: String): String =
            raw.lineSequence().firstOrNull { it.isNotBlank() }.orEmpty()
                .trim().trim('"', '“', '”', '\'', '*').trimEnd('.').trim()

        internal fun bodyDetail(body: String): String {
            val trimmed = body.replace(Regex("\\s+"), " ").trim()
            return if (trimmed.length <= 200) trimmed else trimmed.substring(0, 200) + "…"
        }

        internal fun errorFor(code: Int, body: String): GeminiError {
            val detail = bodyDetail(body)
            return when {
                code == 401 || code == 403 -> GeminiError(
                    "API key inválida ($code) $detail", ErrorKind.AUTH, Reason.KEY_INVALID, code, detail, "Google")
                code == 404 -> GeminiError(
                    "Modelo no disponible: $detail", ErrorKind.BAD_REQUEST, Reason.MODEL_UNAVAILABLE, code, detail)
                code == 429 -> GeminiError(
                    "Cuota agotada: $detail", ErrorKind.SERVER, Reason.LIMIT, code, detail, "Google")
                code >= 500 -> GeminiError(
                    "Error del servidor ($code): $detail", ErrorKind.SERVER, Reason.SERVER, code, detail)
                else -> GeminiError("Error $code: $detail", ErrorKind.BAD_REQUEST, Reason.HTTP, code, detail)
            }
        }
    }

    override fun sugerirTitulo(texto: String): String =
        cleanTitle(run(fill(PROMPT_TITULO, texto), maxOutputTokens = 256))

    override fun resumir(texto: String): String =
        run(fill(PROMPT_RESUMEN, texto), maxOutputTokens = 2048)

    override fun traducir(texto: String, idiomaDestino: String): String =
        KeyboardTranslator.cleanTranslation(
            run(
                KeyboardTranslator.userPrompt(texto),
                maxOutputTokens = KeyboardTranslator.maxOutputTokens(texto),
                system = KeyboardTranslator.systemPrompt(idiomaDestino),
            )
        )

    private fun run(prompt: String, maxOutputTokens: Int, system: String = SYSTEM_INSTRUCTION): String {
        val conn: HttpURLConnection
        val code: Int
        val body: String
        try {
            conn = URL("$MODELS_ENDPOINT/$MODEL:generateContent").openConnection() as HttpURLConnection
        } catch (e: Exception) {
            throw GeminiError("Error de red: ${e.javaClass.simpleName}", ErrorKind.NETWORK, Reason.NETWORK)
        }
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = timeoutMs
            conn.readTimeout = timeoutMs
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setRequestProperty("x-goog-api-key", apiKey)
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use {
                it.write(buildBody(prompt, maxOutputTokens, system))
            }
            code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        } catch (_: SocketTimeoutException) {
            throw GeminiError("Tiempo de espera agotado", ErrorKind.NETWORK, Reason.TIMEOUT)
        } catch (e: Exception) {
            throw GeminiError("Error de red: ${e.javaClass.simpleName}", ErrorKind.NETWORK, Reason.NETWORK)
        } finally {
            try {
                conn.disconnect()
            } catch (_: Exception) {}
        }
        if (code == 200) {
            return extractText(body)
                ?: throw GeminiError("Respuesta vacía del modelo", ErrorKind.UNKNOWN, Reason.EMPTY)
        }
        throw errorFor(code, body)
    }
}
