package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reglas de la barra flotante (prototipo "Burbuja de puntero"): formas,
 * conversión barra ↔ burbuja, límites de pantalla, abanico y toques.
 * JVM pura: sin Android.
 */
class DockGeometryTest {

    private val d = 3f // densidad típica (xxhdpi)
    private val sw = 1080f
    private val sh = 2400f

    @Test
    fun `la lengueta mide 7 dp y la barra abierta crece con las herramientas`() {
        val c = DockGeometry.collapsed(d)
        assertEquals(7f * d, c.w, 0.01f)
        val one = DockGeometry.expanded(d, 1)
        val two = DockGeometry.expanded(d, 2)
        assertEquals(62f * d, two.w, 0.01f)
        // 2 herramientas: 44 + 6 + 44 + 2 * 14 = 122 dp
        assertEquals(122f * d, two.h, 0.01f)
        assertTrue(two.h > one.h)
    }

    @Test
    fun `la ventana de la lengueta es mas ancha que lo visible para poder tocarla`() {
        val c = DockGeometry.collapsed(d)
        assertEquals(DockGeometry.HIT_W_DP * d, DockGeometry.windowWidth(c, d), 0.01f)
        val open = DockGeometry.expanded(d, 2)
        assertEquals(open.w, DockGeometry.windowWidth(open, d), 0.01f)
        assertEquals(open.h + 2 * open.r, DockGeometry.windowHeight(open), 0.01f)
    }

    @Test
    fun `la barra abierta entra en la zona protegida del gesto Atras`() {
        val open = DockGeometry.expanded(d, 2)
        val h = DockGeometry.windowHeight(open)
        assertTrue("la barra abierta no debería superar 200 dp", h <= 200f * d)
        assertEquals(h, DockGeometry.gestureExclusionHeight(h, d), 0.01f)
        assertEquals(200f * d, DockGeometry.gestureExclusionHeight(900f * d, d), 0.01f)
    }

    @Test
    fun `arrastrar hacia adentro la vuelve burbuja, hacia afuera no`() {
        val t = DockGeometry.CONVERT_INWARD_DP * d
        assertTrue(DockGeometry.shouldBecomeBubble(DockGeometry.Side.RIGHT, -(t + 1), d))
        assertFalse(DockGeometry.shouldBecomeBubble(DockGeometry.Side.RIGHT, -(t - 1), d))
        assertFalse(DockGeometry.shouldBecomeBubble(DockGeometry.Side.RIGHT, t + 50, d))
        assertTrue(DockGeometry.shouldBecomeBubble(DockGeometry.Side.LEFT, t + 1, d))
        assertFalse(DockGeometry.shouldBecomeBubble(DockGeometry.Side.LEFT, -(t + 50), d))
    }

    @Test
    fun `la burbuja soltada contra un borde se pega como barra`() {
        val snap = DockGeometry.SNAP_EDGE_DP * d
        assertEquals(DockGeometry.Side.LEFT, DockGeometry.snapSide(snap - 1, sw, d))
        assertEquals(DockGeometry.Side.RIGHT, DockGeometry.snapSide(sw - snap + 1, sw, d))
        assertNull(DockGeometry.snapSide(sw / 2, sw, d))
        assertNull(DockGeometry.snapSide(snap + 1, sw, d))
    }

    @Test
    fun `el centro de la barra queda dentro de la zona segura`() {
        val half = 100f
        val top = 80f
        val bottom = 120f
        assertEquals(top + half, DockGeometry.clampCenterY(0f, sh, top, bottom, half), 0.01f)
        assertEquals(sh - bottom - half, DockGeometry.clampCenterY(sh, sh, top, bottom, half), 0.01f)
        assertEquals(1000f, DockGeometry.clampCenterY(1000f, sh, top, bottom, half), 0.01f)
    }

    @Test
    fun `pantalla minima no rompe el limite vertical`() {
        val y = DockGeometry.clampCenterY(50f, 300f, 100f, 100f, 200f)
        assertEquals(150f, y, 0.01f)
    }

    @Test
    fun `la burbuja no se sale de la pantalla`() {
        val size = DockGeometry.BUBBLE_DP * d
        val (x, y) = DockGeometry.clampBubble(-50f, -50f, size, sw, sh, 80f, 120f)
        assertEquals(0f, x, 0.01f)
        assertEquals(80f, y, 0.01f)
        val (x2, y2) = DockGeometry.clampBubble(5000f, 5000f, size, sw, sh, 80f, 120f)
        assertEquals(sw - size, x2, 0.01f)
        assertEquals(sh - 120f - size, y2, 0.01f)
    }

    @Test
    fun `el abanico se abre hacia el centro de la pantalla`() {
        // Burbuja a la derecha: las herramientas quedan a su izquierda.
        val right = DockGeometry.arcCenters(sw - 100f, sh / 2, sw, sh, 2, d)
        assertEquals(2, right.size)
        right.forEach { (x, _) -> assertTrue(x < sw - 100f) }
        // Burbuja a la izquierda: a su derecha.
        val left = DockGeometry.arcCenters(100f, sh / 2, sw, sh, 2, d)
        left.forEach { (x, _) -> assertTrue(x > 100f) }
        // Dos herramientas separadas (no encimadas).
        val (a, b) = right
        val dist = kotlin.math.hypot(a.first - b.first, a.second - b.second)
        assertTrue("herramientas encimadas: $dist", dist > DockGeometry.ARC_TOOL_DP * d)
    }

    @Test
    fun `el abanico nunca sale de la pantalla aunque la burbuja este en una esquina`() {
        val half = DockGeometry.ARC_TOOL_DP * d / 2
        listOf(0f to 0f, sw to 0f, 0f to sh, sw to sh).forEach { (cx, cy) ->
            DockGeometry.arcCenters(cx, cy, sw, sh, 2, d).forEach { (x, y) ->
                assertTrue(x >= half && x <= sw - half)
                assertTrue(y >= half && y <= sh - half)
            }
        }
    }

    @Test
    fun `herramientas en orden fijo y nunca vacias`() {
        assertEquals(listOf(DockGeometry.Tool.MIC, DockGeometry.Tool.POINTER), DockGeometry.tools(mic = true, pointer = true))
        assertEquals(listOf(DockGeometry.Tool.POINTER), DockGeometry.tools(mic = false, pointer = true))
        assertEquals(listOf(DockGeometry.Tool.MIC), DockGeometry.tools(mic = false, pointer = false))
    }

    @Test
    fun `tocar la burbuja con solo microfono dicta como siempre`() {
        val onlyMic = DockGeometry.tools(mic = true, pointer = false)
        assertEquals(DockGeometry.TapAction.RUN_ONLY_TOOL, DockGeometry.tapAction(onlyMic, recording = false))
        val both = DockGeometry.tools(mic = true, pointer = true)
        assertEquals(DockGeometry.TapAction.TOGGLE_TOOLS, DockGeometry.tapAction(both, recording = false))
        assertEquals(DockGeometry.TapAction.STOP_RECORDING, DockGeometry.tapAction(both, recording = true))
    }

    @Test
    fun `cada toque en la barra abierta cae en su herramienta`() {
        val shape = DockGeometry.expanded(d, 2)
        val top = 10f
        val c0 = DockGeometry.toolCenterY(0, top, shape, 2, d)
        val c1 = DockGeometry.toolCenterY(1, top, shape, 2, d)
        assertEquals(0, DockGeometry.toolIndexAt(c0, top, shape, 2, d))
        assertEquals(1, DockGeometry.toolIndexAt(c1, top, shape, 2, d))
        assertEquals(-1, DockGeometry.toolIndexAt(top, top, shape, 2, d))
        assertEquals(-1, DockGeometry.toolIndexAt(top + shape.h + 50f, top, shape, 2, d))
    }

    @Test
    fun `la forma de la preferencia se lee con valor seguro`() {
        assertEquals(DockGeometry.Form.EDGE, DockGeometry.Form.fromPref("edge"))
        assertEquals(DockGeometry.Form.BUBBLE, DockGeometry.Form.fromPref("bubble"))
        assertEquals(DockGeometry.Form.EDGE, DockGeometry.Form.fromPref(null))
        assertEquals(DockGeometry.Form.EDGE, DockGeometry.Form.fromPref("cualquiera"))
    }

    @Test
    fun `el contorno liquido esta cerrado y dentro de su caja`() {
        for (side in DockGeometry.Side.entries) {
            for (shape in listOf(DockGeometry.collapsed(d), DockGeometry.expanded(d, 2))) {
                val ops = DockGeometry.edgeOutline(shape, side)
                assertTrue(ops.first() is DockGeometry.Op.Move)
                assertTrue(ops.last() is DockGeometry.Op.Close)
                val h = DockGeometry.windowHeight(shape)
                ops.forEach { op ->
                    val pts = when (op) {
                        is DockGeometry.Op.Move -> listOf(op.x to op.y)
                        is DockGeometry.Op.Line -> listOf(op.x to op.y)
                        is DockGeometry.Op.Quad -> listOf(op.cx to op.cy, op.x to op.y)
                        is DockGeometry.Op.Arc -> listOf(op.l to op.t, op.r to op.b)
                        DockGeometry.Op.Close -> emptyList()
                    }
                    pts.forEach { (x, y) ->
                        assertTrue("x fuera ($side): $x", x >= -0.01f && x <= shape.w + 0.01f)
                        assertTrue("y fuera ($side): $y", y >= -0.01f && y <= h + 0.01f)
                    }
                }
            }
        }
    }

    @Test
    fun `el contorno arranca y termina pegado al borde de su lado`() {
        val shape = DockGeometry.expanded(d, 2)
        val right = DockGeometry.edgeOutline(shape, DockGeometry.Side.RIGHT)
        val left = DockGeometry.edgeOutline(shape, DockGeometry.Side.LEFT)
        assertEquals(shape.w, (right.first() as DockGeometry.Op.Move).x, 0.01f)
        assertEquals(0f, (left.first() as DockGeometry.Op.Move).x, 0.01f)
        val lastQuadRight = right.filterIsInstance<DockGeometry.Op.Quad>().last()
        assertEquals(shape.w, lastQuadRight.x, 0.01f)
        assertEquals(DockGeometry.windowHeight(shape), lastQuadRight.y, 0.01f)
    }

    @Test
    fun `la animacion interpola entre lengueta y barra abierta`() {
        val a = DockGeometry.collapsed(d)
        val b = DockGeometry.expanded(d, 2)
        assertEquals(a, DockGeometry.lerp(a, b, 0f))
        assertEquals(b, DockGeometry.lerp(a, b, 1f))
        val mid = DockGeometry.lerp(a, b, 0.5f)
        assertEquals((a.w + b.w) / 2, mid.w, 0.01f)
    }
}
