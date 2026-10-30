package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Espejo del test de VoiceBubble: el protocolo debe validar igual en las dos apps. */
class PointerProtocolTest {

    @Test
    fun `solo acepta operaciones conocidas`() {
        assertNotNull(PointerProtocol.validate(PointerProtocol.OP_TAP, 10f, 20f))
        assertNotNull(PointerProtocol.validate(PointerProtocol.OP_LONG_PRESS, 10f, 20f))
        assertNotNull(PointerProtocol.validate(PointerProtocol.OP_SCROLL, 10f, 20f, 30f))
        assertNull(PointerProtocol.validate("swipe", 10f, 20f))
        assertNull(PointerProtocol.validate(null, 10f, 20f))
    }

    @Test
    fun `rechaza coordenadas invalidas`() {
        assertNull(PointerProtocol.validate(PointerProtocol.OP_TAP, Float.NaN, 20f))
        assertNull(PointerProtocol.validate(PointerProtocol.OP_TAP, 10f, Float.POSITIVE_INFINITY))
        assertNull(PointerProtocol.validate(PointerProtocol.OP_TAP, -1f, 20f))
        assertNull(PointerProtocol.validate(PointerProtocol.OP_TAP, 10f, -0.5f))
    }

    @Test
    fun `el scroll sin recorrido se descarta y el largo se limita`() {
        assertNull(PointerProtocol.validate(PointerProtocol.OP_SCROLL, 10f, 20f, 0.4f))
        assertNull(PointerProtocol.validate(PointerProtocol.OP_SCROLL, 10f, 20f, Float.NaN))
        assertEquals(600f, PointerProtocol.validate(PointerProtocol.OP_SCROLL, 10f, 20f, 5000f)!!.dy, 0f)
        assertEquals(-600f, PointerProtocol.validate(PointerProtocol.OP_SCROLL, 10f, 20f, -5000f)!!.dy, 0f)
    }

    @Test
    fun `el tap ignora el desplazamiento`() {
        assertEquals(0f, PointerProtocol.validate(PointerProtocol.OP_TAP, 1f, 2f, 99f)!!.dy, 0f)
    }

    @Test
    fun `duracion de cada gesto`() {
        assertEquals(PointerProtocol.TAP_MS, PointerProtocol.validate(PointerProtocol.OP_TAP, 1f, 1f)!!.durationMs())
        assertEquals(PointerProtocol.LONG_PRESS_MS, PointerProtocol.validate(PointerProtocol.OP_LONG_PRESS, 1f, 1f)!!.durationMs())
        assertEquals(PointerProtocol.SCROLL_MS, PointerProtocol.validate(PointerProtocol.OP_SCROLL, 1f, 1f, 9f)!!.durationMs())
    }

    @Test
    fun `detecta el servicio activo en la lista de Accesibilidad`() {
        val pkg = PointerProtocol.COMPANION_PACKAGE
        val full = "$pkg/${PointerProtocol.COMPANION_SERVICE_CLASS}"
        val short = "$pkg/.PunteroService"
        assertTrue(PointerProtocol.isServiceEnabled(full))
        assertTrue(PointerProtocol.isServiceEnabled(short))
        assertTrue(PointerProtocol.isServiceEnabled("com.otro/.Svc:$full"))
        assertFalse(PointerProtocol.isServiceEnabled(null))
        assertFalse(PointerProtocol.isServiceEnabled(""))
        assertFalse(PointerProtocol.isServiceEnabled("com.otro/.Svc"))
        assertFalse(PointerProtocol.isServiceEnabled("$pkg/.OtroServicio"))
        assertFalse(PointerProtocol.isServiceEnabled("$pkg/"))
        // Un paquete que solo empieza igual no cuenta.
        assertFalse(PointerProtocol.isServiceEnabled("${pkg}x/.PunteroService"))
    }

    @Test
    fun `estado del complemento`() {
        assertEquals(PointerProtocol.STATUS_MISSING, PointerProtocol.status(installed = false, enabled = true))
        assertEquals(PointerProtocol.STATUS_DISABLED, PointerProtocol.status(installed = true, enabled = false))
        assertEquals(PointerProtocol.STATUS_READY, PointerProtocol.status(installed = true, enabled = true))
    }

    @Test
    fun `aparta la ventana solo si el trazo pasa por ella`() {
        val tap = PointerProtocol.validate(PointerProtocol.OP_TAP, 100f, 100f)!!
        assertTrue(PointerProtocol.pathHits(tap, 50, 50, 150, 150))
        assertFalse(PointerProtocol.pathHits(tap, 200, 200, 300, 300))
        // Con margen: casi en el borde cuenta.
        assertTrue(PointerProtocol.pathHits(tap, 102, 50, 150, 150, slopPx = 4f))
        // Scroll hacia abajo que entra en una ventana más abajo.
        val scroll = PointerProtocol.validate(PointerProtocol.OP_SCROLL, 100f, 100f, 300f)!!
        assertTrue(PointerProtocol.pathHits(scroll, 50, 350, 150, 450))
        assertFalse(PointerProtocol.pathHits(tap, 50, 350, 150, 450))
        // Rectángulo vacío nunca.
        assertFalse(PointerProtocol.pathHits(tap, 100, 100, 100, 100))
    }

    @Test
    fun `solo los clics piden confirmacion`() {
        assertTrue(PointerProtocol.wantsAck(PointerProtocol.OP_TAP))
        assertTrue(PointerProtocol.wantsAck(PointerProtocol.OP_LONG_PRESS))
        assertFalse(PointerProtocol.wantsAck(PointerProtocol.OP_SCROLL))
    }

    @Test
    fun `mensaje segun la respuesta del complemento`() {
        assertEquals(null, PointerProtocol.resultMessage(PointerProtocol.RESULT_DONE))
        assertTrue(PointerProtocol.resultMessage(PointerProtocol.RESULT_CANCELLED)!!.contains("interrumpió"))
        assertTrue(PointerProtocol.resultMessage(PointerProtocol.RESULT_REJECTED)!!.contains("Accesibilidad"))
        // Sin respuesta (o desconocida): el complemento no está escuchando.
        assertTrue(PointerProtocol.resultMessage(null)!!.contains("no responde"))
        assertTrue(PointerProtocol.resultMessage("raro")!!.contains("no responde"))
    }

    @Test
    fun `la respuesta va solo a VoiceBubble`() {
        assertEquals("com.royleguiza.voicebubblestt", PointerProtocol.HOST_PACKAGE)
        assertTrue(PointerProtocol.ACTION_RESULT.startsWith(PointerProtocol.COMPANION_PACKAGE))
        assertTrue(PointerProtocol.ACK_TIMEOUT_MS in 500L..3000L)
    }
}
