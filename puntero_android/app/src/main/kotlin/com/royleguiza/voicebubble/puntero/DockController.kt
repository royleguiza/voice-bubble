package com.royleguiza.voicebubble.puntero

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import kotlin.math.hypot
import kotlin.math.roundToInt

/**
 * Barra flotante en el complemento (port de `DockController` de VoiceBubble):
 * un solo objeto con dos formas (ver [DockGeometry]); la tercera, la isla, es
 * de [IslandController]. Dibuja con ventanas de Accesibilidad ([DockWindow]):
 * por eso no desaparece cuando Android cierra VoiceBubble.
 *
 * - EDGE: lengüeta en el borde. Toque → se abre con las herramientas.
 *   Deslizar arriba/abajo → la ubica. Arrastrar hacia el centro → burbuja.
 * - BUBBLE: burbuja libre. Toque → con una herramienta la usa (la burbuja de
 *   siempre: tocar y dictar); con varias abre el abanico. Soltarla contra un
 *   borde → barra.
 *
 * Diferencias con el host: el historial (toque largo) lo muestra VoiceBubble
 * ([DockCallbacks.onHistoryRequested], fase 4), el dictado lo hace VoiceBubble sin Flutter ([DockCallbacks.onMicTap]), la
 * posición se guarda en [DockPrefs] y la forma que elige la persona con el
 * dedo se le avisa a VoiceBubble ([DockCallbacks.onFormChanged]) para que
 * Ajustes la muestre.
 *
 * Todo en el hilo principal. [destroy] saca ventanas, animadores y temporizadores.
 */
@SuppressLint("ClickableViewAccessibility")
internal class DockController(
    private val context: PunteroService,
    private val windowManager: WindowManager,
    private val screen: ScreenProbe,
    private val palette: Palette,
    private val prefs: DockPrefs,
    private val callbacks: DockCallbacks,
    level: HorizonView.LevelSource,
) : DockSurface {

    companion object {
        const val OPEN_MS = 320L
        const val CLOSE_MS = 240L
        const val ARC_OUTSIDE_GRACE_MS = 300L
        const val LONG_PRESS_MS = 500L

        // Ids de las acciones de TalkBack (el byte alto distinto de cero los separa de los estándar).
        const val ACTION_DICTATE = 0x7E000001
        const val ACTION_POINTER = 0x7E000002
    }

    private val d = context.resources.displayMetrics.density
    private val handler = Handler(Looper.getMainLooper())
    private val slop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()

    private var started = false
    private var form = DockGeometry.Form.EDGE
    private var announcedForm = DockGeometry.Form.EDGE.pref
    private var side = DockGeometry.Side.RIGHT
    private var centerY = 0f
    private var bubbleX = 0f
    private var bubbleY = 0f
    private var tools = listOf(DockGeometry.Tool.MIC)
    private var dictationState = "idle"

    /** Con el trackpad abierto la burbuja se esconde (la barra del borde queda). */
    private var trackpadOpen = false

    private var openFraction = 0f
    private var expanded = false
    private var openAnimator: ValueAnimator? = null

    private val edgeView = EdgeView(context, palette, level)
    private val bubbleView = BubbleView(context, palette, level)
    private val bubbleSize = (DockGeometry.BUBBLE_DP * d).roundToInt()
    private val arcSize = (DockGeometry.ARC_TOOL_DP * d).roundToInt()
    private var edgeWindow: DockWindow? = null
    private var bubbleWindow: DockWindow? = null
    private val arcWindows = mutableListOf<Pair<DockWindow, ToolOrbView>>()
    private var arcOpen = false
    private var arcToolPressed = false

    private val edgeIdle = Runnable { if (form == DockGeometry.Form.EDGE && dictationState == "idle") collapse() }
    private val arcIdle = Runnable { closeArc() }
    private val arcOutside = Runnable { if (!arcToolPressed) closeArc() }

    // ---------------------------------------------------------------- ciclo

    /** Primera configuración: crea las ventanas. Las siguientes cambian la barra en vivo. */
    override fun applyConfig(cfg: PointerProtocol.DockConfig) {
        tools = DockGeometry.tools(cfg.toolMic, cfg.toolPointer)
        edgeView.tools = tools
        bubbleView.tools = tools
        val wanted = DockGeometry.Form.fromPref(cfg.form).let {
            // La isla no es de este controlador: [DockManager] no debería habérsela pasado.
            if (it == DockGeometry.Form.ISLAND) DockGeometry.Form.EDGE else it
        }
        if (!started) {
            start(wanted)
            return
        }
        if (wanted != form) {
            convertForm(wanted)
        } else {
            applyForm()
        }
    }

    private fun start(initial: DockGeometry.Form) {
        started = true
        form = initial
        announcedForm = initial.pref
        val (sw, sh) = screen.size()
        side = prefs.side()
        centerY = prefs.centerYFrac() * sh
        bubbleX = prefs.bubbleXFrac() * sw
        bubbleY = prefs.bubbleYFrac() * sh

        // Superficie sólida (Horizonte): las vistas pintan su fondo; sin desenfoque.
        edgeWindow = DockWindow(windowManager, edgeView)
        bubbleWindow = DockWindow(windowManager, bubbleView)
        edgeView.setOnTouchListener(EdgeTouch())
        bubbleView.setOnTouchListener(BubbleTouch())
        edgeView.contentDescription = context.getString(R.string.ptr_dock_bar_desc)
        bubbleView.contentDescription = context.getString(R.string.ptr_dock_bubble_desc)
        installAccessibility(edgeView) { if (expanded) collapse() else expand() }
        installAccessibility(bubbleView) { onBubbleTap() }
        applyForm()
    }

    override fun isDrawing(): Boolean = edgeWindow?.isShown() == true || bubbleWindow?.isShown() == true

    override fun setMic(tracker: MicStateTracker, nowMs: Long) {
        val value = when (tracker.state) {
            PointerProtocol.MIC_RECORDING -> "recording"
            PointerProtocol.MIC_TRANSCRIBING -> "transcribing"
            else -> "idle"
        }
        if (value == dictationState) return
        dictationState = value
        edgeView.dictationState = value
        bubbleView.dictationState = value
        val spoken = when (value) {
            "recording" -> context.getString(R.string.ptr_dock_recording)
            "transcribing" -> context.getString(R.string.ptr_dock_transcribing)
            else -> null
        }
        edgeView.contentDescription = context.getString(R.string.ptr_dock_bar_desc) + (spoken?.let { ". $it" } ?: "")
        bubbleView.contentDescription = context.getString(R.string.ptr_dock_bubble_desc) + (spoken?.let { ". $it" } ?: "")
        if (value != "idle") {
            handler.removeCallbacks(edgeIdle)
            closeArc()
            if (form == DockGeometry.Form.EDGE && !expanded) expand()
        } else if (form == DockGeometry.Form.EDGE && expanded) {
            restartEdgeIdle()
        }
    }

    override fun setVeiled(veiled: Boolean) {
        if (veiled) closeArc()
        edgeWindow?.setVeiled(veiled)
        bubbleWindow?.setVeiled(veiled)
    }

    override fun setTrackpadOpen(open: Boolean) {
        if (trackpadOpen == open) return
        trackpadOpen = open
        edgeView.pointerActive = open
        if (open) closeArc()
        bubbleWindow?.setVisible(!open && form == DockGeometry.Form.BUBBLE)
    }

    override fun onConfigurationChanged() {
        palette.reload()
        edgeView.refreshPalette()
        bubbleView.refreshPalette()
        closeArc()
        if (started) {
            // Giro o cambio de pantalla: la posición se rehace desde lo guardado (fracciones), así al
            // volver a la orientación de antes la barra vuelve a su lugar y no queda donde la recortó el giro.
            val (sw, sh) = screenSize()
            centerY = prefs.centerYFrac() * sh
            bubbleX = prefs.bubbleXFrac() * sw
            bubbleY = prefs.bubbleYFrac() * sh
            applyForm()
        }
    }

    override fun destroy() {
        handler.removeCallbacksAndMessages(null)
        openAnimator?.cancel()
        closeArcNow()
        // La corona se detiene sola al desacoplarse; IDLE explícito por si
        // la ventana no llegó a mostrarse.
        edgeView.horizon.setPhase(HorizonView.Phase.IDLE)
        bubbleView.horizon.setPhase(HorizonView.Phase.IDLE)
        edgeWindow?.dismiss()
        bubbleWindow?.dismiss()
        edgeWindow = null
        bubbleWindow = null
        started = false
    }

    // ------------------------------------------------------------ pantalla

    private fun screenSize(): Pair<Int, Int> = screen.size()

    private fun clampCenter(y: Float): Float {
        val (_, sh) = screenSize()
        val half = DockGeometry.windowHeight(expandedShape()) / 2f
        return DockGeometry.clampCenterY(y, sh.toFloat(), screen.topInset().toFloat(), screen.bottomInset().toFloat(), half)
    }

    private fun expandedShape() = DockGeometry.expanded(d, tools.size)

    private fun clampBubblePos() {
        val (sw, sh) = screenSize()
        val (x, y) = DockGeometry.clampBubble(
            bubbleX, bubbleY, bubbleSize.toFloat(), sw.toFloat(), sh.toFloat(),
            screen.topInset().toFloat(), screen.bottomInset().toFloat(),
        )
        bubbleX = x
        bubbleY = y
    }

    // --------------------------------------------------------------- forma

    private fun applyForm() {
        if (form == DockGeometry.Form.EDGE) {
            bubbleWindow?.let { if (it.isShown()) it.setVisible(false) }
            centerY = clampCenter(centerY)
            edgeView.side = side
            val shape = if (expanded) expandedShape() else DockGeometry.collapsed(d)
            edgeView.shape = shape
            edgeView.openFraction = if (expanded) 1f else 0f
            layoutEdge(shape)
            edgeWindow?.setVisible(true)
        } else {
            edgeWindow?.let { if (it.isShown()) it.setVisible(false) }
            expanded = false
            openFraction = 0f
            clampBubblePos()
            showBubbleAt(bubbleX, bubbleY)
            bubbleWindow?.setVisible(!trackpadOpen)
        }
    }

    private fun layoutEdge(windowShape: DockGeometry.Shape) {
        val win = edgeWindow ?: return
        val (sw, _) = screenSize()
        val w = DockGeometry.windowWidth(windowShape, d).roundToInt()
        val h = DockGeometry.windowHeight(windowShape).roundToInt()
        val x = if (side == DockGeometry.Side.RIGHT) sw - w else 0
        val y = (centerY - h / 2f).roundToInt()
        if (win.isShown()) win.setBounds(x, y, w, h) else win.show(x, y, w, h)
        val ex = DockGeometry.gestureExclusionHeight(h.toFloat(), d).roundToInt()
        win.setGestureExclusion(Rect(0, (h - ex) / 2, w, (h + ex) / 2))
    }

    private fun showBubbleAt(x: Float, y: Float) {
        val win = bubbleWindow ?: return
        if (win.isShown()) {
            win.moveTo(x.roundToInt(), y.roundToInt())
        } else {
            win.show(x.roundToInt(), y.roundToInt(), bubbleSize, bubbleSize)
        }
    }

    /** Cambio de forma desde Ajustes (sin gesto). */
    private fun convertForm(target: DockGeometry.Form) {
        val (sw, _) = screenSize()
        closeArc()
        if (target == DockGeometry.Form.BUBBLE) {
            bubbleX = if (side == DockGeometry.Side.RIGHT) sw - bubbleSize - 16f * d else 16f * d
            bubbleY = centerY - bubbleSize / 2f
        } else {
            side = DockGeometry.nearestSide(bubbleX + bubbleSize / 2f, sw.toFloat())
            centerY = bubbleY + bubbleSize / 2f
        }
        form = target
        // Vino de VoiceBubble: no hace falta contárselo de vuelta.
        announcedForm = target.pref
        expanded = false
        applyForm()
        persist()
    }

    private fun persist() {
        val (sw, sh) = screenSize()
        prefs.savePosition(side, centerY / sh, bubbleX / sw, bubbleY / sh)
        if (announcedForm != form.pref) {
            announcedForm = form.pref
            callbacks.onFormChanged(form.pref)
        }
    }

    // ------------------------------------------------- abrir/cerrar la barra

    private fun expand() {
        if (expanded || form != DockGeometry.Form.EDGE) return
        expanded = true
        layoutEdge(expandedShape())
        animateOpen(1f, OPEN_MS) { }
        tick(edgeView)
        restartEdgeIdle()
    }

    private fun collapse() {
        if (!expanded) return
        if (dictationState != "idle") return
        expanded = false
        handler.removeCallbacks(edgeIdle)
        animateOpen(0f, CLOSE_MS) {
            if (!expanded && form == DockGeometry.Form.EDGE) layoutEdge(DockGeometry.collapsed(d))
        }
    }

    private fun animateOpen(target: Float, duration: Long, end: () -> Unit) {
        openAnimator?.cancel()
        val from = openFraction
        val collapsed = DockGeometry.collapsed(d)
        val open = expandedShape()
        // Sin animaciones del sistema: salta directo al estado final.
        if (!ValueAnimator.areAnimatorsEnabled()) {
            openFraction = target
            edgeView.shape = DockGeometry.lerp(collapsed, open, target.coerceIn(0f, 1f))
            edgeView.openFraction = target
            end()
            return
        }
        openAnimator = ValueAnimator.ofFloat(from, target).apply {
            this.duration = duration
            interpolator = if (target > from) OvershootInterpolator(0.8f) else DecelerateInterpolator()
            addUpdateListener {
                openFraction = it.animatedValue as Float
                // El rebote vive en las herramientas; la forma no pasa de su ventana.
                val t = openFraction.coerceIn(0f, 1f)
                edgeView.shape = DockGeometry.lerp(collapsed, open, t)
                edgeView.openFraction = openFraction
            }
            addListener(object : AnimatorListenerAdapter() {
                private var cancelled = false

                override fun onAnimationCancel(animation: Animator) {
                    cancelled = true
                }

                override fun onAnimationEnd(animation: Animator) {
                    if (!cancelled) end()
                }
            })
            start()
        }
    }

    private fun restartEdgeIdle() {
        handler.removeCallbacks(edgeIdle)
        handler.postDelayed(edgeIdle, DockGeometry.EDGE_IDLE_MS)
    }

    // --------------------------------------------------------- herramientas

    private fun runTool(tool: DockGeometry.Tool) {
        when (tool) {
            DockGeometry.Tool.MIC -> {
                callbacks.onMicTap()
                if (form == DockGeometry.Form.EDGE) restartEdgeIdle()
            }
            DockGeometry.Tool.POINTER -> {
                val (ax, ay) = anchorCenter()
                closeArc()
                if (form == DockGeometry.Form.EDGE && expanded) collapse()
                callbacks.onPointerTap(ax, ay)
            }
        }
    }

    private fun anchorCenter(): Pair<Int, Int> {
        val (sw, _) = screenSize()
        return if (form == DockGeometry.Form.BUBBLE) {
            Pair((bubbleX + bubbleSize / 2f).roundToInt(), (bubbleY + bubbleSize / 2f).roundToInt())
        } else {
            Pair(if (side == DockGeometry.Side.RIGHT) sw - (4 * d).roundToInt() else (4 * d).roundToInt(), centerY.roundToInt())
        }
    }

    /** Toque simple sobre la burbuja (también el «activar» de TalkBack). */
    private fun onBubbleTap() {
        when (DockGeometry.tapAction(tools, dictationState == "recording")) {
            DockGeometry.TapAction.STOP_RECORDING -> callbacks.onMicTap()
            DockGeometry.TapAction.RUN_ONLY_TOOL -> runTool(tools.first())
            DockGeometry.TapAction.TOGGLE_TOOLS -> if (arcOpen) closeArc() else openArc()
        }
    }

    /**
     * TalkBack: la barra y la burbuja son una sola vista (las herramientas no
     * son vistas aparte), así que cada herramienta se ofrece como acción
     * personalizada, y «activar» hace lo mismo que un toque.
     */
    private fun installAccessibility(view: View, onClick: () -> Unit) {
        view.setOnClickListener { onClick() }
        view.accessibilityDelegate = object : View.AccessibilityDelegate() {
            override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
                super.onInitializeAccessibilityNodeInfo(host, info)
                if (tools.contains(DockGeometry.Tool.MIC)) {
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction(ACTION_DICTATE, context.getString(R.string.ptr_dock_dictate)))
                }
                if (tools.contains(DockGeometry.Tool.POINTER)) {
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction(ACTION_POINTER, context.getString(R.string.ptr_dock_open_pointer)))
                }
            }

            override fun performAccessibilityAction(host: View, action: Int, args: Bundle?): Boolean = when (action) {
                ACTION_DICTATE -> { runTool(DockGeometry.Tool.MIC); true }
                ACTION_POINTER -> { runTool(DockGeometry.Tool.POINTER); true }
                else -> super.performAccessibilityAction(host, action, args)
            }
        }
    }

    // ----------------------------------------------------------- abanico

    private fun openArc() {
        if (arcOpen || form != DockGeometry.Form.BUBBLE) return
        val (sw, sh) = screenSize()
        val cx = bubbleX + bubbleSize / 2f
        val cy = bubbleY + bubbleSize / 2f
        val centers = DockGeometry.arcCenters(cx, cy, sw.toFloat(), sh.toFloat(), tools.size, d)
        arcOpen = true
        arcToolPressed = false
        tools.forEachIndexed { i, tool ->
            val (tx, ty) = centers[i]
            val orb = ToolOrbView(context, palette, tool)
            orb.contentDescription = if (tool == DockGeometry.Tool.MIC) context.getString(R.string.ptr_dock_dictate) else context.getString(R.string.ptr_dock_open_pointer)
            val win = DockWindow(windowManager, orb)
            orb.setOnTouchListener { v, e ->
                when (e.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        arcToolPressed = true
                        v.isPressed = true
                    }
                    MotionEvent.ACTION_UP -> {
                        v.isPressed = false
                        runTool(tool)
                        closeArc()
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        v.isPressed = false
                        arcToolPressed = false
                    }
                }
                true
            }
            orb.setOnClickListener {
                // «Activar» de TalkBack (el toque normal lo resuelve el listener de arriba).
                runTool(tool)
                closeArc()
            }
            if (!win.show((tx - arcSize / 2f).roundToInt(), (ty - arcSize / 2f).roundToInt(), arcSize, arcSize)) return@forEachIndexed
            orb.translationX = cx - tx
            orb.translationY = cy - ty
            orb.scaleX = 0.3f
            orb.scaleY = 0.3f
            orb.alpha = 0f
            orb.animate().translationX(0f).translationY(0f).scaleX(1f).scaleY(1f).alpha(1f)
                .setStartDelay(i * 30L).setDuration(280L).setInterpolator(DecelerateInterpolator(2f)).start()
            arcWindows += Pair(win, orb)
        }
        bubbleWindow?.setWatchOutside(true)
        tick(bubbleView)
        handler.removeCallbacks(arcIdle)
        handler.postDelayed(arcIdle, DockGeometry.ARC_IDLE_MS)
    }

    private fun closeArc() {
        handler.removeCallbacks(arcIdle)
        handler.removeCallbacks(arcOutside)
        if (!arcOpen) return
        arcOpen = false
        bubbleWindow?.setWatchOutside(false)
        val closing = arcWindows.toList()
        arcWindows.clear()
        closing.forEach { (win, orb) ->
            orb.animate().alpha(0f).scaleX(0.6f).scaleY(0.6f).setDuration(140L)
                .withEndAction { win.dismiss() }.start()
        }
    }

    /** Cierra el abanico ya, sin animar (al destruir: nada queda pendiente). */
    private fun closeArcNow() {
        handler.removeCallbacks(arcIdle)
        handler.removeCallbacks(arcOutside)
        arcOpen = false
        arcWindows.toList().forEach { (win, orb) ->
            orb.animate().cancel()
            win.dismiss()
        }
        arcWindows.clear()
    }

    private fun tick(v: View) {
        try {
            v.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        } catch (_: Exception) {}
    }

    // ------------------------------------------------------------- gestos

    /** Gesto que empezó en la barra (puede terminar como burbuja). */
    private inner class EdgeTouch : View.OnTouchListener {
        private var x0 = 0f
        private var y0 = 0f
        private var center0 = 0f
        private var moved = false
        private var converted = false
        private var longFired = false
        private val longPress = Runnable {
            if (!moved && requestHistory()) {
                longFired = true
                tick(edgeView)
            }
        }

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX
                    y0 = e.rawY
                    center0 = centerY
                    moved = false
                    converted = false
                    longFired = false
                    handler.removeCallbacks(edgeIdle)
                    if (expanded) edgeView.pressedIndex = toolAt(e.y)
                    handler.postDelayed(longPress, LONG_PRESS_MS)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - x0
                    val dy = e.rawY - y0
                    if (!moved && hypot(dx, dy) > slop) {
                        moved = true
                        handler.removeCallbacks(longPress)
                        edgeView.pressedIndex = -1
                    }
                    if (!moved || longFired) return true
                    if (!converted && DockGeometry.shouldBecomeBubble(side, dx, d)) {
                        converted = true
                        form = DockGeometry.Form.BUBBLE
                        openAnimator?.cancel()
                        expanded = false
                        openFraction = 0f
                        edgeWindow?.setWindowAlpha(0f)
                        bubbleView.lifted = true
                        tick(v)
                    }
                    if (converted) {
                        bubbleX = e.rawX - bubbleSize / 2f
                        bubbleY = e.rawY - bubbleSize / 2f
                        clampBubblePos()
                        showBubbleAt(bubbleX, bubbleY)
                        bubbleWindow?.setVisible(true)
                    } else {
                        centerY = clampCenter(center0 + dy)
                        layoutEdge(if (expanded) expandedShape() else DockGeometry.collapsed(d))
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longPress)
                    val pressed = edgeView.pressedIndex
                    edgeView.pressedIndex = -1
                    if (longFired) return true
                    if (converted) {
                        edgeWindow?.setWindowAlpha(1f)
                        finishBubbleDrag()
                        return true
                    }
                    if (moved) {
                        persist()
                        if (expanded) restartEdgeIdle()
                        return true
                    }
                    if (e.actionMasked == MotionEvent.ACTION_CANCEL) return true
                    if (!expanded) {
                        expand()
                    } else {
                        val i = if (pressed >= 0) pressed else toolAt(e.y)
                        if (i >= 0) runTool(tools[i]) else collapse()
                    }
                }
            }
            return true
        }

        private fun toolAt(localY: Float): Int {
            val shape = expandedShape()
            val top = (edgeView.height - DockGeometry.windowHeight(shape)) / 2f + shape.r
            return DockGeometry.toolIndexAt(localY, top, shape, tools.size, d)
        }
    }

    /** Toque largo: historial (solo en reposo; lo dibuja VoiceBubble). */
    private fun requestHistory(): Boolean {
        if (dictationState != "idle") return false
        val (ax, ay) = anchorCenter()
        val size = bubbleSize
        val asked = callbacks.onHistoryRequested(ax - size / 2, ay - size / 2, size)
        if (asked) {
            closeArc()
            if (form == DockGeometry.Form.EDGE && expanded) collapse()
        }
        return asked
    }

    /** Suelta de la burbuja: contra un borde vuelve a ser barra. */
    private fun finishBubbleDrag() {
        bubbleView.lifted = false
        val (sw, _) = screenSize()
        val snap = DockGeometry.snapSide(bubbleX + bubbleSize / 2f, sw.toFloat(), d)
        if (snap != null) {
            side = snap
            centerY = clampCenter(bubbleY + bubbleSize / 2f)
            form = DockGeometry.Form.EDGE
            expanded = false
            openFraction = 0f
            tick(edgeView)
        } else {
            form = DockGeometry.Form.BUBBLE
        }
        applyForm()
        persist()
    }

    private inner class BubbleTouch : View.OnTouchListener {
        private var x0 = 0f
        private var y0 = 0f
        private var bx0 = 0f
        private var by0 = 0f
        private var moved = false
        private var longFired = false
        private val longPress = Runnable {
            if (!moved && requestHistory()) {
                longFired = true
                tick(bubbleView)
            }
        }

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            when (e.actionMasked) {
                MotionEvent.ACTION_OUTSIDE -> {
                    // Gracia: si el toque fue sobre una herramienta del abanico, su
                    // ACTION_UP llega después y la usa antes de cerrar.
                    if (arcOpen) {
                        handler.removeCallbacks(arcOutside)
                        handler.postDelayed(arcOutside, ARC_OUTSIDE_GRACE_MS)
                    }
                }
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX
                    y0 = e.rawY
                    bx0 = bubbleX
                    by0 = bubbleY
                    moved = false
                    longFired = false
                    handler.postDelayed(longPress, LONG_PRESS_MS)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - x0
                    val dy = e.rawY - y0
                    if (!moved && hypot(dx, dy) > slop) {
                        moved = true
                        handler.removeCallbacks(longPress)
                        closeArc()
                        bubbleView.lifted = true
                    }
                    if (!moved || longFired) return true
                    bubbleX = bx0 + dx
                    bubbleY = by0 + dy
                    clampBubblePos()
                    showBubbleAt(bubbleX, bubbleY)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    handler.removeCallbacks(longPress)
                    if (longFired) return true
                    if (moved) {
                        finishBubbleDrag()
                        return true
                    }
                    if (e.actionMasked == MotionEvent.ACTION_CANCEL) return true
                    onBubbleTap()
                }
            }
            return true
        }
    }
}
