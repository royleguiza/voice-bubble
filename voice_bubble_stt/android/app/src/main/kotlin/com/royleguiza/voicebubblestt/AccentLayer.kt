package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Acentos (SPK-05, módulo 11 de N): popup de tildes por toque largo
 * y pares auto-cerrados de la capa código, extraída de
 * VoiceKeyboardService sin cambiar conducta. Todo lo que necesita del
 * teclado entra por [service] (contexto/sistema) y [host]; el commit
 * concreto de cada tecla entra por lambdas del llamador (letras, símbolos
 * y snippets comiten distinto). El popup comparte [UiHost.takePopup] con
 * el resto de ventanas. PRIVACIDAD: nada se registra en Log.
 */
class AccentLayer(
    private val service: InputMethodService,
    private val host: UiHost,
) {

    /** Lo mínimo que los acentos exigen al teclado. */
    interface UiHost {
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun haptic(view: View)
        fun commitText(text: String)
        fun dimenPx(resId: Int): Int
        fun rootView(): LinearLayout
        fun takePopup(popup: PopupWindow?)
        fun dismissPopups()
    }

    /** Letra con tildes: largo abre el popup, tap delega en [onTapUp]. */
    fun attachAccent(key: TextView, base: Char, onTapUp: () -> Unit) {
        host.attachPress(
            key,
            onLongPress = {
                host.haptic(key)
                showPopup(key, base)
            },
            onTapUp = onTapUp,
        )
    }

    /** Símbolo de código: largo inserta el par cerrado (solo si hay pareja;
     *  AT-A11: sin pareja el toque es un click plano con el mismo commit). */
    fun attachPair(
        key: TextView,
        ch: Char,
        onCommit: (String) -> Unit,
        onAutoPair: (Char, Char) -> Unit,
    ) {
        val close = pairCloseFor(ch)
        if (close == null) {
            key.setOnClickListener { onCommit(ch.toString()) }
            return
        }
        host.attachPress(
            key,
            onLongPress = { onAutoPair(ch, close) },
            onTapUp = { onCommit(ch.toString()) },
        )
    }

    fun showPopup(anchor: View, base: Char) {
        host.dismissPopups()
        val options = accentsFor(base)
        if (options.isEmpty()) return
        val box = LinearLayout(service)
        box.orientation = LinearLayout.HORIZONTAL
        box.setBackgroundResource(R.drawable.kb_popup_bg)
        val pad = host.dimenPx(R.dimen.kb_popup_padding)
        box.setPadding(pad, pad, pad, pad)
        for (opt in options) {
            val tv = TextView(service)
            tv.text = opt
            tv.gravity = Gravity.CENTER
            tv.isClickable = true
            tv.isFocusable = true
            tv.setPadding(pad * 2, pad, pad * 2, pad)
            tv.setBackgroundResource(R.drawable.kb_menu_item)
            tv.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size).toFloat())
            tv.setOnClickListener {
                host.haptic(it)
                host.commitText(opt)
                host.dismissPopups()
            }
            box.addView(tv)
        }
        val popup = PopupWindow(
            box,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            true,
        )
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        box.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val gap = host.dimenPx(R.dimen.kb_key_gap)
        host.takePopup(popup)
        popup.showAtLocation(
            host.rootView(),
            Gravity.NO_GRAVITY,
            loc[0],
            // AT-A12: jamas Y negativo; si no cabe arriba se solapa con el ancla.
            maxOf(gap, loc[1] - box.measuredHeight - gap),
        )
    }
}
