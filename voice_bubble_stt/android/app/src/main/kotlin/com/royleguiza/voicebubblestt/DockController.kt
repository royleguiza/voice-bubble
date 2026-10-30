package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import kotlin.math.hypot
import kotlin.math.roundToInt

/**
 * Barra flotante: un solo objeto con dos formas (ver [DockGeometry]).
 *
 * - EDGE: lengüeta en el borde. Toque → se abre con las herramientas.
 *   Deslizar arriba/abajo → la ubica. Arrastrar hacia el centro → burbuja.
 * - BUBBLE: burbuja libre. Toque → con una herramienta la usa (la burbuja de
 *   siempre: tocar y dictar); con varias abre el abanico. Soltarla contra un
 *   borde → barra.
 * - Toque largo en reposo → historial (si está activado en Ajustes).
 *
 * La posición vive en prefs nativas (vb_dock_state); la forma elegida se
 * escribe también en flutter.dock_form para que Ajustes la muestre.
 */
@SuppressLint("ClickableViewAccessibility")
internal class DockController(
    private val context: Context,
    private val callbacks: Callbacks,
) {

    interface Callbacks {
        fun onMicTap()
        fun onPointerTap(anchorX: Int, anchorY: Int)
        /** Pedido de historial anclado en (x, y, size). Devuelve true si se mostró. */
        fun onHistoryRequested(x: Int, y: Int, size: Int): Boolean
    }

    companion object {
        const val STATE_PREFS = "vb_dock_state"
        const val FLUTTER_PREFS = "FlutterSharedPreferences"
        const val PREF_FORM = "flutter.dock_form"
        const val PREF_TOOL_MIC = "flutter.dock_tool_mic"
        const val PREF_TOOL_POINTER = "flutter.dock_tool_pointer"
        private const val LONG_PRESS_MS = 500L
        private const val OPEN_MS = 320L
        private const val CLOSE_MS = 240L
        private const val ARC_OUTSIDE_GRACE_MS = 300L
    }

    private val d = context.resources.displayMetrics.density
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val slop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()
    private val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
    private val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    private var form = DockGeometry.Form.EDGE
    private var side = DockGeometry.Side.RIGHT
    private var centerY = 0f
    private var bubbleX = 0f
    private var bubbleY = 0f
    private var tools = listOf(DockGeometry.Tool.MIC)
    private var dictationState = "idle"
    private var hidden = false

    /** Con el trackpad abierto la burbuja se esconde (la barra del borde queda). */
    private var trackpadOpen = false

    private var openFraction = 0f
    private var expanded = false
    private var openAnimator: ValueAnimator? = null

    private val edgeView = EdgeView(context)
    private val bubbleView = BubbleView(context)
    private val bubbleSize = (DockGeometry.BUBBLE_DP * d).roundToInt()
    private val arcSize = (DockGeometry.ARC_TOOL_DP * d).roundToInt()
    private var edgeWindow: GlassWindow? = null
    private var bubbleWindow: GlassWindow? = null
    private val arcWindows = mutableListOf<Pair<GlassWindow, ToolOrbView>>()
    private var arcOpen = false
    private var arcToolPressed = false

    private val edgeIdle = Runnable { if (form == DockGeometry.Form.EDGE && dictationState == "idle") collapse() }
    private val arcIdle = Runnable { closeArc() }
    private val arcOutside = Runnable { if (!arcToolPressed) closeArc() }

    // ---------------------------------------------------------------- ciclo

    fun start() {
        readToolPrefs()
        form = DockGeometry.Form.fromPref(flutterPrefs.getString(PREF_FORM, null))
        val (sw, sh) = screenSize()
        side = if (state.getString("side", "right") == "left") DockGeometry.Side.LEFT else DockGeometry.Side.RIGHT
        centerY = state.getFloat("center_y_frac", 0.45f) * sh
        bubbleX = state.getFloat("bubble_x_frac", 0.8f) * sw
        bubbleY = state.getFloat("bubble_y_frac", 0.45f) * sh

        edgeWindow = GlassWindow(context, edgeView, cornerRadiusPx = null)
        bubbleWindow = GlassWindow(context, bubbleView, cornerRadiusPx = bubbleSize / 2f) { blur ->
            bubbleView.frosted = !blur
        }
        edgeView.setOnTouchListener(EdgeTouch())
        bubbleView.setOnTouchListener(BubbleTouch())
        bubbleWindow?.onOutsideTouch = {
            // Gracia: si el toque fue sobre una herramienta del abanico, su
            // ACTION_UP llega después y la usa antes de cerrar.
            if (arcOpen) {
                handler.removeCallbacks(arcOutside)
                handler.postDelayed(arcOutside, ARC_OUTSIDE_GRACE_MS)
            }
        }
        edgeView.contentDescription = "Barra flotante de VoiceBubble"
        bubbleView.contentDescription = "Burbuja de VoiceBubble"
        applyForm()
    }

    /** Ajustes cambió herramientas o forma. */
    fun reloadPrefs() {
        readToolPrefs()
        val wanted = DockGeometry.Form.fromPref(flutterPrefs.getString(PREF_FORM, null))
        if (wanted != form) {
            convertForm(wanted)
        } else {
            applyForm()
        }
    }

    fun setDictationState(value: String) {
        dictationState = value
        edgeView.dictationState = value
        bubbleView.dictationState = value
        if (value != "idle") {
            handler.removeCallbacks(edgeIdle)
            closeArc()
            if (form == DockGeometry.Form.EDGE && !expanded) expand()
        } else if (form == DockGeometry.Form.EDGE && expanded) {
            restartEdgeIdle()
        }
    }

    /** Ocultar mientras está abierto el historial. */
    fun setHidden(value: Boolean) {
        hidden = value
        closeArc()
        edgeWindow?.setVisible(!value && form == DockGeometry.Form.EDGE)
        bubbleWindow?.setVisible(!value && !trackpadOpen && form == DockGeometry.Form.BUBBLE)
    }

    fun setTrackpadOpen(open: Boolean) {
        if (trackpadOpen == open) return
        trackpadOpen = open
        if (open) closeArc()
        bubbleWindow?.setVisible(!hidden && !open && form == DockGeometry.Form.BUBBLE)
    }

    fun onConfigurationChanged() {
        edgeView.refreshPalette()
        bubbleView.refreshPalette()
        edgeWindow?.refreshTheme()
        bubbleWindow?.refreshTheme()
        closeArc()
        applyForm()
    }

    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        openAnimator?.cancel()
        closeArc()
        edgeWindow?.dismiss()
        bubbleWindow?.dismiss()
        edgeWindow = null
        bubbleWindow = null
    }

    // ------------------------------------------------------------ pantalla

    private fun screenSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val b = wm.currentWindowMetrics.bounds
                if (b.width() > 0 && b.height() > 0) return Pair(b.width(), b.height())
            } catch (_: Exception) {}
        }
        val dm = context.resources.displayMetrics
        return Pair(dm.widthPixels, dm.heightPixels)
    }

    private fun topInset(): Float {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val i = wm.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout(),
                )
                if (i.top > 0) return i.top.toFloat()
            } catch (_: Exception) {}
        }
        return 28f * d
    }

    private fun bottomInset(): Float {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val i = wm.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars())
                if (i.bottom > 0) return i.bottom.toFloat()
            } catch (_: Exception) {}
        }
        return 48f * d
    }

    private fun readToolPrefs() {
        val mic = try { flutterPrefs.getBoolean(PREF_TOOL_MIC, true) } catch (_: Exception) { true }
        val pointer = try { flutterPrefs.getBoolean(PREF_TOOL_POINTER, false) } catch (_: Exception) { false }
        tools = DockGeometry.tools(mic, pointer)
        edgeView.tools = tools
        bubbleView.tools = tools
    }

    private fun expandedShape() = DockGeometry.expanded(d, tools.size)

    private fun clampCenter(y: Float): Float {
        val (_, sh) = screenSize()
        val half = DockGeometry.windowHeight(expandedShape()) / 2f
        return DockGeometry.clampCenterY(y, sh.toFloat(), topInset(), bottomInset(), half)
    }

    private fun clampBubblePos() {
        val (sw, sh) = screenSize()
        val (x, y) = DockGeometry.clampBubble(
            bubbleX, bubbleY, bubbleSize.toFloat(), sw.toFloat(), sh.toFloat(), topInset(), bottomInset(),
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
            edgeWindow?.setVisible(!hidden)
        } else {
            edgeWindow?.let { if (it.isShown()) it.setVisible(false) }
            expanded = false
            openFraction = 0f
            clampBubblePos()
            showBubbleAt(bubbleX, bubbleY)
            bubbleWindow?.setVisible(!hidden && !trackpadOpen)
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
        expanded = false
        applyForm()
        persist()
    }

    private fun persist() {
        val (sw, sh) = screenSize()
        state.edit()
            .putString("side", if (side == DockGeometry.Side.LEFT) "left" else "right")
            .putFloat("center_y_frac", centerY / sh)
            .putFloat("bubble_x_frac", bubbleX / sw)
            .putFloat("bubble_y_frac", bubbleY / sh)
            .apply()
        if (flutterPrefs.getString(PREF_FORM, null) != form.pref) {
            flutterPrefs.edit().putString(PREF_FORM, form.pref).apply()
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
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    end()
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

    private fun requestHistory(): Boolean {
        if (dictationState != "idle") return false
        val (ax, ay) = anchorCenter()
        val size = bubbleSize
        return callbacks.onHistoryRequested(ax - size / 2, ay - size / 2, size)
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
            val orb = ToolOrbView(context, tool)
            orb.contentDescription = if (tool == DockGeometry.Tool.MIC) "Dictar" else "Abrir trackpad"
            val win = GlassWindow(context, orb, cornerRadiusPx = arcSize / 2f) { blur -> orb.frosted = !blur }
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
            win.show((tx - arcSize / 2f).roundToInt(), (ty - arcSize / 2f).roundToInt(), arcSize, arcSize)
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
            if (!moved && requestHistory()) longFired = true
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
            if (!moved && requestHistory()) longFired = true
        }

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            when (e.actionMasked) {
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
                    when (DockGeometry.tapAction(tools, dictationState == "recording")) {
                        DockGeometry.TapAction.STOP_RECORDING -> callbacks.onMicTap()
                        DockGeometry.TapAction.RUN_ONLY_TOOL -> runTool(tools.first())
                        DockGeometry.TapAction.TOGGLE_TOOLS -> if (arcOpen) closeArc() else openArc()
                    }
                }
            }
            return true
        }
    }
}
