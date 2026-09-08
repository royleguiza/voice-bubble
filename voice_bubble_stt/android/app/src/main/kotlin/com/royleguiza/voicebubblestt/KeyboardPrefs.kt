package com.royleguiza.voicebubblestt

import android.content.Context

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

    // AT-A8: cache de visibilidad; rebuild jamas consulta SharedPreferences.
    var terminalRowVisiblePref = true
    var codeKeyVisiblePref = true
    var languageKeyVisiblePref = true

    // --- Modo Trackpad y Puntero Virtual (MEJ-09) ---
    var trackpadEnabled = true
    var trackpadToolbarVisible = true
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

    /**
     * Preferencia escrita por los Ajustes de la app (Flutter shared_preferences
     * guarda con prefijo "flutter." en el archivo FlutterSharedPreferences).
     * Parseo tolerante: ante cualquier error se muestra la fila (default true).
     */
    fun terminalRowVisible(): Boolean = try {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_terminal_row_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla "</>" de capa codigo ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    fun codeKeyVisible(): Boolean = try {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_code_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla ES/EN de idioma ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    fun languageKeyVisible(): Boolean = try {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_language_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * K5-T2/T3 + AT-A8: lectura UNICA por ciclo del campo (onStartInputView)
     * de las preferencias de aspecto escritas por Ajustes (archivo
     * FlutterSharedPreferences, claves con prefijo "flutter."). Parseo
     * tolerante: valor desconocido o error cae al default.
     */
    fun load() {
        heightFactor = try {
            when (
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString("flutter.kb_height_profile", HEIGHT_PROFILE_MEDIA)
            ) {
                HEIGHT_PROFILE_BAJA -> HEIGHT_FACTOR_BAJA
                HEIGHT_PROFILE_ALTA -> HEIGHT_FACTOR_ALTA
                HEIGHT_PROFILE_MUY_ALTA -> HEIGHT_FACTOR_MUY_ALTA
                else -> HEIGHT_FACTOR_MEDIA
            }
        } catch (_: Exception) {
            HEIGHT_FACTOR_MEDIA
        }
        hapticsEnabled = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_haptics_enabled", true)
        } catch (_: Exception) {
            true
        }
        bottomElevationDp = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getLong("flutter.kb_bottom_elevation_dp", 24L).toInt()
        } catch (_: Exception) {
            24
        }
        invertToolbar = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_invert_toolbar", false)
        } catch (_: Exception) {
            false
        }
        spacebarAlignment = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_spacebar_alignment", "center") ?: "center"
        } catch (_: Exception) {
            "center"
        }
        spacebarTrackpadMode = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_spacebar_trackpad_mode", "ios_2d") ?: "ios_2d"
        } catch (_: Exception) {
            "ios_2d"
        }
        terminalRowVisiblePref = terminalRowVisible()
        codeKeyVisiblePref = codeKeyVisible()
        languageKeyVisiblePref = languageKeyVisible()

        // MEJ-09: lectura de preferencias del trackpad
        trackpadButtonLayout = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_button_layout", "top") ?: "top"
        } catch (_: Exception) {
            "top"
        }
        trackpadEnabled = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_trackpad_enabled", true)
        } catch (_: Exception) {
            true
        }
        trackpadToolbarVisible = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_trackpad_toolbar_visible", true)
        } catch (_: Exception) {
            true
        }
        trackpadScrollPosition = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_scroll_position", "right") ?: "right"
        } catch (_: Exception) {
            "right"
        }
        trackpadSensitivity = try {
            val p = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = p.all["flutter.kb_trackpad_sensitivity"]
            when (raw) {
                is Float -> raw
                is Double -> raw.toFloat()
                is Number -> raw.toFloat()
                is String -> raw.toFloatOrNull() ?: 1.2f
                else -> 1.2f
            }
        } catch (_: Exception) {
            1.2f
        }
        trackpadAccelCurve = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_accel_curve", "dynamic") ?: "dynamic"
        } catch (_: Exception) {
            "dynamic"
        }
        trackpadTapToClick = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_trackpad_tap_to_click", true)
        } catch (_: Exception) {
            true
        }
        trackpadSecondaryClick = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_secondary_click", "2fingers") ?: "2fingers"
        } catch (_: Exception) {
            "2fingers"
        }
        trackpadScrollDirection = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_scroll_direction", "natural") ?: "natural"
        } catch (_: Exception) {
            "natural"
        }
        trackpadHaptic = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_haptic", "subtle") ?: "subtle"
        } catch (_: Exception) {
            "subtle"
        }
        trackpadPointerStyle = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_trackpad_pointer_style", "arrow") ?: "arrow"
        } catch (_: Exception) {
            "arrow"
        }
        trackpadAutoReturn = try {
            val p = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = p.all["flutter.kb_trackpad_auto_return"]
            when (raw) {
                is Number -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }
}
