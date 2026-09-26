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
