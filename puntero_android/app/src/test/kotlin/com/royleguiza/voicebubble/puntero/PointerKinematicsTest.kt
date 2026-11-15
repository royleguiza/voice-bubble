package com.royleguiza.voicebubble.puntero

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Cinemática del puntero: sensibilidad y curvas de aceleración. */
class PointerKinematicsTest {

    private val density = 2f

    @Test
    fun `lineal solo multiplica por la sensibilidad`() {
        val (x, y) = PointerKinematics.apply(10f, -4f, 1.5f, PointerProtocol.ACCEL_LINEAR, density)
        assertEquals(15f, x, 0.001f)
        assertEquals(-6f, y, 0.001f)
    }

    @Test
    fun `precision mueve menos que lineal`() {
        val (x, _) = PointerKinematics.apply(10f, 0f, 2f, PointerProtocol.ACCEL_PRECISION, density)
        assertEquals(11f, x, 0.001f)
    }

    @Test
    fun `dinamica no acelera los movimientos cortos`() {
        // Umbral = 10 dp = 20 px con densidad 2: 6 px no lo pasa.
        val (x, y) = PointerKinematics.apply(6f, 0f, 1.2f, PointerProtocol.ACCEL_DYNAMIC, density)
        assertEquals(7.2f, x, 0.001f)
        assertEquals(0f, y, 0.001f)
    }

    @Test
    fun `dinamica acelera los barridos largos y se detiene en el tope`() {
        val (shortX, _) = PointerKinematics.apply(40f, 0f, 1f, PointerProtocol.ACCEL_DYNAMIC, density)
        val (longX, _) = PointerKinematics.apply(400f, 0f, 1f, PointerProtocol.ACCEL_DYNAMIC, density)
        assertTrue(shortX > 40f)
        // Tope del factor: 3.2.
        assertEquals(400f * 3.2f, longX, 0.01f)
    }

    @Test
    fun `una curva desconocida se trata como dinamica`() {
        val a = PointerKinematics.apply(30f, 12f, 1f, "turbo", density)
        val b = PointerKinematics.apply(30f, 12f, 1f, PointerProtocol.ACCEL_DYNAMIC, density)
        assertEquals(b.first, a.first, 0f)
        assertEquals(b.second, a.second, 0f)
    }

    @Test
    fun `el sentido del movimiento se conserva`() {
        val (x, y) = PointerKinematics.apply(-30f, 30f, 1f, PointerProtocol.ACCEL_DYNAMIC, density)
        assertTrue(x < 0f)
        assertTrue(y > 0f)
    }
}
