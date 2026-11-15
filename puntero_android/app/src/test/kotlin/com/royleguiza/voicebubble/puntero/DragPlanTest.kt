package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Gesto del arrastre en dos pasos: puntos, tiempos y recorte a pantalla. */
class DragPlanTest {

    @Test
    fun `espera 550 ms en el origen y recorre en 400 ms`() {
        val p = DragPlan.of(100f, 200f, 300f, 600f, 1080, 2400)!!
        assertEquals(550L, DragPlan.HOLD_MS)
        assertEquals(400L, DragPlan.MOVE_MS)
        assertEquals(950L, p.totalMs)
        // El primer trazo arranca ya; el segundo, justo cuando termina la espera.
        assertEquals(0L, p.holdStartMs)
        assertEquals(DragPlan.HOLD_MS, p.moveStartMs)
        assertEquals(100f, p.startX, 0f)
        assertEquals(200f, p.startY, 0f)
        assertEquals(300f, p.endX, 0f)
        assertEquals(600f, p.endY, 0f)
    }

    @Test
    fun `recorta origen y destino a la pantalla`() {
        val p = DragPlan.of(-30f, 5000f, 2000f, -1f, 1080, 2400)!!
        assertEquals(0f, p.startX, 0f)
        assertEquals(2399f, p.startY, 0f)
        assertEquals(1079f, p.endX, 0f)
        assertEquals(0f, p.endY, 0f)
    }

    @Test
    fun `datos invalidos no arman gesto`() {
        assertNull(DragPlan.of(Float.NaN, 0f, 1f, 1f, 1080, 2400))
        assertNull(DragPlan.of(0f, Float.POSITIVE_INFINITY, 1f, 1f, 1080, 2400))
        assertNull(DragPlan.of(0f, 0f, Float.NEGATIVE_INFINITY, 1f, 1080, 2400))
        assertNull(DragPlan.of(0f, 0f, 1f, Float.NaN, 1080, 2400))
        assertNull(DragPlan.of(0f, 0f, 1f, 1f, 0, 2400))
        assertNull(DragPlan.of(0f, 0f, 1f, 1f, 1080, -1))
    }

    @Test
    fun `soltar en el mismo punto sigue siendo un gesto valido`() {
        val p = DragPlan.of(40f, 40f, 40f, 40f, 1080, 2400)
        assertNotNull(p)
        assertTrue(p!!.totalMs > 0)
    }

    @Test
    fun `los extremos de la pantalla son alcanzables`() {
        val p = DragPlan.of(0f, 0f, 1079f, 2399f, 1080, 2400)!!
        assertEquals(1079f, p.endX, 0f)
        assertEquals(2399f, p.endY, 0f)
    }
}
