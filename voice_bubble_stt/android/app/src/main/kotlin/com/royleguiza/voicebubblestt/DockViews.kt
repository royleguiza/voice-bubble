package com.royleguiza.voicebubblestt

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import android.widget.FrameLayout
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils

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
}

/** Colores de la barra (tokens R.color, claro/noche). Superficie sólida, sin vidrio. */
internal class DockPalette(context: Context) {
    val surface = ContextCompat.getColor(context, R.color.dock_surface)
    val line = ContextCompat.getColor(context, R.color.dock_line)
    val label = ContextCompat.getColor(context, R.color.dock_label)
    val pressed = ContextCompat.getColor(context, R.color.dock_tool_pressed)
    val active = ContextCompat.getColor(context, R.color.dock_tool_active)
    val activeIcon = ContextCompat.getColor(context, R.color.dock_tool_active_icon)
    val hole = ContextCompat.getColor(context, R.color.hz_hole)
    val ember = ContextCompat.getColor(context, R.color.hz_ember)
    val hot = ContextCompat.getColor(context, R.color.hz_hot)
    val onHole = ContextCompat.getColor(context, R.color.hz_on_hole)
    val accent = ContextCompat.getColor(context, R.color.kb_key_bg_accent)
    val track = ContextCompat.getColor(context, R.color.dock_track)
    val handle = ContextCompat.getColor(context, R.color.dock_handle)
}

/** Fase del agujero según el estado visual que reporta Dart (idle/recording/transcribing). */
internal fun horizonPhaseOf(dictationState: String): HorizonView.Phase = when (dictationState) {
    "recording" -> HorizonView.Phase.RECORDING
    "transcribing" -> HorizonView.Phase.THINKING
    else -> HorizonView.Phase.IDLE
}

/**
 * Fondo del agujero (design.md §3): disco hole con anillo de brasa de 2 dp
 * (destello al presionar). La corona viva la dibuja el [HorizonView] hijo.
 */
private fun drawHoleDisc(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    r: Float,
    pressed: Boolean,
    d: Float,
    palette: DockPalette,
    fill: Paint,
    stroke: Paint,
    alpha: Int = 255,
) {
    fill.color = ColorUtils.setAlphaComponent(palette.hole, alpha)
    canvas.drawCircle(cx, cy, r, fill)
    stroke.strokeWidth = 2f * d
    stroke.color = ColorUtils.setAlphaComponent(if (pressed) palette.hot else palette.ember, alpha)
    canvas.drawCircle(cx, cy, r - 1f * d, stroke)
}

/**
 * Barra pegada al borde: lengüeta de 7 dp que se abre como un bulto líquido
 * con las herramientas. La forma la calcula [DockGeometry.edgeOutline].
 * Superficie sólida dock_surface + borde dock_line de 1 dp (sin desenfoque).
 * El micrófono es el agujero: disco hole + anillo brasa con un
 * [HorizonView] en modo CORONA encima, ubicado en el centro de su lugar.
 */
@SuppressLint("ViewConstructor")
internal class EdgeView(context: Context) : FrameLayout(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)
    private val outline = Path()
    private val toolPx = (DockGeometry.TOOL_DP * d).toInt()

    /** Corona del micrófono (fase según el dictado; se detiene sola oculta o desacoplada). */
    val horizon = HorizonView(context, HorizonView.Mode.CORONA)

    var shape = DockGeometry.collapsed(d)
        set(value) { field = value; placeHorizon(); invalidate() }
    var side = DockGeometry.Side.RIGHT
        set(value) { field = value; placeHorizon(); invalidate() }
    var tools: List<DockGeometry.Tool> = listOf(DockGeometry.Tool.MIC)
        set(value) { field = value; placeHorizon(); invalidate() }
    /** 0 = lengüeta, 1 = abierta (las herramientas aparecen desde 0,6). */
    var openFraction = 0f
        set(value) { field = value; placeHorizon(); invalidate() }
    var dictationState = "idle"
        set(value) { field = value; horizon.setPhase(horizonPhaseOf(value)); invalidate() }
    var pressedIndex = -1
        set(value) { field = value; invalidate() }
    /** Puntero activo (trackpad abierto): brasa suave + ember-t, como la barra del teclado. */
    var pointerActive = false
        set(value) { field = value; invalidate() }

    init {
        setWillNotDraw(false)
        horizon.visibility = View.INVISIBLE
        addView(horizon, LayoutParams(toolPx, toolPx))
    }

    fun refreshPalette() {
        palette = DockPalette(context)
        invalidate()
    }

    /** Borde izquierdo de la forma dentro de la ventana (la ventana puede ser más ancha). */
    fun shapeLeft(): Float = if (side == DockGeometry.Side.RIGHT) width - shape.w else 0f

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        placeHorizon()
    }

    /** Ubica la corona sobre el lugar del micrófono (fuera de onDraw: sin bucles de invalidación). */
    private fun placeHorizon() {
        val i = tools.indexOf(DockGeometry.Tool.MIC)
        if (i < 0 || openFraction < 0.6f || width == 0) {
            horizon.visibility = View.INVISIBLE
            return
        }
        val top = (height - DockGeometry.windowHeight(shape)) / 2f + shape.r
        val cx = shapeLeft() + shape.w / 2f
        val cy = DockGeometry.toolCenterY(i, top, shape, tools.size, d)
        horizon.translationX = cx - toolPx / 2f
        horizon.translationY = cy - toolPx / 2f
        horizon.alpha = ((openFraction - 0.6f) / 0.4f).coerceIn(0f, 1f)
        horizon.visibility = View.VISIBLE
    }

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
        fill.color = palette.surface
        canvas.drawPath(outline, fill)
        stroke.strokeWidth = 1f * d
        stroke.color = palette.line
        canvas.drawPath(outline, stroke)

        if (openFraction < 0.6f) return
        val alpha = ((openFraction - 0.6f) / 0.4f).coerceIn(0f, 1f)
        val a = (alpha * 255).toInt()
        val cx = left + shape.w / 2f
        val shapeTop = top + shape.r
        tools.forEachIndexed { i, tool ->
            val cy = DockGeometry.toolCenterY(i, shapeTop, shape, tools.size, d)
            val r = DockGeometry.TOOL_DP * d / 2f
            if (tool == DockGeometry.Tool.MIC) {
                drawHoleDisc(canvas, cx, cy, r, i == pressedIndex, d, palette, fill, stroke, a)
                return@forEachIndexed
            }
            val active = tool == DockGeometry.Tool.POINTER && pointerActive
            if (i == pressedIndex || active) {
                fill.color = ColorUtils.setAlphaComponent(if (active) palette.active else palette.pressed, a)
                canvas.drawCircle(cx, cy, r, fill)
            }
            val color = ColorUtils.setAlphaComponent(if (active) palette.activeIcon else palette.label, a)
            DockIcons.drawTool(canvas, tool, cx, cy, 22f * d, color, icon)
        }
    }
}

/**
 * Burbuja libre. Con el micrófono (única herramienta, o dictando) es el
 * agujero: disco hole + anillo brasa con un [HorizonView] CORONA encima.
 * Con varias herramientas en reposo es un botón sólido (dock_surface +
 * dock_line) con el ícono de concentrador en fg2.
 */
@SuppressLint("ViewConstructor")
internal class BubbleView(context: Context) : FrameLayout(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)

    /** Corona del micrófono (fase según el dictado; se detiene sola oculta o desacoplada). */
    val horizon = HorizonView(context, HorizonView.Mode.CORONA)

    var tools: List<DockGeometry.Tool> = listOf(DockGeometry.Tool.MIC)
        set(value) { field = value; syncHorizon(); invalidate() }
    var dictationState = "idle"
        set(value) {
            field = value
            horizon.setPhase(horizonPhaseOf(value))
            syncHorizon()
            invalidate()
        }
    var lifted = false
        set(value) {
            field = value
            animate().scaleX(if (value) 1.08f else 1f).scaleY(if (value) 1.08f else 1f).setDuration(140L).start()
        }

    init {
        setWillNotDraw(false)
        addView(horizon, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        syncHorizon()
    }

    /** ¿La burbuja se muestra como agujero (micrófono) o como concentrador? */
    private fun showsHole(): Boolean = dictationState != "idle" || tools.size <= 1

    private fun syncHorizon() {
        horizon.visibility = if (showsHole()) View.VISIBLE else View.GONE
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
        if (showsHole()) {
            drawHoleDisc(canvas, cx, cy, r, isPressed, d, palette, fill, stroke)
            return
        }
        fill.color = palette.surface
        canvas.drawCircle(cx, cy, r, fill)
        stroke.strokeWidth = 1f * d
        stroke.color = palette.line
        canvas.drawCircle(cx, cy, r - 0.5f * d, stroke)
        DockIcons.drawHub(canvas, cx, cy, r, palette.label, icon)
    }
}

/** Herramienta del abanico: botón de ícono circular sólido (surf + line); el micrófono es el agujero. */
@SuppressLint("ViewConstructor")
internal class ToolOrbView(context: Context, val tool: DockGeometry.Tool) : View(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = minOf(cx, cy) - 1f * d
        if (tool == DockGeometry.Tool.MIC) {
            drawHoleDisc(canvas, cx, cy, r, isPressed, d, palette, fill, stroke)
            DockIcons.drawMic(canvas, cx, cy, 21f * d, palette.onHole, icon)
            return
        }
        fill.color = if (isPressed) palette.pressed else palette.surface
        canvas.drawCircle(cx, cy, r, fill)
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
