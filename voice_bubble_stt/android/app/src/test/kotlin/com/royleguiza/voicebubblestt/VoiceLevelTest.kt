package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Medidor de volumen de la fase "Voz" (Horizonte): PCM16 → 0..1.
 * JVM pura: sin Android.
 */
class VoiceLevelTest {

    /** Seno de 440 Hz a 16 kHz con amplitud [amp] (0..1 de plena escala). */
    private fun sine(amp: Double, samples: Int = 1024): ByteArray {
        val out = ByteArray(samples * 2)
        for (i in 0 until samples) {
            val s = (amp * 32767.0 * sin(2 * PI * 440.0 * i / 16000.0)).roundToInt()
            out[2 * i] = (s and 0xFF).toByte()
            out[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
        }
        return out
    }

    @Test
    fun `silencio digital da cero`() {
        val buf = ByteArray(2048)
        assertEquals(0f, VoiceLevel.rms(buf, buf.size), 0f)
        assertEquals(0f, VoiceLevel.level(buf, buf.size), 0f)
    }

    @Test
    fun `ruido por debajo del piso da cero`() {
        // Amplitud 0.001 ≈ -63 dBFS RMS: bajo el piso de -55 dB.
        val buf = sine(0.001)
        assertEquals(0f, VoiceLevel.level(buf, buf.size), 0.001f)
    }

    @Test
    fun `seno a plena escala da uno`() {
        val buf = sine(1.0)
        assertEquals(0.707f, VoiceLevel.rms(buf, buf.size), 0.01f)
        assertEquals(1f, VoiceLevel.level(buf, buf.size), 0.001f)
    }

    @Test
    fun `el nivel crece con la amplitud`() {
        var prev = -1f
        for (amp in listOf(0.003, 0.01, 0.03, 0.1, 0.3)) {
            val buf = sine(amp)
            val l = VoiceLevel.level(buf, buf.size)
            assertTrue("amp=$amp dio $l, no mayor que $prev", l > prev)
            assertTrue(l in 0f..1f)
            prev = l
        }
    }

    @Test
    fun `respeta len y tolera buffers impares o vacios`() {
        val buf = sine(1.0)
        assertEquals(0f, VoiceLevel.rms(buf, 0), 0f)
        assertEquals(0f, VoiceLevel.rms(buf, 1), 0f)
        // len mayor que el buffer no se sale de rango.
        assertTrue(VoiceLevel.rms(buf, buf.size + 100) > 0.6f)
    }

    @Test
    fun `muestras negativas se leen con signo`() {
        // -32768 en LE = 00 80: RMS 1.0, no 0.5 (lectura sin signo).
        val buf = byteArrayOf(0x00, 0x80.toByte(), 0x00, 0x80.toByte())
        assertEquals(1f, VoiceLevel.rms(buf, buf.size), 0.001f)
    }

    @Test
    fun `suavizado sube rapido y baja lento`() {
        val up = VoiceLevel.smooth(0f, 1f)
        val down = 1f - VoiceLevel.smooth(1f, 0f)
        assertEquals(VoiceLevel.ATTACK, up, 0.0001f)
        assertEquals(VoiceLevel.RELEASE, down, 0.0001f)
        assertTrue("el ataque debe ser más rápido que la caída", up > down)
    }

    @Test
    fun `medidor converge y vuelve a cero al resetear`() {
        val m = VoiceLevelMeter()
        val loud = sine(1.0)
        m.feed(loud, loud.size)
        assertTrue(m.level >= 0.59f)
        repeat(6) { m.feed(loud, loud.size) }
        assertTrue(m.level > 0.99f)
        // Silencio: cae de a poco, no de golpe.
        val quiet = ByteArray(2048)
        m.feed(quiet, quiet.size)
        assertTrue(m.level > 0.8f)
        repeat(40) { m.feed(quiet, quiet.size) }
        assertTrue(m.level < 0.01f)
        m.reset()
        assertEquals(0f, m.level, 0f)
    }
}
