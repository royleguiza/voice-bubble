package com.royleguiza.voicebubblestt

import android.graphics.Typeface
import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Fábrica de teclas (SPK-05, módulo 14 de N): constructores de teclas de
 * texto, icono y filas QWERTY/símbolos/código, extraídos de
 * VoiceKeyboardService sin cambiar conducta. Todo lo que necesita del
 * teclado entra por [service] (contexto/sistema) y [host]; los commits
 * concretos entran por el host (cada capa comite distinto) y el registro
 * visual (mayúsculas, shift) vuelve al servicio. PRIVACIDAD: nada se
 * registra en Log.
 */
class KeyFactory(
    private val service: InputMethodService,
    private val host: UiHost,
) {

    /** Lo mínimo que la fábrica exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun dimenPx(resId: Int): Int
        fun keyHeightPx(): Int
        fun displayLetter(base: Char): String
        fun haptic(view: View)
        fun attachTap(view: View, onTap: () -> Unit)
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun attachAccentKey(key: TextView, base: Char, onTapUp: () -> Unit)
        fun attachPairKey(
            key: TextView,
            ch: Char,
            onCommit: (String) -> Unit,
            onAutoPair: (Char, Char) -> Unit,
        )
        fun attachBackspaceKey(key: View, action: () -> Unit)
        fun commitLetterKey(base: Char)
        fun commitSymbolKey(text: String)
        fun commitText(text: String)
        fun sendCode(code: Int)
        fun deleteBackward()
        fun trackLetterKey(key: TextView, base: Char)
        fun trackShiftKey(key: ImageView)
        fun toggleShiftKey()
    }

    fun horizontalRow(): LinearLayout {
        val row = LinearLayout(service)
        row.orientation = LinearLayout.HORIZONTAL
        return row
    }

    fun letterRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeLetterKey(c))
        }
        return row
    }

    fun symbolRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeSymbolKey(c.toString()))
        }
        return row
    }

    fun codeRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeCodeKey(c))
        }
        return row
    }

    fun makeLetterKey(base: Char): TextView {
        val key = makeKey(
            host.displayLetter(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            host.dimenPx(R.dimen.kb_key_text_size),
        )
        if (accentsFor(base).isEmpty()) {
            host.attachTap(key) { host.commitLetterKey(base) }
        } else {
            host.attachAccentKey(key, base) { host.commitLetterKey(base) }
        }
        host.trackLetterKey(key, base)
        return key
    }

    fun makeSymbolKey(
        label: String,
        textSizePx: Int = host.dimenPx(R.dimen.kb_key_text_size_small),
        isBold: Boolean = false,
    ): TextView {
        val key = makeKey(
            label,
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            textSizePx,
            isBold = isBold,
        )
        key.contentDescription = label
        host.attachTap(key) { host.commitSymbolKey(label) }
        return key
    }

    /** Tecla de capa código: toque corto el símbolo, toque largo el par
     *  cerrado (solo si existe pareja; si no, tap plano). */
    fun makeCodeKey(ch: Char): TextView {
        val key = makeKey(
            ch.toString(),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            host.dimenPx(R.dimen.kb_key_text_size_small),
        )
        key.contentDescription = ch.toString()
        host.attachPairKey(
            key,
            ch,
            onCommit = { host.commitSymbolKey(it) },
            onAutoPair = { open, close ->
                host.commitText("$open$close")
                host.sendCode(android.view.KeyEvent.KEYCODE_DPAD_LEFT)
            },
        )
        return key
    }

    fun makeSpecialKey(
        label: String,
        bgRes: Int,
        weight: Float,
        description: String?,
        textSizePx: Int = host.dimenPx(R.dimen.kb_key_text_size_small),
        isBold: Boolean = true,
        onClick: () -> Unit,
    ): TextView {
        val key = makeKey(
            label,
            weight,
            bgRes,
            R.color.kb_label,
            textSizePx,
            isBold = isBold,
        )
        if (description != null) {
            key.contentDescription = description
        }
        host.attachTap(key, onClick)
        return key
    }

    fun makeActionIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(service)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(service, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        val lp = LinearLayout.LayoutParams(0, host.keyHeightPx(), weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        host.attachTap(key, onClick)
        return key
    }

    fun makeBackspaceKey(): ImageView {
        val key = makeActionIconKey(
            R.drawable.ic_backspace,
            R.drawable.kb_key_alt,
            1.3f,
            if (host.isSpanish()) "borrar" else "delete",
            tintColorRes = R.color.kb_label,
        ) {
            host.deleteBackward()
        }
        host.attachBackspaceKey(key) {
            host.deleteBackward()
        }
        return key
    }

    fun makeIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(service)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(service, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        key.setPadding(0, 0, 0, 0)

        val hPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, service.resources.displayMetrics).toInt()
        val lp = LinearLayout.LayoutParams(0, hPx, weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, m, m, m)
        key.layoutParams = lp

        host.attachTap(key, onClick)
        return key
    }

    fun makeKey(
        label: String,
        weight: Float,
        bgRes: Int,
        colorRes: Int,
        textSizePx: Int,
        isBold: Boolean = false,
    ): TextView {
        val key = TextView(service)
        key.text = label
        key.gravity = Gravity.CENTER
        key.isClickable = true
        key.isFocusable = true
        key.includeFontPadding = false
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setTextColor(ContextCompat.getColor(service, colorRes))
        key.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSizePx.toFloat())
        if (isBold) {
            key.setTypeface(null, Typeface.BOLD)
        }
        val lp = LinearLayout.LayoutParams(0, host.keyHeightPx(), weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        return key
    }
}
