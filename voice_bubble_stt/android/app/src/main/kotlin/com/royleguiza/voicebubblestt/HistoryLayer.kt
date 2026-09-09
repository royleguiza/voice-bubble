package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Capa Historial (SPK-05, módulo 9 de N): ventana con las últimas
 * transcripciones para insertar una en el cursor, extraída de
 * VoiceKeyboardService sin cambiar conducta. Todo lo que necesita del
 * teclado entra por [service] (contexto/sistema) y [host]; el popup es
 * compartido vía [UiHost.takePopup] para no pelear con acentos/centrados.
 * PRIVACIDAD: el contenido jamás se registra en Log; la ventana vive solo
 * en memoria y se cierra al insertar o tocar afuera.
 */
class HistoryLayer(
    private val service: InputMethodService,
    private val host: UiHost,
) {

    /** Lo mínimo que el historial exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun isAlive(): Boolean
        fun dimenPx(resId: Int): Int
        fun haptic(view: View)
        fun commitText(text: String)
        fun rootView(): LinearLayout
        fun takePopup(popup: PopupWindow?)
        fun currentPopup(): PopupWindow?
        fun dismissPopups()
    }

    fun show(anchor: View, repo: TranscriptionHistoryRepository?) {
        // I/O fuera del main (disco vía repo); la construcción vuelve al
        // main con la vista vigente.
        BackgroundWork.executeWithResult(
            block = { loadEntries(repo) },
            onResult = { entries -> build(anchor, entries ?: emptyList()) },
        )
    }

    fun dismiss() {
        host.dismissPopups()
    }

    private fun loadEntries(repo: TranscriptionHistoryRepository?): List<JSONObject> {
        return try {
            repo?.loadHistory() ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun build(anchor: View, entries: List<JSONObject>) {
        if (!host.isAlive()) return
        val pad = host.dimenPx(R.dimen.kb_popup_padding)

        val box = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad, pad, pad, pad)
        }

        val header = TextView(service).apply {
            text = if (host.isSpanish()) "Historial de transcripciones" else "Transcription history"
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            alpha = 0.75f
            setPadding(pad * 2, pad, pad * 2, pad)
        }
        box.addView(header)

        val headerSep = View(service).apply {
            setBackgroundColor(ContextCompat.getColor(service, R.color.kb_key_stroke))
        }
        box.addView(
            headerSep,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, service.resources.displayMetrics).toInt(),
            ),
        )

        val content = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
        }

        var count = 0
        for (obj in entries) {
            val text = obj.optString("text")
            if (text.isBlank()) continue
            if (count > 0) {
                val sep = View(service).apply {
                    setBackgroundColor(ContextCompat.getColor(service, R.color.kb_key_stroke))
                }
                content.addView(
                    sep,
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, service.resources.displayMetrics).toInt(),
                    ),
                )
            }
            count++
            val tv = TextView(service).apply {
                this.text = text
                maxLines = 2
                ellipsize = TextUtils.TruncateAt.END
                isClickable = true
                isFocusable = true
                setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
                setBackgroundResource(R.drawable.kb_menu_item)
                setTextColor(ContextCompat.getColor(service, R.color.kb_label))
                setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
                setOnClickListener {
                    host.haptic(this)
                    host.commitText(text)
                    host.dismissPopups()
                }
            }
            content.addView(tv)
        }

        if (count == 0) {
            val empty = TextView(service).apply {
                this.text = if (host.isSpanish()) "Sin transcripciones todavía." else "No transcriptions yet."
                gravity = Gravity.CENTER
                setPadding(pad * 2, pad * 4, pad * 2, pad * 4)
                setTextColor(ContextCompat.getColor(service, R.color.kb_label))
                setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            }
            content.addView(empty)
        }

        val scroll = ScrollView(service).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = true
            scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
            addView(content)
        }
        val scrollLp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        box.addView(scroll, scrollLp)

        val dm = service.resources.displayMetrics
        val minHeightPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 220f, dm).toInt()
        val maxHeightPx = (dm.heightPixels * 0.45f).toInt().coerceAtLeast(minHeightPx)

        box.measure(
            View.MeasureSpec.makeMeasureSpec((dm.widthPixels * 0.85f).toInt(), View.MeasureSpec.AT_MOST),
            View.MeasureSpec.UNSPECIFIED,
        )

        val popupHeight = box.measuredHeight.coerceIn(minHeightPx, maxHeightPx)
        val desiredWidthPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 320f, dm).toInt()
        val gap = host.dimenPx(R.dimen.kb_key_gap)
        val maxAllowedWidth = dm.widthPixels - (gap * 2)
        val popupWidth = minOf(desiredWidthPx, maxAllowedWidth)

        val popup = PopupWindow(box, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = R.style.VoiceHistoryPopupAnimation
        }

        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val anchorCenterX = loc[0] + anchor.width / 2
        val rawX = if (anchorCenterX > dm.widthPixels / 2) {
            loc[0] + anchor.width - popupWidth
        } else {
            loc[0]
        }
        val posX = rawX.coerceIn(gap, dm.widthPixels - popupWidth - gap)
        val posY = maxOf(gap, loc[1] - popupHeight - gap)

        val isRightAligned = (posX + popupWidth / 2) > (dm.widthPixels / 2)
        box.pivotX = if (isRightAligned) popupWidth.toFloat() else 0f
        box.pivotY = popupHeight.toFloat()
        box.alpha = 0f
        box.scaleX = 0.8f
        box.scaleY = 0.8f

        host.takePopup(popup)
        // El ancla puede haberse desmontado mientras cargaba el historial
        // en fondo (rebuild en el medio): sin ventana no hay popup.
        try {
            popup.showAtLocation(host.rootView(), Gravity.NO_GRAVITY, posX, posY)
        } catch (_: Exception) {
            host.takePopup(null)
            return
        }

        box.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(200)
            .setInterpolator(android.view.animation.DecelerateInterpolator(1.8f))
            .start()
    }
}
