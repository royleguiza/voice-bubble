package com.royleguiza.voicebubble.puntero

import kotlin.math.abs

/**
 * Cola de scroll: los deltas llegan a 60 Hz y Android cancela un gesto si
 * otro empieza antes de que termine. Se acumulan mientras hay un trazo en
 * curso y se despachan juntos al terminar. Lógica pura (testeable en JVM).
 */
class ScrollQueue(private val minDeltaPx: Float = 2f, private val maxDeltaPx: Float = PointerProtocol.MAX_SCROLL_PX) {
    private var pending = 0f
    var x = 0f
        private set
    var y = 0f
        private set
    var active = false
        private set

    /** Suma un delta. Devuelve el trazo a despachar ya, o null si hay que esperar. */
    fun add(x: Float, y: Float, dy: Float): Float? {
        this.x = x
        this.y = y
        pending += dy
        return if (active) null else take()
    }

    /** El trazo en curso terminó (o se canceló): ¿queda algo por despachar? */
    fun finished(): Float? {
        active = false
        return take()
    }

    fun reset() {
        pending = 0f
        active = false
    }

    private fun take(): Float? {
        if (abs(pending) < minDeltaPx) {
            pending = 0f
            return null
        }
        val out = pending.coerceIn(-maxDeltaPx, maxDeltaPx)
        pending = 0f
        active = true
        return out
    }
}
