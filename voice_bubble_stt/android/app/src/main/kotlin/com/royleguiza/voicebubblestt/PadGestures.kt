package com.royleguiza.voicebubblestt

import kotlin.math.hypot

/**
 * Gestos de la superficie del trackpad flotante (como el prototipo HTML):
 * deslizar mueve el puntero, tocar hace clic, mantener hace clic largo y
 * dos dedos desplazan. Lógica pura (sin android.*) para testearla en la JVM.
 */
class PadGestures(private val slopPx: Float) {

    companion object {
        /** Toque más largo que esto no es clic (generoso para manos lentas). */
        const val TAP_MAX_MS = 350L
        const val LONG_PRESS_MS = 550L
        const val TWO_FINGER_SCROLL_GAIN = 1.5f
        const val RAIL_SCROLL_GAIN = 3f

        /**
         * Recorrido del gesto de scroll que hace el complemento a partir del
         * movimiento de dos dedos. Natural: el contenido sigue a los dedos.
         */
        fun scrollDelta(fingerDy: Float, natural: Boolean): Float =
            fingerDy * TWO_FINGER_SCROLL_GAIN * (if (natural) 1f else -1f)

        /** La guía de la derecha funciona como barra de desplazamiento: bajar = avanzar. */
        fun railDelta(fingerDy: Float): Float = -fingerDy * RAIL_SCROLL_GAIN
    }

    sealed class Action {
        data class Move(val dx: Float, val dy: Float) : Action()
        data class Scroll(val fingerDy: Float) : Action()
        object Tap : Action()
        object LongPress : Action()
    }

    private var active = false
    private var moved = false
    private var multi = false
    private var longFired = false
    private var downX = 0f
    private var downY = 0f
    private var downT = 0L
    private var lastX = 0f
    private var lastY = 0f
    private var lastAvgY = 0f
    private var lastCount = 0

    val isActive: Boolean get() = active

    fun down(x: Float, y: Float, t: Long) {
        active = true
        moved = false
        multi = false
        longFired = false
        downX = x
        downY = y
        downT = t
        lastX = x
        lastY = y
        lastCount = 1
    }

    /**
     * Un movimiento. [count] = dedos apoyados; [avgY] = su altura promedio.
     * Al cambiar la cantidad de dedos se re-ancla para que el puntero no salte.
     */
    fun move(x: Float, y: Float, count: Int, avgY: Float): Action? {
        if (!active) return null
        if (count >= 2) {
            multi = true
            moved = true
            if (lastCount != count) {
                lastCount = count
                lastAvgY = avgY
                return null
            }
            val dy = avgY - lastAvgY
            lastAvgY = avgY
            return if (dy != 0f) Action.Scroll(dy) else null
        }
        if (lastCount != 1) {
            lastCount = 1
            lastX = x
            lastY = y
            return null
        }
        // Hasta pasar el margen no se mueve nada (así un toque no corre el
        // puntero); al pasarlo se aplica todo lo recorrido, sin perderlo.
        if (!moved) {
            if (hypot(x - downX, y - downY) <= slopPx) return null
            moved = true
        }
        val dx = x - lastX
        val dy = y - lastY
        lastX = x
        lastY = y
        return if (dx != 0f || dy != 0f) Action.Move(dx, dy) else null
    }

    /** Llamar cuando vence el temporizador del clic largo. */
    fun longPressDue(t: Long): Action? {
        if (!active || moved || multi || longFired) return null
        if (t - downT < LONG_PRESS_MS) return null
        longFired = true
        return Action.LongPress
    }

    fun up(t: Long): Action? {
        val tap = active && !moved && !multi && !longFired && t - downT < TAP_MAX_MS
        active = false
        return if (tap) Action.Tap else null
    }

    fun cancel() {
        active = false
    }
}
