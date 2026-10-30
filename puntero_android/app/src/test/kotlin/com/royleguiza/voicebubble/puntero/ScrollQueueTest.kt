package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScrollQueueTest {

    @Test
    fun `el primer delta sale enseguida y marca el trazo activo`() {
        val q = ScrollQueue()
        assertEquals(30f, q.add(10f, 20f, 30f)!!, 0f)
        assertTrue(q.active)
        assertEquals(10f, q.x, 0f)
        assertEquals(20f, q.y, 0f)
    }

    @Test
    fun `mientras hay un trazo en curso los deltas se acumulan`() {
        val q = ScrollQueue()
        q.add(0f, 0f, 30f)
        assertNull(q.add(0f, 0f, 10f))
        assertNull(q.add(0f, 0f, 15f))
        assertEquals(25f, q.finished()!!, 0f)
        assertTrue(q.active)
        assertNull(q.finished())
        assertFalse(q.active)
    }

    @Test
    fun `deltas minimos no generan trazos`() {
        val q = ScrollQueue()
        assertNull(q.add(0f, 0f, 1f))
        assertFalse(q.active)
    }

    @Test
    fun `el acumulado se limita al maximo del protocolo`() {
        val q = ScrollQueue()
        q.add(0f, 0f, 10f)
        repeat(20) { q.add(0f, 0f, 100f) }
        assertEquals(PointerProtocol.MAX_SCROLL_PX, q.finished()!!, 0f)
    }

    @Test
    fun `un clic descarta el scroll pendiente`() {
        val q = ScrollQueue()
        q.add(0f, 0f, 10f)
        q.add(0f, 0f, 50f)
        q.reset()
        assertFalse(q.active)
        assertNull(q.finished())
    }
}
