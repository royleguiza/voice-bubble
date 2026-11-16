package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Dónde se abre el panel del trackpad y cómo se reacomoda al girar. */
class TrackpadGeometryTest {

    private val d = 2f
    private val sw = 1080
    private val sh = 2400
    private val nav = 96

    private fun open(mode: String, ax: Int = -1, ay: Int = -1, extended: Boolean = false) =
        TrackpadGeometry.open(mode, sw, sh, nav, ax, ay, extended, d)

    @Test
    fun `panel abajo con margen de 10 dp y sobre la barra de navegacion`() {
        val b = open(PointerProtocol.MODE_PANEL)
        assertEquals(20, b.x)
        assertEquals(sw - 40, b.w)
        // Termina 12 dp (24 px) arriba de la barra de navegacion.
        assertEquals(sh - nav - 24, b.y + b.h)
    }

    @Test
    fun `extendido es mas alto y sigue pegado abajo`() {
        val normal = open(PointerProtocol.MODE_PANEL)
        val ext = open(PointerProtocol.MODE_PANEL, extended = true)
        assertTrue(ext.h > normal.h)
        assertEquals(normal.y + normal.h, ext.y + ext.h)
    }

    @Test
    fun `ventana de 280 dp del lado opuesto al ancla`() {
        val left = open(PointerProtocol.MODE_WINDOW, ax = 100, ay = 1200)
        assertEquals(560, left.w)
        // Ancla en la mitad izquierda: la ventana se abre a su derecha.
        assertEquals(100 + 32, left.x)
        val right = open(PointerProtocol.MODE_WINDOW, ax = 1000, ay = 1200)
        assertEquals(1000 - 560 - 32, right.x)
    }

    @Test
    fun `ventana sin ancla se centra`() {
        val b = open(PointerProtocol.MODE_WINDOW)
        assertEquals(sh / 2 - b.h / 2, b.y)
    }

    @Test
    fun `la ventana nunca se sale de la pantalla`() {
        val top = open(PointerProtocol.MODE_WINDOW, ax = 10, ay = 0)
        assertTrue(top.y >= 80)
        val bottom = open(PointerProtocol.MODE_WINDOW, ax = 10, ay = sh)
        assertTrue(bottom.y + bottom.h <= sh - nav)
        assertTrue(top.x >= 0 && top.x + top.w <= sw)
    }

    @Test
    fun `en horizontal el alto se acota y no explota`() {
        // 360 dp de alto en una pantalla baja: el panel se achica para entrar.
        val h = 720
        val b = TrackpadGeometry.open(PointerProtocol.MODE_PANEL, 2400, h, nav, -1, -1, true, d)
        assertTrue(b.h <= h - nav - 48)
        assertTrue(b.y >= 0)
        val w = TrackpadGeometry.open(PointerProtocol.MODE_WINDOW, 2400, h, nav, 100, 300, true, d)
        assertTrue(w.y + w.h <= h)
    }

    @Test
    fun `el panel se recalcula al girar`() {
        val portrait = open(PointerProtocol.MODE_PANEL)
        val land = TrackpadGeometry.refit(portrait, PointerProtocol.MODE_PANEL, sh, sw, nav, false, d)
        assertEquals(sh - 40, land.w)
        assertTrue(land.y + land.h <= sw - nav)
    }

    @Test
    fun `la ventana libre conserva su lugar y solo se acota`() {
        val b = TrackpadGeometry.Bounds(300, 1500, 560, 592)
        val kept = TrackpadGeometry.refit(b, PointerProtocol.MODE_WINDOW, sw, sh, nav, false, d)
        assertEquals(b.x, kept.x)
        assertEquals(b.y, kept.y)
        // Si la pantalla se achica, queda adentro.
        val small = TrackpadGeometry.refit(b, PointerProtocol.MODE_WINDOW, 900, 1200, nav, false, d)
        assertTrue(small.x + small.w <= 900)
        assertTrue(small.y + small.h <= 1200 - nav)
    }

    @Test
    fun `mover la ventana la acota a la pantalla`() {
        val b = TrackpadGeometry.Bounds(0, 0, 560, 592)
        assertEquals(Pair(0, 0), TrackpadGeometry.clampMove(-50, -50, b, sw, sh))
        assertEquals(Pair(sw - 560, sh - 592), TrackpadGeometry.clampMove(5000, 5000, b, sw, sh))
    }

    @Test
    fun `contiene el punto con margen`() {
        val b = TrackpadGeometry.Bounds(100, 100, 200, 200)
        assertTrue(b.contains(150f, 150f))
        assertFalse(b.contains(99f, 150f))
        assertTrue(b.contains(99f, 150f, slop = 1f))
        assertFalse(b.contains(150f, 301f))
    }

    // ---------------------------------------------------------- fase 3: ventana libre

    @Test
    fun `ventana libre guardada se abre donde la dejaron, ignorando el ancla`() {
        val saved = TrackpadGeometry.Placement(0.1f, 0.05f, 240f, 220f)
        val b = TrackpadGeometry.open(PointerProtocol.MODE_WINDOW, sw, sh, nav, 900, 2000, false, d, saved)
        assertEquals(108, b.x)
        assertEquals(120, b.y)
        assertEquals(480, b.w)
        assertEquals(440, b.h)
    }

    @Test
    fun `el panel abajo no usa el lugar guardado`() {
        val saved = TrackpadGeometry.Placement(0.1f, 0.05f, 240f, 220f)
        val b = TrackpadGeometry.open(PointerProtocol.MODE_PANEL, sw, sh, nav, -1, -1, false, d, saved)
        assertEquals(open(PointerProtocol.MODE_PANEL), b)
    }

    @Test
    fun `guardar y volver a abrir da la misma ventana`() {
        val b = TrackpadGeometry.Bounds(300, 700, 500, 460)
        val p = TrackpadGeometry.toPlacement(b, sw, sh, d)
        val again = TrackpadGeometry.fromPlacement(p, sw, sh, nav, d)
        assertTrue(kotlin.math.abs(again.x - b.x) <= 1)
        assertTrue(kotlin.math.abs(again.y - b.y) <= 1)
        assertEquals(b.w, again.w)
        assertEquals(b.h, again.h)
    }

    @Test
    fun `achicar no baja del minimo y agrandar no se sale de la pantalla`() {
        val b = TrackpadGeometry.Bounds(600, 1500, 560, 592)
        val tiny = TrackpadGeometry.resize(b, 10, 10, sw, sh, nav, d)
        assertEquals((TrackpadGeometry.MIN_WINDOW_W_DP * d).toInt(), tiny.w)
        assertEquals((TrackpadGeometry.MIN_WINDOW_H_DP * d).toInt(), tiny.h)
        assertEquals(b.x, tiny.x)
        assertEquals(b.y, tiny.y)
        val huge = TrackpadGeometry.resize(b, 5000, 5000, sw, sh, nav, d)
        assertEquals(sw, huge.x + huge.w)
        assertEquals(sh - nav, huge.y + huge.h)
    }

    @Test
    fun `al girar la ventana libre conserva su tamano elegido`() {
        val b = TrackpadGeometry.Bounds(100, 300, 460, 420)
        val r = TrackpadGeometry.refit(b, PointerProtocol.MODE_WINDOW, sh, sw, nav, false, d)
        assertEquals(460, r.w)
        assertEquals(420, r.h)
        // Acotada a la pantalla girada.
        assertTrue(r.y + r.h <= sw - nav)
    }

    @Test
    fun `lugar guardado fuera de una pantalla mas chica queda adentro`() {
        val saved = TrackpadGeometry.Placement(0.95f, 0.95f, 400f, 400f)
        val b = TrackpadGeometry.fromPlacement(saved, 720, 1280, 60, 2f)
        assertTrue(b.x >= 0 && b.x + b.w <= 720)
        assertTrue(b.y >= 0 && b.y + b.h <= 1280 - 60)
    }
}
