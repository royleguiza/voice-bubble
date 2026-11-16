package com.royleguiza.voicebubble.puntero

import kotlin.math.roundToInt

/**
 * Dónde queda la ventana del trackpad según el modo, el ancla y la pantalla.
 * Lógica pura (sin android.*) para testearla en la JVM y para recalcular al
 * girar el teléfono o cambiar el tamaño de pantalla.
 *
 * Modos (ver [PointerProtocol.MODE_PANEL] / [PointerProtocol.MODE_WINDOW]):
 * - panel: abajo, ancho completo con margen, respetando la barra de navegación.
 * - window: 280 dp junto al ancla (la barra o burbuja que lo abrió). Si la
 *   persona la movió o la achicó ([Placement]), se abre donde la dejó: así
 *   queda siempre en la zona sana de la pantalla (fase 3).
 */
object TrackpadGeometry {

    data class Bounds(val x: Int, val y: Int, val w: Int, val h: Int) {
        /** ¿El punto (px, py) cae dentro, con [slop] de margen? */
        fun contains(px: Float, py: Float, slop: Float = 0f): Boolean =
            px >= x - slop && px <= x + w + slop && py >= y - slop && py <= y + h + slop
    }

    /**
     * Lugar y tamaño que eligió la persona para la ventana libre: esquina
     * superior izquierda como fracción de la pantalla (sobrevive al giro) y
     * tamaño en dp (sobrevive a cambios de densidad).
     */
    data class Placement(val xFrac: Float, val yFrac: Float, val wDp: Float, val hDp: Float)

    /** Tamaño mínimo de la ventana libre: entran la agarradera, la fila de sistema y algo de pad. */
    const val MIN_WINDOW_W_DP = 220f
    const val MIN_WINDOW_H_DP = 200f

    /** Alto con la fila de sistema: agarradera + botones + superficie del pad. */
    private const val HEIGHT_DP = 296f
    private const val HEIGHT_EXTENDED_DP = 436f
    private const val MIN_HEIGHT_DP = 160f
    private const val WINDOW_WIDTH_DP = 280f
    private const val PANEL_MARGIN_DP = 10f
    private const val PANEL_LIFT_DP = 12f
    private const val ANCHOR_GAP_DP = 16f
    private const val WINDOW_TOP_DP = 40f

    private fun dp(v: Float, density: Float) = (v * density).roundToInt()

    /** coerceIn que no explota si el rango quedó al revés (pantallas muy bajas). */
    private fun clamp(v: Int, lo: Int, hi: Int): Int = if (hi < lo) lo else v.coerceIn(lo, hi)

    /** Alto del panel: el pedido, sin pasarse de lo que entra en pantalla. */
    fun height(extended: Boolean, screenH: Int, bottomInset: Int, density: Float): Int {
        val wanted = dp(if (extended) HEIGHT_EXTENDED_DP else HEIGHT_DP, density)
        val room = screenH - bottomInset - 2 * dp(PANEL_LIFT_DP, density)
        return clamp(wanted, dp(MIN_HEIGHT_DP, density), maxOf(room, dp(MIN_HEIGHT_DP, density)))
            .coerceAtMost(maxOf(screenH, 1))
    }

    /** Posición inicial al abrir. [anchorX]/[anchorY] = −1 si no hay ancla. */
    fun open(
        mode: String,
        screenW: Int,
        screenH: Int,
        bottomInset: Int,
        anchorX: Int,
        anchorY: Int,
        extended: Boolean,
        density: Float,
        placement: Placement? = null,
    ): Bounds {
        val h = height(extended, screenH, bottomInset, density)
        if (mode == PointerProtocol.MODE_WINDOW && placement != null) {
            return fromPlacement(placement, screenW, screenH, bottomInset, density)
        }
        if (mode != PointerProtocol.MODE_WINDOW) {
            val margin = dp(PANEL_MARGIN_DP, density)
            return Bounds(margin, screenH - bottomInset - h - dp(PANEL_LIFT_DP, density), screenW - 2 * margin, h)
        }
        val w = dp(WINDOW_WIDTH_DP, density).coerceAtMost(screenW - dp(ANCHOR_GAP_DP, density))
        val ax = if (anchorX >= 0) anchorX else screenW / 2
        val ay = if (anchorY >= 0) anchorY else screenH / 2
        val gap = dp(ANCHOR_GAP_DP, density)
        // Del lado del centro de la pantalla opuesto al ancla, para no taparla.
        val x = if (ax < screenW / 2) ax + gap else ax - w - gap
        return Bounds(
            clamp(x, 0, screenW - w),
            clamp(ay - h / 2, dp(WINDOW_TOP_DP, density), screenH - h - bottomInset),
            w,
            h,
        )
    }

    /**
     * Acomoda una ventana ya abierta tras un cambio de pantalla (giro, otro
     * tamaño): el panel se recalcula; la ventana libre solo se acota para
     * que no quede fuera, conservando donde la dejó la persona.
     */
    fun refit(
        current: Bounds,
        mode: String,
        screenW: Int,
        screenH: Int,
        bottomInset: Int,
        extended: Boolean,
        density: Float,
    ): Bounds {
        if (mode != PointerProtocol.MODE_WINDOW) {
            return open(mode, screenW, screenH, bottomInset, -1, -1, extended, density)
        }
        // Ventana libre: conserva el tamaño que tenía (la persona pudo achicarla), solo acotado.
        val (w, h) = clampSize(current.w, current.h, screenW, screenH, bottomInset, density)
        return Bounds(
            clamp(current.x, 0, screenW - w),
            clamp(current.y, 0, screenH - h - bottomInset),
            w,
            h,
        )
    }

    /** Tamaño acotado de la ventana libre: entre el mínimo y lo que entra en pantalla. */
    fun clampSize(w: Int, h: Int, screenW: Int, screenH: Int, bottomInset: Int, density: Float): Pair<Int, Int> {
        val maxW = maxOf(screenW, 1)
        val maxH = maxOf(screenH - bottomInset, 1)
        val minW = dp(MIN_WINDOW_W_DP, density).coerceAtMost(maxW)
        val minH = dp(MIN_WINDOW_H_DP, density).coerceAtMost(maxH)
        return Pair(clamp(w, minW, maxW), clamp(h, minH, maxH))
    }

    /** Agrandar o achicar desde la esquina: la esquina superior izquierda queda quieta. */
    fun resize(b: Bounds, newW: Int, newH: Int, screenW: Int, screenH: Int, bottomInset: Int, density: Float): Bounds {
        val (w0, h0) = clampSize(newW, newH, screenW, screenH, bottomInset, density)
        // Sin pasarse del borde derecho ni de la barra de navegación.
        val w = w0.coerceAtMost(maxOf(screenW - b.x, 1))
        val h = h0.coerceAtMost(maxOf(screenH - bottomInset - b.y, 1))
        return Bounds(b.x, b.y, w, h)
    }

    /** Ventana libre en el lugar guardado, acotada a la pantalla de ahora. */
    fun fromPlacement(p: Placement, screenW: Int, screenH: Int, bottomInset: Int, density: Float): Bounds {
        val (w, h) = clampSize(dp(p.wDp, density), dp(p.hDp, density), screenW, screenH, bottomInset, density)
        val x = (p.xFrac * screenW).roundToInt()
        val y = (p.yFrac * screenH).roundToInt()
        return Bounds(clamp(x, 0, screenW - w), clamp(y, 0, screenH - h - bottomInset), w, h)
    }

    /** Lo que se guarda al soltar la agarradera o la esquina. */
    fun toPlacement(b: Bounds, screenW: Int, screenH: Int, density: Float): Placement = Placement(
        xFrac = if (screenW > 0) (b.x.toFloat() / screenW).coerceIn(0f, 1f) else 0f,
        yFrac = if (screenH > 0) (b.y.toFloat() / screenH).coerceIn(0f, 1f) else 0f,
        wDp = b.w / density,
        hDp = b.h / density,
    )

    /** Lo máximo que se puede mover la ventana libre sin salirse (para la agarradera). */
    fun clampMove(x: Int, y: Int, b: Bounds, screenW: Int, screenH: Int): Pair<Int, Int> =
        Pair(clamp(x, 0, screenW - b.w), clamp(y, 0, screenH - b.h))
}
