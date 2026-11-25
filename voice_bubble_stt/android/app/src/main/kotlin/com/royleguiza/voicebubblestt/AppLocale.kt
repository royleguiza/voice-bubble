package com.royleguiza.voicebubblestt

import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import java.util.Locale

/**
 * Idioma de la app (Ruta IA, etapa 4). Una sola fuente de verdad:
 * - Android 13+: el «idioma por app» del sistema (`LocaleManager`), que
 *   también se cambia en Ajustes del sistema › Apps › Idioma y que Android
 *   aplica a todo el proceso (teclado, burbuja, widget, notificaciones).
 * - Android 9–12: la clave del puente `kb_app_locale` que guarda Flutter;
 *   los servicios envuelven su contexto con [wrap].
 * Valores: `sistema` (el del teléfono) o `es` / `en` / `pt`.
 */
object AppLocale {
    const val PREF_KEY = "flutter.kb_app_locale"
    const val SYSTEM = "sistema"
    private val SUPPORTED = setOf("es", "en", "pt")

    /** Lo que eligió el usuario en la app (Android 9–12 lo usa para [wrap]). */
    fun stored(context: Context): String {
        val raw = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString(PREF_KEY, SYSTEM)
        } catch (_: Exception) {
            SYSTEM
        }
        return if (raw in SUPPORTED) raw!! else SYSTEM
    }

    /** Android 13+: guarda el idioma por app (vacío = el del teléfono). */
    fun apply(context: Context, tag: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val lm = context.getSystemService(LocaleManager::class.java) ?: return
        lm.applicationLocales =
            if (tag in SUPPORTED) LocaleList.forLanguageTags(tag) else LocaleList.getEmptyLocaleList()
    }

    /**
     * Android 13+: el idioma por app que tiene guardado el sistema
     * (`sistema` si sigue al teléfono). `null` en Android 9–12.
     */
    fun current(context: Context): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        val lm = context.getSystemService(LocaleManager::class.java) ?: return null
        val list = lm.applicationLocales
        if (list.isEmpty) return SYSTEM
        val lang = list[0].language
        return if (lang in SUPPORTED) lang else SYSTEM
    }

    /**
     * Contexto con el idioma elegido para Android 9–12 (en 13+ lo pone el
     * sistema y se devuelve [base] tal cual). Para `attachBaseContext`.
     */
    fun wrap(base: Context): Context {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return base
        val tag = stored(base)
        if (tag == SYSTEM) return base
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag))
        return base.createConfigurationContext(config)
    }

    /**
     * Idioma en el que se ve la app ahora (código de dos letras): el elegido
     * en Ajustes o, con «sistema», el del teléfono. Sirve para que el
     * teclado (Ñ o no) y el dictado sigan a la app mientras el usuario no
     * elija otra cosa a mano.
     */
    fun effectiveLanguage(context: Context): String {
        val chosen = current(context) ?: stored(context)
        if (chosen in SUPPORTED) return chosen
        return try {
            context.resources.configuration.locales[0].language
        } catch (_: Exception) {
            Locale.getDefault().language
        }
    }
}
