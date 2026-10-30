package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Gestos del trackpad flotante: mover, clic, clic largo y scroll con dos dedos. */
class PadGesturesTest {

    private fun g() = PadGestures(slopPx = 10f)

    @Test
    fun `tocar rapido es clic`() {
        val p = g()
        p.down(50f, 50f, 0L)
        assertEquals(PadGestures.Action.Tap, p.up(120L))
    }

    @Test
    fun `un temblor dentro del margen sigue siendo clic y no mueve el puntero`() {
        val p = g()
        p.down(50f, 50f, 0L)
        assertNull(p.move(54f, 53f, 1, 53f))
        assertEquals(PadGestures.Action.Tap, p.up(150L))
    }

    @Test
    fun `apoyar demasiado tiempo no es clic`() {
        val p = g()
        p.down(50f, 50f, 0L)
        assertNull(p.up(PadGestures.TAP_MAX_MS + 1))
    }

    @Test
    fun `deslizar mueve sin perder lo recorrido y no hace clic`() {
        val p = g()
        p.down(0f, 0f, 0L)
        assertNull(p.move(6f, 0f, 1, 0f))
        // Al pasar el margen se aplica todo desde el inicio.
        assertEquals(PadGestures.Action.Move(12f, 0f), p.move(12f, 0f, 1, 0f))
        assertEquals(PadGestures.Action.Move(3f, 4f), p.move(15f, 4f, 1, 4f))
        assertNull(p.up(100L))
    }

    @Test
    fun `mantener quieto dispara un solo clic largo y al soltar no hay clic`() {
        val p = g()
        p.down(10f, 10f, 0L)
        assertNull(p.longPressDue(PadGestures.LONG_PRESS_MS - 1))
        assertEquals(PadGestures.Action.LongPress, p.longPressDue(PadGestures.LONG_PRESS_MS))
        assertNull(p.longPressDue(PadGestures.LONG_PRESS_MS + 100))
        assertNull(p.up(PadGestures.LONG_PRESS_MS + 200))
    }

    @Test
    fun `si se movio no hay clic largo`() {
        val p = g()
        p.down(0f, 0f, 0L)
        p.move(30f, 0f, 1, 0f)
        assertNull(p.longPressDue(PadGestures.LONG_PRESS_MS + 50))
    }

    @Test
    fun `dos dedos desplazan sin mover el puntero ni hacer clic`() {
        val p = g()
        p.down(0f, 100f, 0L)
        // Al apoyar el segundo dedo se ancla, sin salto.
        assertNull(p.move(0f, 100f, 2, 110f))
        assertEquals(PadGestures.Action.Scroll(-20f), p.move(0f, 80f, 2, 90f))
        assertNull(p.longPressDue(PadGestures.LONG_PRESS_MS + 10))
        assertNull(p.up(120L))
    }

    @Test
    fun `al levantar un dedo el puntero no salta`() {
        val p = g()
        p.down(0f, 0f, 0L)
        p.move(0f, 0f, 2, 0f)
        assertNull(p.move(200f, 200f, 1, 200f))
        assertEquals(PadGestures.Action.Move(5f, 0f), p.move(205f, 200f, 1, 200f))
    }

    @Test
    fun `sin toque activo no hay acciones`() {
        val p = g()
        assertNull(p.move(10f, 10f, 1, 10f))
        assertNull(p.longPressDue(10_000L))
        assertNull(p.up(10L))
        p.down(0f, 0f, 0L)
        p.cancel()
        assertNull(p.up(10L))
    }

    @Test
    fun `direccion del scroll`() {
        // Natural: el gesto sigue a los dedos.
        assertEquals(30f, PadGestures.scrollDelta(20f, natural = true), 0.001f)
        assertEquals(-30f, PadGestures.scrollDelta(20f, natural = false), 0.001f)
        // La guía funciona como barra de desplazamiento: bajar la guía = avanzar.
        assertTrue(PadGestures.railDelta(10f) < 0f)
        assertEquals(-30f, PadGestures.railDelta(10f), 0.001f)
    }
}
