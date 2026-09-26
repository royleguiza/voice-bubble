package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.SharedPreferences

/**
 * Preferencias del teclado (SPK-05, módulo 4 de N): las 21 claves del
 * puente Flutter escritas por Ajustes, extraídas de VoiceKeyboardService
 * sin cambiar conducta. Lectura ÚNICA por ciclo del campo ([load] en
 * onStartInputView, que siempre corre tras onCreateInputView) y todo queda
 * cacheado acá para no golpear SharedPreferences en cada tecla.
 * Caducidad honesta: un cambio hecho en Ajustes se aplica al abrirse el
 * proximo campo, no en vivo.
 */
class KeyboardPrefs(private val context: Context) {

    // AT-A13: heightFactor escala solo alturas propias del teclado, jamas
    // el padding inferior por insets.
    var heightFactor = HEIGHT_FACTOR_MEDIA
    var hapticsEnabled = true
    var bottomElevationDp = 24
    var invertToolbar = false
    var spacebarAlignment = "center"
    var spacebarTrackpadMode = "ios_2d" // MEJ-25: "ios_2d" o "gboard_horizontal"
    var sttKeyConfigured = false

    // AT-A8: cache de visibilidad; rebuild jamas consulta SharedPreferences.
    var terminalRowVisiblePref = true
    var codeKeyVisiblePref = true
    var languageKeyVisiblePref = true
    var credentialsKeyVisiblePref = true

    // SPK-10: imágenes del portapapeles opt-in (texto primero). Default OFF.
    var clipboardImagesEnabled = false

    // Anti-fantasma: espaciado entre teclas (Compacto/Normal/Amplio).
    var keySpacing = SPACING_PROFILE_NORMAL
    var keySpacingFactor = SPACING_FACTOR_NORMAL

    // Estilo háptico de teclas (Nítido/Firme/Suave). Default nítido.
    var hapticStyle = HAPTIC_STYLE_NITIDO

    // Micrófono: feedback independiente de la vibración de teclas.
    // Master háptico + 4 eventos (inicio/grabando/pegar/cancelar), default ON;
    // sonidos default OFF (opt-in).
    var micHapticsEnabled = true
    var micHapticStart = true
    var micHapticRecording = true
    var micHapticPaste = true
    var micHapticCancel = true
    var micSoundsEnabled = false
    var micStartStyle = "3"
    var micStopStyle = "3"

    // --- Modo Trackpad y Puntero Virtual (MEJ-09) ---
    // Defaults OFF (2026-09-20, pedido del dueño): en instalación nueva el
    // trackpad arranca desactivado; quien lo tenía ON lo conserva en prefs.
    var trackpadEnabled = false
    var trackpadToolbarVisible = false
    var trackpadButtonLayout = "top"
    var trackpadScrollPosition = "right"
    var trackpadSensitivity = 1.2f
    var trackpadAccelCurve = "dynamic"
    var trackpadTapToClick = true
    var trackpadSecondaryClick = "2fingers"
    var trackpadScrollDirection = "natural"
    var trackpadHaptic = "subtle"
    var trackpadPointerStyle = "arrow"
    var trackpadAutoReturn = 0

    // --- Pulsación larga de símbolos (MEJ-05): switch + retardo
    // Rápido/Normal/Relajado. Default ON + normal (350ms, conducta histórica).
    var longPressSymbolsEnabled = true
    var longPressDelay = LONG_PRESS_DELAY_NORMAL
    var longPressDelayMs = LONG_PRESS_DELAY_NORMAL_MS

    @Volatile
    private var cachedPrefs: SharedPreferences? = null

    /** C-12: Inicialización perezosa / warm-up de SharedPreferences fuera del hilo principal. */
    fun warmUp() {
        if (cachedPrefs == null) {
            prefs()
        }
    }

    private fun prefs(): SharedPreferences =
        cachedPrefs ?: synchronized(this) {
            cachedPrefs ?: run {
                val p = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                cachedPrefs = p
                p
            }
        }

    /**
     * Preferencia escrita por los Ajustes de la app (Flutter shared_preferences
     * guarda con prefijo "flutter." en el archivo FlutterSharedPreferences).
     * Parseo tolerante: ante cualquier error se muestra la fila (default true).
     */
    fun terminalRowVisible(): Boolean = try {
        prefs().getBoolean("flutter.kb_terminal_row_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla "</>" de capa codigo ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    fun codeKeyVisible(): Boolean = try {
        prefs().getBoolean("flutter.kb_code_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla ES/EN de idioma ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    fun languageKeyVisible(): Boolean = try {
        prefs().getBoolean("flutter.kb_language_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Llavecita de credenciales en la barra superior del teclado
     * (Ajustes → Claves). Default true (visible, conducta histórica).
     */
    fun credentialsKeyVisible(): Boolean = try {
        prefs().getBoolean("flutter.kb_credentials_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * K5-T2/T3 + AT-A8: lectura UNICA por ciclo del campo (onStartInputView)
     * de las preferencias de aspecto escritas por Ajustes (archivo
     * FlutterSharedPreferences, claves con prefijo "flutter."). Parseo
     * tolerante: valor desconocido o error cae al default.
     */
    private fun readFlag(key: String, def: Boolean): Boolean =
        readFlag(prefs(), key, def)

    private fun readFlag(p: SharedPreferences, key: String, def: Boolean): Boolean = try {
        p.getBoolean(key, def)
    } catch (_: Exception) {
        def
    }

    /** Estilo '1'..'4' de sonido; cualquier otro valor cae a '3'. */
    private fun readStyle(key: String): String =
        readStyle(prefs(), key)

    private fun readStyle(p: SharedPreferences, key: String): String = try {
        p.getString(key, "3")
            ?.takeIf { it == "1" || it == "2" || it == "3" || it == "4" }
            ?: "3"
    } catch (_: Exception) {
        "3"
    }

    /**
     * Carga de preferencias desde SharedPreferences.
     * C-08: se ejecuta únicamente al cambiar de campo (onStartInputView con restarting=false
     * o cambio de paquete/campo). En restarts sobre el mismo campo se preserva la caché
     * en memoria para no golpear I/O ni reconstruir vistas.
     * C-12: Abre y referencia SharedPreferences una única vez por llamada a load().
     */
    fun load() {
        val p = prefs()
        heightFactor = try {
            when (p.getString("flutter.kb_height_profile", HEIGHT_PROFILE_MEDIA)) {
                HEIGHT_PROFILE_BAJA -> HEIGHT_FACTOR_BAJA
                HEIGHT_PROFILE_ALTA -> HEIGHT_FACTOR_ALTA
                HEIGHT_PROFILE_MUY_ALTA -> HEIGHT_FACTOR_MUY_ALTA
                else -> HEIGHT_FACTOR_MEDIA
            }
        } catch (_: Exception) {
            HEIGHT_FACTOR_MEDIA
        }
        hapticsEnabled = try {
            p.getBoolean("flutter.kb_haptics_enabled", true)
        } catch (_: Exception) {
            true
        }
        micHapticsEnabled = readFlag("flutter.kb_mic_haptics_enabled", true)
        micHapticStart = readFlag("flutter.kb_mic_haptic_start", true)
        micHapticRecording = readFlag("flutter.kb_mic_haptic_recording", true)
        micHapticPaste = readFlag("flutter.kb_mic_haptic_paste", true)
        micHapticCancel = readFlag("flutter.kb_mic_haptic_cancel", true)
        micSoundsEnabled = readFlag("flutter.kb_mic_sounds_enabled", false)
        micStartStyle = readStyle("flutter.kb_mic_start_style")
        micStopStyle = readStyle("flutter.kb_mic_stop_style")
        bottomElevationDp = try {
            val raw = p.all["flutter.kb_bottom_elevation_dp"]
            val v = when (raw) {
                is Long -> raw.toInt()
                is Int -> raw
                is Number -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 24
                else -> 24
            }
            v.coerceIn(0, 64)
        } catch (_: Exception) {
            24
        }
        sttKeyConfigured = try {
            p.getBoolean("flutter.kb_stt_key_configured", false)
        } catch (_: Exception) {
            false
        }
        invertToolbar = try {
            p.getBoolean("flutter.kb_invert_toolbar", false)
        } catch (_: Exception) {
            false
        }
        spacebarAlignment = try {
            val v = p.getString("flutter.kb_spacebar_alignment", "center") ?: "center"
            if (v in listOf("left", "center", "right")) v else "center"
        } catch (_: Exception) {
            "center"
        }
        spacebarTrackpadMode = try {
            val v = p.getString("flutter.kb_spacebar_trackpad_mode", "ios_2d") ?: "ios_2d"
            if (v in listOf("ios_2d", "gboard_horizontal")) v else "ios_2d"
        } catch (_: Exception) {
            "ios_2d"
        }
        terminalRowVisiblePref = try { p.getBoolean("flutter.kb_terminal_row_visible", true) } catch (_: Exception) { true }
        codeKeyVisiblePref = try { p.getBoolean("flutter.kb_code_key_visible", true) } catch (_: Exception) { true }
        languageKeyVisiblePref = try { p.getBoolean("flutter.kb_language_key_visible", true) } catch (_: Exception) { true }
        credentialsKeyVisiblePref = try { p.getBoolean("flutter.kb_credentials_key_visible", true) } catch (_: Exception) { true }
        clipboardImagesEnabled = try {
            p.getBoolean("flutter.kb_clipboard_images_enabled", false)
        } catch (_: Exception) {
            false
        }
        keySpacing = try {
            p.getString("flutter.kb_key_spacing", SPACING_PROFILE_NORMAL)
                ?.takeIf { it == SPACING_PROFILE_COMPACTO || it == SPACING_PROFILE_NORMAL || it == SPACING_PROFILE_AMPLIO || it == SPACING_PROFILE_EXTRA }
                ?: SPACING_PROFILE_NORMAL
        } catch (_: Exception) {
            SPACING_PROFILE_NORMAL
        }
        keySpacingFactor = when (keySpacing) {
            SPACING_PROFILE_COMPACTO -> SPACING_FACTOR_COMPACTO
            SPACING_PROFILE_AMPLIO -> SPACING_FACTOR_AMPLIO
            SPACING_PROFILE_EXTRA -> SPACING_FACTOR_EXTRA
            else -> SPACING_FACTOR_NORMAL
        }
        hapticStyle = try {
            p.getString("flutter.kb_haptic_style", HAPTIC_STYLE_NITIDO)
                ?.takeIf { it == HAPTIC_STYLE_NITIDO || it == HAPTIC_STYLE_FIRME || it == HAPTIC_STYLE_SUAVE }
                ?: HAPTIC_STYLE_NITIDO
        } catch (_: Exception) {
            HAPTIC_STYLE_NITIDO
        }

        // MEJ-09: lectura de preferencias del trackpad con whitelists y clamps de contrato (C-19)
        trackpadButtonLayout = try {
            val v = p.getString("flutter.kb_trackpad_button_layout", "top") ?: "top"
            if (v in listOf("top", "wings")) v else "top"
        } catch (_: Exception) {
            "top"
        }
        trackpadEnabled = try {
            p.getBoolean("flutter.kb_trackpad_enabled", false)
        } catch (_: Exception) {
            false
        }
        trackpadToolbarVisible = try {
            p.getBoolean("flutter.kb_trackpad_toolbar_visible", false)
        } catch (_: Exception) {
            false
        }
        trackpadScrollPosition = try {
            val v = p.getString("flutter.kb_trackpad_scroll_position", "right") ?: "right"
            if (v in listOf("right", "left", "disabled")) v else "right"
        } catch (_: Exception) {
            "right"
        }
        trackpadSensitivity = try {
            val raw = p.all["flutter.kb_trackpad_sensitivity"]
            val v = when (raw) {
                is Float -> raw
                is Double -> raw.toFloat()
                is Number -> raw.toFloat()
                is String -> raw.toFloatOrNull() ?: 1.2f
                else -> 1.2f
            }
            v.coerceIn(0.5f, 2.5f)
        } catch (_: Exception) {
            1.2f
        }
        trackpadAccelCurve = try {
            val v = p.getString("flutter.kb_trackpad_accel_curve", "dynamic") ?: "dynamic"
            if (v in listOf("dynamic", "linear", "precision")) v else "dynamic"
        } catch (_: Exception) {
            "dynamic"
        }
        trackpadTapToClick = try {
            p.getBoolean("flutter.kb_trackpad_tap_to_click", true)
        } catch (_: Exception) {
            true
        }
        trackpadSecondaryClick = try {
            val v = p.getString("flutter.kb_trackpad_secondary_click", "2fingers") ?: "2fingers"
            if (v in listOf("2fingers", "button", "hold")) v else "2fingers"
        } catch (_: Exception) {
            "2fingers"
        }
        trackpadScrollDirection = try {
            val v = p.getString("flutter.kb_trackpad_scroll_direction", "natural") ?: "natural"
            if (v in listOf("natural", "standard")) v else "natural"
        } catch (_: Exception) {
            "natural"
        }
        trackpadHaptic = try {
            val v = p.getString("flutter.kb_trackpad_haptic", "subtle") ?: "subtle"
            if (v in listOf("subtle", "none", "firm")) v else "subtle"
        } catch (_: Exception) {
            "subtle"
        }
        trackpadPointerStyle = try {
            val v = p.getString("flutter.kb_trackpad_pointer_style", "arrow") ?: "arrow"
            if (v in listOf("arrow", "dot", "cross")) v else "arrow"
        } catch (_: Exception) {
            "arrow"
        }
        trackpadAutoReturn = try {
            val raw = p.all["flutter.kb_trackpad_auto_return"]
            val v = when (raw) {
                is Number -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
            if (v in listOf(0, 5, 15, 30)) v else 0
        } catch (_: Exception) {
            0
        }
        // MEJ-05: menús de pulsación larga + retardo (parseo tolerante).
        longPressSymbolsEnabled = try {
            p.getBoolean("flutter.kb_long_press_symbols", true)
        } catch (_: Exception) {
            true
        }
        longPressDelay = try {
            p.getString("flutter.kb_long_press_delay", LONG_PRESS_DELAY_NORMAL)
                ?.takeIf { it == LONG_PRESS_DELAY_RAPIDO || it == LONG_PRESS_DELAY_NORMAL || it == LONG_PRESS_DELAY_RELAJADO }
                ?: LONG_PRESS_DELAY_NORMAL
        } catch (_: Exception) {
            LONG_PRESS_DELAY_NORMAL
        }
        longPressDelayMs = longPressDelayMillis(longPressDelay)
    }
}
