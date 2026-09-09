package com.royleguiza.voicebubblestt

import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Status (SPK-05, módulo 10 de N): aviso inline no bloqueante con
 * auto-descarte, extraída de VoiceKeyboardService sin cambiar conducta.
 * Todo lo que necesita del teclado entra por [service], [handler] y
 * [host]; el estado (vista, mensaje, timer) es suyo. PRIVACIDAD: solo
 * muestra mensajes operativos (nunca contenido dictado ni tecleado).
 */
class StatusLayer(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {

    /** Lo mínimo que el aviso exige al teclado. */
    interface UiHost {
        fun rootView(): LinearLayout
        fun currentInputView(): View?
        fun dimenPx(resId: Int): Int
    }

    private var statusRowView: TextView? = null
    private var statusMessage: String? = null
    private var dismissStatusRunnable: Runnable? = null

    /** Aviso inline no bloqueante; auto-descarta a los 3.5 s. */
    fun show(message: String, openSettingsOnClick: Boolean = false) {
        val view = host.rootView()
        view.post {
            // AT-A9: identidad contra la vista vigente; una vista vieja ya
            // reemplazada nunca crea ni borra avisos.
            if (view !== host.currentInputView()) return@post
            // AT-A9: un aviso identico aun vivo conserva su timer original.
            if (message == statusMessage && statusRowView != null) return@post
            hide()
            val tv = TextView(service)
            tv.text = message
            tv.gravity = Gravity.CENTER
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            val pad = host.dimenPx(R.dimen.kb_popup_padding)
            tv.setPadding(pad, pad, pad, pad)
            tv.setBackgroundResource(R.drawable.kb_popup_bg)
            tv.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            if (openSettingsOnClick) {
                tv.isClickable = true
                tv.setOnClickListener { service.openAppUi() }
            }
            statusMessage = message
            statusRowView = tv
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            lp.bottomMargin = host.dimenPx(R.dimen.kb_key_gap)
            view.addView(tv, 0, lp)
            val dismiss = Runnable { hide() }
            dismissStatusRunnable = dismiss
            handler.postDelayed(dismiss, 3500L)
        }
    }

    fun hide() {
        dismissStatusRunnable?.let { handler.removeCallbacks(it) }
        dismissStatusRunnable = null
        statusMessage = null
        statusRowView?.let {
            (it.parent as? ViewGroup)?.removeView(it)
        }
        statusRowView = null
    }
}
