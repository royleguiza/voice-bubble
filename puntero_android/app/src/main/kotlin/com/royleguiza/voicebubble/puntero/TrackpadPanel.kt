package com.royleguiza.voicebubble.puntero

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import kotlin.math.hypot
import kotlin.math.roundToInt

/**
 * Panel del trackpad: ventana TYPE_ACCESSIBILITY_OVERLAY tocable, por encima
 * de la barra de estado y la cortina de notificaciones. Arriba la agarradera
 * (cierra al tocarla y muestra la cuenta del cierre automático), debajo la
 * fila de sistema (Atrás, Inicio, Recientes, Notificaciones y Arrastrar) y el
 * resto es la superficie del pad ([PadView]). En la ventana libre, la
 * agarradera la mueve y la esquina de abajo a la derecha la agranda o la
 * achica; al soltar, el lugar se guarda ([Host.onPlacementChanged]).
 *
 * Solo dibuja y reparte toques: qué hace cada cosa lo decide [Host]. Dónde
 * queda la ventana lo calcula [TrackpadGeometry].
 */
internal class TrackpadPanel(
    private val context: Context,
    private val windowManager: WindowManager,
    private val screen: ScreenProbe,
    private val palette: Palette,
    private val config: PointerProtocol.TrackpadConfig,
    private val host: Host,
    /** Lugar guardado de la ventana libre (null = junto al ancla). */
    private val placement: TrackpadGeometry.Placement? = null,
) {

    interface Host : PadView.Listener {
        /** Botón de sistema: una de las `AccessibilityService.GLOBAL_ACTION_*`. */
        fun onSystemAction(globalAction: Int)

        /** Se tocó «Arrastrar». */
        fun onDragButton()

        /** La persona cerró el panel (agarradera). */
        fun onCloseRequested()

        /** Algún dedo apoyó / soltó el panel (para pausar el cierre automático). */
        fun onPanelTouch(down: Boolean)

        /** La persona movió o cambió el tamaño de la ventana libre (al soltar). */
        fun onPlacementChanged(bounds: TrackpadGeometry.Bounds)
    }

    private val d = context.resources.displayMetrics.density
    private val mode = config.mode

    private val root = PanelRoot(context)
    private val handle = HandleView(context, palette)
    private val dragButton: SystemButton
    private val pad: PadView
    private var params: WindowManager.LayoutParams? = null
    private var attached = false
    private var extended = false
    private var passThrough = false

    var bounds = TrackpadGeometry.Bounds(0, 0, 0, 0)
        private set

    init {
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(px(10f), px(2f), px(10f), px(10f))
        root.onTouch = { down -> host.onPanelTouch(down) }
        applySurface()

        handle.contentDescription = context.getString(R.string.ptr_panel_close)
        handle.setOnTouchListener(HandleTouch())
        root.addView(handle, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, px(34f)))

        // Fila de sistema: los botones reparten el ancho con espacio entre ellos.
        val row = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL }
        fun add(button: SystemButton, spaceBefore: Boolean) {
            if (spaceBefore) row.addView(View(context), LinearLayout.LayoutParams(0, 1, 1f))
            row.addView(button, LinearLayout.LayoutParams(px(SystemButton.SIZE_DP), px(SystemButton.SIZE_DP)))
        }
        val actions = listOf(
            Triple(SystemButton.Icon.BACK, context.getString(R.string.ptr_panel_back), AccessibilityService.GLOBAL_ACTION_BACK),
            Triple(SystemButton.Icon.HOME, context.getString(R.string.ptr_panel_home), AccessibilityService.GLOBAL_ACTION_HOME),
            Triple(SystemButton.Icon.RECENTS, context.getString(R.string.ptr_panel_recents), AccessibilityService.GLOBAL_ACTION_RECENTS),
            Triple(SystemButton.Icon.NOTIFICATIONS, context.getString(R.string.ptr_panel_notifications), AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS),
        )
        actions.forEachIndexed { i, (icon, label, action) ->
            val b = SystemButton(context, palette, icon, label)
            b.setOnClickListener { host.onSystemAction(action) }
            add(b, spaceBefore = i > 0)
        }
        dragButton = SystemButton(context, palette, SystemButton.Icon.DRAG, context.getString(DRAG_LABEL))
        dragButton.setOnClickListener { host.onDragButton() }
        add(dragButton, spaceBefore = true)
        root.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, px(SystemButton.SIZE_DP)).apply {
            bottomMargin = px(8f)
        })

        // Superficie única del trackpad (sin botones de mouse ni grilla).
        pad = PadView(context, palette, config.naturalScroll, config.haptic, host)
        if (mode == PointerProtocol.MODE_WINDOW) {
            // Ventana libre: esquina para agrandar o achicar, encima del pad.
            val frame = FrameLayout(context)
            frame.addView(pad, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            val grip = ResizeGrip(context, palette)
            grip.contentDescription = context.getString(R.string.ptr_panel_resize)
            grip.setOnTouchListener(GripTouch())
            frame.addView(grip, FrameLayout.LayoutParams(px(ResizeGrip.SIZE_DP), px(ResizeGrip.SIZE_DP)).apply {
                gravity = Gravity.BOTTOM or Gravity.END
            })
            root.addView(frame, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        } else {
            root.addView(pad, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }
    }

    private companion object {
        /** Texto del botón Arrastrar (id de recurso: el nombre se conserva). */
        val DRAG_LABEL = R.string.ptr_panel_drag
    }

    private fun px(dp: Float) = (dp * d).roundToInt()

    /** Superficie sólida (Horizonte, sin desenfoque): surf + borde line de 1 dp. */
    private fun applySurface() {
        root.background = GradientDrawable().apply {
            cornerRadius = 30 * d
            setColor(palette.surf)
            setStroke(px(1f), palette.line)
        }
    }

    // ------------------------------------------------------------- ventana

    /** Agrega la ventana. Devuelve false si Android no la dejó crear. */
    fun show(): Boolean {
        if (attached) return true
        val (sw, sh) = screen.size()
        bounds = TrackpadGeometry.open(mode, sw, sh, screen.bottomInset(), config.anchorX, config.anchorY, extended, d, placement)
        val lp = WindowManager.LayoutParams(
            bounds.w,
            bounds.h,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = bounds.x
            y = bounds.y
            windowAnimations = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                fitInsetsTypes = 0
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        root.alpha = 0f
        root.scaleX = 0.92f
        root.scaleY = 0.92f
        try {
            windowManager.addView(root, lp)
        } catch (_: Exception) {
            return false
        }
        params = lp
        attached = true
        root.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(220L).start()
        return true
    }

    private fun applyBounds(b: TrackpadGeometry.Bounds) {
        bounds = b
        val lp = params ?: return
        lp.x = b.x
        lp.y = b.y
        lp.width = b.w
        lp.height = b.h
        try {
            windowManager.updateViewLayout(root, lp)
        } catch (_: Exception) {}
    }

    /** Cambió la pantalla (giro, otro tamaño): reacomoda la ventana y repinta. */
    fun onScreenChanged() {
        if (!attached) return
        val (sw, sh) = screen.size()
        applyBounds(TrackpadGeometry.refit(bounds, mode, sw, sh, screen.bottomInset(), extended, d))
    }

    /** Cambió el tema claro/oscuro: los colores ya se releyeron, falta repintar. */
    fun onThemeChanged() {
        applySurface()
        root.invalidate()
        handle.invalidate()
        pad.invalidate()
        for (i in 0 until root.childCount) root.getChildAt(i).invalidate()
    }

    private fun setExtended(value: Boolean) {
        if (!attached || extended == value) return
        extended = value
        val (sw, sh) = screen.size()
        applyBounds(TrackpadGeometry.refit(bounds, mode, sw, sh, screen.bottomInset(), extended, d))
    }

    /** Con el puntero encima, el panel se vuelve casi transparente para ver lo de abajo. */
    fun setGhost(on: Boolean) {
        val target = if (on) 0.28f else 1f
        if (root.alpha != target) root.animate().alpha(target).setDuration(120L).start()
    }

    /**
     * Deja pasar los toques mientras sale un gesto del servicio: si no, el
     * gesto caería sobre el propio panel cuando el puntero está debajo de él.
     */
    fun setPassThrough(enabled: Boolean) {
        if (!attached || passThrough == enabled) return
        passThrough = enabled
        val lp = params ?: return
        lp.flags = if (enabled) {
            lp.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        } else {
            lp.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        }
        try {
            windowManager.updateViewLayout(root, lp)
        } catch (_: Exception) {}
    }

    // ------------------------------------------------------------- estado

    fun setDragActive(active: Boolean, hint: String?) {
        dragButton.active = active
        dragButton.contentDescription = if (active) context.getString(R.string.ptr_panel_drag_active) else context.getString(DRAG_LABEL)
        if (hint != null) pad.setHint(hint, sticky = true) else pad.setHint(context.getString(R.string.ptr_pad_default_hint))
    }

    /** Cambia el paso del arrastre sin apagar el botón. */
    fun setDragHint(hint: String) = pad.setHint(hint, sticky = true)

    fun startCountdown(ms: Long) = handle.startCountdown(ms)

    fun cancelCountdown() = handle.cancelCountdown()

    // ------------------------------------------------------------- cierre

    /** Saca la ventana con una animación corta; [onEnd] cuando ya no está. */
    fun dismiss(onEnd: () -> Unit) {
        if (!attached) {
            onEnd()
            return
        }
        root.animate().alpha(0f).scaleX(0.94f).scaleY(0.94f).setDuration(160L).withEndAction {
            release()
            onEnd()
        }.start()
    }

    /** Saca la ventana ya, sin animar, y corta todo lo que quedara corriendo. */
    fun release() {
        handle.cancelCountdown()
        pad.release()
        root.animate().cancel()
        if (attached) {
            attached = false
            try {
                windowManager.removeViewImmediate(root)
            } catch (_: Exception) {}
        }
        params = null
    }

    // ------------------------------------------------------------- toques

    /** Raíz del panel: avisa cuándo hay un dedo apoyado, sea en el pad, un botón o la agarradera. */
    private class PanelRoot(context: Context) : LinearLayout(context) {
        var onTouch: ((Boolean) -> Unit)? = null

        override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
            if (ev.actionMasked == MotionEvent.ACTION_DOWN) onTouch?.invoke(true)
            val handled = super.dispatchTouchEvent(ev)
            if (ev.actionMasked == MotionEvent.ACTION_UP || ev.actionMasked == MotionEvent.ACTION_CANCEL) {
                onTouch?.invoke(false)
            }
            return handled
        }
    }

    /** La línea: toque = cerrar; arrastre = mover (ventana) o bajar/extender (panel). */
    private inner class HandleTouch : View.OnTouchListener {
        private var x0 = 0f
        private var y0 = 0f
        private var wx0 = 0
        private var wy0 = 0
        private var dragged = false

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, e: MotionEvent): Boolean {
            if (!attached) return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX
                    y0 = e.rawY
                    wx0 = bounds.x
                    wy0 = bounds.y
                    dragged = false
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - x0
                    val dy = e.rawY - y0
                    if (!dragged && hypot(dx, dy) > 6 * d) dragged = true
                    if (!dragged) return true
                    if (mode == PointerProtocol.MODE_WINDOW) {
                        val (sw, sh) = screen.size()
                        val (nx, ny) = TrackpadGeometry.clampMove((wx0 + dx).roundToInt(), (wy0 + dy).roundToInt(), bounds, sw, sh)
                        applyBounds(bounds.copy(x = nx, y = ny))
                    } else {
                        root.translationY = dy.coerceAtLeast(0f)
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val dy = e.rawY - y0
                    root.animate().translationY(0f).setDuration(160L).start()
                    if (!dragged) {
                        if (e.actionMasked == MotionEvent.ACTION_UP) host.onCloseRequested()
                        return true
                    }
                    if (mode == PointerProtocol.MODE_WINDOW) {
                        host.onPlacementChanged(bounds)
                    } else {
                        when {
                            dy > 55 * d -> host.onCloseRequested()
                            dy < -25 * d && !extended -> setExtended(true)
                            dy > 20 * d && extended -> setExtended(false)
                        }
                    }
                }
            }
            return true
        }
    }

    /** La esquina: arrastrar = agrandar o achicar (la esquina de arriba a la izquierda queda quieta). */
    private inner class GripTouch : View.OnTouchListener {
        private var x0 = 0f
        private var y0 = 0f
        private var w0 = 0
        private var h0 = 0

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, e: MotionEvent): Boolean {
            if (!attached) return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX
                    y0 = e.rawY
                    w0 = bounds.w
                    h0 = bounds.h
                    v.isPressed = true
                }
                MotionEvent.ACTION_MOVE -> {
                    val (sw, sh) = screen.size()
                    val nw = (w0 + e.rawX - x0).roundToInt()
                    val nh = (h0 + e.rawY - y0).roundToInt()
                    val b = TrackpadGeometry.resize(bounds, nw, nh, sw, sh, screen.bottomInset(), d)
                    if (b != bounds) applyBounds(b)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.isPressed = false
                    if (bounds.w != w0 || bounds.h != h0) host.onPlacementChanged(bounds)
                }
            }
            return true
        }
    }
}
