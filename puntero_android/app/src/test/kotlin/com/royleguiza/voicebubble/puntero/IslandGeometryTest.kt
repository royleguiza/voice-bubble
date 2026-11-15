package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Geometría de la isla (maqueta `laboratorio_ui/isla.html`): tamaños por
 * estado, centrada en x, recortada a la pantalla, y las piezas adentro de la
 * píldora. JVM pura: sin Android.
 */
class IslandGeometryTest {

    private val d = 3f // densidad típica (xxhdpi)
    private val sw = 1080
    private val sh = 2400
    private val def = PointerProtocol.ISLAND_DEFAULT

    private fun size(s: IslandGeometry.State, w: Int = def, h: Int = def, textW: Int = 0, screenW: Int = sw) =
        IslandGeometry.sizeFor(s, w, h, d, screenW, textW)

    @Test
    fun `tamanos por estado de la maqueta`() {
        assertEquals(IslandGeometry.Size(336, 90), size(IslandGeometry.State.IDLE))          // 112 x 30 dp
        assertEquals(IslandGeometry.Size(756, 132), size(IslandGeometry.State.REC))          // 252 x 44 dp
        assertEquals(IslandGeometry.Size(756, 132), size(IslandGeometry.State.THINK))        // pensando mide lo mismo
        assertEquals(IslandGeometry.Size(384, 102), size(IslandGeometry.State.DONE))         // 128 x 34 dp
    }

    @Test
    fun `ancho y alto en reposo respetan los limites de Ajustes`() {
        assertEquals(72 * 3, size(IslandGeometry.State.IDLE, w = 10).w)
        assertEquals(180 * 3, size(IslandGeometry.State.IDLE, w = 9000).w)
        assertEquals(22 * 3, size(IslandGeometry.State.IDLE, h = 5).h)
        assertEquals(48 * 3, size(IslandGeometry.State.IDLE, h = 9000).h)
        assertEquals(100 * 3, size(IslandGeometry.State.IDLE, w = 300).w)
    }

    @Test
    fun `el estado listo se ensancha lo justo para el texto y tiene tope`() {
        assertEquals(128 * 3, size(IslandGeometry.State.DONE, textW = 10).w)
        val wide = size(IslandGeometry.State.DONE, textW = 600).w
        assertTrue(wide > 128 * 3)
        assertEquals((14 * 2 + 15 + 6) * 3 + 600, wide)
        assertEquals(320 * 3, size(IslandGeometry.State.DONE, textW = 5000, screenW = 4000).w)
    }

    @Test
    fun `se centra en x y el borde superior es y`() {
        val s = IslandGeometry.Size(336, 90)
        val r = IslandGeometry.bounds(s, 540, 20, d, sw, sh)
        assertEquals(540 - 168, r.x)
        assertEquals(20, r.y)
        assertEquals(336, r.w)
    }

    @Test
    fun `por defecto queda centrada arriba a 3 dp`() {
        val r = IslandGeometry.bounds(size(IslandGeometry.State.IDLE), def, def, d, sw, sh)
        assertEquals(sw / 2 - 168, r.x)
        assertEquals(9, r.y)
    }

    @Test
    fun `al crecer se mantiene centrada en x`() {
        val idle = IslandGeometry.bounds(size(IslandGeometry.State.IDLE), 540, 9, d, sw, sh)
        val rec = IslandGeometry.bounds(size(IslandGeometry.State.REC), 540, 9, d, sw, sh)
        assertEquals(idle.x + idle.w / 2, rec.x + rec.w / 2)
    }

    @Test
    fun `nunca sale de la pantalla aunque x este en un borde`() {
        val margin = (IslandGeometry.EDGE_MARGIN_DP * d).toInt()
        for (cx in listOf(0, 10, sw - 10, sw, 5000)) {
            for (state in IslandGeometry.State.entries) {
                val r = IslandGeometry.bounds(size(state), cx, 0, d, sw, sh)
                assertTrue("x >= margen ($state, cx=$cx)", r.x >= margin)
                assertTrue("derecha dentro ($state, cx=$cx)", r.right <= sw - margin)
            }
        }
    }

    @Test
    fun `el borde superior se recorta a la pantalla`() {
        val r = IslandGeometry.bounds(size(IslandGeometry.State.REC), 540, 99999, d, sw, sh)
        assertEquals(sh - r.h, r.y)
        assertTrue(r.bottom <= sh)
    }

    @Test
    fun `en pantallas muy angostas la isla se achica para entrar`() {
        val narrow = 300
        for (state in IslandGeometry.State.entries) {
            val s = size(state, screenW = narrow, textW = 400)
            val r = IslandGeometry.bounds(s, 150, 0, d, narrow, sh)
            assertTrue("$state entra", r.x >= 0 && r.right <= narrow)
        }
        // Pantalla diminuta: no explota ni devuelve medidas negativas.
        val tiny = IslandGeometry.bounds(IslandGeometry.Size(336, 90), 10, 0, d, 20, 40)
        assertTrue(tiny.w >= 1 && tiny.h >= 1)
    }

    @Test
    fun `el rebote interpola y la ventana contiene toda la animacion`() {
        val a = IslandGeometry.Rect(100, 10, 300, 90)
        val b = IslandGeometry.Rect(0, 10, 500, 170)
        assertEquals(a, IslandGeometry.lerp(a, b, 0f))
        assertEquals(b, IslandGeometry.lerp(a, b, 1f))
        val over = IslandGeometry.lerp(a, b, 1.1f)
        assertTrue(over.w > b.w)
        val win = IslandGeometry.animationWindow(a, b, d, sw, sh)
        for (t in listOf(0f, 0.5f, 1f, 1.1f)) {
            val r = IslandGeometry.lerp(a, b, t)
            assertTrue(win.x <= r.x + 1 || win.x == 0)
            assertTrue(win.right >= r.right - 1 || win.right == sw)
            assertTrue(win.bottom >= r.bottom - 1 || win.bottom == sh)
        }
        assertTrue(win.x >= 0 && win.right <= sw && win.y >= 0 && win.bottom <= sh)
    }

    @Test
    fun `grabando - agujero, franja, cronometro y cruz caben en la pildora y se espejan`() {
        val s = size(IslandGeometry.State.REC)
        val l = IslandGeometry.recLayout(s.w, s.h, d, true)
        val r = IslandGeometry.recLayout(s.w, s.h, d, false)
        for (lay in listOf(l, r)) {
            assertTrue(lay.hole.x >= 0 && lay.hole.right <= s.w)
            assertTrue(lay.voice.x >= 0 && lay.voice.right <= s.w && lay.voice.w > 0)
            assertTrue(lay.cancel.x >= 0 && lay.cancel.right <= s.w)
            assertTrue(lay.timerCenterX in 0..s.w)
            assertTrue(lay.hole.y >= 0 && lay.hole.bottom <= s.h)
        }
        // Micrófono a la izquierda: agujero, franja, cronómetro, cruz.
        assertTrue(l.hole.right <= l.voice.x + 1)
        assertTrue(l.voice.right <= l.timerCenterX)
        assertTrue(l.timerCenterX < l.cancel.x + l.cancel.w / 2)
        // Espejo exacto con el micrófono a la derecha.
        assertEquals(s.w - (l.hole.x + l.hole.w), r.hole.x)
        assertEquals(s.w - l.timerCenterX, r.timerCenterX)
        // La franja de voz de la maqueta (252 dp) mide 122 dp.
        assertEquals(122 * 3, l.voice.w)
        // El agujero grabando es de 32 dp dentro de una caja de 44 dp.
        assertEquals(44 * 3, l.hole.w)
    }

    @Test
    fun `reposo - agujero de un lado y puntero del otro`() {
        val s = size(IslandGeometry.State.IDLE)
        val l = IslandGeometry.idleLayout(s.w, s.h, d, true)
        val r = IslandGeometry.idleLayout(s.w, s.h, d, false)
        assertTrue(l.dotCx < l.pointerCx)
        assertTrue(r.dotCx > r.pointerCx)
        assertEquals(s.h / 2, l.cy)
        assertTrue(l.dotCx > 0 && l.pointerCx < s.w)
    }

    @Test
    fun `en reposo cada mitad es su boton - sin paso intermedio`() {
        val w = size(IslandGeometry.State.IDLE).w
        val mic = IslandGeometry.Tool.MIC
        val ptr = IslandGeometry.Tool.POINTER
        // Micrófono a la izquierda: mitad izquierda dicta, mitad derecha abre el puntero.
        assertEquals(mic, IslandGeometry.idleTapTool(0f, w, true, true, true))
        assertEquals(mic, IslandGeometry.idleTapTool(w / 2f - 1f, w, true, true, true))
        assertEquals(ptr, IslandGeometry.idleTapTool(w / 2f, w, true, true, true))
        assertEquals(ptr, IslandGeometry.idleTapTool(w - 1f, w, true, true, true))
        // Micrófono a la derecha: en espejo.
        assertEquals(ptr, IslandGeometry.idleTapTool(0f, w, false, true, true))
        assertEquals(mic, IslandGeometry.idleTapTool(w - 1f, w, false, true, true))
        // El toque cae donde está dibujada cada pieza.
        for (left in listOf(true, false)) {
            val l = IslandGeometry.idleLayout(w, 90, d, left)
            assertEquals(mic, IslandGeometry.idleTapTool(l.dotCx.toFloat(), w, left, true, true))
            assertEquals(ptr, IslandGeometry.idleTapTool(l.pointerCx.toFloat(), w, left, true, true))
        }
    }

    @Test
    fun `con una sola herramienta toda la isla es esa herramienta`() {
        val w = size(IslandGeometry.State.IDLE).w
        for (x in listOf(0f, w / 2f, w - 1f)) {
            assertEquals(IslandGeometry.Tool.MIC, IslandGeometry.idleTapTool(x, w, true, true, false))
            assertEquals(IslandGeometry.Tool.POINTER, IslandGeometry.idleTapTool(x, w, true, false, true))
            assertEquals(IslandGeometry.Tool.NONE, IslandGeometry.idleTapTool(x, w, true, false, false))
        }
    }

    @Test
    fun `tiempos de la maqueta`() {
        assertEquals(1300L, IslandGeometry.DONE_MS)
        assertEquals(420L, IslandGeometry.MORPH_MS)
        assertTrue(IslandGeometry.ERROR_MS > IslandGeometry.DONE_MS)
    }
}
