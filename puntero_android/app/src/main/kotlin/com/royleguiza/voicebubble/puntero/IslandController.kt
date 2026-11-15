package com.royleguiza.voicebubble.puntero

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import android.view.animation.OvershootInterpolator

/**
 * La isla: dueña de su ventana de Accesibilidad, de la máquina de estados
 * (reposo → abierta → grabando → pensando → listo → reposo) y del rebote entre
 * tamaños. Las medidas salen de [IslandGeometry]; el dibujo, de [IslandView].
 *
 * - Una sola ventana. Quieta mide justo lo que la píldora; solo durante el
 *   rebote (≈ 420 ms) es la unión del tamaño viejo y el nuevo, para no tapar
 *   la pantalla de más.
 * - Siempre dentro de la pantalla, sea cual sea su tamaño (ver [IslandGeometry.bounds]).
 * - Con «quitar animaciones» del sistema, los cambios de tamaño son directos.
 * - Todo en el hilo principal. [destroy] saca la ventana, el animador y los
 *   temporizadores: nada queda corriendo.
 */
internal class IslandController(
    service: PunteroService,
    private val windowManager: WindowManager,
    private val screen: ScreenProbe,
    private val palette: Palette,
    private val callbacks: DockCallbacks,
    private val level: HorizonView.LevelSource,
) : DockSurface {

    private val context = service
    private val d = context.resources.displayMetrics.density
    private val handler = Handler(Looper.getMainLooper())

    private val view = IslandView(context, palette, level)
    private var window: DockWindow? = null

    private var cfg: PointerProtocol.DockConfig? = null
    private var state = IslandGeometry.State.IDLE
    private var doneTextW = 0
    private var trackpadOpen = false

    /** Dónde está la píldora ahora, en pantalla (durante el rebote va cambiando). */
    private var shown: IslandGeometry.Rect? = null
    private var morphAnimator: ValueAnimator? = null

    private val autoClose = Runnable { if (state == IslandGeometry.State.OPEN) go(IslandGeometry.State.IDLE) }
    private val backToIdle = Runnable { if (state == IslandGeometry.State.DONE) go(IslandGeometry.State.IDLE) }

    init {
        view.onIdleTap = { onIdleTap() }
        view.onMicTap = { onMicButton() }
        view.onPointerTap = { onPointerButton() }
        view.onCancelTap = { callbacks.onMicCancel() }
        // Toque en la parte transparente de la ventana mientras rebota: que no lo agarre la isla.
        view.setOnTouchListener { _, e -> !view.pillContains(e.x, e.y) }
    }

    // ---------------------------------------------------------- tamaño

    private fun idleW() = cfg?.islandW ?: PointerProtocol.ISLAND_DEFAULT
    private fun idleH() = cfg?.islandH ?: PointerProtocol.ISLAND_DEFAULT

    private fun targetSize(s: IslandGeometry.State): IslandGeometry.Size {
        val (sw, _) = screen.size()
        return IslandGeometry.sizeFor(s, idleW(), idleH(), d, sw, doneTextW)
    }

    private fun targetRect(s: IslandGeometry.State): IslandGeometry.Rect {
        val (sw, sh) = screen.size()
        val c = cfg
        return IslandGeometry.bounds(
            targetSize(s),
            c?.islandX ?: PointerProtocol.ISLAND_DEFAULT,
            c?.islandY ?: PointerProtocol.ISLAND_DEFAULT,
            d, sw, sh,
        )
    }

    // ---------------------------------------------------------- ciclo

    override fun applyConfig(cfg: PointerProtocol.DockConfig) {
        this.cfg = cfg
        view.micOnLeft = cfg.micOnLeft
        view.hasMic = cfg.toolMic
        view.hasPointer = cfg.toolPointer
        // Una sola herramienta: no hay nada que abrir (el toque la ejecuta directo).
        if (state == IslandGeometry.State.OPEN && !IslandGeometry.idleTapOpens(cfg.toolMic, cfg.toolPointer)) {
            state = IslandGeometry.State.IDLE
        }
        if (window == null) {
            val w = DockWindow(windowManager, view, noLimits = true)
            val r = targetRect(state)
            if (!w.show(r.x, r.y, r.w, r.h)) return
            window = w
            shown = r
            view.show(state, IslandGeometry.Size(r.w, r.h))
            view.setPill(0f, 0f, r.w.toFloat(), r.h.toFloat())
            view.setMorph(1f)
        } else {
            settle()
        }
    }

    /** Pone la ventana y la píldora en su lugar de reposo, sin rebote (cambió algo de la configuración o de la pantalla). */
    private fun settle() {
        val w = window ?: return
        morphAnimator?.cancel()
        morphAnimator = null
        val r = targetRect(state)
        w.setBounds(r.x, r.y, r.w, r.h)
        shown = r
        view.show(state, IslandGeometry.Size(r.w, r.h))
        view.setPill(0f, 0f, r.w.toFloat(), r.h.toFloat())
        view.setMorph(1f)
    }

    override fun isDrawing(): Boolean = window?.isShown() == true

    override fun setTrackpadOpen(open: Boolean) {
        trackpadOpen = open
        view.pointerActive = open
    }

    override fun onConfigurationChanged() {
        palette.reload()
        view.refreshPalette()
        settle()
    }

    override fun destroy() {
        handler.removeCallbacksAndMessages(null)
        morphAnimator?.cancel()
        morphAnimator = null
        // El agujero y la voz se detienen solos al desacoplarse; IDLE explícito por si no llegó a mostrarse.
        view.stopAnimations()
        window?.dismiss()
        window = null
        shown = null
    }

    // ---------------------------------------------------------- estados

    /** Pasa a [next] con rebote de tamaño. */
    private fun go(next: IslandGeometry.State) {
        if (window == null) {
            state = next
            return
        }
        handler.removeCallbacks(autoClose)
        handler.removeCallbacks(backToIdle)
        val from = shown ?: targetRect(state)
        state = next
        when (next) {
            IslandGeometry.State.OPEN -> handler.postDelayed(autoClose, IslandGeometry.OPEN_AUTO_CLOSE_MS)
            IslandGeometry.State.DONE -> handler.postDelayed(
                backToIdle,
                if (view.doneIsError) IslandGeometry.ERROR_MS else IslandGeometry.DONE_MS,
            )
            else -> {}
        }
        morph(from, targetRect(next), next)
    }

    private fun morph(from: IslandGeometry.Rect, to: IslandGeometry.Rect, next: IslandGeometry.State) {
        val w = window ?: return
        morphAnimator?.cancel()
        morphAnimator = null
        view.show(next, IslandGeometry.Size(to.w, to.h))
        if (!ValueAnimator.areAnimatorsEnabled() || (from == to)) {
            w.setBounds(to.x, to.y, to.w, to.h)
            shown = to
            view.setPill(0f, 0f, to.w.toFloat(), to.h.toFloat())
            view.setMorph(1f)
            return
        }
        val (sw, sh) = screen.size()
        val win = IslandGeometry.animationWindow(from, to, d, sw, sh)
        w.setBounds(win.x, win.y, win.w, win.h)
        morphAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = IslandGeometry.MORPH_MS
            interpolator = OvershootInterpolator(1.1f)
            addUpdateListener {
                val f = it.animatedValue as Float
                val r = IslandGeometry.lerp(from, to, f)
                shown = r
                view.setPill(
                    (r.x - win.x).toFloat(), (r.y - win.y).toFloat(),
                    (r.right - win.x).toFloat(), (r.bottom - win.y).toFloat(),
                )
                view.setMorph(it.animatedFraction)
            }
            addListener(object : AnimatorListenerAdapter() {
                private var cancelled = false

                override fun onAnimationCancel(animation: Animator) {
                    cancelled = true
                }

                override fun onAnimationEnd(animation: Animator) {
                    if (cancelled) return
                    // Fin del rebote: la ventana vuelve a medir justo lo que la píldora.
                    w.setBounds(to.x, to.y, to.w, to.h)
                    shown = to
                    view.setPill(0f, 0f, to.w.toFloat(), to.h.toFloat())
                    view.setMorph(1f)
                    morphAnimator = null
                }
            })
            start()
        }
    }

    // ---------------------------------------------------------- toques

    private fun tick() {
        try {
            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        } catch (_: Exception) {}
    }

    private fun onIdleTap() {
        val c = cfg ?: return
        if (state != IslandGeometry.State.IDLE) return
        if (IslandGeometry.idleTapOpens(c.toolMic, c.toolPointer)) {
            tick()
            go(IslandGeometry.State.OPEN)
        } else if (c.toolMic) {
            callbacks.onMicTap()
        } else {
            onPointerButton()
        }
    }

    private fun onMicButton() {
        tick()
        callbacks.onMicTap()
    }

    private fun onPointerButton() {
        tick()
        val r = shown ?: targetRect(state)
        val ax = r.x + r.w / 2
        val ay = r.bottom
        // «La isla vuelve al reposo con el puntero encendido».
        go(IslandGeometry.State.IDLE)
        callbacks.onPointerTap(ax, ay)
    }

    // ---------------------------------------------------------- dictado

    override fun setMic(tracker: MicStateTracker, nowMs: Long) {
        when (tracker.state) {
            PointerProtocol.MIC_RECORDING -> {
                view.timerText = MicStateTracker.clock(tracker.elapsedSeconds(nowMs))
                if (state != IslandGeometry.State.REC) go(IslandGeometry.State.REC)
            }
            PointerProtocol.MIC_TRANSCRIBING -> {
                if (state != IslandGeometry.State.THINK) go(IslandGeometry.State.THINK)
            }
            PointerProtocol.MIC_DONE, PointerProtocol.MIC_ERROR -> {
                val error = tracker.state == PointerProtocol.MIC_ERROR
                val text = tracker.message ?: if (error) "No se pudo dictar" else "Pegado"
                if (state == IslandGeometry.State.DONE && view.doneText == text && view.doneIsError == error) return
                view.doneIsError = error
                view.doneText = text
                doneTextW = view.measureDone(text)
                go(IslandGeometry.State.DONE)
            }
            else -> {
                if (state == IslandGeometry.State.REC || state == IslandGeometry.State.THINK) {
                    go(IslandGeometry.State.IDLE)
                }
            }
        }
    }
}
