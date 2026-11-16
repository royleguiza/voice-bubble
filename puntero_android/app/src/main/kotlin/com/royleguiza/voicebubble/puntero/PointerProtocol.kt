package com.royleguiza.voicebubble.puntero

import kotlin.math.abs

/**
 * Protocolo con el complemento "VoiceBubble Puntero" (docs/contrato-trackpad.md).
 *
 * VoiceBubble NO declara AccessibilityService (perfil anti-Play-Protect): los
 * clics en otras apps los ejecuta el complemento, que solo recibe órdenes
 * "tocá en (x, y)" por broadcast explícito protegido con un permiso de firma
 * declarado en las dos apps. Sin lectura de pantalla, sin registro.
 *
 * Protocolo v2 (fase 1 del puntero por encima de todo): además de las órdenes
 * de gesto sueltas, VoiceBubble pide «abrí / cerrá el trackpad» y el
 * complemento dibuja el puntero y el panel como ventanas propias de
 * Accesibilidad, avisando el estado de vuelta.
 *
 * ESPEJO EXACTO: voice_bubble_stt/android/app/src/main/kotlin/.../PointerProtocol.kt.
 * La suite test_floating_dock_suite.py verifica que las constantes coincidan.
 * Protocolo v3 (fase 2A): la barra flotante (borde · burbuja · isla) la dibuja
 * el complemento como ventanas de Accesibilidad, para que no desaparezca nunca;
 * VoiceBubble le manda la configuración ([ACTION_DOCK_CONFIG]) y el estado del
 * dictado ([ACTION_MIC_STATE]); el dictado lo hace un servicio nativo de
 * VoiceBubble (sin Flutter). El audio y el texto NUNCA pasan por acá.
 *
 * Lógica pura (sin android.*) para testearla en la JVM.
 */
object PointerProtocol {
    const val COMPANION_PACKAGE = "com.royleguiza.voicebubble.puntero"
    const val COMPANION_SERVICE_CLASS = "com.royleguiza.voicebubble.puntero.PunteroService"
    const val ACTION_POINTER = "com.royleguiza.voicebubble.puntero.ACTION_POINTER"
    const val PERMISSION_POINTER = "com.royleguiza.voicebubble.puntero.permission.POINTER"

    const val EXTRA_OP = "op"
    const val EXTRA_X = "x"
    const val EXTRA_Y = "y"
    const val EXTRA_DY = "dy"

    const val OP_TAP = "tap"
    const val OP_LONG_PRESS = "long_press"
    const val OP_SCROLL = "scroll"

    /** Recorrido máximo de un trazo de scroll (px). */
    const val MAX_SCROLL_PX = 600f

    /** Duraciones de los gestos que despacha el complemento (ms). */
    const val TAP_MS = 40L
    const val LONG_PRESS_MS = 450L
    const val SCROLL_MS = 80L

    const val STATUS_MISSING = "missing"
    const val STATUS_DISABLED = "disabled"
    const val STATUS_READY = "ready"

    /** Respuesta del complemento a un clic: confirma que Android lo hizo. */
    const val HOST_PACKAGE = "com.royleguiza.voicebubblestt"
    const val ACTION_RESULT = "com.royleguiza.voicebubble.puntero.ACTION_RESULT"
    const val EXTRA_SEQ = "seq"
    const val EXTRA_RESULT = "result"
    const val RESULT_DONE = "done"
    const val RESULT_CANCELLED = "cancelled"
    const val RESULT_REJECTED = "rejected"

    /** Si no llega respuesta en este tiempo (tras el gesto), el complemento no está escuchando. */
    const val ACK_TIMEOUT_MS = 1200L

    // --- v2: el trackpad vive en el complemento ---

    /** VoiceBubble → complemento: abrir el trackpad (ancla + configuración). */
    const val ACTION_OPEN_TRACKPAD = "com.royleguiza.voicebubble.puntero.ACTION_OPEN_TRACKPAD"

    /** VoiceBubble → complemento: cerrar el trackpad. */
    const val ACTION_CLOSE_TRACKPAD = "com.royleguiza.voicebubble.puntero.ACTION_CLOSE_TRACKPAD"

    /** Complemento → VoiceBubble: el trackpad se abrió o se cerró (extra [EXTRA_OPEN]). */
    const val ACTION_TRACKPAD_STATE = "com.royleguiza.voicebubble.puntero.ACTION_TRACKPAD_STATE"

    const val EXTRA_ANCHOR_X = "anchor_x"
    const val EXTRA_ANCHOR_Y = "anchor_y"
    const val EXTRA_MODE = "mode"
    const val EXTRA_SENSITIVITY = "sensitivity"
    const val EXTRA_ACCEL = "accel"
    const val EXTRA_STYLE = "style"
    const val EXTRA_HAPTIC = "haptic"
    const val EXTRA_SCROLL_DIR = "scroll_dir"
    const val EXTRA_AUTO_RETURN = "auto_return"
    const val EXTRA_OPEN = "open"

    const val MODE_PANEL = "panel"
    const val MODE_WINDOW = "window"
    const val ACCEL_DYNAMIC = "dynamic"
    const val ACCEL_LINEAR = "linear"
    const val ACCEL_PRECISION = "precision"
    const val STYLE_ARROW = "arrow"
    const val STYLE_DOT = "dot"
    const val STYLE_CROSS = "cross"
    const val HAPTIC_SUBTLE = "subtle"
    const val HAPTIC_NONE = "none"
    const val HAPTIC_FIRM = "firm"
    const val SCROLL_NATURAL = "natural"
    const val SCROLL_TRADITIONAL = "traditional"

    /** Sensibilidad por defecto y límites válidos del puntero. */
    const val DEFAULT_SENSITIVITY = 1.2f
    const val MIN_SENSITIVITY = 0.5f
    const val MAX_SENSITIVITY = 2.5f

    /** Tope del cierre automático (segundos); 0 = el trackpad queda abierto. */
    const val MAX_AUTO_RETURN_S = 120

    // --- v3: la barra flotante (borde · burbuja · isla) la dibuja el complemento ---

    /** VoiceBubble → complemento: configuración de la barra (ver [DockConfig]). Aplica EN VIVO. */
    const val ACTION_DOCK_CONFIG = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_CONFIG"

    /** VoiceBubble → complemento: estado del dictado (ver [MicState]). */
    const val ACTION_MIC_STATE = "com.royleguiza.voicebubble.puntero.ACTION_MIC_STATE"

    /** Complemento → VoiceBubble: arrancó (o quiere configuración); el host contesta con DOCK_CONFIG. */
    const val ACTION_DOCK_HELLO = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_HELLO"

    /** Complemento → VoiceBubble: dice si está dibujando la barra ([EXTRA_ACTIVE]) y qué forma tiene. */
    const val ACTION_DOCK_STATE = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_STATE"

    /**
     * Complemento → VoiceBubble (fase 4): toque largo en la barra o la burbuja;
     * VoiceBubble muestra SU panel de historial desde ([EXTRA_HISTORY_X],
     * [EXTRA_HISTORY_Y]) con lado [EXTRA_HISTORY_SIZE]. El texto dictado nunca
     * pasa por el complemento.
     */
    const val ACTION_DOCK_HISTORY = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_HISTORY"
    const val EXTRA_HISTORY_X = "history_x"
    const val EXTRA_HISTORY_Y = "history_y"
    const val EXTRA_HISTORY_SIZE = "history_size"

    /**
     * VoiceBubble → complemento: su panel de historial se abrió
     * ([EXTRA_VEILED] = true) o se cerró (false). Abierto, la barra del
     * complemento se vela (invisible y sin tomar toques) para no taparlo; si
     * el «cerrado» no llega, vuelve sola a los [VEIL_MAX_MS].
     */
    const val ACTION_DOCK_VEIL = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_VEIL"
    const val EXTRA_VEILED = "veiled"
    const val VEIL_MAX_MS = 120_000L

    const val EXTRA_DOCK_ENABLED = "enabled"
    const val EXTRA_DOCK_FORM = "form"
    const val EXTRA_TOOL_MIC = "tool_mic"
    const val EXTRA_TOOL_POINTER = "tool_pointer"
    const val EXTRA_ISLAND_X = "island_x"
    const val EXTRA_ISLAND_Y = "island_y"
    const val EXTRA_ISLAND_W = "island_w"
    const val EXTRA_ISLAND_H = "island_h"
    const val EXTRA_ISLAND_SIDE = "island_side"
    const val EXTRA_ACTIVE = "active"

    /** DOCK_CONFIG: el host quiere que el complemento conteste con DOCK_STATE aunque nada haya cambiado. */
    const val EXTRA_ACK = "ack"

    const val EXTRA_MIC_STATE = "state"
    const val EXTRA_MIC_LEVEL = "level"
    const val EXTRA_MIC_MESSAGE = "message"
    const val EXTRA_NEEDS_UI = "needs_ui"

    const val FORM_EDGE = "edge"
    const val FORM_BUBBLE = "bubble"
    const val FORM_ISLAND = "island"
    const val SIDE_LEFT = "left"
    const val SIDE_RIGHT = "right"

    const val MIC_IDLE = "idle"
    const val MIC_RECORDING = "recording"
    const val MIC_TRANSCRIBING = "transcribing"
    const val MIC_DONE = "done"
    const val MIC_ERROR = "error"

    /** Isla: −1 = valor por defecto (centrada arriba, 112 × 30 dp). */
    const val ISLAND_DEFAULT = -1

    /** Tope de las medidas de la isla en px (más que eso es basura y vuelve al valor por defecto). */
    const val ISLAND_MAX_PX = 20000

    /** Largo máximo del mensaje corto de MIC_STATE (siempre una frase fija de VoiceBubble, nunca texto dictado). */
    const val MAX_MIC_MESSAGE = 40

    /** Mientras graba, el host manda el estado al menos cada tanto; si pasa este tiempo sin noticias, el complemento vuelve a reposo. */
    const val MIC_STALE_MS = 6000L

    /** Nivel de voz: como mucho 15 mensajes por segundo (un envío cada [MIC_LEVEL_EVERY_MS]). */
    const val MIC_LEVEL_EVERY_MS = 70L

    /** Dictado nativo de la barra (servicio DockDictationService del host): acciones y destino. */
    const val HOST_DICTATION_SERVICE_CLASS = "com.royleguiza.voicebubblestt.DockDictationService"
    const val HOST_TRAMPOLINE_CLASS = "com.royleguiza.voicebubblestt.DockTrampolineActivity"
    const val ACTION_DICTATION_TOGGLE = "com.royleguiza.voicebubblestt.DOCK_DICTATION_TOGGLE"
    const val ACTION_DICTATION_CANCEL = "com.royleguiza.voicebubblestt.DOCK_DICTATION_CANCEL"
    const val EXTRA_FROM_TRAMPOLINE = "from_trampoline"

    data class Command(val op: String, val x: Float, val y: Float, val dy: Float = 0f) {
        /** Cuánto dura el gesto en pantalla: las ventanas propias se apartan ese tiempo. */
        fun durationMs(): Long = when (op) {
            OP_LONG_PRESS -> LONG_PRESS_MS
            OP_SCROLL -> SCROLL_MS
            else -> TAP_MS
        }
    }

    /**
     * Valida y normaliza una orden. Devuelve null si es inválida: operación
     * desconocida, coordenadas no finitas o negativas, o scroll sin recorrido.
     */
    fun validate(op: String?, x: Float, y: Float, dy: Float = 0f): Command? {
        if (op != OP_TAP && op != OP_LONG_PRESS && op != OP_SCROLL) return null
        if (!x.isFinite() || !y.isFinite() || x < 0f || y < 0f) return null
        if (op == OP_SCROLL) {
            if (!dy.isFinite() || abs(dy) < 1f) return null
            return Command(op, x, y, dy.coerceIn(-MAX_SCROLL_PX, MAX_SCROLL_PX))
        }
        return Command(op, x, y, 0f)
    }

    /**
     * ¿Está el servicio del complemento en Settings.Secure
     * ENABLED_ACCESSIBILITY_SERVICES? Formato: "pkg/cls:pkg/.cls".
     */
    fun isServiceEnabled(
        setting: String?,
        pkg: String = COMPANION_PACKAGE,
        cls: String = COMPANION_SERVICE_CLASS,
    ): Boolean {
        if (setting.isNullOrBlank()) return false
        return setting.split(':').any { entry ->
            val slash = entry.indexOf('/')
            if (slash <= 0 || slash == entry.length - 1) return@any false
            val p = entry.substring(0, slash).trim()
            var c = entry.substring(slash + 1).trim()
            if (c.startsWith(".")) c = p + c
            p == pkg && c == cls
        }
    }

    /**
     * ¿El trazo de [cmd] pasa por el rectángulo (l, t, r, b)? Con [slopPx]
     * de margen. Sirve para apartar nuestras ventanas flotantes que taparían
     * el clic (Android 12+ bloquea toques bajo overlays opacos de otra app).
     */
    fun pathHits(cmd: Command, l: Int, t: Int, r: Int, b: Int, slopPx: Float = 0f): Boolean {
        if (r <= l || b <= t) return false
        val top = minOf(cmd.y, cmd.y + cmd.dy) - slopPx
        val bottom = maxOf(cmd.y, cmd.y + cmd.dy) + slopPx
        return cmd.x + slopPx >= l && cmd.x - slopPx <= r && bottom >= t && top <= b
    }

    fun status(installed: Boolean, enabled: Boolean): String = when {
        !installed -> STATUS_MISSING
        !enabled -> STATUS_DISABLED
        else -> STATUS_READY
    }

    /** ¿Esta orden pide confirmación? Solo los clics (el scroll llega a 60 Hz). */
    fun wantsAck(op: String): Boolean = op == OP_TAP || op == OP_LONG_PRESS

    /**
     * Qué decirle a la persona según la respuesta del complemento.
     * null = salió bien (no hay nada que avisar). [result] null = no respondió.
     */
    fun resultMessage(result: String?): String? = when (result) {
        RESULT_DONE -> null
        RESULT_CANCELLED -> "Android interrumpió el clic. Probá de nuevo."
        RESULT_REJECTED -> "VoiceBubble Puntero no pudo hacer el clic. Apagalo y volvé a prenderlo en Accesibilidad."
        else -> "VoiceBubble Puntero no responde. Apagalo y volvé a prenderlo en Accesibilidad."
    }

    /**
     * Parte un scroll largo en tramos de hasta [MAX_SCROLL_PX] con el mismo
     * signo. Ignora recorridos de menos de 1 px o no finitos.
     */
    fun scrollChunks(total: Float): List<Float> {
        if (!total.isFinite() || abs(total) < 1f) return emptyList()
        val out = ArrayList<Float>()
        var left = total
        while (abs(left) >= 1f && out.size < 20) {
            val step = left.coerceIn(-MAX_SCROLL_PX, MAX_SCROLL_PX)
            out.add(step)
            left -= step
        }
        return out
    }

    /** Configuración ya validada con la que el complemento abre el trackpad. */
    data class TrackpadConfig(
        /** Ancla (px de pantalla) junto a la que se abre la ventana; −1 = sin ancla. */
        val anchorX: Int,
        val anchorY: Int,
        val mode: String,
        val sensitivity: Float,
        val accel: String,
        val style: String,
        val haptic: String,
        val scrollDir: String,
        val autoReturnS: Int,
    ) {
        val hasAnchor: Boolean get() = anchorX >= 0 && anchorY >= 0
        val naturalScroll: Boolean get() = scrollDir != SCROLL_TRADITIONAL
    }

    /**
     * Valida y normaliza la configuración de OPEN_TRACKPAD: lo desconocido o
     * fuera de rango cae al valor por defecto, nunca rompe. Sin ancla (o con
     * una sola coordenada) queda en −1/−1.
     */
    fun normalizeTrackpadConfig(
        anchorX: Int,
        anchorY: Int,
        mode: String?,
        sensitivity: Float,
        accel: String?,
        style: String?,
        haptic: String?,
        scrollDir: String?,
        autoReturnS: Int,
    ): TrackpadConfig {
        val anchored = anchorX >= 0 && anchorY >= 0
        return TrackpadConfig(
            anchorX = if (anchored) anchorX else -1,
            anchorY = if (anchored) anchorY else -1,
            mode = if (mode == MODE_WINDOW) MODE_WINDOW else MODE_PANEL,
            sensitivity = if (sensitivity.isFinite() && sensitivity in MIN_SENSITIVITY..MAX_SENSITIVITY) sensitivity else DEFAULT_SENSITIVITY,
            accel = if (accel == ACCEL_LINEAR || accel == ACCEL_PRECISION) accel else ACCEL_DYNAMIC,
            style = if (style == STYLE_DOT || style == STYLE_CROSS) style else STYLE_ARROW,
            haptic = if (haptic == HAPTIC_NONE || haptic == HAPTIC_FIRM) haptic else HAPTIC_SUBTLE,
            scrollDir = if (scrollDir == SCROLL_TRADITIONAL) SCROLL_TRADITIONAL else SCROLL_NATURAL,
            autoReturnS = if (autoReturnS in 0..MAX_AUTO_RETURN_S) autoReturnS else 0,
        )
    }

    // --- v3: configuración de la barra y estado del dictado ---

    /** Configuración ya validada de la barra flotante. */
    data class DockConfig(
        /** La barra flotante está encendida en Ajustes. */
        val enabled: Boolean,
        /** [FORM_EDGE], [FORM_BUBBLE] o [FORM_ISLAND]. */
        val form: String,
        val toolMic: Boolean,
        val toolPointer: Boolean,
        /** Isla: centro horizontal y borde superior en px de pantalla completa; −1 = por defecto. */
        val islandX: Int,
        val islandY: Int,
        /** Isla en reposo: ancho y alto en px; −1 = por defecto (112 × 30 dp). */
        val islandW: Int,
        val islandH: Int,
        /** Lado del micrófono en la isla ([SIDE_LEFT]/[SIDE_RIGHT]); el puntero va del otro. */
        val islandSide: String,
        /** Configuración del trackpad (sin ancla: la pone la barra). */
        val trackpad: TrackpadConfig,
    ) {
        val micOnLeft: Boolean get() = islandSide != SIDE_RIGHT
    }

    private fun islandPx(v: Int): Int = if (v in 0..ISLAND_MAX_PX) v else ISLAND_DEFAULT

    /**
     * Valida y normaliza DOCK_CONFIG: lo desconocido cae al valor por defecto,
     * nunca rompe. Sin ninguna herramienta queda el micrófono (como la barra).
     */
    fun normalizeDockConfig(
        enabled: Boolean,
        form: String?,
        toolMic: Boolean,
        toolPointer: Boolean,
        islandX: Int,
        islandY: Int,
        islandW: Int,
        islandH: Int,
        islandSide: String?,
        trackpad: TrackpadConfig,
    ): DockConfig {
        val noTools = !toolMic && !toolPointer
        return DockConfig(
            enabled = enabled,
            form = if (form == FORM_BUBBLE || form == FORM_ISLAND) form else FORM_EDGE,
            toolMic = toolMic || noTools,
            toolPointer = toolPointer && !noTools,
            islandX = islandPx(islandX),
            islandY = islandPx(islandY),
            islandW = islandPx(islandW).let { if (it == 0) ISLAND_DEFAULT else it },
            islandH = islandPx(islandH).let { if (it == 0) ISLAND_DEFAULT else it },
            islandSide = if (islandSide == SIDE_RIGHT) SIDE_RIGHT else SIDE_LEFT,
            trackpad = trackpad.copy(anchorX = -1, anchorY = -1),
        )
    }

    /** Estado del dictado que el host le cuenta a la barra. */
    data class MicState(
        val state: String,
        /** 0..1; solo grabando. */
        val level: Float,
        /** Frase corta fija (done/error); nunca texto dictado. */
        val message: String?,
        /** El host no pudo arrancar en segundo plano: abrir la actividad trampolín. */
        val needsUi: Boolean,
    )

    /** Valida MIC_STATE. null = estado desconocido (se ignora). */
    fun normalizeMicState(state: String?, level: Float, message: String?, needsUi: Boolean): MicState? {
        if (state != MIC_IDLE && state != MIC_RECORDING && state != MIC_TRANSCRIBING &&
            state != MIC_DONE && state != MIC_ERROR
        ) {
            return null
        }
        val lv = if (state == MIC_RECORDING && level.isFinite()) level.coerceIn(0f, 1f) else 0f
        val msg = if (state == MIC_DONE || state == MIC_ERROR) {
            message?.trim()?.take(MAX_MIC_MESSAGE)?.takeIf { it.isNotEmpty() }
        } else {
            null
        }
        return MicState(state, lv, msg, needsUi && state == MIC_ERROR)
    }

    /** ¿El estado exige que el complemento muestre algo (no es reposo)? */
    fun isBusy(state: String): Boolean = state == MIC_RECORDING || state == MIC_TRANSCRIBING
}
