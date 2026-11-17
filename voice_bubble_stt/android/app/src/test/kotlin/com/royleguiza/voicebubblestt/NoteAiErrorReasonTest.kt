package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Test

/** Ruta IA, etapa 4: cada error de IA trae su motivo para mostrarlo traducido. */
class NoteAiErrorReasonTest {
    @Test
    fun googleErrorsCarryReasonCodeAndProvider() {
        val auth = GeminiNoteClient.errorFor(401, "bad key")
        assertEquals(GeminiNoteClient.Reason.KEY_INVALID, auth.reason)
        assertEquals(401, auth.code)
        assertEquals("Google", auth.provider)
        assertEquals("bad key", auth.detail)
        assertEquals(GeminiNoteClient.Reason.MODEL_UNAVAILABLE, GeminiNoteClient.errorFor(404, "").reason)
        assertEquals(GeminiNoteClient.Reason.LIMIT, GeminiNoteClient.errorFor(429, "").reason)
        assertEquals(GeminiNoteClient.Reason.SERVER, GeminiNoteClient.errorFor(503, "").reason)
        assertEquals(GeminiNoteClient.Reason.HTTP, GeminiNoteClient.errorFor(400, "").reason)
    }

    @Test
    fun groqErrorsCarryReasonAndProvider() {
        val auth = GroqNoteClient.errorFor(403, "x")
        assertEquals(GeminiNoteClient.Reason.KEY_INVALID, auth.reason)
        assertEquals("Groq", auth.provider)
        assertEquals(GeminiNoteClient.Reason.TOO_LONG, GroqNoteClient.errorFor(413, "").reason)
        val limit = GroqNoteClient.errorFor(429, "slow down")
        assertEquals(GeminiNoteClient.Reason.LIMIT, limit.reason)
        assertEquals("Groq", limit.provider)
        // El mensaje en español queda para registros (y la suite C-48).
        assertEquals(GroqNoteClient.TOO_LONG_MESSAGE, GroqNoteClient.errorFor(413, "").message)
    }
}
