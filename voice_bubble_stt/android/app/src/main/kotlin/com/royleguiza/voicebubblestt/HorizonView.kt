package com.royleguiza.voicebubblestt

import android.animation.TimeAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * El micrófono "agujero negro" de Horizonte con voz viva (fase 1, design.md
 * §8 "Voz"; maqueta `laboratorio_ui/horizonte.html`, `drawA`/`drawC`).
 *
 * - [Mode.ACCRETION] (A, pastilla): agujero a la izquierda; mientras graba
 *   entran por la derecha puntos, rayas y 0/1/{/} que caen al agujero, en
 *   cantidad y velocidad proporcionales al volumen; pensando, un arco gira
 *   sobre el anillo y salen renglones hacia la derecha.
 * - [Mode.CORONA] (C, círculo): agujero centrado con espigas radiales que
 *   siguen el volumen; pensando, arco giratorio. Pensada para reutilizarse
 *   en la burbuja flotante y el widget.
 *
 * Presupuesto: pool fijo de [MAX_PARTICLES] partículas y 44 espigas, todos
 * los Paint/Path/Shader creados una sola vez (cero asignaciones en onDraw).
 * El nivel llega por [levelSource] (lectura volátil del hilo de captura,
 * sin trabajo en el main). El animador corre solo en grabando/pensando con
 * la vista adjunta y visible; con las animaciones del sistema desactivadas
 * queda un anillo fijo cuyo grosor sigue el volumen, sin partículas.
 *
 * El fondo de la pastilla lo pone el contenedor (drawable); esta vista solo
 * recorta a su forma de cápsula y dibuja encima.
 */
class HorizonView(context: Context, val mode: Mode) : View(context) {

    constructor(context: Context, attrs: AttributeSet?) : this(context, Mode.ACCRETION)

    enum class Mode { ACCRETION, CORONA }

    enum class Phase { IDLE, RECORDING, THINKING }

    /** Fuente del nivel 0..1; se lee una vez por cuadro en el main. */
    fun interface LevelSource {
        fun level(): Float
    }

    var levelSource: LevelSource? = null

    var phase: Phase = Phase.IDLE
        private set

    private val dp = resources.displayMetrics.density

    private val colorHole = ContextCompat.getColor(context, R.color.hz_hole)
    private val colorFg = ContextCompat.getColor(context, R.color.hz_on_hole)
    private val colorEmber = ContextCompat.getColor(context, R.color.hz_ember)
    private val colorHot = ContextCompat.getColor(context, R.color.hz_hot)

    // --- Pool fijo de partículas (A) ---
    private val px = FloatArray(MAX_PARTICLES)
    private val py = FloatArray(MAX_PARTICLES)
    private val ps = FloatArray(MAX_PARTICLES)
    private val plen = FloatArray(MAX_PARTICLES)
    private val pkind = IntArray(MAX_PARTICLES)
    private val pactive = BooleanArray(MAX_PARTICLES)

    // --- Espigas (C) ---
    private val spikes = FloatArray(SPIKES)

    private var spawnAcc = 0f
    private var clock = 0f
    private var vol = 0f

    // --- Pinceles y geometría reutilizados ---
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = try {
            ResourcesCompat.getFont(context, R.font.jetbrains_mono)
        } catch (_: Exception) {
            null
        } ?: Typeface.MONOSPACE
    }
    private val glowShader = RadialGradient(
        0f, 0f, 1f,
        intArrayOf(colorEmber, colorEmber, colorEmber and 0x00FFFFFF),
        floatArrayOf(0f, 0.28f, 1f),
        Shader.TileMode.CLAMP,
    )
    private val glowMatrix = Matrix()
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        shader = glowShader
    }
    private val oval = RectF()
    private val clip = Path()

    // --- Bucle ---
    private var aggregatedVisible = false
    private val animator = TimeAnimator().apply {
        setTimeListener { _, _, deltaMs ->
            step(min(0.05f, deltaMs / 1000f))
            invalidate()
        }
    }
    private var staticRefreshPosted = false
    private val staticRefresh = object : Runnable {
        override fun run() {
            staticRefreshPosted = false
            if (phase != Phase.RECORDING || !isAttachedToWindow || !aggregatedVisible) return
            vol = currentTarget()
            invalidate()
            staticRefreshPosted = true
            postDelayed(this, STATIC_REFRESH_MS)
        }
    }

    init {
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    /** Cambia de estado; el animador arranca o se detiene según corresponda. */
    fun setPhase(next: Phase) {
        if (next == phase) return
        phase = next
        if (next == Phase.IDLE) {
            pactive.fill(false)
            spikes.fill(0f)
            vol = 0f
        }
        spawnAcc = 0f
        updateRunning()
        invalidate()
    }

    /** true mientras el animador de cuadros está corriendo (tests/diagnóstico). */
    fun isAnimating(): Boolean = animator.isStarted

    private fun animationsEnabled(): Boolean = ValueAnimator.areAnimatorsEnabled()

    private fun currentTarget(): Float =
        if (phase == Phase.RECORDING) (levelSource?.level() ?: 0f).coerceIn(0f, 1f) else 0f

    private fun updateRunning() {
        val active = isAttachedToWindow && aggregatedVisible && phase != Phase.IDLE
        if (active && animationsEnabled()) {
            stopStaticRefresh()
            if (!animator.isStarted) animator.start()
        } else {
            if (animator.isStarted) animator.cancel()
            if (active && phase == Phase.RECORDING) {
                if (!staticRefreshPosted) {
                    staticRefreshPosted = true
                    post(staticRefresh)
                }
            } else {
                stopStaticRefresh()
            }
        }
    }

    private fun stopStaticRefresh() {
        if (staticRefreshPosted) removeCallbacks(staticRefresh)
        staticRefreshPosted = false
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        aggregatedVisible = isShown
        updateRunning()
    }

    override fun onDetachedFromWindow() {
        aggregatedVisible = false
        if (animator.isStarted) animator.cancel()
        stopStaticRefresh()
        super.onDetachedFromWindow()
    }

    override fun onVisibilityAggregated(isVisible: Boolean) {
        super.onVisibilityAggregated(isVisible)
        aggregatedVisible = isVisible
        updateRunning()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        clip.reset()
        if (mode == Mode.ACCRETION) {
            val r = h / 2f
            clip.addRoundRect(0f, 0f, w.toFloat(), h.toFloat(), r, r, Path.Direction.CW)
        }
    }

    // ------------------------------------------------------------------
    // Simulación (solo con animaciones activas)
    // ------------------------------------------------------------------

    private fun step(dt: Float) {
        clock += dt
        val target = currentTarget()
        vol += (target - vol) * min(1f, dt * 14f)
        if (mode == Mode.CORONA) {
            val recording = phase == Phase.RECORDING
            for (i in 0 until SPIKES) {
                val tgt = if (recording) {
                    vol * (0.35f + 0.65f * abs(sin(i * 1.7f + clock * 3.1f) * sin(i * 0.9f - clock * 2.3f)))
                } else 0f
                spikes[i] += (tgt - spikes[i]) * min(1f, dt * 16f)
            }
            return
        }
        val h = height.toFloat()
        val w = width.toFloat()
        if (w <= 0f || h <= 0f) return
        val r = h * 0.3f
        val cx = h * 0.5f + dp
        val cy = h * 0.5f
        when (phase) {
            Phase.RECORDING -> {
                spawnAcc += dt * (5f + 90f * vol)
                while (spawnAcc > 1f) {
                    spawnAcc -= 1f
                    val i = freeSlot()
                    if (i < 0) break
                    pactive[i] = true
                    px[i] = w + 4f * dp
                    py[i] = h * (0.12f + Random.nextFloat() * 0.76f)
                    ps[i] = 0.55f + Random.nextFloat() * 0.9f
                    pkind[i] = if (Random.nextFloat() < 0.45f) {
                        KIND_GLYPH0 + Random.nextInt(GLYPHS.size)
                    } else if (Random.nextFloat() < 0.5f) KIND_DASH else KIND_DOT
                }
            }
            Phase.THINKING -> {
                spawnAcc += dt * 9f
                while (spawnAcc > 1f) {
                    spawnAcc -= 1f
                    val i = freeSlot()
                    if (i < 0) break
                    pactive[i] = true
                    px[i] = cx + r + 2f * dp
                    py[i] = cy + (Random.nextFloat() - 0.5f) * h * 0.36f
                    ps[i] = 0.6f + Random.nextFloat() * 0.6f
                    plen[i] = (5f + Random.nextFloat() * 16f) * dp
                    pkind[i] = KIND_LINE
                }
            }
            Phase.IDLE -> {}
        }
        for (i in 0 until MAX_PARTICLES) {
            if (!pactive[i]) continue
            if (pkind[i] == KIND_LINE) {
                px[i] += dt * (26f + 70f * ps[i]) * dp * max(0.25f, 1f - (px[i] - cx) / (w * 0.9f))
                val a = lineAlpha(i, cx, r, w)
                if (a <= 0f && px[i] >= cx + r + 16f * dp) pactive[i] = false
            } else {
                val d = (px[i] - cx) / (w - cx)
                px[i] -= dt * (50f + 330f * vol) * dp * ps[i] * (0.55f + 0.45f * d)
                val near = 1f - d
                py[i] += (cy - py[i]) * min(1f, dt * (1.2f + 6f * near * near))
                if (hypot(px[i] - cx, py[i] - cy) < r) pactive[i] = false
            }
        }
    }

    private fun freeSlot(): Int {
        for (i in 0 until MAX_PARTICLES) if (!pactive[i]) return i
        return -1
    }

    private fun lineAlpha(i: Int, cx: Float, r: Float, w: Float): Float =
        min(1f, (px[i] - cx - r) / (14f * dp)) * max(0f, 1f - (px[i] - cx) / (w * 0.86f))

    // ------------------------------------------------------------------
    // Dibujo
    // ------------------------------------------------------------------

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w < 4f || h < 4f) return
        val live = animator.isStarted
        if (!live) vol = currentTarget()
        if (mode == Mode.ACCRETION) drawAccretion(canvas, w, h, live) else drawCorona(canvas, w, h, live)
    }

    private fun drawAccretion(canvas: Canvas, w: Float, h: Float, live: Boolean) {
        val save = canvas.save()
        canvas.clipPath(clip)
        val r = h * 0.3f
        val cx = h * 0.5f + dp
        val cy = h * 0.5f
        if (live) {
            for (i in 0 until MAX_PARTICLES) {
                if (!pactive[i]) continue
                if (pkind[i] == KIND_LINE) {
                    val a = lineAlpha(i, cx, r, w).coerceIn(0f, 1f)
                    stroke.color = colorFg
                    stroke.alpha = (a * 255).toInt()
                    stroke.strokeWidth = 2f * dp
                    canvas.drawLine(px[i], py[i], px[i] + plen[i], py[i], stroke)
                    continue
                }
                val d = ((px[i] - cx) / (w - cx)).coerceIn(0f, 1f)
                val a = min(1f, 0.25f + d * 0.9f) * ((w - px[i]) / (20f * dp) + 0.2f).coerceIn(0f, 1f)
                val color = if (d < 0.18f) colorHot else if (d < 0.45f) colorEmber else colorFg
                val k = 0.45f + 0.55f * d
                when (pkind[i]) {
                    KIND_DOT -> {
                        fill.color = color
                        fill.alpha = (a * 255).toInt()
                        canvas.drawCircle(px[i], py[i], 1.5f * k * dp, fill)
                    }
                    KIND_DASH -> {
                        fill.color = color
                        fill.alpha = (a * 255).toInt()
                        canvas.drawRect(px[i], py[i] - 0.8f * k * dp, px[i] + 8f * k * dp, py[i] + 0.8f * k * dp, fill)
                    }
                    else -> {
                        text.color = color
                        text.alpha = (a * 255).toInt()
                        text.textSize = h * 0.2f * k + 3f * dp
                        canvas.drawText(GLYPHS, pkind[i] - KIND_GLYPH0, 1, px[i], py[i] + 3f * dp, text)
                    }
                }
            }
        }
        val k = when (phase) {
            Phase.RECORDING -> vol
            Phase.THINKING -> 0.25f
            Phase.IDLE -> 0f
        }
        ringGlow(canvas, cx, cy, r, k)
        when (phase) {
            Phase.THINKING -> spinArc(canvas, cx, cy, r, if (live) clock else 0f)
            Phase.IDLE -> micGlyph(canvas, cx, cy, h / 64f)
            Phase.RECORDING -> {}
        }
        canvas.restoreToCount(save)
    }

    private fun drawCorona(canvas: Canvas, w: Float, h: Float, live: Boolean) {
        val s = min(w, h)
        val cx = w / 2f
        val cy = h / 2f
        val r = s * 0.25f
        val recording = phase == Phase.RECORDING
        if (live) {
            val r0 = r + 3f * dp
            stroke.strokeWidth = max(1.2f * dp, s / 60f)
            for (i in 0 until SPIKES) {
                val a = i.toFloat() / SPIKES * TWO_PI + clock * 0.25f
                val len = 2f * dp + spikes[i] * s * 0.21f
                stroke.color = if (spikes[i] > 0.45f) colorHot else colorEmber
                stroke.alpha = ((0.4f + 0.6f * spikes[i]) * 255).toInt()
                val ca = cos(a)
                val sa = sin(a)
                canvas.drawLine(cx + ca * r0, cy + sa * r0, cx + ca * (r0 + len), cy + sa * (r0 + len), stroke)
            }
        }
        fill.color = colorHole
        fill.alpha = 255
        canvas.drawCircle(cx, cy, r, fill)
        val k = if (recording) vol else 0f
        stroke.color = if (recording && vol > 0.5f) colorHot else colorEmber
        stroke.alpha = 255
        stroke.strokeWidth = (1.5f + 2f * k) * dp
        canvas.drawCircle(cx, cy, r, stroke)
        if (phase == Phase.THINKING) {
            spinArc(canvas, cx, cy, r, if (live) clock else 0f)
        } else {
            micGlyph(canvas, cx, cy, s / 120f + 0.35f * dp)
        }
    }

    /** Anillo del agujero con halo; [k] 0..1 engrosa el anillo y abre el halo. */
    private fun ringGlow(canvas: Canvas, x: Float, y: Float, r: Float, k: Float) {
        val kk = k.coerceIn(0f, 1f)
        if (r <= 0f) return
        val outer = r * (1.6f + kk * 1.6f)
        glowMatrix.setScale(outer, outer)
        glowMatrix.postTranslate(x, y)
        glowShader.setLocalMatrix(glowMatrix)
        glow.alpha = ((0.35f + 0.5f * kk) * 255).toInt()
        canvas.drawCircle(x, y, outer, glow)
        fill.color = colorHole
        fill.alpha = 255
        canvas.drawCircle(x, y, r, fill)
        stroke.color = if (kk > 0.5f) colorHot else colorEmber
        stroke.alpha = 255
        stroke.strokeWidth = (1.2f + 2.2f * kk) * dp
        canvas.drawCircle(x, y, r, stroke)
    }

    /** Arco con cola que gira sobre el anillo (pensando). */
    private fun spinArc(canvas: Canvas, x: Float, y: Float, r: Float, t: Float) {
        val rr = r + 4f * dp
        oval.set(x - rr, y - rr, x + rr, y + rr)
        stroke.strokeWidth = 3f * dp
        for (i in 0 until ARC_SEGMENTS) {
            val a = t * 5f - i * 0.13f
            stroke.color = if (i < 6) colorHot else colorEmber
            stroke.alpha = ((1f - i.toFloat() / ARC_SEGMENTS) * 0.95f * 255).toInt()
            canvas.drawArc(oval, Math.toDegrees(a.toDouble()).toFloat(), ARC_SWEEP_DEG, false, stroke)
        }
    }

    /** Glifo de micrófono en on-hole, escalado por [k] (px por unidad de la maqueta). */
    private fun micGlyph(canvas: Canvas, x: Float, y: Float, k: Float) {
        stroke.color = colorFg
        stroke.alpha = 255
        stroke.strokeWidth = 1.6f * k
        oval.set(x - 3f * k, y - 8f * k, x + 3f * k, y + 3f * k)
        canvas.drawRoundRect(oval, 3f * k, 3f * k, stroke)
        val rr = 6.2f * k
        oval.set(x - rr, y + k - rr, x + rr, y + k + rr)
        canvas.drawArc(oval, MIC_ARC_START_DEG, MIC_ARC_SWEEP_DEG, false, stroke)
        canvas.drawLine(x, y + 7.2f * k, x, y + 10f * k, stroke)
    }

    companion object {
        /** Tope de partículas en la pastilla (pool fijo). */
        const val MAX_PARTICLES = 60
        const val SPIKES = 44
        private const val ARC_SEGMENTS = 22
        private const val STATIC_REFRESH_MS = 100L
        private const val PI_F = 3.1415927f
        private const val TWO_PI = 2f * PI_F
        private const val ARC_SWEEP_DEG = 0.14f * 180f / PI_F
        private const val MIC_ARC_START_DEG = 0.15f * 180f / PI_F
        private const val MIC_ARC_SWEEP_DEG = (PI_F - 0.3f) * 180f / PI_F

        private const val KIND_DOT = 0
        private const val KIND_DASH = 1
        private const val KIND_LINE = 2
        private const val KIND_GLYPH0 = 3

        /** Caracteres que caen al agujero (mono): 0, 1, {, }. */
        private val GLYPHS = charArrayOf('0', '1', '{', '}')
    }
}

/**
 * Fondo de la tecla de micrófono en reposo: el agujero (círculo `hz_hole`
 * del lado menor, centrado, con anillo `hz_ember`; presionado, `hz_hot`).
 * Drawable propio para que siga siendo círculo en teclas anchas y con
 * cualquier espaciado (un `oval` XML se estiraría en elipse).
 */
class HoleDrawable(context: Context) : android.graphics.drawable.Drawable() {
    private val density = context.resources.displayMetrics.density
    private val ember = ContextCompat.getColor(context, R.color.hz_ember)
    private val hot = ContextCompat.getColor(context, R.color.hz_hot)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = ContextCompat.getColor(context, R.color.hz_hole)
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.5f * density
        color = ember
    }
    private var pressed = false

    override fun draw(canvas: Canvas) {
        val b = bounds
        val r = min(b.width(), b.height()) / 2f - ring.strokeWidth / 2f
        if (r <= 0f) return
        ring.color = if (pressed) hot else ember
        canvas.drawCircle(b.exactCenterX(), b.exactCenterY(), r, fill)
        canvas.drawCircle(b.exactCenterX(), b.exactCenterY(), r, ring)
    }

    override fun isStateful(): Boolean = true

    override fun onStateChange(state: IntArray): Boolean {
        val now = state.contains(android.R.attr.state_pressed)
        if (now == pressed) return false
        pressed = now
        invalidateSelf()
        return true
    }

    override fun setAlpha(alpha: Int) {
        fill.alpha = alpha
        ring.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        fill.colorFilter = colorFilter
        ring.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = android.graphics.PixelFormat.TRANSLUCENT
}
