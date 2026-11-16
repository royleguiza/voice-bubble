package com.royleguiza.voicebubblestt

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Partes puras del dictado por tramos (Ruta IA, etapa 3). */
class DictationTranchesTest {

    private val perSecond = SpeechToTextClient.SAMPLE_RATE * 2

    @Test
    fun `dictados cortos no se cortan`() {
        assertFalse(DictationTranches.shouldCut(10 * perSecond, 2000))
        assertFalse(DictationTranches.shouldCut(24 * perSecond, 2000))
    }

    @Test
    fun `desde 25 s corta en una pausa y a los 40 s corta igual`() {
        assertFalse(DictationTranches.shouldCut(30 * perSecond, 100))
        assertTrue(DictationTranches.shouldCut(25 * perSecond, DictationTranches.SILENCE_MS))
        assertTrue(DictationTranches.shouldCut(40 * perSecond, 0))
    }

    @Test
    fun `silencio por RMS`() {
        val quiet = ByteArray(2048)
        assertTrue(DictationTranches.isQuietFrame(quiet, quiet.size))
        val loud = ByteArray(2048)
        for (i in loud.indices step 2) {
            // 0x1000 = 4096 (little-endian): muy por encima del umbral.
            loud[i] = 0x00
            loud[i + 1] = 0x10
        }
        assertFalse(DictationTranches.isQuietFrame(loud, loud.size))
        assertEquals(64, DictationTranches.frameMs(2048))
    }

    @Test
    fun `une los tramos sin dobles espacios ni vacios`() {
        assertEquals("Hola, ¿cómo estás? Bien.", DictationTranches.joinTexts(listOf(" Hola, ¿cómo estás? ", "", "Bien.")))
        assertEquals("", DictationTranches.joinTexts(emptyList()))
    }

    @Test
    fun `prompt con el final del texto en limite de palabra`() {
        assertNull(DictationTranches.promptFrom("  "))
        assertEquals("corto", DictationTranches.promptFrom("corto"))
        val long = (1..80).joinToString(" ") { "palabra$it" }
        val p = DictationTranches.promptFrom(long)!!
        assertTrue(p.length <= DictationTranches.PROMPT_CHARS)
        assertTrue(long.endsWith(p))
        assertTrue(p.startsWith("palabra"))
    }

    @Test
    fun `solo se reintentan red, limite y servidor`() {
        assertTrue(DictationTranches.isRetryable(null))
        assertTrue(DictationTranches.isRetryable(429))
        assertTrue(DictationTranches.isRetryable(503))
        assertFalse(DictationTranches.isRetryable(401))
        assertFalse(DictationTranches.isRetryable(400))
    }

    @Test
    fun `el ultimo pedazo sale del WAV completo con su cabecera`() {
        val pcm = ByteArray(100) { it.toByte() }
        val full = SpeechToTextClient.wavFromPcm(pcm)
        assertEquals(44 + 100, full.size)
        val tail = SpeechToTextClient.wavTail(full, 60)
        assertEquals(44 + 40, tail.size)
        assertArrayEquals(pcm.copyOfRange(60, 100), tail.copyOfRange(44, tail.size))
        assertEquals("RIFF", String(tail.copyOfRange(0, 4)))
    }
}
