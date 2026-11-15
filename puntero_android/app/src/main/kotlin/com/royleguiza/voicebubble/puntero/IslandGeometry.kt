package com.royleguiza.voicebubble.puntero

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Geometría de la isla (maqueta `laboratorio_ui/isla.html`): tamaños por
 * estado, posición centrada en `x` y recortada a la pantalla, y dónde cae
 * cada pieza adentro de la píldora. Lógica pura (sin android.*) para testearla
 * en la JVM; todo en px salvo que el nombre diga dp.
 *
 * Posición: `x` = centro horizontal y `y` = borde superior, en px de pantalla
 * completa (puede quedar sobre la barra de estado y la cámara). Al crecer se
 * mantiene centrada en `x`; la píldora nunca sale de la pantalla, sea cual sea
 * el tamaño del teléfono o lo que haya pedido Ajustes.
 */
object IslandGeometry {

    /** Lo que muestra la isla. */
    enum class State { IDLE, REC, THINK, DONE }

    // --- medidas en dp (maqueta) ---
    const val DEFAULT_W_DP = 112f
    const val DEFAULT_H_DP = 30f
    const val MIN_W_DP = 72f
    const val MAX_W_DP = 180f
    const val MIN_H_DP = 22f
    const val MAX_H_DP = 48f
    const val DEFAULT_TOP_DP = 3f

    const val REC_W_DP = 252f
    const val REC_H_DP = 44f
    const val DONE_W_DP = 128f
    const val DONE_H_DP = 34f

    /** Separación mínima de la píldora a los bordes laterales de la pantalla. */
    const val EDGE_MARGIN_DP = 4f

    /** Agujero (micrófono) grabando. */
    const val REC_HOLE_DP = 32f

    /** Ventana del agujero grabando: deja lugar al arco que gira alrededor. */
    const val REC_HOLE_BOX_DP = 44f

    /** Reposo: agujero chico con anillo, glifo del puntero. */
    const val IDLE_DOT_DP = 12f
    const val IDLE_POINTER_DP = 14f
    const val IDLE_PAD_DP = 10f

    /** Layout grabando: relleno, separación y piezas fijas. */
    const val REC_PAD_HOLE_DP = 6f
    const val REC_PAD_END_DP = 8f
    const val REC_GAP_DP = 8f
    const val REC_TIMER_W_DP = 34f
    const val REC_CANCEL_DP = 26f

    /** Área táctil mínima de ✕ y del agujero (la pastilla mide 44 dp de alto). */
    const val TOUCH_DP = 40f

    /** «Listo»: ✓ + texto. */
    const val DONE_CHECK_DP = 15f
    const val DONE_GAP_DP = 6f
    const val DONE_PAD_DP = 14f
    const val DONE_MAX_W_DP = 320f

    /** Tiempos. */
    const val DONE_MS = 1300L
    const val ERROR_MS = 2600L
    const val MORPH_MS = 420L

    /** Margen extra de la ventana mientras dura el rebote (el overshoot pasa un poco del destino). */
    const val OVERSHOOT_MARGIN_DP = 12f

    data class Size(val w: Int, val h: Int)

    data class Rect(val x: Int, val y: Int, val w: Int, val h: Int) {
        val right: Int get() = x + w
        val bottom: Int get() = y + h
        fun contains(px: Float, py: Float): Boolean = px >= x && px < x + w && py >= y && py < y + h

        /** Unión de dos rectángulos (la ventana mientras se anima de uno al otro). */
        fun union(o: Rect): Rect {
            val l = min(x, o.x)
            val t = min(y, o.y)
            return Rect(l, t, max(right, o.right) - l, max(bottom, o.bottom) - t)
        }
    }

    private fun px(dp: Float, d: Float) = (dp * d).roundToInt()

    /** Ancho en reposo: el pedido ([PointerProtocol.ISLAND_DEFAULT] = 112 dp), entre 72 y 180 dp y siempre dentro de la pantalla. */
    fun idleWidth(requestedPx: Int, d: Float, screenW: Int): Int {
        val w = if (requestedPx < 0) px(DEFAULT_W_DP, d) else requestedPx
        return fitWidth(w.coerceIn(px(MIN_W_DP, d), px(MAX_W_DP, d)), d, screenW)
    }

    /** Alto en reposo: el pedido ([PointerProtocol.ISLAND_DEFAULT] = 30 dp), entre 22 y 48 dp. */
    fun idleHeight(requestedPx: Int, d: Float): Int {
        val h = if (requestedPx < 0) px(DEFAULT_H_DP, d) else requestedPx
        return h.coerceIn(px(MIN_H_DP, d), px(MAX_H_DP, d))
    }

    /** Recorta el ancho para que entre en la pantalla con su margen (pantallas muy angostas). */
    private fun fitWidth(w: Int, d: Float, screenW: Int): Int =
        w.coerceAtMost(max(1, screenW - 2 * px(EDGE_MARGIN_DP, d)))

    /**
     * Ancho del estado «listo»: 128 dp, o más si el texto no entra; con tope y
     * sin pasar de la pantalla. [textWidthPx] = lo que mide el texto ya medido.
     */
    fun doneWidth(textWidthPx: Int, d: Float, screenW: Int): Int {
        val need = px(DONE_PAD_DP * 2 + DONE_CHECK_DP + DONE_GAP_DP, d) + max(0, textWidthPx)
        val w = max(px(DONE_W_DP, d), need).coerceAtMost(px(DONE_MAX_W_DP, d))
        return fitWidth(w, d, screenW)
    }

    /** Tamaño de la píldora en cada estado. */
    fun sizeFor(
        state: State,
        idleWPx: Int,
        idleHPx: Int,
        d: Float,
        screenW: Int,
        doneTextWidthPx: Int = 0,
    ): Size = when (state) {
        State.IDLE -> Size(idleWidth(idleWPx, d, screenW), idleHeight(idleHPx, d))
        State.REC, State.THINK -> Size(fitWidth(px(REC_W_DP, d), d, screenW), px(REC_H_DP, d))
        State.DONE -> Size(doneWidth(doneTextWidthPx, d, screenW), px(DONE_H_DP, d))
    }

    /**
     * Rectángulo de la píldora en pantalla: centrada en [centerX] (−1 = centro
     * de la pantalla), con el borde superior en [top] (−1 = 3 dp), y recortada
     * para que nunca salga de la pantalla (ni de los lados ni de abajo).
     */
    fun bounds(size: Size, centerX: Int, top: Int, d: Float, screenW: Int, screenH: Int): Rect {
        val margin = px(EDGE_MARGIN_DP, d)
        val w = size.w.coerceAtMost(max(1, screenW - 2 * margin))
        val h = size.h.coerceAtMost(max(1, screenH))
        val cx = if (centerX < 0) screenW / 2 else centerX
        val y = if (top < 0) px(DEFAULT_TOP_DP, d) else top
        val left = clamp(cx - w / 2, margin, screenW - w - margin)
        val t = clamp(y, 0, screenH - h)
        return Rect(left, t, w, h)
    }

    /** coerceIn que no explota si el rango quedó al revés (pantallas diminutas). */
    private fun clamp(v: Int, lo: Int, hi: Int): Int = if (hi < lo) lo else v.coerceIn(lo, hi)

    /** Interpolación del rebote (t puede pasarse de 1 con el overshoot). */
    fun lerp(from: Rect, to: Rect, t: Float): Rect = Rect(
        (from.x + (to.x - from.x) * t).roundToInt(),
        (from.y + (to.y - from.y) * t).roundToInt(),
        max(1, (from.w + (to.w - from.w) * t).roundToInt()),
        max(1, (from.h + (to.h - from.h) * t).roundToInt()),
    )

    /**
     * Ventana que contiene toda la animación de [from] a [to]: la unión de los
     * dos más el margen del rebote, siempre dentro de la pantalla.
     */
    fun animationWindow(from: Rect, to: Rect, d: Float, screenW: Int, screenH: Int): Rect {
        val m = px(OVERSHOOT_MARGIN_DP, d)
        val u = from.union(to)
        val l = max(0, u.x - m)
        val t = max(0, u.y - m)
        val r = min(screenW, u.right + m)
        val b = min(screenH, u.bottom + m)
        return Rect(l, t, max(1, r - l), max(1, b - t))
    }

    // ------------------------------------------------------------- piezas

    /** Piezas de grabando / pensando, relativas a la píldora. */
    data class RecLayout(
        /** Ventana del agujero (REC_HOLE_BOX_DP, centrada en el agujero de REC_HOLE_DP). */
        val hole: Rect,
        /** Franja donde caen los símbolos. */
        val voice: Rect,
        /** Centro del cronómetro. */
        val timerCenterX: Int,
        /** Lugar de la ✕ (zona táctil de [TOUCH_DP]). */
        val cancel: Rect,
    )

    /**
     * Grabando: [agujero][franja de voz][cronómetro][✕] de izquierda a derecha
     * con el micrófono a la izquierda; con el micrófono a la derecha, todo en
     * espejo (como la maqueta: `row-reverse`).
     */
    fun recLayout(w: Int, h: Int, d: Float, micOnLeft: Boolean): RecLayout {
        val padHole = px(REC_PAD_HOLE_DP, d)
        val padEnd = px(REC_PAD_END_DP, d)
        val gap = px(REC_GAP_DP, d)
        val holeD = px(REC_HOLE_DP, d)
        val timerW = px(REC_TIMER_W_DP, d)
        val cancelD = px(REC_CANCEL_DP, d)
        val box = px(REC_HOLE_BOX_DP, d)
        val touch = px(TOUCH_DP, d)

        // Se arma para micrófono a la izquierda (coordenadas de izquierda a derecha)…
        val holeLeft = padHole
        val voiceLeft = holeLeft + holeD + gap
        val cancelRight = w - padEnd
        val cancelLeft = cancelRight - cancelD
        val timerRight = cancelLeft - gap
        val timerLeft = timerRight - timerW
        val voiceRight = max(voiceLeft + 1, timerLeft - gap)

        val holeCx = holeLeft + holeD / 2
        val timerCx = (timerLeft + timerRight) / 2
        val cancelCx = (cancelLeft + cancelRight) / 2
        val cy = h / 2

        fun mx(x: Int) = if (micOnLeft) x else w - x

        val holeRect = Rect(mx(holeCx) - box / 2, cy - box / 2, box, box)
        val voiceLo = mx(voiceLeft)
        val voiceHi = mx(voiceRight)
        val voice = Rect(min(voiceLo, voiceHi), 0, abs(voiceHi - voiceLo), h)
        val cancel = Rect(mx(cancelCx) - touch / 2, (h - min(h, touch)) / 2, touch, min(h, touch))
        return RecLayout(holeRect, voice, mx(timerCx), cancel)
    }

    /** Reposo: centro del agujero (anillo) y del glifo del puntero, relativos a la píldora. */
    data class IdleLayout(val dotCx: Int, val pointerCx: Int, val cy: Int)

    fun idleLayout(w: Int, h: Int, d: Float, micOnLeft: Boolean): IdleLayout {
        val pad = px(IDLE_PAD_DP, d)
        val dot = px(IDLE_DOT_DP, d)
        val ptr = px(IDLE_POINTER_DP, d)
        val left = pad + dot / 2
        val right = w - pad - ptr / 2
        return if (micOnLeft) IdleLayout(left, right, h / 2) else IdleLayout(w - pad - dot / 2, pad + ptr / 2, h / 2)
    }

    /** Qué hace un toque sobre la isla en reposo. */
    enum class Tool { NONE, MIC, POINTER }

    /**
     * La isla en reposo no se abre: cada mitad ES su botón. Con las dos
     * herramientas, tocar la mitad del agujero dicta y tocar la mitad del
     * glifo abre el puntero, de una. Con una sola, toda la isla es esa
     * herramienta. [xInPill] = dónde cayó el dedo, en px desde el borde
     * izquierdo de la píldora de ancho [w].
     */
    fun idleTapTool(xInPill: Float, w: Int, micOnLeft: Boolean, hasMic: Boolean, hasPointer: Boolean): Tool = when {
        hasMic && hasPointer -> if ((xInPill < w / 2f) == micOnLeft) Tool.MIC else Tool.POINTER
        hasMic -> Tool.MIC
        hasPointer -> Tool.POINTER
        else -> Tool.NONE
    }
}
