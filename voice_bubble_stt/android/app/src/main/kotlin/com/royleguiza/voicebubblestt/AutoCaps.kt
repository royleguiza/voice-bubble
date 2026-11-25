package com.royleguiza.voicebubblestt

import android.text.InputType

/**
 * T6 (K2) · Mayúscula automática. Lógica pura: qué campos la admiten.
 *
 * La decisión de cuándo poner mayúscula la toma Android con
 * `InputConnection.getCursorCapsMode(inputType)`, que ya respeta las marcas
 * CAP_CHARACTERS / CAP_WORDS / CAP_SENTENCES del campo (un campo sin marcas,
 * como la terminal de Termux, devuelve 0 y no pide mayúscula). Acá solo se
 * descartan los campos donde nunca corresponde: contraseñas, correos y
 * direcciones web, y todo lo que no es texto.
 */
object AutoCaps {
    private val NEVER = setOf(
        InputType.TYPE_TEXT_VARIATION_PASSWORD,
        InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
        InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
        InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS,
        InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS,
        InputType.TYPE_TEXT_VARIATION_URI,
    )

    fun fieldAllows(inputType: Int): Boolean {
        if (inputType and InputType.TYPE_MASK_CLASS != InputType.TYPE_CLASS_TEXT) return false
        return (inputType and InputType.TYPE_MASK_VARIATION) !in NEVER
    }

    /** Estado del Shift después de reevaluar; [auto] = lo puso la mayúscula automática. */
    internal data class Step(val state: ShiftState, val auto: Boolean)

    /**
     * Nunca pisa el bloqueo de mayúsculas ni un Shift puesto a mano; solo
     * prende (OFF → MOMENTARY) y apaga el suyo.
     */
    internal fun next(state: ShiftState, auto: Boolean, capsMode: Int, allowed: Boolean): Step {
        if (state == ShiftState.CAPS_LOCK) return Step(state, false)
        if (state == ShiftState.MOMENTARY && !auto) return Step(state, false)
        val want = allowed && capsMode != 0
        return when {
            want && state == ShiftState.OFF -> Step(ShiftState.MOMENTARY, true)
            !want && auto -> Step(ShiftState.OFF, false)
            else -> Step(state, auto)
        }
    }
}
