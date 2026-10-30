package com.royleguiza.voicebubblestt

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import kotlin.math.sin

/** Íconos de la barra dibujados a mano (un solo trazo y peso, sin glifos). */
internal object DockIcons {
    private val path = Path()

    fun drawMic(canvas: Canvas, cx: Float, cy: Float, size: Float, color: Int, paint: Paint) {
        paint.color = color
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = size * 0.085f
        paint.strokeCap = Paint.Cap.ROUND
        val capW = size * 0.30f
        val capH = size * 0.50f
        val top = cy - size * 0.40f
        canvas.drawRoundRect(RectF(cx - capW / 2, top, cx + capW / 2, top + capH), capW / 2, capW / 2, paint)
        val arcR = size * 0.30f
        val arcCy = top + capH * 0.62f
        canvas.drawArc(RectF(cx - arcR, arcCy - arcR, cx + arcR, arcCy + arcR), 0f, 180f, false, paint)
        canvas.drawLine(cx, arcCy + arcR, cx, cy + size * 0.42f, paint)
    }

    fun drawPointer(canvas: Canvas, cx: Float, cy: Float, size: Float, color: Int, paint: Paint) {
        paint.color = color
        paint.style = Paint.Style.FILL
        val s = size / 26f
        val ox = cx - 11f * s
        val oy = cy - 13f * s
        path.reset()
        path.moveTo(ox + 5f * s, oy + 3f * s)
        path.lineTo(ox + 5f * s, oy + 19.6f * s)
        path.lineTo(ox + 9.4f * s, oy + 15.6f * s)
        path.lineTo(ox + 12.6f * s, oy + 22.9f * s)
        path.lineTo(ox + 15.4f * s, oy + 21.7f * s)
        path.lineTo(ox + 12.3f * s, oy + 14.6f * s)
        path.lineTo(ox + 18.6f * s, oy + 14.6f * s)
        path.close()
        canvas.drawPath(path, paint)
    }

    /** Burbuja con varias herramientas: dos anillos concéntricos (estilo AssistiveTouch). */
    fun drawHub(canvas: Canvas, cx: Float, cy: Float, size: Float, color: Int, paint: Paint) {
        paint.style = Paint.Style.FILL
        paint.color = color
        paint.alpha = 36
        canvas.drawCircle(cx, cy, size * 0.46f, paint)
        paint.alpha = 190
        canvas.drawCircle(cx, cy, size * 0.24f, paint)
        paint.alpha = 255
    }

    fun drawTool(canvas: Canvas, tool: DockGeometry.Tool, cx: Float, cy: Float, size: Float, color: Int, paint: Paint) {
        when (tool) {
            DockGeometry.Tool.MIC -> drawMic(canvas, cx, cy, size, color, paint)
            DockGeometry.Tool.POINTER -> drawPointer(canvas, cx, cy, size, color, paint)
        }
    }

    /** Estado de dictado sobre un círculo: grabando (rojo + detener) o transcribiendo (giro). */
    fun drawDictationState(
        canvas: Canvas,
        state: String,
        cx: Float,
        cy: Float,
        radius: Float,
        phase: Float,
        recording: Int,
        accent: Int,
        onRecording: Int,
        paint: Paint,
    ): Boolean {
        when (state) {
            "recording" -> {
                paint.style = Paint.Style.FILL
                paint.color = recording
                val pulse = 1f + 0.06f * (0.5f + 0.5f * sin(phase))
                canvas.drawCircle(cx, cy, radius * pulse, paint)
                paint.color = onRecording
                val s = radius * 0.36f
                canvas.drawRoundRect(RectF(cx - s, cy - s, cx + s, cy + s), s * 0.3f, s * 0.3f, paint)
                return true
            }
            "transcribing" -> {
                paint.style = Paint.Style.STROKE
                paint.strokeCap = Paint.Cap.ROUND
                paint.strokeWidth = radius * 0.14f
                paint.color = accent
                val r = radius * 0.55f
                canvas.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), (phase * 57.3f) % 360f, 280f, false, paint)
                return true
            }
        }
        return false
    }
}

/** Colores de la barra (tokens R.color, claro/noche). */
internal class DockPalette(context: Context) {
    val frosted = ContextCompat.getColor(context, R.color.dock_glass_frosted)
    val highlight = ContextCompat.getColor(context, R.color.dock_glass_highlight)
    val line = ContextCompat.getColor(context, R.color.dock_glass_line)
    val label = ContextCompat.getColor(context, R.color.dock_label)
    val pressed = ContextCompat.getColor(context, R.color.dock_tool_pressed)
    val recording = ContextCompat.getColor(context, R.color.kb_recording)
    val accent = ContextCompat.getColor(context, R.color.kb_key_bg_accent)
    val onRecording = ContextCompat.getColor(context, R.color.kb_label_on_accent)
    val track = ContextCompat.getColor(context, R.color.dock_track)
    val handle = ContextCompat.getColor(context, R.color.dock_handle)
}

/**
 * Barra pegada al borde: lengüeta de 7 dp que se abre como un bulto líquido
 * con las herramientas. La forma la calcula [DockGeometry.edgeOutline].
 * Vidrio lechoso propio: Android solo desenfoca rectángulos redondeados y
 * esta forma tiene cuellos cóncavos.
 */
@SuppressLint("ViewConstructor")
internal class EdgeView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)
    private val outline = Path()
    private var phase = 0f

    var shape = DockGeometry.collapsed(d)
        set(value) { field = value; invalidate() }
    var side = DockGeometry.Side.RIGHT
        set(value) { field = value; invalidate() }
    var tools: List<DockGeometry.Tool> = listOf(DockGeometry.Tool.MIC)
        set(value) { field = value; invalidate() }
    /** 0 = lengüeta, 1 = abierta (las herramientas aparecen desde 0,6). */
    var openFraction = 0f
        set(value) { field = value; invalidate() }
    var dictationState = "idle"
        set(value) { field = value; invalidate() }
    var pressedIndex = -1
        set(value) { field = value; invalidate() }

    fun refreshPalette() {
        palette = DockPalette(context)
        invalidate()
    }

    /** Borde izquierdo de la forma dentro de la ventana (la ventana puede ser más ancha). */
    fun shapeLeft(): Float = if (side == DockGeometry.Side.RIGHT) width - shape.w else 0f

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val left = shapeLeft()
        val top = (height - DockGeometry.windowHeight(shape)) / 2f
        outline.reset()
        for (op in DockGeometry.edgeOutline(shape, side)) {
            when (op) {
                is DockGeometry.Op.Move -> outline.moveTo(left + op.x, top + op.y)
                is DockGeometry.Op.Line -> outline.lineTo(left + op.x, top + op.y)
                is DockGeometry.Op.Quad -> outline.quadTo(left + op.cx, top + op.cy, left + op.x, top + op.y)
                is DockGeometry.Op.Arc -> outline.arcTo(
                    RectF(left + op.l, top + op.t, left + op.r, top + op.b), op.start, op.sweep, false,
                )
                DockGeometry.Op.Close -> outline.close()
            }
        }
        fill.color = palette.frosted
        canvas.drawPath(outline, fill)
        stroke.strokeWidth = 1f * d
        stroke.color = palette.line
        canvas.drawPath(outline, stroke)
        stroke.strokeWidth = 0.8f * d
        stroke.color = palette.highlight
        canvas.drawPath(outline, stroke)

        if (openFraction < 0.6f) return
        val alpha = ((openFraction - 0.6f) / 0.4f).coerceIn(0f, 1f)
        val cx = left + shape.w / 2f
        val shapeTop = top + shape.r
        var animating = false
        tools.forEachIndexed { i, tool ->
            val cy = DockGeometry.toolCenterY(i, shapeTop, shape, tools.size, d)
            val r = DockGeometry.TOOL_DP * d / 2f
            if (i == pressedIndex) {
                fill.color = palette.pressed
                canvas.drawCircle(cx, cy, r, fill)
            }
            val drewState = tool == DockGeometry.Tool.MIC && DockIcons.drawDictationState(
                canvas, dictationState, cx, cy, r * 0.92f, phase, palette.recording, palette.accent, palette.onRecording, icon,
            )
            if (drewState) {
                animating = true
            } else {
                val faded = ColorUtils.setAlphaComponent(palette.label, (alpha * 255).toInt())
                DockIcons.drawTool(canvas, tool, cx, cy, 22f * d, faded, icon)
            }
        }
        if (animating) {
            phase += 0.12f
            postInvalidateOnAnimation()
        }
    }
}

/** Burbuja libre. Con desenfoque real el fondo lo pone la ventana. */
@SuppressLint("ViewConstructor")
internal class BubbleView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)
    private var phase = 0f

    var frosted = true
        set(value) { field = value; invalidate() }
    var tools: List<DockGeometry.Tool> = listOf(DockGeometry.Tool.MIC)
        set(value) { field = value; invalidate() }
    var dictationState = "idle"
        set(value) { field = value; invalidate() }
    var lifted = false
        set(value) {
            field = value
            animate().scaleX(if (value) 1.08f else 1f).scaleY(if (value) 1.08f else 1f).setDuration(140L).start()
        }

    fun refreshPalette() {
        palette = DockPalette(context)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = minOf(cx, cy) - 1f * d
        if (frosted) {
            fill.color = palette.frosted
            canvas.drawCircle(cx, cy, r, fill)
        }
        stroke.strokeWidth = 1f * d
        stroke.color = palette.line
        canvas.drawCircle(cx, cy, r - 0.5f * d, stroke)
        stroke.color = palette.highlight
        canvas.drawArc(RectF(cx - r + d, cy - r + d, cx + r - d, cy + r - d), 200f, 140f, false, stroke)

        if (DockIcons.drawDictationState(canvas, dictationState, cx, cy, r * 0.82f, phase, palette.recording, palette.accent, palette.onRecording, icon)) {
            phase += 0.12f
            postInvalidateOnAnimation()
            return
        }
        when {
            tools.size > 1 -> DockIcons.drawHub(canvas, cx, cy, r, palette.label, icon)
            else -> DockIcons.drawTool(canvas, tools.first(), cx, cy, 24f * d, palette.label, icon)
        }
    }
}

/** Herramienta del abanico (círculo de vidrio con un ícono). */
@SuppressLint("ViewConstructor")
internal class ToolOrbView(context: Context, val tool: DockGeometry.Tool) : View(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)

    var frosted = true
        set(value) { field = value; invalidate() }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = minOf(cx, cy) - 1f * d
        if (frosted) {
            fill.color = palette.frosted
            canvas.drawCircle(cx, cy, r, fill)
        }
        if (isPressed) {
            fill.color = palette.pressed
            canvas.drawCircle(cx, cy, r, fill)
        }
        stroke.strokeWidth = 1f * d
        stroke.color = palette.line
        canvas.drawCircle(cx, cy, r - 0.5f * d, stroke)
        DockIcons.drawTool(canvas, tool, cx, cy, 21f * d, palette.label, icon)
    }

    override fun setPressed(pressed: Boolean) {
        super.setPressed(pressed)
        invalidate()
    }
}
