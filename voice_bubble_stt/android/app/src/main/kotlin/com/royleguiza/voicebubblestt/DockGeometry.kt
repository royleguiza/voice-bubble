package com.royleguiza.voicebubblestt

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Geometría y reglas de la barra flotante (prototipo "Burbuja de puntero",
 * aprobado 2026-10-30). Un solo objeto con dos formas:
 *  - EDGE: lengüeta fina pegada a un borde que se abre como un bulto líquido
 *    con las herramientas; se desliza arriba/abajo.
 *  - BUBBLE: burbuja libre; con varias herramientas, se abren en abanico.
 * Arrastrar la barra hacia el centro la vuelve burbuja; soltar la burbuja
 * contra un borde la vuelve barra.
 *
 * Todo en px salvo que el nombre diga dp. Sin android.*: se testea en la JVM.
 */
object DockGeometry {

    enum class Form(val pref: String) {
        EDGE("edge"),
        BUBBLE("bubble");

        companion object {
            fun fromPref(value: String?): Form = entries.firstOrNull { it.pref == value } ?: EDGE
        }
    }

    enum class Side { LEFT, RIGHT }

    enum class Tool { MIC, POINTER }

    /** Qué hace un toque simple sobre la barra/burbuja. */
    enum class TapAction { RUN_ONLY_TOOL, TOGGLE_TOOLS, STOP_RECORDING }

    // --- medidas en dp ---
    const val COLLAPSED_W_DP = 7f
    const val COLLAPSED_H_DP = 66f
    const val COLLAPSED_R_DP = 10f
    const val EXPANDED_W_DP = 62f
    const val EXPANDED_R_DP = 24f
    const val TOOL_DP = 44f
    const val TOOL_GAP_DP = 6f
    const val EXPANDED_PAD_DP = 14f
    /** Ancho tocable de la lengüeta (la parte visible mide 7 dp). */
    const val HIT_W_DP = 30f
    const val BUBBLE_DP = 56f
    const val ARC_TOOL_DP = 48f
    const val ARC_RADIUS_DP = 78f
    const val ARC_SPREAD_RAD = 0.55
    /** Arrastre hacia adentro que convierte la barra en burbuja. */
    const val CONVERT_INWARD_DP = 56f
    /** Burbuja soltada a menos de esto del borde → barra. */
    const val SNAP_EDGE_DP = 44f
    /** Android deja reservar hasta 200 dp por borde frente al gesto Atrás. */
    const val GESTURE_EXCLUSION_MAX_DP = 200f
    /** Inactividad tras la que la barra abierta vuelve a lengüeta. */
    const val EDGE_IDLE_MS = 4000L
    const val ARC_IDLE_MS = 4000L

    data class Shape(val w: Float, val h: Float, val r: Float)

    fun collapsed(d: Float) = Shape(COLLAPSED_W_DP * d, COLLAPSED_H_DP * d, COLLAPSED_R_DP * d)

    fun expanded(d: Float, toolCount: Int): Shape {
        val n = toolCount.coerceAtLeast(1)
        val h = n * TOOL_DP + (n - 1) * TOOL_GAP_DP + 2 * EXPANDED_PAD_DP
        return Shape(EXPANDED_W_DP * d, h * d, EXPANDED_R_DP * d)
    }

    fun lerp(a: Shape, b: Shape, t: Float) = Shape(
        a.w + (b.w - a.w) * t,
        a.h + (b.h - a.h) * t,
        a.r + (b.r - a.r) * t,
    )

    /** Ventana que contiene la forma: alto = cuerpo + los dos cuellos. */
    fun windowWidth(shape: Shape, d: Float): Float = max(shape.w, HIT_W_DP * d)

    fun windowHeight(shape: Shape): Float = shape.h + 2 * shape.r

    /** Alto a excluir del gesto Atrás, con el tope de Android. */
    fun gestureExclusionHeight(windowH: Float, d: Float): Float =
        min(windowH, GESTURE_EXCLUSION_MAX_DP * d)

    /** ¿El arrastre de la barra ya entró lo suficiente para volverse burbuja? */
    fun shouldBecomeBubble(side: Side, dx: Float, d: Float): Boolean {
        val inward = if (side == Side.RIGHT) -dx else dx
        return inward > CONVERT_INWARD_DP * d
    }

    /** Borde al que se pega la burbuja soltada, o null si queda libre. */
    fun snapSide(bubbleCenterX: Float, screenW: Float, d: Float): Side? {
        val snap = SNAP_EDGE_DP * d
        return when {
            bubbleCenterX < snap -> Side.LEFT
            bubbleCenterX > screenW - snap -> Side.RIGHT
            else -> null
        }
    }

    /** Lado natural de una burbuja convertida a barra desde Ajustes. */
    fun nearestSide(centerX: Float, screenW: Float): Side =
        if (centerX < screenW / 2f) Side.LEFT else Side.RIGHT

    /** Centro vertical de la barra dentro de la zona segura. */
    fun clampCenterY(y: Float, screenH: Float, topInset: Float, bottomInset: Float, halfExtent: Float): Float {
        val lo = topInset + halfExtent
        val hi = screenH - bottomInset - halfExtent
        return if (hi <= lo) (topInset + screenH - bottomInset) / 2f else y.coerceIn(lo, hi)
    }

    /** Esquina superior izquierda de la burbuja dentro de la zona segura. */
    fun clampBubble(x: Float, y: Float, size: Float, screenW: Float, screenH: Float, topInset: Float, bottomInset: Float): Pair<Float, Float> {
        val maxX = max(0f, screenW - size)
        val maxY = max(topInset, screenH - bottomInset - size)
        return Pair(x.coerceIn(0f, maxX), y.coerceIn(topInset, maxY))
    }

    /**
     * Centros de las herramientas del abanico: en arco alrededor de la
     * burbuja, abiertas hacia el centro de la pantalla.
     */
    fun arcCenters(cx: Float, cy: Float, screenW: Float, screenH: Float, count: Int, d: Float): List<Pair<Float, Float>> {
        if (count <= 0) return emptyList()
        val base = atan2((screenH / 2f - cy).toDouble(), (screenW / 2f - cx).toDouble())
        val radius = ARC_RADIUS_DP * d
        val half = ARC_TOOL_DP * d / 2f
        return (0 until count).map { i ->
            val offset = if (count == 1) 0.0 else -ARC_SPREAD_RAD + (2 * ARC_SPREAD_RAD) * i / (count - 1)
            val a = base + offset
            val x = (cx + cos(a) * radius).toFloat().coerceIn(half, screenW - half)
            val y = (cy + sin(a) * radius).toFloat().coerceIn(half, screenH - half)
            Pair(x, y)
        }
    }

    /** Herramientas visibles, en orden fijo. Nunca vacío: sin ninguna, queda el micrófono. */
    fun tools(mic: Boolean, pointer: Boolean): List<Tool> {
        val list = buildList {
            if (mic) add(Tool.MIC)
            if (pointer) add(Tool.POINTER)
        }
        return list.ifEmpty { listOf(Tool.MIC) }
    }

    /**
     * Toque simple sobre la burbuja (o sobre la lengüeta cerrada):
     * grabando → detener; una sola herramienta → usarla (la burbuja de
     * siempre: tocar y dictar); varias → mostrar/ocultar herramientas.
     */
    fun tapAction(tools: List<Tool>, recording: Boolean): TapAction = when {
        recording -> TapAction.STOP_RECORDING
        tools.size == 1 -> TapAction.RUN_ONLY_TOOL
        else -> TapAction.TOGGLE_TOOLS
    }

    /** Índice de la herramienta bajo (x, y) en la barra abierta, o -1. Coordenadas locales. */
    fun toolIndexAt(y: Float, shapeTop: Float, shape: Shape, toolCount: Int, d: Float): Int {
        val n = toolCount.coerceAtLeast(1)
        val tool = TOOL_DP * d
        val gap = TOOL_GAP_DP * d
        val stack = n * tool + (n - 1) * gap
        val start = shapeTop + (shape.h - stack) / 2f
        if (y < start || y > start + stack) return -1
        val i = ((y - start) / (tool + gap)).toInt().coerceIn(0, n - 1)
        val inTool = (y - start) - i * (tool + gap) <= tool + gap / 2f
        return if (inTool) i else -1
    }

    /** Centro vertical de la herramienta i en la barra abierta (local). */
    fun toolCenterY(i: Int, shapeTop: Float, shape: Shape, toolCount: Int, d: Float): Float {
        val n = toolCount.coerceAtLeast(1)
        val tool = TOOL_DP * d
        val gap = TOOL_GAP_DP * d
        val stack = n * tool + (n - 1) * gap
        val start = shapeTop + (shape.h - stack) / 2f
        return start + i * (tool + gap) + tool / 2f
    }

    // --- contorno líquido ---

    sealed class Op {
        data class Move(val x: Float, val y: Float) : Op()
        data class Line(val x: Float, val y: Float) : Op()
        data class Quad(val cx: Float, val cy: Float, val x: Float, val y: Float) : Op()
        /** Arco al estilo android.graphics.Path.arcTo(oval, start, sweep). */
        data class Arc(val l: Float, val t: Float, val r: Float, val b: Float, val start: Float, val sweep: Float) : Op()
        object Close : Op()
    }

    /**
     * Contorno de la barra pegada al borde [side], dentro de una caja de
     * ancho [shape].w y alto [windowHeight]: cuello cóncavo arriba, cuerpo
     * redondeado hacia adentro y cuello cóncavo abajo, abierto al borde.
     */
    fun edgeOutline(shape: Shape, side: Side): List<Op> {
        val w = shape.w
        val r = shape.r
        val top = r
        val bot = r + shape.h
        // Radio de las esquinas internas: ~22 dp abierta, la mitad del ancho cerrada.
        val rc = minOf(r * 0.92f, w / 2f, shape.h / 2f).coerceAtLeast(0f)
        val fx = max(0f, min(r, w - rc))
        fun x(v: Float) = if (side == Side.RIGHT) v else w - v
        val ops = mutableListOf<Op>()
        ops += Op.Move(x(w), 0f)
        ops += Op.Quad(x(w), top, x(w - fx), top)
        ops += Op.Line(x(rc), top)
        if (side == Side.RIGHT) {
            ops += Op.Arc(0f, top, 2 * rc, top + 2 * rc, 270f, -90f)
        } else {
            ops += Op.Arc(w - 2 * rc, top, w, top + 2 * rc, 270f, 90f)
        }
        ops += Op.Line(x(0f), bot - rc)
        if (side == Side.RIGHT) {
            ops += Op.Arc(0f, bot - 2 * rc, 2 * rc, bot, 180f, -90f)
        } else {
            ops += Op.Arc(w - 2 * rc, bot - 2 * rc, w, bot, 0f, 90f)
        }
        ops += Op.Line(x(w - fx), bot)
        ops += Op.Quad(x(w), bot, x(w), bot + r)
        ops += Op.Close
        return ops
    }
}
