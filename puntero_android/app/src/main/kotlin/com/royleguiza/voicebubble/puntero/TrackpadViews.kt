package com.royleguiza.voicebubble.puntero

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * La línea de arriba del trackpad: botón de cerrar y, a la vez, reloj del
 * cierre automático (se acorta desde los extremos hacia el centro).
 */
@SuppressLint("ViewConstructor")
internal class HandleView(context: Context, private val palette: Palette) : View(context) {
    private val d = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private var remaining = 1f
    private var counting = false
    private var animator: ValueAnimator? = null

    fun startCountdown(totalMs: Long) {
        animator?.cancel()
        if (totalMs <= 0) return
        counting = true
        animator = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = totalMs
            interpolator = LinearInterpolator()
            addUpdateListener {
                remaining = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    fun cancelCountdown() {
        animator?.cancel()
        animator = null
        counting = false
        remaining = 1f
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = 40 * d
        val h = 5 * d
        val cx = width / 2f
        val cy = height / 2f
        val track = RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        paint.color = palette.line
        canvas.drawRoundRect(track, h / 2, h / 2, paint)
        val fw = w * (if (counting) remaining else 1f)
        if (fw > 0.5f) {
            paint.color = if (counting) palette.ember else palette.fg2
            canvas.drawRoundRect(RectF(cx - fw / 2, track.top, cx + fw / 2, track.bottom), h / 2, h / 2, paint)
        }
    }
}

/**
 * Botón circular de 44 dp de la fila de sistema: ícono de trazo 2.2 en `fg`
 * sobre `surf` con borde `line`. Con [active] (solo «Arrastrar») se pinta en
 * brasa suave con el ícono en `ember-t`.
 */
@SuppressLint("ViewConstructor")
internal class SystemButton(
    context: Context,
    private val palette: Palette,
    private val icon: Icon,
    description: String,
) : View(context) {

    enum class Icon { BACK, HOME, RECENTS, NOTIFICATIONS, DRAG }

    private val d = resources.displayMetrics.density
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f * d
    }
    private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = STROKE_UNITS
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()
    private val box = RectF()

    var active = false
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }

    init {
        contentDescription = description
        isClickable = true
        isFocusable = true
    }

    companion object {
        const val SIZE_DP = 44f

        /** Grilla de los íconos: 24 unidades = 24 dp; el trazo es de 2.2. */
        private const val GRID = 24f
        private const val STROKE_UNITS = 2.2f
    }

    override fun setPressed(pressed: Boolean) {
        super.setPressed(pressed)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = minOf(width, height) / 2f - 0.5f * d
        fill.color = when {
            active -> palette.emberSoft
            isPressed -> palette.surf2
            else -> palette.surf
        }
        canvas.drawCircle(cx, cy, r, fill)
        ring.color = if (active) palette.ember else palette.line
        canvas.drawCircle(cx, cy, r, ring)

        ink.color = if (active) palette.emberT else palette.fg
        canvas.save()
        canvas.translate(cx - GRID * d / 2f, cy - GRID * d / 2f)
        canvas.scale(d, d)
        drawIcon(canvas)
        canvas.restore()
    }

    /** Trazos en la grilla de 24 × 24 (estilo de línea redondeada). */
    private fun drawIcon(canvas: Canvas) {
        path.reset()
        when (icon) {
            Icon.BACK -> {
                path.moveTo(19f, 12f); path.lineTo(5f, 12f)
                path.moveTo(12f, 19f); path.lineTo(5f, 12f); path.lineTo(12f, 5f)
            }
            Icon.HOME -> {
                path.moveTo(4f, 11f); path.lineTo(12f, 4f); path.lineTo(20f, 11f)
                path.lineTo(20f, 20f); path.lineTo(4f, 20f); path.close()
                path.moveTo(10f, 20f); path.lineTo(10f, 14f); path.lineTo(14f, 14f); path.lineTo(14f, 20f)
            }
            Icon.RECENTS -> {
                box.set(6f, 6f, 18f, 18f)
                path.addRoundRect(box, 2.5f, 2.5f, Path.Direction.CW)
            }
            Icon.NOTIFICATIONS -> {
                // Campana: cúpula, faldón y badajo.
                box.set(6f, 2f, 18f, 14f)
                path.moveTo(18f, 8f)
                path.arcTo(box, 0f, -180f)
                path.cubicTo(6f, 15f, 3f, 17f, 3f, 17f)
                path.lineTo(21f, 17f)
                path.cubicTo(21f, 17f, 18f, 15f, 18f, 8f)
                path.moveTo(10f, 20.5f)
                path.quadTo(12f, 22.5f, 14f, 20.5f)
            }
            Icon.DRAG -> {
                // Cuatro flechas: mover.
                path.moveTo(12f, 3f); path.lineTo(12f, 21f)
                path.moveTo(3f, 12f); path.lineTo(21f, 12f)
                path.moveTo(9f, 6f); path.lineTo(12f, 3f); path.lineTo(15f, 6f)
                path.moveTo(9f, 18f); path.lineTo(12f, 21f); path.lineTo(15f, 18f)
                path.moveTo(6f, 9f); path.lineTo(3f, 12f); path.lineTo(6f, 15f)
                path.moveTo(18f, 9f); path.lineTo(21f, 12f); path.lineTo(18f, 15f)
            }
        }
        canvas.drawPath(path, ink)
    }
}
