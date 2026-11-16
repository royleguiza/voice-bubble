package com.royleguiza.voicebubble.puntero

import android.content.Context

/**
 * Estado de la barra flotante guardado en preferencias PROPIAS del complemento
 * (`vb_puntero_dock`): la última configuración que mandó VoiceBubble (para que
 * la barra vuelva sola tras reiniciar, aunque VoiceBubble esté cerrada) y
 * dónde dejó la persona la barra o la burbuja.
 *
 * Solo guarda ajustes de la barra: nunca audio, texto, coordenadas de clics ni
 * nombres de apps.
 */
internal class DockPrefs(context: Context) {

    private val prefs = context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    companion object {
        const val NAME = "vb_puntero_dock"
        private const val K_ENABLED = "cfg_enabled"
        private const val K_FORM = "cfg_form"
        private const val K_TOOL_MIC = "cfg_tool_mic"
        private const val K_TOOL_POINTER = "cfg_tool_pointer"
        private const val K_ISLAND_X = "cfg_island_x"
        private const val K_ISLAND_Y = "cfg_island_y"
        private const val K_ISLAND_W = "cfg_island_w"
        private const val K_ISLAND_H = "cfg_island_h"
        private const val K_ISLAND_SIDE = "cfg_island_side"
        private const val K_TP_MODE = "tp_mode"
        private const val K_TP_SENS = "tp_sensitivity"
        private const val K_TP_ACCEL = "tp_accel"
        private const val K_TP_STYLE = "tp_style"
        private const val K_TP_HAPTIC = "tp_haptic"
        private const val K_TP_SCROLL = "tp_scroll_dir"
        private const val K_TP_AUTO = "tp_auto_return"

        private const val K_SIDE = "side"
        private const val K_CENTER_Y = "center_y_frac"
        private const val K_BUBBLE_X = "bubble_x_frac"
        private const val K_BUBBLE_Y = "bubble_y_frac"

        // Fase 3: uso sin VoiceBubble (pestaña propia y ajustes mínimos).
        private const val K_OWN_TAB = "own_tab"
        private const val K_OWN_SENS = "own_sensitivity"
        private const val K_OWN_STYLE = "own_style"
        private const val K_OWN_MODE = "own_mode"

        // Fase 3: dónde y de qué tamaño dejó la persona el trackpad (ventana libre).
        private const val K_TPW_X = "tpw_x_frac"
        private const val K_TPW_Y = "tpw_y_frac"
        private const val K_TPW_W = "tpw_w_dp"
        private const val K_TPW_H = "tpw_h_dp"
    }

    /** Valores por defecto de un teléfono recién instalado: la barra no se dibuja hasta que VoiceBubble la encienda. */
    private fun defaults(): PointerProtocol.DockConfig = PointerProtocol.normalizeDockConfig(
        enabled = false,
        form = PointerProtocol.FORM_EDGE,
        toolMic = true,
        toolPointer = false,
        islandX = PointerProtocol.ISLAND_DEFAULT,
        islandY = PointerProtocol.ISLAND_DEFAULT,
        islandW = PointerProtocol.ISLAND_DEFAULT,
        islandH = PointerProtocol.ISLAND_DEFAULT,
        islandSide = PointerProtocol.SIDE_LEFT,
        trackpad = PointerProtocol.normalizeTrackpadConfig(
            -1, -1, null, Float.NaN, null, null, null, null, 0,
        ),
    )

    /** Última configuración guardada (siempre normalizada: nunca rompe). */
    fun loadConfig(): PointerProtocol.DockConfig = try {
        PointerProtocol.normalizeDockConfig(
            enabled = prefs.getBoolean(K_ENABLED, false),
            form = prefs.getString(K_FORM, null),
            toolMic = prefs.getBoolean(K_TOOL_MIC, true),
            toolPointer = prefs.getBoolean(K_TOOL_POINTER, false),
            islandX = prefs.getInt(K_ISLAND_X, PointerProtocol.ISLAND_DEFAULT),
            islandY = prefs.getInt(K_ISLAND_Y, PointerProtocol.ISLAND_DEFAULT),
            islandW = prefs.getInt(K_ISLAND_W, PointerProtocol.ISLAND_DEFAULT),
            islandH = prefs.getInt(K_ISLAND_H, PointerProtocol.ISLAND_DEFAULT),
            islandSide = prefs.getString(K_ISLAND_SIDE, null),
            trackpad = PointerProtocol.normalizeTrackpadConfig(
                anchorX = -1,
                anchorY = -1,
                mode = prefs.getString(K_TP_MODE, null),
                sensitivity = prefs.getFloat(K_TP_SENS, Float.NaN),
                accel = prefs.getString(K_TP_ACCEL, null),
                style = prefs.getString(K_TP_STYLE, null),
                haptic = prefs.getString(K_TP_HAPTIC, null),
                scrollDir = prefs.getString(K_TP_SCROLL, null),
                autoReturnS = prefs.getInt(K_TP_AUTO, 0),
            ),
        )
    } catch (_: Exception) {
        defaults()
    }

    fun saveConfig(cfg: PointerProtocol.DockConfig) {
        try {
            prefs.edit()
                .putBoolean(K_ENABLED, cfg.enabled)
                .putString(K_FORM, cfg.form)
                .putBoolean(K_TOOL_MIC, cfg.toolMic)
                .putBoolean(K_TOOL_POINTER, cfg.toolPointer)
                .putInt(K_ISLAND_X, cfg.islandX)
                .putInt(K_ISLAND_Y, cfg.islandY)
                .putInt(K_ISLAND_W, cfg.islandW)
                .putInt(K_ISLAND_H, cfg.islandH)
                .putString(K_ISLAND_SIDE, cfg.islandSide)
                .putString(K_TP_MODE, cfg.trackpad.mode)
                .putFloat(K_TP_SENS, cfg.trackpad.sensitivity)
                .putString(K_TP_ACCEL, cfg.trackpad.accel)
                .putString(K_TP_STYLE, cfg.trackpad.style)
                .putString(K_TP_HAPTIC, cfg.trackpad.haptic)
                .putString(K_TP_SCROLL, cfg.trackpad.scrollDir)
                .putInt(K_TP_AUTO, cfg.trackpad.autoReturnS)
                .apply()
        } catch (_: Exception) {}
    }

    /** Solo la forma (la persona la cambió con el dedo: barra ↔ burbuja). */
    fun saveForm(form: String) {
        try {
            prefs.edit().putString(K_FORM, form).apply()
        } catch (_: Exception) {}
    }

    // --- Posición de la barra (borde) y de la burbuja, como fracción de la pantalla ---

    /** Lado de la barra del borde. */
    fun side(): DockGeometry.Side =
        if (prefs.getString(K_SIDE, "right") == "left") DockGeometry.Side.LEFT else DockGeometry.Side.RIGHT

    fun centerYFrac(): Float = frac(K_CENTER_Y, 0.45f)
    fun bubbleXFrac(): Float = frac(K_BUBBLE_X, 0.8f)
    fun bubbleYFrac(): Float = frac(K_BUBBLE_Y, 0.45f)

    private fun frac(key: String, fallback: Float): Float {
        val v = try {
            prefs.getFloat(key, fallback)
        } catch (_: Exception) {
            fallback
        }
        return if (v.isFinite()) v.coerceIn(0f, 1f) else fallback
    }

    fun savePosition(side: DockGeometry.Side, centerYFrac: Float, bubbleXFrac: Float, bubbleYFrac: Float) {
        try {
            prefs.edit()
                .putString(K_SIDE, if (side == DockGeometry.Side.LEFT) "left" else "right")
                .putFloat(K_CENTER_Y, centerYFrac)
                .putFloat(K_BUBBLE_X, bubbleXFrac)
                .putFloat(K_BUBBLE_Y, bubbleYFrac)
                .apply()
        } catch (_: Exception) {}
    }

    fun saveSide(side: DockGeometry.Side) {
        try {
            prefs.edit().putString(K_SIDE, if (side == DockGeometry.Side.LEFT) "left" else "right").apply()
        } catch (_: Exception) {}
    }

    /** La forma guardada (la que dejó la persona con el dedo o la que mandó VoiceBubble). */
    fun form(): String = try {
        prefs.getString(K_FORM, null) ?: PointerProtocol.FORM_EDGE
    } catch (_: Exception) {
        PointerProtocol.FORM_EDGE
    }

    // --- Fase 3: pestaña propia y ajustes mínimos (sin VoiceBubble) ---

    /** La persona encendió la pestaña propia del complemento. */
    fun ownTab(): Boolean = try {
        prefs.getBoolean(K_OWN_TAB, false)
    } catch (_: Exception) {
        false
    }

    fun setOwnTab(on: Boolean) {
        try {
            prefs.edit().putBoolean(K_OWN_TAB, on).apply()
        } catch (_: Exception) {}
    }

    /**
     * Trackpad con los ajustes propios del complemento (los usa la pestaña
     * propia cuando VoiceBubble no está instalada). Siempre normalizado.
     */
    fun ownTrackpad(): PointerProtocol.TrackpadConfig {
        val base = loadConfig().trackpad
        return try {
            PointerProtocol.normalizeTrackpadConfig(
                anchorX = -1,
                anchorY = -1,
                mode = prefs.getString(K_OWN_MODE, PointerProtocol.MODE_WINDOW),
                sensitivity = prefs.getFloat(K_OWN_SENS, PointerProtocol.DEFAULT_SENSITIVITY),
                accel = base.accel,
                style = prefs.getString(K_OWN_STYLE, null),
                haptic = base.haptic,
                scrollDir = base.scrollDir,
                autoReturnS = base.autoReturnS,
            )
        } catch (_: Exception) {
            base
        }
    }

    fun saveOwnTrackpad(sensitivity: Float, style: String, mode: String) {
        try {
            prefs.edit()
                .putFloat(K_OWN_SENS, sensitivity)
                .putString(K_OWN_STYLE, style)
                .putString(K_OWN_MODE, mode)
                .apply()
        } catch (_: Exception) {}
    }

    // --- Fase 3: lugar y tamaño del trackpad en ventana libre ---

    /** Dónde la dejó la persona (null = nunca la movió ni la achicó). */
    fun trackpadPlacement(): TrackpadGeometry.Placement? = try {
        val x = prefs.getFloat(K_TPW_X, Float.NaN)
        val y = prefs.getFloat(K_TPW_Y, Float.NaN)
        val w = prefs.getFloat(K_TPW_W, Float.NaN)
        val h = prefs.getFloat(K_TPW_H, Float.NaN)
        if (x.isFinite() && y.isFinite() && w.isFinite() && h.isFinite()) {
            TrackpadGeometry.Placement(x.coerceIn(0f, 1f), y.coerceIn(0f, 1f), w, h)
        } else {
            null
        }
    } catch (_: Exception) {
        null
    }

    fun saveTrackpadPlacement(p: TrackpadGeometry.Placement) {
        try {
            prefs.edit()
                .putFloat(K_TPW_X, p.xFrac)
                .putFloat(K_TPW_Y, p.yFrac)
                .putFloat(K_TPW_W, p.wDp)
                .putFloat(K_TPW_H, p.hDp)
                .apply()
        } catch (_: Exception) {}
    }

    fun clearTrackpadPlacement() {
        try {
            prefs.edit().remove(K_TPW_X).remove(K_TPW_Y).remove(K_TPW_W).remove(K_TPW_H).apply()
        } catch (_: Exception) {}
    }
}
