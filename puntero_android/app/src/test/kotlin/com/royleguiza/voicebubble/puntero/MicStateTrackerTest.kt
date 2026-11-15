package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Lo último que el host contó del dictado, con su vigilante contra un host que muere. JVM pura. */
class MicStateTrackerTest {

    private fun ms(state: String, level: Float = 0f, msg: String? = null) =
        PointerProtocol.normalizeMicState(state, level, msg, false)!!

    @Test
    fun `arranca en reposo`() {
        val t = MicStateTracker()
        assertEquals(PointerProtocol.MIC_IDLE, t.state)
        assertFalse(t.isBusy)
        assertEquals(0, t.elapsedSeconds(1000))
    }

    @Test
    fun `update avisa si cambio el estado y no si solo cambio el nivel`() {
        val t = MicStateTracker()
        assertTrue(t.update(ms("recording", 0.2f), 100))
        assertFalse(t.update(ms("recording", 0.8f), 170))
        assertEquals(0.8f, t.level, 0f)
        assertTrue(t.update(ms("transcribing"), 3000))
    }

    @Test
    fun `el cronometro cuenta desde que empezo a grabar y sigue transcribiendo`() {
        val t = MicStateTracker()
        t.update(ms("recording"), 10_000)
        assertEquals(0, t.elapsedSeconds(10_500))
        assertEquals(3, t.elapsedSeconds(13_999))
        t.update(ms("recording", 0.4f), 14_000)
        assertEquals(4, t.elapsedSeconds(14_000)) // un nivel nuevo no reinicia el reloj
        t.update(ms("transcribing"), 20_000)
        assertEquals(10, t.elapsedSeconds(20_000))
        t.update(ms("idle"), 21_000)
        assertEquals(0, t.elapsedSeconds(22_000))
    }

    @Test
    fun `vigilante - sin noticias mientras graba o transcribe se da por perdido`() {
        val t = MicStateTracker()
        t.update(ms("recording"), 1000)
        assertFalse(t.isStale(1000 + PointerProtocol.MIC_STALE_MS))
        assertTrue(t.isStale(1001 + PointerProtocol.MIC_STALE_MS))
        t.update(ms("recording", 0.3f), 5000)
        assertFalse(t.isStale(5000 + PointerProtocol.MIC_STALE_MS))
        t.update(ms("transcribing"), 6000)
        assertTrue(t.isStale(6001 + PointerProtocol.MIC_STALE_MS))
    }

    @Test
    fun `en reposo, listo o error nunca esta vencido`() {
        val t = MicStateTracker()
        assertFalse(t.isStale(Long.MAX_VALUE / 2))
        t.update(ms("done", msg = "Pegado"), 0)
        assertFalse(t.isStale(Long.MAX_VALUE / 2))
        t.update(ms("error", msg = "Sin conexión"), 0)
        assertFalse(t.isStale(Long.MAX_VALUE / 2))
    }

    @Test
    fun `listo y error se muestran una sola vez`() {
        val t = MicStateTracker()
        t.update(ms("done", msg = "Copiado"), 100)
        assertEquals("Copiado", t.message)
        t.consumeResult()
        assertEquals(PointerProtocol.MIC_IDLE, t.state)
        assertNull(t.message)
        // Grabando no se consume.
        t.update(ms("recording"), 200)
        t.consumeResult()
        assertEquals(PointerProtocol.MIC_RECORDING, t.state)
    }

    @Test
    fun `reset vuelve a reposo`() {
        val t = MicStateTracker()
        t.update(ms("recording", 0.9f), 100)
        t.reset()
        assertEquals(PointerProtocol.MIC_IDLE, t.state)
        assertEquals(0f, t.level, 0f)
        assertFalse(t.isStale(1_000_000))
    }

    @Test
    fun `reloj m ss`() {
        assertEquals("0:00", MicStateTracker.clock(0))
        assertEquals("0:09", MicStateTracker.clock(9))
        assertEquals("1:05", MicStateTracker.clock(65))
        assertEquals("10:00", MicStateTracker.clock(600))
        assertEquals("0:00", MicStateTracker.clock(-4))
    }
}
