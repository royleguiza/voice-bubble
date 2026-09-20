package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
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

    /** Puntuación MEJ-05: largo abre el menú de símbolos, tap delega.
     *  Si [enabled] es false (switch OFF en Ajustes) queda tap plano. */
    fun attachSymbol(
        key: TextView,
        base: Char,
        enabled: () -> Boolean,
        onTapUp: () -> Unit,
    ) {
        if (symbolsFor(base).isEmpty()) {
            key.setOnClickListener { onTapUp() }
            return
        }
        host.attachPress(
            key,
            onLongPress = {
                if (!enabled()) {
                    onTapUp()
                    return@attachPress
                }
                host.haptic(key)
                showSymbolsPopup(key, base)
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
        val options = accentsFor(base)
        if (options.isEmpty()) return
        showOptionsPopup(anchor, options)
    }

    /** Menú de puntuación MEJ-05: mismas reglas visuales que tildes. */
    fun showSymbolsPopup(anchor: View, base: Char) {
        val options = symbolsFor(base)
        if (options.isEmpty()) return
        showOptionsPopup(anchor, options)
    }

    /** Popup glass compartido (tildes + símbolos MEJ-05): tap en opción
     *  comite directo; deslizar sobre el menú y soltar comite la opción
     *  bajo el dedo; soltar sin moverse comite la primera (secundario
     *  predeterminado). Sin Log de contenido. */
    fun showOptionsPopup(anchor: View, options: List<String>) {
        host.dismissPopups()
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
        // MEJ-05: deslizamiento sobre el menú (estilo tildes mejorado).
        // MOVE resalta la opción bajo el dedo; UP comite la resaltada o la
        // primera si se soltó sin moverse (secundario predeterminado).
        var highlighted: TextView? = null
        fun childAt(x: Float, y: Float): TextView? {
            for (i in 0 until box.childCount) {
                val c = box.getChildAt(i) as? TextView ?: continue
                if (x >= c.left && x <= c.right && y >= c.top && y <= c.bottom) return c
            }
            return null
        }
        fun setHighlighted(tv: TextView?) {
            if (highlighted === tv) return
            try { highlighted?.isPressed = false } catch (_: Exception) {}
            highlighted = tv
            try { tv?.isPressed = true } catch (_: Exception) {}
        }
        box.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    setHighlighted(childAt(ev.x, ev.y))
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    setHighlighted(childAt(ev.x, ev.y))
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val target = childAt(ev.x, ev.y) ?: highlighted ?: (box.getChildAt(0) as? TextView)
                    val text = target?.text?.toString()
                    try { highlighted?.isPressed = false } catch (_: Exception) {}
                    highlighted = null
                    if (text != null) {
                        host.haptic(box)
                        host.commitText(text)
                    }
                    host.dismissPopups()
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    try { highlighted?.isPressed = false } catch (_: Exception) {}
                    highlighted = null
                    true
                }
                else -> false
            }
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
