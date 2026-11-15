package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Protocolo VoiceBubble → VoiceBubble Puntero (JVM pura). */
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

    @Test
    fun `scroll largo en tramos sin perder recorrido`() {
        val max = PointerProtocol.MAX_SCROLL_PX
        assertEquals(listOf(max, max, 300f), PointerProtocol.scrollChunks(2 * max + 300f))
        assertEquals(listOf(-max, -50f), PointerProtocol.scrollChunks(-max - 50f))
        assertEquals(listOf(120f), PointerProtocol.scrollChunks(120f))
        assertTrue(PointerProtocol.scrollChunks(0.5f).isEmpty())
        assertTrue(PointerProtocol.scrollChunks(Float.NaN).isEmpty())
        // Tope de seguridad: nunca más de 20 tramos.
        assertEquals(20, PointerProtocol.scrollChunks(1e9f).size)
    }

    @Test
    fun `la configuracion valida de OPEN_TRACKPAD pasa tal cual`() {
        val c = PointerProtocol.normalizeTrackpadConfig(
            anchorX = 120, anchorY = 800, mode = PointerProtocol.MODE_WINDOW, sensitivity = 2f,
            accel = PointerProtocol.ACCEL_PRECISION, style = PointerProtocol.STYLE_CROSS,
            haptic = PointerProtocol.HAPTIC_FIRM, scrollDir = PointerProtocol.SCROLL_TRADITIONAL, autoReturnS = 15,
        )
        assertEquals(PointerProtocol.TrackpadConfig(120, 800, "window", 2f, "precision", "cross", "firm", "traditional", 15), c)
        assertTrue(c.hasAnchor)
        assertFalse(c.naturalScroll)
    }

    @Test
    fun `lo desconocido o fuera de rango cae al valor por defecto`() {
        val c = PointerProtocol.normalizeTrackpadConfig(
            anchorX = -5, anchorY = 300, mode = "flotando", sensitivity = 9f,
            accel = "turbo", style = "estrella", haptic = "fuerte", scrollDir = "standard", autoReturnS = -3,
        )
        assertEquals(PointerProtocol.TrackpadConfig(-1, -1, "panel", 1.2f, "dynamic", "arrow", "subtle", "natural", 0), c)
        assertFalse(c.hasAnchor)
        assertTrue(c.naturalScroll)
    }

    @Test
    fun `configuracion sin datos usa los valores por defecto`() {
        val c = PointerProtocol.normalizeTrackpadConfig(-1, -1, null, Float.NaN, null, null, null, null, 0)
        assertEquals(PointerProtocol.DEFAULT_SENSITIVITY, c.sensitivity, 0f)
        assertEquals(PointerProtocol.MODE_PANEL, c.mode)
        assertEquals(PointerProtocol.ACCEL_DYNAMIC, c.accel)
        assertEquals(PointerProtocol.STYLE_ARROW, c.style)
        assertEquals(PointerProtocol.HAPTIC_SUBTLE, c.haptic)
        assertEquals(PointerProtocol.SCROLL_NATURAL, c.scrollDir)
        assertEquals(0, c.autoReturnS)
    }

    @Test
    fun `sensibilidad y cierre automatico respetan sus limites`() {
        fun cfg(sens: Float, auto: Int) =
            PointerProtocol.normalizeTrackpadConfig(-1, -1, null, sens, null, null, null, null, auto)
        assertEquals(0.5f, cfg(0.5f, 0).sensitivity, 0f)
        assertEquals(2.5f, cfg(2.5f, 0).sensitivity, 0f)
        assertEquals(1.2f, cfg(0.49f, 0).sensitivity, 0f)
        assertEquals(1.2f, cfg(2.51f, 0).sensitivity, 0f)
        assertEquals(1.2f, cfg(Float.POSITIVE_INFINITY, 0).sensitivity, 0f)
        assertEquals(PointerProtocol.MAX_AUTO_RETURN_S, cfg(1f, PointerProtocol.MAX_AUTO_RETURN_S).autoReturnS)
        assertEquals(0, cfg(1f, PointerProtocol.MAX_AUTO_RETURN_S + 1).autoReturnS)
    }

    @Test
    fun `una sola coordenada de ancla equivale a sin ancla`() {
        val c = PointerProtocol.normalizeTrackpadConfig(50, -1, null, 1f, null, null, null, null, 0)
        assertEquals(-1, c.anchorX)
        assertEquals(-1, c.anchorY)
        assertFalse(c.hasAnchor)
    }

    @Test
    fun `las acciones del trackpad son del complemento y el estado vuelve solo a VoiceBubble`() {
        for (a in listOf(PointerProtocol.ACTION_OPEN_TRACKPAD, PointerProtocol.ACTION_CLOSE_TRACKPAD, PointerProtocol.ACTION_TRACKPAD_STATE)) {
            assertTrue(a.startsWith(PointerProtocol.COMPANION_PACKAGE))
        }
        assertEquals(3, setOf(
            PointerProtocol.ACTION_OPEN_TRACKPAD, PointerProtocol.ACTION_CLOSE_TRACKPAD, PointerProtocol.ACTION_TRACKPAD_STATE,
        ).size)
    }
}
