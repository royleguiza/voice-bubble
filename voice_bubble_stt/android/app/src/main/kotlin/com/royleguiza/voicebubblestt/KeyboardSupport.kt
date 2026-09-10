package com.royleguiza.voicebubblestt

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.view.KeyEvent
import android.view.inputmethod.EditorInfo

/**
 * Soporte del teclado (SPK-05, módulo 1 de N): tablas puras, constantes y
 * extensiones de Context extraídas de VoiceKeyboardService SIN cambiar
 * conducta. Mismo paquete, mismos nombres y firmas: ningún call site se
 * tocó. Los módulos grandes (dictado, snippets, credenciales, clipboard,
 * trackpad, prefs) siguen en VKS hasta los próximos cortes, que moverán
 * cada uno su estado con él.
 */

// --- Constantes (antes companion privado de VKS) ---

internal const val LONG_PRESS_MILLIS = 350L

/** Autorrepeticion de ⌫ (P6): primer ciclo y aceleracion geometrica
 *  hasta el piso (250 -> 212 -> 180 ... -> 50 ms). */
internal const val REPEAT_INITIAL_DELAY_MS = 250L
internal const val REPEAT_MIN_INTERVAL_MS = 50L
internal const val REPEAT_ACCEL = 0.85f

/** Gesto ⌫ (P6): recorrido izquierdo que borra una palabra completa. */
internal const val SWIPE_DELETE_STEP_DP = 48f

/** Ventana previa examinada para hallar el limite de palabra. */
internal const val SWIPE_WORD_LOOKBACK_CHARS = 64

/** Umbral de doble pulso sobre shift para activar caps lock (P3). */
internal const val SHIFT_DOUBLE_TAP_MILLIS = 300L

/** Tope del query de busqueda de snippets. */
internal const val SNIPPET_QUERY_MAX_CHARS = 50

/** Columnas del grid de chips de snippets. */
internal const val SNIPPET_GRID_COLUMNS = 3

/** Valores del perfil de altura escritos por Ajustes (K5-T2). */
internal const val HEIGHT_PROFILE_BAJA = "baja"
internal const val HEIGHT_PROFILE_MEDIA = "media"
internal const val HEIGHT_PROFILE_ALTA = "alta"
internal const val HEIGHT_PROFILE_MUY_ALTA = "muy_alta"

/** Factores aplicados a alturas verticales propias del teclado. */
internal const val HEIGHT_FACTOR_BAJA = 0.85f
internal const val HEIGHT_FACTOR_MEDIA = 1f
internal const val HEIGHT_FACTOR_ALTA = 1.15f
internal const val HEIGHT_FACTOR_MUY_ALTA = 1.30f

/** Valores del espaciado entre teclas escritos por Ajustes (anti-fantasma). */
internal const val SPACING_PROFILE_COMPACTO = "compacto"
internal const val SPACING_PROFILE_NORMAL = "normal"
internal const val SPACING_PROFILE_AMPLIO = "amplio"
internal const val SPACING_PROFILE_EXTRA = "extra"

/** Factores aplicados a los gaps horizontales/verticales entre teclas. */
internal const val SPACING_FACTOR_COMPACTO = 0.8f
internal const val SPACING_FACTOR_NORMAL = 1f
internal const val SPACING_FACTOR_AMPLIO = 1.5f
internal const val SPACING_FACTOR_EXTRA = 2.0f

/** Valores del estilo háptico escritos por Ajustes. */
internal const val HAPTIC_STYLE_NITIDO = "nitido"
internal const val HAPTIC_STYLE_FIRME = "firme"
internal const val HAPTIC_STYLE_SUAVE = "suave"

/** Handler principal compartido: runOnMain no aloja uno por llamada. */
private val sharedMainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }

internal fun runOnMain(block: () -> Unit) {
    sharedMainHandler.post(block)
}

// --- Extensiones de Context (antes métodos privados de VKS) ---

internal fun Context.dimen(resId: Int): Int = resources.getDimensionPixelSize(resId)

internal fun Context.reducedMotion(): Boolean =
    Settings.Global.getFloat(
        contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f,
    ) == 0f

/** Abre la UI principal de la app (Ajustes) desde el teclado. */
internal fun Context.openAppUi() {
    try {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    } catch (_: Exception) {}
}

internal fun Context.copySnippetToClipboard(text: String) {
    try {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("VoiceBubble", text))
    } catch (_: Exception) {}
}

internal fun Context.showClipboardNotice(message: String) {
    try {
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    } catch (_: Exception) {}
}

// --- Tablas puras (sin estado) ---

/** Campos de contraseña: sin micrófono, snippets, trackpad ni sugerencias (K3, MEJ-09). */
internal fun isPasswordInput(info: EditorInfo?): Boolean {
    if (info == null) return false
    val variation = info.inputType and InputType.TYPE_MASK_VARIATION
    return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
        variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
        variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
        variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
}

/** Codigo de tecla fisica para combinaciones modificadoras (a-z y corchetes). */
internal fun keyCodeFor(c: Char): Int? = when {
    c in 'a'..'z' -> KeyEvent.KEYCODE_A + (c - 'a')
    c == '[' -> KeyEvent.KEYCODE_LEFT_BRACKET
    else -> null
}

internal fun accentsFor(c: Char): List<String> = when (c) {
    'a' -> listOf("á", "à", "ä", "â", "ã")
    'e' -> listOf("é", "è", "ë", "ê")
    'i' -> listOf("í", "ì", "ï", "î")
    'o' -> listOf("ó", "ò", "ö", "ô", "õ")
    'u' -> listOf("ú", "ù", "ü", "û")
    'n' -> listOf("ñ")
    'c' -> listOf("ç")
    else -> emptyList()
}

/** Par auto-cerrado para la capa codigo; null si no aplica. */
internal fun pairCloseFor(open: Char): Char? = when (open) {
    '{' -> '}'
    '[' -> ']'
    '(' -> ')'
    '<' -> '>'
    '"' -> '"'
    '\'' -> '\''
    '`' -> '`'
    else -> null
}
