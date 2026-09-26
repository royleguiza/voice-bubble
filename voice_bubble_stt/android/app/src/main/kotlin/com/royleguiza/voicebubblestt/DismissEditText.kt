package com.royleguiza.voicebubblestt

import android.content.Context
import android.util.AttributeSet
import android.view.KeyEvent
import android.widget.EditText

/**
 * EditText que avisa al host cuando el usuario pulsa atrás con el teclado
 * visible: [onKeyPreIme] corre antes de que el IME consuma el evento, así
 * que la modal del widget puede cerrar igual que la X en un solo gesto
 * (sin el IME de por medio, el atrás llegaría a la activity y el primer
 * toque solo minimizaría el teclado).
 */
class DismissEditText @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : EditText(context, attrs) {

    var onBackWhileEditing: (() -> Unit)? = null

    override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
            try {
                onBackWhileEditing?.invoke()
            } catch (_: Exception) {
            }
            return true
        }
        return super.onKeyPreIme(keyCode, event)
    }
}

/** Máximo del cuerpo expandible: lo visible menos el cromo. Puro (C-40). */
internal fun computeBodyMaxPx(
    rootH: Int,
    rootPadBottom: Int,
    chromeH: Int,
    marginPx: Int,
    topPx: Int,
    minPx: Int,
): Int {
    if (rootH <= 0 || chromeH < 0 || minPx <= 0) return minPx
    return maxOf(minPx, rootH - rootPadBottom - chromeH - marginPx - topPx)
}

/** Clamp del alto deseado al rango vigente. Puro (C-40). */
internal fun clampBodyHeight(want: Int, minPx: Int, maxPx: Int): Int {
    if (minPx <= 0) return want
    return want.coerceIn(minPx, maxOf(minPx, maxPx))
}
