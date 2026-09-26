package com.royleguiza.voicebubblestt

import android.content.Context

/**
 * Estado del modo mini (MEJ-12, micro-teclado de 2 filas): vive en el
 * archivo propio `VoiceBubbleIme` (NO en las prefs compartidas con Flutter:
 * el contrato de claves Kotlin==Dart solo cubre ese puente y el modo mini
 * es estado local del IME, no un ajuste de la app). Default: completo.
 * Parseo tolerante: ante cualquier error arranca en completo.
 * PRIVACIDAD: solo un booleano de UI, jamás contenido del usuario.
 */
class MiniModeStore(private val context: Context) {

    @Volatile
    private var cachedPrefs: android.content.SharedPreferences? = null

    /** C-12: Warm-up fuera del hilo principal. */
    fun warmUp() {
        if (cachedPrefs == null) prefs()
    }

    private fun prefs(): android.content.SharedPreferences =
        cachedPrefs ?: synchronized(this) {
            cachedPrefs ?: run {
                val p = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
                cachedPrefs = p
                p
            }
        }

    fun load(): Boolean = try {
        prefs().getBoolean(KEY_MINI_MODE, false)
    } catch (_: Exception) {
        false
    }

    fun save(enabled: Boolean) {
        try {
            prefs().edit().putBoolean(KEY_MINI_MODE, enabled).apply()
        } catch (_: Exception) {}
    }

    companion object {
        private const val PREFS_FILE = "VoiceBubbleIme"
        private const val KEY_MINI_MODE = "mini_mode"
    }
}
