package com.royleguiza.voicebubble.puntero

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import kotlin.math.roundToInt

/**
 * La isla (maqueta `laboratorio_ui/isla.html`): píldora negra siempre, de día
 * y de noche (tokens `island_*`), borde de 1 dp. Dibuja ella misma la
 * superficie y las piezas decorativas de cada estado (reposo, listo, cronómetro,
 * anillo brasa grabando). En reposo cada mitad es un botón (la del agujero
 * dicta, la del glifo abre el puntero); grabando, tocar la píldora termina y
 * la ✕ cancela. El agujero y la ✕ son vistas reales para TalkBack.
 *
 * Quién decide qué estado mostrar, cuánto mide la píldora y cuándo se mueve la
 * ventana es [IslandController]; esta vista solo pinta lo que le dicen:
 * [setPill] (dónde está la píldora adentro de su ventana), [show] (qué estado,
 * con el cruce de capas durante el rebote) y los textos.
 */
@SuppressLint("ViewConstructor")
internal class IslandView(
    context: Context,
    private val palette: Palette,
    levelSource: HorizonView.LevelSource,
) : FrameLayout(context) {

    private val d = resources.displayMetrics.density
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val icon = Paint(Paint.ANTI_ALIAS_FLAG)
    private val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Fonts.interMedium(context)
        textSize = 12f * d
    }
    private val timerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Fonts.mono(context)
        textSize = 11f * d
        textAlign = Paint.Align.CENTER
    }
    private val path = Path()
    private val box = RectF()

    /** Píldora adentro de la ventana (px de la vista); la mueve el controlador durante el rebote. */
    private val pill = RectF()

    // Estado visible y cruce de capas durante el rebote (t de 0 a 1).
    private var current = IslandGeometry.State.IDLE
    private var from = IslandGeometry.State.IDLE
    private var morph = 1f

    /**
     * Tamaño de la píldora grabando (el último que se usó). Las piezas de
     * grabar se arman con esta medida aunque ya se esté yendo a otro estado,
     * así se apagan de a poco en su lugar en vez de desaparecer de golpe.
     */
    private var recW = 0
    private var recH = 0

    var micOnLeft = true
        set(value) { field = value; relayoutPieces(); invalidate() }
    var hasMic = true
        set(value) { field = value; relayoutPieces(); invalidate() }
    var hasPointer = false
        set(value) { field = value; relayoutPieces(); invalidate() }

    /** Trackpad abierto: el glifo del puntero se pinta en brasa. */
    var pointerActive = false
        set(value) {
            field = value
            updateDescriptions()
            invalidate()
        }

    var timerText = "0:00"
        set(value) { field = value; invalidate() }

    var doneText = ""
        set(value) { field = value; invalidate() }

    var doneIsError = false
        set(value) { field = value; invalidate() }

    // Piezas con vida propia.
    val holeView = HorizonView(context, HorizonView.Mode.HOLE)
    private val voiceView = HorizonView(context, HorizonView.Mode.VOICE)
    private val cancelButton = CancelButton(context, palette)

    /** Toque en reposo; el argumento es la x del dedo desde el borde izquierdo de la píldora. */
    var onIdleTap: ((Float) -> Unit)? = null

    /** Terminar el dictado (toque en la píldora o en el agujero mientras graba). */
    var onMicTap: (() -> Unit)? = null
    var onCancelTap: (() -> Unit)? = null

    /** Abrir el puntero sin coordenadas (acción de TalkBack). */
    var onPointerAction: (() -> Unit)? = null

    init {
        setWillNotDraw(false)
        clipChildren = false
        holeView.levelSource = levelSource
        voiceView.levelSource = levelSource
        holeView.setOnClickListener { onMicTap?.invoke() }
        cancelButton.setOnClickListener { onCancelTap?.invoke() }
        setOnClickListener {
            when (current) {
                IslandGeometry.State.IDLE -> onIdleTap?.invoke(tapX?.let { it - pill.left } ?: if (micOnLeft) 0f else pill.width())
                // Grabando: la píldora entera termina (el dedo no tiene que ir a buscar el agujero).
                IslandGeometry.State.REC -> onMicTap?.invoke()
                else -> {}
            }
        }
        addView(voiceView, LayoutParams(1, 1))
        addView(holeView, LayoutParams(1, 1))
        addView(cancelButton, LayoutParams(1, 1))
        accessibilityLiveRegion = ACCESSIBILITY_LIVE_REGION_POLITE
        // TalkBack no toca «una mitad»: en reposo cada herramienta es una acción con nombre.
        accessibilityDelegate = object : AccessibilityDelegate() {
            override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
                super.onInitializeAccessibilityNodeInfo(host, info)
                if (current != IslandGeometry.State.IDLE) return
                if (hasMic) info.addAction(AccessibilityNodeInfo.AccessibilityAction(DockController.ACTION_DICTATE, "Dictar"))
                if (hasPointer) info.addAction(AccessibilityNodeInfo.AccessibilityAction(DockController.ACTION_POINTER, "Abrir el puntero"))
            }

            override fun performAccessibilityAction(host: View, action: Int, args: Bundle?): Boolean = when {
                current != IslandGeometry.State.IDLE -> super.performAccessibilityAction(host, action, args)
                action == DockController.ACTION_DICTATE && hasMic -> { onMicTap?.invoke(); true }
                action == DockController.ACTION_POINTER && hasPointer -> { onPointerAction?.invoke(); true }
                else -> super.performAccessibilityAction(host, action, args)
            }
        }
        updateDescriptions()
    }

    /**
     * Dónde cayó el último toque (x de la vista). Sin toque (TalkBack activa
     * la isla sin coordenadas) queda del lado del micrófono.
     */
    private var tapX: Float? = null

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (ev.actionMasked == MotionEvent.ACTION_DOWN || ev.actionMasked == MotionEvent.ACTION_UP) tapX = ev.x
        return super.dispatchTouchEvent(ev)
    }

    override fun performClick(): Boolean {
        val handled = super.performClick()
        // El próximo clic sin dedo (accesibilidad) cae del lado del micrófono.
        tapX = null
        return handled
    }

    /** Detiene las animaciones (al sacar la ventana: nada queda corriendo). */
    fun stopAnimations() {
        holeView.setPhase(HorizonView.Phase.IDLE)
        voiceView.setPhase(HorizonView.Phase.IDLE)
    }

    /** Cambió el tema claro/oscuro (la isla casi no cambia, pero el agujero y la voz sí leen tokens). */
    fun refreshPalette() {
        holeView.refreshPalette()
        voiceView.refreshPalette()
        invalidate()
    }

    // ------------------------------------------------------------ estado

    /**
     * Pasa a [state]. [finalSize] = lo que va a medir la píldora (para ubicar
     * las piezas). El cruce de capas lo maneja [setMorph].
     */
    fun show(state: IslandGeometry.State, finalSize: IslandGeometry.Size) {
        if (state != current) from = current
        current = state
        val rec = state == IslandGeometry.State.REC || state == IslandGeometry.State.THINK
        if (rec) {
            recW = finalSize.w
            recH = finalSize.h
        }
        holeView.setPhase(
            when (state) {
                IslandGeometry.State.REC -> HorizonView.Phase.RECORDING
                IslandGeometry.State.THINK -> HorizonView.Phase.THINKING
                else -> HorizonView.Phase.IDLE
            },
        )
        voiceView.setPhase(
            when (state) {
                IslandGeometry.State.REC -> HorizonView.Phase.RECORDING
                IslandGeometry.State.THINK -> HorizonView.Phase.THINKING
                else -> HorizonView.Phase.IDLE
            },
        )
        holeView.holeRadiusDp = IslandGeometry.REC_HOLE_DP / 2f
        isClickable = state == IslandGeometry.State.IDLE || state == IslandGeometry.State.REC
        relayoutPieces()
        updateDescriptions()
        invalidate()
    }

    /** Avance del rebote: 0 = recién empezó, 1 = terminó. Con 1 solo se ve la capa del estado actual. */
    fun setMorph(t: Float) {
        morph = t.coerceIn(0f, 1f)
        positionPieces()
        invalidate()
    }

    fun setPill(left: Float, top: Float, right: Float, bottom: Float) {
        pill.set(left, top, right, bottom)
        positionPieces()
        invalidate()
    }

    /** ¿Cae (x, y) de la vista adentro de la píldora? (durante el rebote la ventana es más grande que ella). */
    fun pillContains(x: Float, y: Float): Boolean = pill.contains(x, y)

    /** Ancho del texto de «listo» tal como se dibuja (para que la isla se ensanche lo justo). */
    fun measureDone(text: String): Int = label.measureText(text).roundToInt()

    private fun layerAlpha(layer: IslandGeometry.State): Float {
        val l = canonical(layer)
        val cur = canonical(current)
        val prev = canonical(from)
        if (morph >= 1f || cur == prev) return if (l == cur) 1f else 0f
        return when (l) {
            cur -> ((morph - 0.35f) / 0.65f).coerceIn(0f, 1f)
            prev -> (1f - morph / 0.4f).coerceIn(0f, 1f)
            else -> 0f
        }
    }

    private fun canonical(s: IslandGeometry.State) = if (s == IslandGeometry.State.THINK) IslandGeometry.State.REC else s

    // ------------------------------------------------------------ piezas

    private var holeSizePx = 0
    private var voiceW = 0
    private var voiceH = 0

    /** Tamaños de las piezas según el estado (una vez por cambio de estado; la posición se pone por cuadro). */
    private fun relayoutPieces() {
        if (recW <= 0 || recH <= 0) {
            positionPieces() // todavía no grabó nunca: las piezas quedan escondidas
            return
        }
        val l = IslandGeometry.recLayout(recW, recH, d, micOnLeft)
        holeSizePx = l.hole.w
        voiceW = l.voice.w
        voiceH = l.voice.h
        voiceView.holeOnLeft = micOnLeft
        sizeOf(holeView, holeSizePx, holeSizePx)
        sizeOf(voiceView, voiceW, voiceH)
        sizeOf(cancelButton, l.cancel.w, l.cancel.h)
        positionPieces()
    }

    /**
     * x en la píldora de AHORA de algo que en una píldora de ancho [layoutW]
     * tiene su centro en [cxInLayout]: lo de la mitad izquierda va pegado al
     * borde izquierdo y lo de la derecha al derecho. Así cada pieza acompaña
     * su borde mientras la píldora crece o se achica (nada salta).
     */
    private fun anchoredCx(cxInLayout: Float, layoutW: Int): Float =
        if (cxInLayout <= layoutW / 2f) pill.left + cxInLayout else pill.right - (layoutW - cxInLayout)

    private fun sizeOf(v: View, w: Int, h: Int) {
        val lp = v.layoutParams as LayoutParams
        if (lp.width != w || lp.height != h) {
            lp.width = w.coerceAtLeast(1)
            lp.height = h.coerceAtLeast(1)
            v.layoutParams = lp
        }
    }

    /** Pone cada pieza donde va, relativa al CENTRO de la píldora (así acompaña el rebote sin salirse). */
    private fun positionPieces() {
        val a = layerAlpha(IslandGeometry.State.REC)
        val on = a > 0f && recW > 0 && recH > 0
        if (on) {
            val l = IslandGeometry.recLayout(recW, recH, d, micOnLeft)
            val cy = pill.centerY() - recH / 2f
            // Agujero y ✕ pegados a su borde; la franja de símbolos, al centro.
            holeView.translationX = anchoredCx(l.hole.x + l.hole.w / 2f, recW) - l.hole.w / 2f
            holeView.translationY = cy + l.hole.y
            voiceView.translationX = pill.centerX() - recW / 2f + l.voice.x
            voiceView.translationY = cy + l.voice.y
            cancelButton.translationX = anchoredCx(l.cancel.x + l.cancel.w / 2f, recW) - l.cancel.w / 2f
            cancelButton.translationY = cy + l.cancel.y
        }
        // La ✕ es solo de «grabando» (pensando no se cancela desde acá).
        val cancelOn = on && (current == IslandGeometry.State.REC ||
            (from == IslandGeometry.State.REC && canonical(current) != IslandGeometry.State.REC))
        setPiece(holeView, on, a)
        setPiece(voiceView, on, a)
        setPiece(cancelButton, cancelOn, a)
        cancelButton.isClickable = current == IslandGeometry.State.REC
        // En reposo los botones son las mitades de la píldora; «listo» solo informa.
        holeView.isClickable = current == IslandGeometry.State.REC
    }

    private fun setPiece(v: View, on: Boolean, alpha: Float) {
        val vis = if (on) VISIBLE else GONE
        if (v.visibility != vis) v.visibility = vis
        v.alpha = if (on) alpha else 0f
    }

    private fun updateDescriptions() {
        holeView.contentDescription = when (current) {
            IslandGeometry.State.REC -> "Terminar dictado"
            IslandGeometry.State.THINK -> "Transcribiendo"
            else -> null
        }
        cancelButton.contentDescription = "Cancelar dictado"
        contentDescription = when (current) {
            IslandGeometry.State.IDLE -> idleDescription()
            IslandGeometry.State.REC -> "Grabando. Tocá para terminar"
            IslandGeometry.State.THINK -> "Transcribiendo"
            IslandGeometry.State.DONE -> doneText.ifEmpty { "Listo" }
        }
    }

    private fun idleDescription(): String = when {
        hasMic && hasPointer -> "Isla de VoiceBubble. Tocá el lado del círculo para dictar o el lado de la flecha para abrir el puntero"
        hasMic -> "Isla de VoiceBubble. Tocá para dictar"
        hasPointer -> "Isla de VoiceBubble. Tocá para abrir el puntero"
        else -> "Isla de VoiceBubble"
    }

    // ------------------------------------------------------------ dibujo

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (pill.width() < 2f || pill.height() < 2f) return
        val r = pill.height() / 2f
        // Superficie: negra siempre, borde de 1 dp.
        fill.color = palette.islandBg
        canvas.drawRoundRect(pill, r, r, fill)
        stroke.strokeWidth = 1f * d
        stroke.color = palette.islandLine
        box.set(pill.left + 0.5f * d, pill.top + 0.5f * d, pill.right - 0.5f * d, pill.bottom - 0.5f * d)
        canvas.drawRoundRect(box, r - 0.5f * d, r - 0.5f * d, stroke)

        val recA = layerAlpha(IslandGeometry.State.REC)
        if (recA > 0f) {
            // Grabando: anillo brasa exterior; pensando, solo la capa.
            if (current == IslandGeometry.State.REC) {
                stroke.strokeWidth = 1.5f * d
                stroke.color = withAlpha(palette.ember, (recA * 255).toInt())
                box.set(pill.left + 0.75f * d, pill.top + 0.75f * d, pill.right - 0.75f * d, pill.bottom - 0.75f * d)
                canvas.drawRoundRect(box, r - 0.75f * d, r - 0.75f * d, stroke)
            }
            drawTimer(canvas, (recA * 255).toInt())
        }
        val idleA = layerAlpha(IslandGeometry.State.IDLE)
        if (idleA > 0f) drawIdle(canvas, (idleA * 255).toInt())
        val doneA = layerAlpha(IslandGeometry.State.DONE)
        if (doneA > 0f) drawDone(canvas, (doneA * 255).toInt())
    }

    /** Reposo: agujero chico con anillo brasa de un lado, glifo del puntero del otro. */
    private fun drawIdle(canvas: Canvas, a: Int) {
        // Medida de la píldora de AHORA: el agujero y la flecha acompañan los bordes
        // mientras crece o se achica (antes saltaban a la medida final).
        val l = IslandGeometry.idleLayout(pill.width().roundToInt(), pill.height().roundToInt(), d, micOnLeft)
        val ox = pill.left
        val oy = pill.top
        val dotR = IslandGeometry.IDLE_DOT_DP * d / 2f
        fill.color = withAlpha(palette.hole, a)
        canvas.drawCircle(ox + l.dotCx, oy + l.cy, dotR, fill)
        stroke.strokeWidth = 1.5f * d
        stroke.color = withAlpha(palette.ember, a)
        canvas.drawCircle(ox + l.dotCx, oy + l.cy, dotR - 0.75f * d, stroke)
        if (hasPointer) {
            val color = if (pointerActive) withAlpha(palette.ember, a) else withAlpha(palette.islandFg, (a * 0.55f).toInt())
            DockIcons.drawPointer(canvas, ox + l.pointerCx, oy + l.cy, IslandGeometry.IDLE_POINTER_DP * d * 1.15f, color, icon)
        }
    }

    private fun drawTimer(canvas: Canvas, a: Int) {
        if (recW <= 0 || recH <= 0) return
        val l = IslandGeometry.recLayout(recW, recH, d, micOnLeft)
        timerPaint.color = withAlpha(palette.onHole, a)
        val base = pill.centerY() - (timerPaint.descent() + timerPaint.ascent()) / 2f
        canvas.drawText(timerText, anchoredCx(l.timerCenterX.toFloat(), recW), base, timerPaint)
    }

    /** «Listo»: ✓ en destello + frase corta («Pegado», «Copiado»…); con error, un «!» en su lugar. */
    private fun drawDone(canvas: Canvas, a: Int) {
        val textW = label.measureText(doneText)
        val check = IslandGeometry.DONE_CHECK_DP * d
        val gap = IslandGeometry.DONE_GAP_DP * d
        val total = check + (if (doneText.isEmpty()) 0f else gap + textW)
        val cx = pill.centerX()
        val cy = pill.centerY()
        val left = cx - total / 2f
        stroke.strokeWidth = 2.4f * d
        stroke.color = withAlpha(palette.hot, a)
        val k = check / 24f
        path.reset()
        if (doneIsError) {
            path.moveTo(left + 12f * k, cy - 6.5f * k)
            path.lineTo(left + 12f * k, cy + 1.5f * k)
            path.moveTo(left + 12f * k, cy + 6f * k)
            path.lineTo(left + 12f * k, cy + 6.1f * k)
        } else {
            path.moveTo(left + 5f * k, cy + 0.5f * k)
            path.lineTo(left + 9.5f * k, cy + 5f * k)
            path.lineTo(left + 19f * k, cy - 4.5f * k)
        }
        canvas.drawPath(path, stroke)
        if (doneText.isNotEmpty()) {
            label.color = withAlpha(palette.onHole, a)
            val base = cy - (label.descent() + label.ascent()) / 2f
            canvas.drawText(doneText, left + check + gap, base, label)
        }
    }

    // ------------------------------------------------------------ botones

    /** ✕ de cancelar: sin fondo, trazo 2.2 en on-hole; la zona táctil es más grande que el dibujo. */
    private class CancelButton(context: Context, private val palette: Palette) : View(context) {
        private val d = resources.displayMetrics.density
        private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 2.2f * d
        }

        init {
            isClickable = true
            isFocusable = true
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width / 2f
            val cy = height / 2f
            val e = 5.5f * d
            ink.color = if (isPressed) palette.hot else palette.onHole
            canvas.drawLine(cx - e, cy - e, cx + e, cy + e, ink)
            canvas.drawLine(cx + e, cy - e, cx - e, cy + e, ink)
        }

        override fun setPressed(pressed: Boolean) {
            super.setPressed(pressed)
            invalidate()
        }
    }
}
