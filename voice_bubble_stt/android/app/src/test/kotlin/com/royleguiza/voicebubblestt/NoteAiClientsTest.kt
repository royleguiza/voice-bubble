package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Elección del proveedor de IA de notas del widget (espejo de NoteAiResolver en Dart). */
class NoteAiClientsTest {

    @Test
    fun `valor desconocido o vacio cae a Groq`() {
        assertEquals("groq", NoteAiClients.normalize(null))
        assertEquals("groq", NoteAiClients.normalize(""))
        assertEquals("groq", NoteAiClients.normalize("otro"))
        assertEquals("google", NoteAiClients.normalize(" google "))
    }

    @Test
    fun `usa el elegido si tiene clave y si no el otro`() {
        assertEquals("groq", NoteAiClients.choose("groq", hasGroq = true, hasGoogle = true))
        assertEquals("google", NoteAiClients.choose("google", hasGroq = true, hasGoogle = true))
        assertEquals("groq", NoteAiClients.choose("google", hasGroq = true, hasGoogle = false))
        assertEquals("google", NoteAiClients.choose("groq", hasGroq = false, hasGoogle = true))
        assertNull(NoteAiClients.choose("groq", hasGroq = false, hasGoogle = false))
    }

    @Test
    fun `mismo modelo y topes que el servicio de Dart`() {
        assertEquals("openai/gpt-oss-20b", GroqNoteClient.MODEL)
        assertEquals("https://api.groq.com/openai/v1/chat/completions", GroqNoteClient.ENDPOINT)
        assertEquals(1024, GroqNoteClient.TITLE_MAX_TOKENS)
        assertEquals(4096, GroqNoteClient.SUMMARY_MAX_TOKENS)
    }
}
