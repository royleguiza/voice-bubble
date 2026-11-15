package com.royleguiza.voicebubble.puntero

import android.animation.TimeAnimator
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.view.View
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * El micrófono «agujero negro» de Horizonte con voz viva (design.md §8 «Voz»;
 * maquetas `laboratorio_ui/horizonte.html` e `isla.html`). Port al complemento
 * de la vista de VoiceBubble: la misma estética y las mismas reglas, ahora
 * dibujadas por las ventanas de Accesibilidad de la barra.
 *
 * - [Mode.CORONA] (burbuja y barra del borde): agujero centrado con ~44 espigas
 *   radiales que siguen el volumen; pensando, arco giratorio.
 * - [Mode.HOLE] (isla): solo el agujero (disco `hole`, anillo brasa cuyo grosor
 *   sigue el volumen, glifo de micrófono); pensando, arco con cola que gira.
 * - [Mode.VOICE] (isla): la franja entre el agujero y el cronómetro. Grabando,
 *   puntos, rayas y 0 1 { } caen hacia el agujero (más y más rápido cuanto más
 *   fuerte); pensando, rayitas blancas salen del agujero y se desvanecen.
 *   [holeOnLeft] decide hacia qué lado caen.
 *
 * Presupuesto: pools fijos ([MAX_PARTICLES] partículas, 44 espigas), todos los
 * Paint/Shader creados una sola vez (cero asignaciones en onDraw). El nivel
 * llega por [levelSource] (lectura volátil, sin trabajo en el main). El
 * animador corre solo en grabando/pensando con la vista adjunta y visible; con
 * las animaciones del sistema desactivadas queda un anillo fijo cuyo grosor
 * sigue el volumen, sin partículas, espigas ni arco.
 */
@SuppressLint("ViewConstructor")
internal class HorizonView(context: Context, val mode: Mode) : View(context) {

    enum class Mode { CORONA, HOLE, VOICE }

    enum class Phase { IDLE, RECORDING, THINKING }

    /** Fuente del nivel 0..1; se lee una vez por cuadro en el main. */
    fun interface LevelSource {
        fun level(): Float
    }

    var levelSource: LevelSource? = null

    /** [Mode.VOICE]: el agujero está a la izquierda (las partículas caen hacia ahí). */
    var holeOnLeft: Boolean = true
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }

    /** [Mode.HOLE]: radio del disco (sin el anillo), en dp. */
    var holeRadiusDp: Float = 16f
        set(value) {
            field = value
            invalidate()
        }

    var phase: Phase = Phase.IDLE
        private set

    private val dp = resources.displayMetrics.density
    private var palette = Palette(context)

    private val colorHole get() = palette.hole
    private val colorFg get() = palette.onHole
    private val colorEmber get() = palette.ember
    private val colorHot get() = palette.hot
    private val colorWhite get() = palette.islandFg

    // --- Espigas (CORONA) y partículas (VOICE) ---
    private val spikes = FloatArray(SPIKES)
    private val pp = FloatArray(MAX_PARTICLES)
    private val py = FloatArray(MAX_PARTICLES)
    private val pk = FloatArray(MAX_PARTICLES)
    private val pg = FloatArray(MAX_PARTICLES)

    private var clock = 0f
    private var vol = 0f

    // --- Pinceles reutilizados ---
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = try {
            context.resources.getFont(R.font.jetbrains_mono_medium)
        } catch (_: Exception) {
            Typeface.MONOSPACE
        }
    }
    private val oval = RectF()

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
        // El agujero de la isla es un botón: TalkBack lo ve. Lo demás es decorado.
        importantForAccessibility = if (mode == Mode.HOLE) IMPORTANT_FOR_ACCESSIBILITY_YES else IMPORTANT_FOR_ACCESSIBILITY_NO
        for (i in 0 until MAX_PARTICLES) respawn(i, scatter = true)
    }

    /** Vuelve a leer los colores (cambio de tema claro/oscuro). */
    fun refreshPalette() {
        palette.reload()
        invalidate()
    }

    /** Cambia de estado; el animador arranca o se detiene según corresponda. */
    fun setPhase(next: Phase) {
        if (next == phase) return
        phase = next
        if (next == Phase.IDLE) {
            spikes.fill(0f)
            vol = 0f
        }
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

    // ------------------------------------------------------------------
    // Simulación (solo con animaciones activas)
    // ------------------------------------------------------------------

    private fun respawn(i: Int, scatter: Boolean) {
        pp[i] = if (scatter) Random.nextFloat() else 0f
        py[i] = Random.nextFloat()
        pk[i] = 0.6f + Random.nextFloat() * 0.8f
        pg[i] = Random.nextFloat()
    }

    private fun step(dt: Float) {
        clock += dt
        val target = currentTarget()
        vol += (target - vol) * min(1f, dt * 14f)
        when (mode) {
            Mode.CORONA -> {
                val recording = phase == Phase.RECORDING
                for (i in 0 until SPIKES) {
                    val tgt = if (recording) {
                        vol * (0.35f + 0.65f * abs(sin(i * 1.7f + clock * 3.1f) * sin(i * 0.9f - clock * 2.3f)))
                    } else 0f
                    spikes[i] += (tgt - spikes[i]) * min(1f, dt * 16f)
                }
            }
            Mode.VOICE -> {
                for (i in 0 until VOICE_PARTICLES) {
                    when (phase) {
                        Phase.RECORDING -> {
                            pp[i] += dt * (0.35f + 0.9f * vol) * pk[i]
                            if (pp[i] > 1f) respawn(i, scatter = false)
                        }
                        Phase.THINKING -> {
                            pp[i] += dt * 0.32f * pk[i]
                            if (pp[i] > 1f) pp[i] = 0f
                        }
                        Phase.IDLE -> {}
                    }
                }
            }
            Mode.HOLE -> {}
        }
    }

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
        when (mode) {
            Mode.CORONA -> drawCorona(canvas, w, h, live)
            Mode.HOLE -> drawHole(canvas, w, h, live)
            Mode.VOICE -> drawVoice(canvas, w, h, live)
        }
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

    /** Agujero de la isla: disco, anillo brasa que engorda con la voz, glifo; pensando, arco que gira. */
    private fun drawHole(canvas: Canvas, w: Float, h: Float, live: Boolean) {
        val cx = w / 2f
        val cy = h / 2f
        val r = holeRadiusDp * dp
        val recording = phase == Phase.RECORDING
        val k = if (recording) vol else 0f
        fill.color = colorHole
        fill.alpha = 255
        canvas.drawCircle(cx, cy, r, fill)
        stroke.color = if (recording && vol > 0.5f) colorHot else colorEmber
        stroke.alpha = 255
        stroke.strokeWidth = (2f + 1.5f * k) * dp
        canvas.drawCircle(cx, cy, r - 1f * dp, stroke)
        if (phase == Phase.THINKING) spinArc(canvas, cx, cy, r, if (live) clock else 0f)
        micGlyph(canvas, cx, cy, r * 2f / 34f)
    }

    /** Franja de la isla: símbolos hacia el agujero (grabando) o rayitas hacia afuera (pensando). */
    private fun drawVoice(canvas: Canvas, w: Float, h: Float, live: Boolean) {
        if (!live || phase == Phase.IDLE) return
        val cy = h / 2f
        for (i in 0 until VOICE_PARTICLES) {
            val p = pp[i]
            if (phase == Phase.RECORDING) {
                val d = 1f - p
                val x = if (holeOnLeft) w * d else w * (1f - d)
                val y = cy + (py[i] - 0.5f) * h * 0.62f * d
                val a = min(1f, 0.25f + 0.9f * d) * min(1f, p / 0.08f)
                val color = if (d > 0.45f) colorFg else if (d > 0.18f) colorEmber else colorHot
                val g = pg[i]
                val kk = 0.45f + 0.55f * d
                if (g < 0.45f) {
                    text.color = color
                    text.alpha = (a * 255).toInt()
                    text.textSize = (6f + 5f * d) * dp
                    canvas.drawText(GLYPHS, (g / 0.45f * GLYPHS.size).toInt().coerceIn(0, GLYPHS.size - 1), 1, x, y + 3f * dp, text)
                } else if (g < 0.72f) {
                    fill.color = color
                    fill.alpha = (a * 255).toInt()
                    canvas.drawRect(x, y - 0.8f * dp, x + 7f * kk * dp, y + 0.8f * dp, fill)
                } else {
                    fill.color = color
                    fill.alpha = (a * 255).toInt()
                    canvas.drawCircle(x, y, 1.5f * kk * dp, fill)
                }
            } else {
                val e = 1f - (1f - p) * (1f - p)
                val x0 = 2f * dp + (w - 8f * dp) * e
                val x = if (holeOnLeft) x0 else w - x0 - 12f * dp
                val y = cy + (py[i] - 0.5f) * h * 0.36f
                val a = min(1f, p / 0.06f) * min(1f, (1f - p) / 0.15f)
                fill.color = colorWhite
                fill.alpha = (a.coerceIn(0f, 1f) * 255).toInt()
                canvas.drawRect(x, y - 1f * dp, x + (5f + 16f * pg[i]) * dp, y + 1f * dp, fill)
            }
        }
        fill.alpha = 255
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
        stroke.alpha = 255
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
        /** Tope de partículas (pool fijo) y de espigas de la corona. */
        const val MAX_PARTICLES = 26
        const val VOICE_PARTICLES = 26
        const val SPIKES = 44
        private const val ARC_SEGMENTS = 22
        private const val STATIC_REFRESH_MS = 100L
        private const val PI_F = 3.1415927f
        private const val TWO_PI = 2f * PI_F
        private const val ARC_SWEEP_DEG = 0.14f * 180f / PI_F
        private const val MIC_ARC_START_DEG = 0.15f * 180f / PI_F
        private const val MIC_ARC_SWEEP_DEG = (PI_F - 0.3f) * 180f / PI_F

        /** Caracteres que caen al agujero (mono): 0, 1, {, }. */
        private val GLYPHS = charArrayOf('0', '1', '{', '}')
    }
}
