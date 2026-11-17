package com.royleguiza.voicebubble.puntero

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.WindowManager

/**
 * Sesión del trackpad dentro del servicio: abre y cierra el puntero y el panel
 * (ventanas de Accesibilidad), traduce lo que pasa en el pad a gestos del
 * servicio, maneja el arrastre en dos pasos y el cierre automático, y le avisa
 * a VoiceBubble si está abierto ([PointerProtocol.ACTION_TRACKPAD_STATE]).
 *
 * Todo en el hilo principal. Nada queda corriendo al cerrar: [destroy] saca
 * las ventanas, los temporizadores y los receptores.
 */
internal class TrackpadController(private val service: PunteroService) : TrackpadPanel.Host {

    private companion object {
        /**
         * Margen para que Android aplique «dejar pasar toques» al panel antes
         * del gesto: el cambio pasa por la ventana y el sistema (≈ 3 cuadros).
         */
        const val PASS_LEAD_MS = 120L
        const val PASS_TAIL_MS = 140L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val screen = ScreenProbe(service, windowManager)
    private val palette = Palette(service)
    private val prefs = DockPrefs(service)

    private var config: PointerProtocol.TrackpadConfig? = null
    private var pointer: PointerOverlay? = null
    private var panel: TrackpadPanel? = null
    private var lastPointer: Pair<Float, Float>? = null
    private var announced = false

    // Arrastre en dos pasos: botón activo y, tras el primer toque, el origen.
    private var dragOn = false
    private var dragOrigin: Pair<Float, Float>? = null

    private val idleClose = Runnable { close() }
    private val restorePanel = Runnable { panel?.setPassThrough(false) }

    val isOpen: Boolean get() = panel != null

    // --------------------------------------------------------------- ciclo

    /** Abre el trackpad (o lo vuelve a abrir en otro lugar si ya estaba). */
    fun open(cfg: PointerProtocol.TrackpadConfig) {
        releaseWindows()
        config = cfg
        palette.reload()
        val ptr = PointerOverlay(service, windowManager, screen).apply {
            sensitivity = cfg.sensitivity
            accelCurve = cfg.accel
            pointerStyle = cfg.style
        }
        val last = lastPointer
        if (!ptr.show(last?.first, last?.second)) {
            ptr.destroy()
            announce(false)
            return
        }
        val p = TrackpadPanel(service, windowManager, screen, palette, cfg, this, prefs.trackpadPlacement())
        if (!p.show()) {
            p.release()
            ptr.destroy()
            announce(false)
            return
        }
        pointer = ptr
        panel = p
        announce(true)
        updateGhost()
        startIdle()
    }

    /** Cierra con animación. VoiceBubble se entera enseguida (la burbuja vuelve). */
    fun close() {
        val p = panel ?: return
        cancelIdle()
        resetDrag()
        pointer?.hide()
        announce(false)
        // Si mientras tanto lo reabren, el cierre viejo no debe llevarse el nuevo.
        p.dismiss { if (panel === p) releaseWindows() }
    }

    /** Fin del servicio (o de la vinculación): todo afuera, sin animar. */
    fun destroy() {
        handler.removeCallbacksAndMessages(null)
        releaseWindows()
        announce(false)
    }

    private fun releaseWindows() {
        handler.removeCallbacks(idleClose)
        handler.removeCallbacks(restorePanel)
        resetDrag()
        pointer?.let { lastPointer = it.getPosition() }
        panel?.release()
        panel = null
        pointer?.destroy()
        pointer = null
    }

    private fun announce(open: Boolean) {
        if (announced == open) return
        announced = open
        service.sendTrackpadState(open)
    }

    /** Giró el teléfono o cambió el tamaño de pantalla (o el tema). */
    fun onConfigurationChanged() {
        palette.reload()
        // Los puntos del arrastre dejan de valer con otra pantalla.
        if (dragOrigin != null) resetDrag()
        pointer?.onScreenChanged()
        panel?.onThemeChanged()
        panel?.onScreenChanged()
        updateGhost()
    }

    // --------------------------------------------------------- cierre solo

    /** Cierre automático al soltar (`auto_return`; 0 = queda abierto). */
    private fun startIdle() {
        handler.removeCallbacks(idleClose)
        val ms = (config?.autoReturnS ?: 0) * 1000L
        // Con el arrastre a medias no se cierra solo: se perdería lo agarrado.
        if (ms <= 0L || dragOn) return
        panel?.startCountdown(ms)
        handler.postDelayed(idleClose, ms)
    }

    private fun cancelIdle() {
        handler.removeCallbacks(idleClose)
        panel?.cancelCountdown()
    }

    override fun onPanelTouch(down: Boolean) {
        if (down) cancelIdle() else startIdle()
    }

    override fun onCloseRequested() = close()

    /** La persona dejó la ventana libre en otro lugar o de otro tamaño: se recuerda para la próxima. */
    override fun onPlacementChanged(bounds: TrackpadGeometry.Bounds) {
        val (sw, sh) = screen.size()
        prefs.saveTrackpadPlacement(TrackpadGeometry.toPlacement(bounds, sw, sh, service.resources.displayMetrics.density))
    }

    // -------------------------------------------------------------- gestos

    override fun onMove(dx: Float, dy: Float) {
        pointer?.moveBy(dx, dy)
        updateGhost()
    }

    override fun onTap() {
        if (dragOn) {
            dragTouch()
            return
        }
        val ptr = pointer ?: return
        ptr.triggerClickFeedback()
        val (x, y) = ptr.getPosition()
        gestureAt(x, y, PointerProtocol.TAP_MS) { service.press(x, y, PointerProtocol.TAP_MS) }
    }

    override fun onLongPressArmed() {
        if (!dragOn) pointer?.triggerClickFeedback(long = true)
    }

    override fun onLongPress() {
        if (dragOn) {
            dragTouch()
            return
        }
        val (x, y) = pointer?.getPosition() ?: return
        gestureAt(x, y, PointerProtocol.LONG_PRESS_MS) { service.press(x, y, PointerProtocol.LONG_PRESS_MS) }
    }

    override fun onScroll(gestureDy: Float) {
        val (x, y) = pointer?.getPosition() ?: return
        // En tramos de hasta MAX_SCROLL_PX: la cola del servicio los encadena.
        val chunks = PointerProtocol.scrollChunks(gestureDy)
        if (chunks.isEmpty()) return
        gestureAt(x, y, chunks.size * (PointerProtocol.SCROLL_MS + 60L)) {
            for (chunk in chunks) service.scrollBy(x, y, chunk)
        }
    }

    override fun onSystemAction(globalAction: Int) {
        service.globalAction(globalAction)
    }

    /**
     * Despacha un gesto que empieza en (x, y). Si ahí está el propio panel, lo
     * deja pasar toques mientras dura el gesto (y un poco antes): si no, el
     * gesto caería sobre el panel en vez de sobre lo que hay debajo. Solo
     * importa dónde APOYA el gesto, no por dónde pasa después.
     */
    private fun gestureAt(x: Float, y: Float, durationMs: Long, run: () -> Unit) {
        val p = panel
        if (p == null || !p.bounds.contains(x, y, slop = 1f)) {
            run()
            return
        }
        p.setPassThrough(true)
        handler.removeCallbacks(restorePanel)
        handler.postDelayed({ run() }, PASS_LEAD_MS)
        handler.postDelayed(restorePanel, PASS_LEAD_MS + durationMs + PASS_TAIL_MS)
    }

    /** El panel casi transparente cuando el puntero está encima (el gesto igual pasa). */
    private fun updateGhost() {
        val p = panel ?: return
        val (x, y) = pointer?.getPosition() ?: return
        p.setGhost(p.bounds.contains(x, y))
    }

    // ------------------------------------------------------------ arrastre

    /** Botón «Arrastrar»: activa el modo; tocarlo de nuevo lo cancela. */
    override fun onDragButton() {
        if (dragOn) {
            resetDrag()
            startIdle()
            return
        }
        dragOn = true
        cancelIdle()
        panel?.setDragActive(true, service.getString(R.string.ptr_drag_hint_grab))
    }

    /** Un toque en el pad con el arrastre activo: el primero agarra, el segundo suelta. */
    private fun dragTouch() {
        val ptr = pointer ?: return
        val pos = ptr.getPosition()
        ptr.triggerClickFeedback()
        val origin = dragOrigin
        if (origin == null) {
            dragOrigin = pos
            ptr.setOrigin(pos.first, pos.second)
            panel?.setDragHint(service.getString(R.string.ptr_drag_hint_drop))
            return
        }
        val (sw, sh) = screen.size()
        val plan = DragPlan.of(origin.first, origin.second, pos.first, pos.second, sw, sh)
        // El modo se apaga solo; el anillo queda hasta que Android termine el trazo.
        dragOn = false
        dragOrigin = null
        panel?.setDragActive(false, null)
        if (plan == null) {
            ptr.clearOrigin()
        } else {
            gestureAt(plan.startX, plan.startY, plan.totalMs) {
                if (!service.drag(plan) { pointer?.clearOrigin() }) pointer?.clearOrigin()
            }
        }
        startIdle()
    }

    /** Apaga el modo arrastrar y borra el anillo del origen. */
    private fun resetDrag() {
        val was = dragOn || dragOrigin != null
        dragOn = false
        dragOrigin = null
        pointer?.clearOrigin()
        if (was) panel?.setDragActive(false, null)
    }
}
