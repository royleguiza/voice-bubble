package com.royleguiza.voicebubblestt

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout

/**
 * T5 (K1) · Fila de teclas sin zonas muertas.
 *
 * Los huecos entre teclas (márgenes laterales), los bordes de la fila y el
 * hueco entre filas (que [LayoutLayer.addRow] convierte en relleno de las
 * filas) quedan dentro de los límites de la fila. Un toque que cae ahí, en
 * vez de perderse, se entrega ENTERO a la tecla más cercana: la tecla recibe
 * el DOWN (se ilumina y vibra), los MOVE (deslizamientos, ⌫ que repite,
 * espacio-trackpad) y el UP, con las coordenadas corridas al borde de la
 * tecla. El dibujo no cambia ni un píxel.
 *
 * Multitoque: si entra un segundo dedo mientras se redirige el primero, el
 * primero se confirma (UP en la tecla elegida) y desde ahí la fila reparte
 * los dedos como cualquier LinearLayout.
 */
class KeyRow(context: Context) : LinearLayout(context) {

    private var target: View? = null
    private var pointerId = MotionEvent.INVALID_POINTER_ID
    private var shiftX = 0f
    private var shiftY = 0f

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (ev.actionMasked == MotionEvent.ACTION_DOWN) {
            target = null
            if (childUnder(ev.x, ev.y) == null) {
                val nearest = nearestKey(this, ev.x, ev.y)
                if (nearest != null) {
                    target = nearest
                    pointerId = ev.getPointerId(0)
                    shiftX = clamp(ev.x, nearest.left, nearest.right) - ev.x
                    shiftY = clamp(ev.y, nearest.top, nearest.bottom) - ev.y
                    forward(ev, MotionEvent.ACTION_DOWN)
                    return true
                }
            }
            return super.dispatchTouchEvent(ev)
        }
        if (target == null) return super.dispatchTouchEvent(ev)
        when (ev.actionMasked) {
            MotionEvent.ACTION_POINTER_DOWN -> {
                forward(ev, MotionEvent.ACTION_UP)
                target = null
                return super.dispatchTouchEvent(ev)
            }
            MotionEvent.ACTION_MOVE -> forward(ev, MotionEvent.ACTION_MOVE)
            MotionEvent.ACTION_UP -> {
                forward(ev, MotionEvent.ACTION_UP)
                target = null
            }
            MotionEvent.ACTION_CANCEL -> {
                forward(ev, MotionEvent.ACTION_CANCEL)
                target = null
            }
        }
        return true
    }

    /** Reenvía solo el dedo redirigido, en coordenadas de la tecla. */
    private fun forward(ev: MotionEvent, action: Int) {
        val child = target ?: return
        val index = ev.findPointerIndex(pointerId).takeIf { it >= 0 } ?: return
        val x = ev.getX(index) + shiftX - child.left
        val y = ev.getY(index) + shiftY - child.top
        val event = if (ev.pointerCount == 1) {
            MotionEvent.obtain(ev).apply {
                this.action = action
                offsetLocation(shiftX - child.left, shiftY - child.top)
            }
        } else {
            MotionEvent.obtain(ev.downTime, ev.eventTime, action, x, y, ev.metaState)
        }
        try {
            child.dispatchTouchEvent(event)
        } finally {
            event.recycle()
        }
    }

    private fun childUnder(x: Float, y: Float): View? {
        for (i in childCount - 1 downTo 0) {
            val c = getChildAt(i)
            if (c.visibility != View.VISIBLE) continue
            if (x >= c.left && x < c.right && y >= c.top && y < c.bottom) return c
        }
        return null
    }

    companion object {
        /** Punto dentro de [lo, hi): un píxel adentro del borde. */
        internal fun clamp(v: Float, lo: Int, hi: Int): Float =
            v.coerceIn(lo.toFloat(), (hi - 1).coerceAtLeast(lo).toFloat())

        /** Tecla visible y tocable más cercana al punto (distancia al rectángulo). */
        internal fun nearestKey(row: LinearLayout, x: Float, y: Float): View? {
            var best: View? = null
            var bestDist = Float.MAX_VALUE
            for (i in 0 until row.childCount) {
                val c = row.getChildAt(i)
                if (c.visibility != View.VISIBLE || c.width <= 0 || !c.isEnabled) continue
                val dx = when {
                    x < c.left -> c.left - x
                    x > c.right -> x - c.right
                    else -> 0f
                }
                val dy = when {
                    y < c.top -> c.top - y
                    y > c.bottom -> y - c.bottom
                    else -> 0f
                }
                val d = dx * dx + dy * dy
                if (d < bestDist) {
                    bestDist = d
                    best = c
                }
            }
            return best
        }
    }
}
