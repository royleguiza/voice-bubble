package com.royleguiza.voicebubble.puntero

/**
 * Arrastre en dos pasos: el primer toque marca el origen y el segundo suelta.
 * Esto es lo que sale al soltar: una espera quieta en el origen (para que
 * Android lo tome como «agarrar») y el recorrido hasta el destino, como dos
 * trazos continuos (`willContinue`) que el servicio despacha en dos gestos
 * encadenados (la continuación de un trazo va en el gesto siguiente).
 *
 * Lógica pura (sin android.*) para testearla en la JVM; el servicio la
 * convierte en `GestureDescription`.
 */
class DragPlan private constructor(
    val startX: Float,
    val startY: Float,
    val endX: Float,
    val endY: Float,
) {
    companion object {
        /** Espera quieta en el origen antes de moverse. */
        const val HOLD_MS = 550L

        /** Recorrido origen → destino. */
        const val MOVE_MS = 400L

        /**
         * Arma el plan recortando ambos puntos a la pantalla ([screenW] ×
         * [screenH] px). null si algún dato no es válido (no finito, pantalla
         * vacía): mejor no hacer nada que arrastrar a cualquier lado.
         */
        fun of(
            originX: Float,
            originY: Float,
            destX: Float,
            destY: Float,
            screenW: Int,
            screenH: Int,
        ): DragPlan? {
            if (screenW <= 0 || screenH <= 0) return null
            if (!originX.isFinite() || !originY.isFinite() || !destX.isFinite() || !destY.isFinite()) return null
            val maxX = (screenW - 1).toFloat()
            val maxY = (screenH - 1).toFloat()
            return DragPlan(
                originX.coerceIn(0f, maxX),
                originY.coerceIn(0f, maxY),
                destX.coerceIn(0f, maxX),
                destY.coerceIn(0f, maxY),
            )
        }
    }

    /** Cuánto dura todo el gesto en pantalla. */
    val totalMs: Long get() = HOLD_MS + MOVE_MS

    /** Trazo 1: quieto en el origen, `willContinue = true`. Empieza en 0 ms. */
    val holdStartMs: Long get() = 0L

    /** Trazo 2: sale del origen hacia el destino cuando termina la espera. */
    val moveStartMs: Long get() = HOLD_MS
}
