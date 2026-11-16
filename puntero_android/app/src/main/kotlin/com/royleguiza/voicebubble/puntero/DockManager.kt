package com.royleguiza.voicebubble.puntero

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.WindowManager

/**
 * Quién dibuja la barra flotante dentro del servicio: guarda la configuración
 * que manda VoiceBubble (en prefs propias, así la barra vuelve sola tras
 * reiniciar aunque VoiceBubble esté cerrada), elige la superficie según la
 * forma (borde y burbuja = [DockController]; isla = [IslandController]) y la
 * cambia EN VIVO, traduce los toques en pedidos a VoiceBubble ([HostLink]) y le
 * cuenta si está dibujando ([PointerProtocol.ACTION_DOCK_STATE]) para que su
 * barra de respaldo se esconda: nunca se ven dos barras.
 *
 * Reparto del port sin duplicar lógica: la geometría, las prefs, las ventanas
 * y el enlace con el host son piezas únicas compartidas por las tres formas;
 * cada forma solo trae lo suyo (gestos de la barra y la burbuja; estados y
 * rebote de la isla).
 *
 * Fase 3, uso sin VoiceBubble: si la barra de VoiceBubble está apagada (o
 * VoiceBubble no está instalada) y la persona encendió la pestaña propia en la
 * pantalla del complemento, se dibuja la barra del borde (o la burbuja) con
 * SOLO el puntero ([effective]). La barra de VoiceBubble siempre manda.
 *
 * Todo en el hilo principal. [destroy] saca la barra, el receptor lo suelta el
 * servicio y no queda ningún temporizador corriendo.
 */
internal class DockManager(private val service: PunteroService) : DockCallbacks {

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val screen = ScreenProbe(service, windowManager)
    private val palette = Palette(service)
    private val prefs = DockPrefs(service)
    private val tracker = MicStateTracker()

    /** Nivel de voz (0..1) que leen las animaciones, una vez por cuadro. */
    @Volatile
    private var micLevel = 0f
    private val level = HorizonView.LevelSource { micLevel }

    private var config: PointerProtocol.DockConfig = prefs.loadConfig()
    private var surface: DockSurface? = null
    private var surfaceIsIsland = false
    private var trackpadOpen = false

    /** Último valor que le conté a VoiceBubble (null = todavía nada). */
    private var announced: Boolean? = null
    private var trampolineTried = false
    private var destroyed = false

    private val staleCheck = object : Runnable {
        override fun run() {
            val now = SystemClock.uptimeMillis()
            if (tracker.isStale(now)) {
                // El host dejó de contar (murió a medio dictado): reposo, sin quedar «grabando».
                tracker.reset()
                micLevel = 0f
                surface?.setMic(tracker, now)
            } else if (tracker.isBusy) {
                handler.postDelayed(this, PointerProtocol.MIC_STALE_MS / 2)
            }
        }
    }

    // --------------------------------------------------------------- ciclo

    /** El servicio se conectó: dibuja lo último que se guardó y le pide configuración fresca a VoiceBubble. */
    fun start() {
        config = prefs.loadConfig()
        apply(force = false)
        HostLink.hello(service)
    }

    /** DOCK_CONFIG de VoiceBubble: se valida, se guarda y se aplica en vivo. */
    fun onDockConfig(intent: Intent) {
        if (destroyed) return
        val trackpad = PointerProtocol.normalizeTrackpadConfig(
            anchorX = -1,
            anchorY = -1,
            mode = intent.getStringExtra(PointerProtocol.EXTRA_MODE),
            sensitivity = intent.getFloatExtra(PointerProtocol.EXTRA_SENSITIVITY, Float.NaN),
            accel = intent.getStringExtra(PointerProtocol.EXTRA_ACCEL),
            style = intent.getStringExtra(PointerProtocol.EXTRA_STYLE),
            haptic = intent.getStringExtra(PointerProtocol.EXTRA_HAPTIC),
            scrollDir = intent.getStringExtra(PointerProtocol.EXTRA_SCROLL_DIR),
            autoReturnS = intent.getIntExtra(PointerProtocol.EXTRA_AUTO_RETURN, 0),
        )
        val cfg = PointerProtocol.normalizeDockConfig(
            enabled = intent.getBooleanExtra(PointerProtocol.EXTRA_DOCK_ENABLED, false),
            form = intent.getStringExtra(PointerProtocol.EXTRA_DOCK_FORM),
            toolMic = intent.getBooleanExtra(PointerProtocol.EXTRA_TOOL_MIC, true),
            toolPointer = intent.getBooleanExtra(PointerProtocol.EXTRA_TOOL_POINTER, false),
            islandX = intent.getIntExtra(PointerProtocol.EXTRA_ISLAND_X, PointerProtocol.ISLAND_DEFAULT),
            islandY = intent.getIntExtra(PointerProtocol.EXTRA_ISLAND_Y, PointerProtocol.ISLAND_DEFAULT),
            islandW = intent.getIntExtra(PointerProtocol.EXTRA_ISLAND_W, PointerProtocol.ISLAND_DEFAULT),
            islandH = intent.getIntExtra(PointerProtocol.EXTRA_ISLAND_H, PointerProtocol.ISLAND_DEFAULT),
            islandSide = intent.getStringExtra(PointerProtocol.EXTRA_ISLAND_SIDE),
            trackpad = trackpad,
        )
        config = cfg
        prefs.saveConfig(cfg)
        apply(force = intent.getBooleanExtra(PointerProtocol.EXTRA_ACK, false))
    }

    /** ¿Se está dibujando la pestaña propia (y no la barra de VoiceBubble)? */
    private fun standalone(): Boolean = !hostDockOn() && prefs.ownTab()

    /** La barra de VoiceBubble está encendida (y VoiceBubble sigue instalada: si la desinstalaron, no cuenta). */
    private fun hostDockOn(): Boolean = config.enabled && HostLink.isHostInstalled(service)

    /**
     * Lo que se dibuja: la configuración de VoiceBubble si su barra está
     * encendida; si no, la pestaña propia (borde o burbuja, solo puntero) con
     * los ajustes propios del trackpad cuando VoiceBubble no está instalada.
     */
    private fun effective(): PointerProtocol.DockConfig {
        val cfg = config
        if (hostDockOn()) return cfg
        if (!prefs.ownTab()) return cfg.copy(enabled = false)
        val form = if (prefs.form() == PointerProtocol.FORM_BUBBLE) PointerProtocol.FORM_BUBBLE else PointerProtocol.FORM_EDGE
        val trackpad = if (HostLink.isHostInstalled(service)) cfg.trackpad else prefs.ownTrackpad()
        return cfg.copy(enabled = true, form = form, toolMic = false, toolPointer = true, trackpad = trackpad)
    }

    /** La pantalla del complemento cambió la pestaña propia o sus ajustes: redibujar en vivo. */
    fun refreshOwn(rebuild: Boolean = false) {
        if (destroyed) return
        // Cambió el lado: la barra lee su lugar guardado al crearse.
        if (rebuild && standalone()) dropSurface()
        apply(force = false)
    }

    /** Crea, cambia o saca la superficie según la configuración; después le cuenta a VoiceBubble. */
    private fun apply(force: Boolean) {
        val cfg = effective()
        if (!cfg.enabled) {
            dropSurface()
            announce(false, force)
            return
        }
        val wantIsland = cfg.form == PointerProtocol.FORM_ISLAND
        var s = surface
        if (s == null || surfaceIsIsland != wantIsland) {
            dropSurface()
            s = if (wantIsland) {
                IslandController(service, windowManager, screen, palette, this, level)
            } else {
                DockController(service, windowManager, screen, palette, prefs, this, level)
            }
            surface = s
            surfaceIsIsland = wantIsland
        }
        s.applyConfig(cfg)
        s.setTrackpadOpen(trackpadOpen)
        s.setMic(tracker, SystemClock.uptimeMillis())
        announce(s.isDrawing(), force)
    }

    private fun dropSurface() {
        surface?.destroy()
        surface = null
    }

    /** Le cuenta a VoiceBubble si la barra está dibujada (solo cuando cambia, o si lo pidió). */
    private fun announce(active: Boolean, force: Boolean) {
        if (!force && announced == active) return
        announced = active
        HostLink.state(service, active)
    }

    /** Giró el teléfono, cambió el tamaño de pantalla o el tema. */
    fun onConfigurationChanged() {
        if (destroyed) return
        palette.reload()
        surface?.onConfigurationChanged()
    }

    /** El trackpad se abrió o se cerró (la burbuja se esconde mientras está abierto; la isla enciende el glifo). */
    fun setTrackpadOpen(open: Boolean) {
        trackpadOpen = open
        surface?.setTrackpadOpen(open)
    }

    /**
     * Fin del servicio (o de la vinculación): barra afuera con todas sus
     * ventanas, animadores y temporizadores, y aviso a VoiceBubble para que
     * muestre la suya si está viva.
     */
    fun destroy() {
        if (destroyed) return
        destroyed = true
        handler.removeCallbacksAndMessages(null)
        dropSurface()
        micLevel = 0f
        tracker.reset()
        if (announced != false) {
            announced = false
            HostLink.state(service, false)
        }
    }

    // --------------------------------------------------------------- dictado

    /** MIC_STATE de VoiceBubble: estado del dictado y nivel de voz. */
    fun onMicState(intent: Intent) {
        if (destroyed) return
        val ms = PointerProtocol.normalizeMicState(
            state = intent.getStringExtra(PointerProtocol.EXTRA_MIC_STATE),
            level = intent.getFloatExtra(PointerProtocol.EXTRA_MIC_LEVEL, 0f),
            message = intent.getStringExtra(PointerProtocol.EXTRA_MIC_MESSAGE),
            needsUi = intent.getBooleanExtra(PointerProtocol.EXTRA_NEEDS_UI, false),
        ) ?: return
        if (ms.needsUi) {
            // VoiceBubble no pudo arrancar en segundo plano: que lo haga una actividad en primer plano.
            if (!trampolineTried) {
                trampolineTried = true
                if (HostLink.openTrampoline(service)) return
            }
            showLocal("No se pudo abrir el micrófono")
            return
        }
        val now = SystemClock.uptimeMillis()
        tracker.update(ms, now)
        micLevel = ms.level
        surface?.setMic(tracker, now)
        tracker.consumeResult()
        handler.removeCallbacks(staleCheck)
        if (tracker.isBusy) handler.postDelayed(staleCheck, PointerProtocol.MIC_STALE_MS / 2)
    }

    /** Un aviso propio del complemento (sin pasar por VoiceBubble), con el mismo canal visual que los del host. */
    private fun showLocal(message: String) {
        val now = SystemClock.uptimeMillis()
        val ms = PointerProtocol.normalizeMicState(PointerProtocol.MIC_ERROR, 0f, message, false) ?: return
        tracker.update(ms, now)
        micLevel = 0f
        surface?.setMic(tracker, now)
        tracker.consumeResult()
    }

    override fun onMicTap() {
        // Transcribiendo no hay nada que hacer con el micrófono: se espera el resultado.
        if (tracker.state == PointerProtocol.MIC_TRANSCRIBING) return
        trampolineTried = false
        if (!HostLink.hostHasMicPermission(service)) {
            showLocal("Falta el permiso del micrófono")
            return
        }
        if (HostLink.toggleDictation(service)) return
        // Android no dejó arrancarlo en segundo plano: actividad trampolín en primer plano.
        trampolineTried = true
        if (!HostLink.openTrampoline(service)) showLocal("No se pudo abrir el micrófono")
    }

    override fun onMicCancel() {
        HostLink.cancelDictation(service)
    }

    override fun onPointerTap(anchorX: Int, anchorY: Int) {
        service.openTrackpadFromDock(effective().trackpad.copy(anchorX = anchorX, anchorY = anchorY))
    }

    override fun onHistoryRequested(x: Int, y: Int, size: Int): Boolean {
        // La pestaña propia no tiene historial (es solo el puntero) y sin VoiceBubble no hay a quién pedírselo.
        if (standalone() || !hostDockOn()) return false
        HostLink.showHistory(service, x, y, size)
        return true
    }

    override fun onFormChanged(form: String) {
        // La persona la cambió con el dedo: se recuerda acá y se le cuenta a VoiceBubble (Ajustes la muestra).
        prefs.saveForm(form)
        // La pestaña propia no toca la forma de la barra de VoiceBubble.
        if (standalone()) return
        config = config.copy(form = form)
        HostLink.state(service, announced ?: true, form)
    }
}
