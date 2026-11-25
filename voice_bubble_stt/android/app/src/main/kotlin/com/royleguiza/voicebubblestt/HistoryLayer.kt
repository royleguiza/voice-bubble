package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
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

    private var lastAnchor: View? = null
    private var lastRepo: TranscriptionHistoryRepository? = null

    fun show(anchor: View, repo: TranscriptionHistoryRepository?) {
        lastAnchor = anchor
        lastRepo = repo
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

    private fun commitOrWarn(text: CharSequence): Boolean {
        return com.royleguiza.voicebubblestt.commitOrWarn(service, text, host.isSpanish()) {
            warnDeadConnection(service, host.isSpanish())
        }
    }

    private fun loadEntries(repo: TranscriptionHistoryRepository?): List<JSONObject> {
        return try {
            repo?.loadHistory() ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun dp(v: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, service.resources.displayMetrics).toInt()

    private fun color(res: Int): Int = ContextCompat.getColor(service, res)

    /**
     * T9 (K6) · Historial nuevo: ventana de ancho completo (16 dp a cada
     * lado) que crece desde el centro del micrófono (escala 0,8 → 1 y fundido
     * de 200 ms) y vuelve a él al cerrarse. Encabezado con línea brasa y
     * contador, hora a la izquierda, divisiones con tinte brasa, 3 renglones,
     * el último dictado resaltado, ícono de copiar y pulsación larga con
     * copiar o borrar. Tocar pega y cierra.
     */
    private fun build(anchor: View, entries: List<JSONObject>) {
        if (!host.isAlive()) return
        val dm = service.resources.displayMetrics
        val side = dp(16f)
        val popupWidth = dm.widthPixels - side * 2

        val box = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            clipToOutline = true
        }

        val items = entries.filter { it.optString("text").isNotBlank() }

        // Encabezado: título, contador brasa y cerrar; línea brasa debajo.
        val header = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14f), dp(8f), dp(6f), dp(8f))
        }
        header.addView(TextView(service).apply {
            text = service.getString(R.string.kb_history_title_short)
            setTextColor(color(R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = KbFonts.body(service, strong = true)
        })
        header.addView(TextView(service).apply {
            text = items.size.toString()
            setTextColor(color(R.color.hz_ember_t))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
            typeface = KbFonts.mono(service, 500)
            background = android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = dp(999f).toFloat()
                setColor(color(R.color.hz_ember_soft))
            }
            setPadding(dp(8f), dp(1f), dp(8f), dp(1f))
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            leftMargin = dp(8f)
        })
        header.addView(View(service), LinearLayout.LayoutParams(0, 1, 1f))
        val close = ImageView(service).apply {
            setImageResource(R.drawable.ic_x)
            setColorFilter(color(R.color.kb_label_secondary))
            scaleType = ImageView.ScaleType.CENTER
            contentDescription = service.getString(R.string.kb_history_close)
            setBackgroundResource(R.drawable.kb_menu_item)
            setOnClickListener { closeTowardMic(box) }
        }
        header.addView(close, LinearLayout.LayoutParams(dp(44f), dp(40f)))
        box.addView(header)
        box.addView(
            View(service).apply { setBackgroundColor(color(R.color.hz_ember)) },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(2f)),
        )

        val content = LinearLayout(service).apply { orientation = LinearLayout.VERTICAL }
        items.forEachIndexed { index, obj ->
            if (index > 0) {
                content.addView(
                    View(service).apply { setBackgroundColor(color(R.color.kb_history_divider)) },
                    LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1f)),
                )
            }
            content.addView(buildItem(box, obj, first = index == 0))
        }
        if (items.isEmpty()) {
            content.addView(TextView(service).apply {
                text = service.getString(R.string.kb_history_empty)
                gravity = Gravity.CENTER
                setPadding(dp(16f), dp(28f), dp(16f), dp(28f))
                setTextColor(color(R.color.kb_label_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                typeface = KbFonts.body(service)
            })
        }

        val scroll = ScrollView(service).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = true
            scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
            addView(content)
        }
        box.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        val minHeightPx = dp(160f)
        val maxHeightPx = (dm.heightPixels * 0.45f).toInt().coerceAtLeast(minHeightPx)
        box.measure(
            View.MeasureSpec.makeMeasureSpec(popupWidth, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.UNSPECIFIED,
        )
        val popupHeight = box.measuredHeight.coerceIn(minHeightPx, maxHeightPx)

        val popup = PopupWindow(box, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = 0
        }

        val gap = host.dimenPx(R.dimen.kb_key_gap)
        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val posX = side
        val posY = maxOf(gap, loc[1] - popupHeight - gap)

        // Nace en el centro del micrófono (puede quedar fuera de la caja).
        box.pivotX = (loc[0] + anchor.width / 2f - posX).coerceIn(0f, popupWidth.toFloat())
        box.pivotY = (loc[1] + anchor.height / 2f - posY)
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

    /** Cierre explícito: vuelve al micrófono y recién ahí se va. */
    private fun closeTowardMic(box: View) {
        box.animate()
            .alpha(0f)
            .scaleX(0.8f)
            .scaleY(0.8f)
            .setDuration(160)
            .setInterpolator(android.view.animation.AccelerateInterpolator(1.4f))
            .withEndAction { host.dismissPopups() }
            .start()
    }

    private fun buildItem(box: View, obj: JSONObject, first: Boolean): View {
        val text = obj.optString("text")
        val timestamp = obj.optString("timestamp")
        val wrap = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            if (first) setBackgroundColor(color(R.color.kb_history_first))
        }
        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            setPadding(dp(14f), dp(10f), dp(6f), dp(10f))
            setBackgroundResource(R.drawable.kb_menu_item)
            isClickable = true
            isFocusable = true
        }
        val time = historyTimeLabel(timestamp)
        row.addView(TextView(service).apply {
            this.text = time
            setTextColor(color(R.color.hz_ember_t))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = KbFonts.mono(service, 500)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(dp(48f), ViewGroup.LayoutParams.WRAP_CONTENT))
        row.addView(TextView(service).apply {
            this.text = text
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END
            setTextColor(color(R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setLineSpacing(0f, 1.15f)
            typeface = KbFonts.body(service)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val copy = ImageView(service).apply {
            setImageResource(R.drawable.ic_copy)
            setColorFilter(color(R.color.kb_label_secondary))
            scaleType = ImageView.ScaleType.CENTER
            contentDescription = service.getString(R.string.kb_history_copy)
            setBackgroundResource(R.drawable.kb_menu_item)
            setOnClickListener {
                host.haptic(this)
                service.copySnippetToClipboard(text)
                service.showClipboardNotice(service.getString(R.string.kb_history_copied))
            }
        }
        row.addView(copy, LinearLayout.LayoutParams(dp(40f), dp(36f)))
        row.contentDescription = service.getString(R.string.kb_a11y_history_item, time, text)
        row.setOnClickListener {
            host.haptic(row)
            // C-06: con la conexión muerta el texto no se pegó: la ventana queda.
            if (commitOrWarn(text)) {
                closeTowardMic(box)
            }
        }

        // Pulsación larga: copiar o borrar, en una fila que se despliega abajo.
        val actions = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(dp(14f), 0, dp(10f), dp(10f))
            visibility = View.GONE
        }
        actions.addView(actionChip(R.string.kb_history_copy, danger = false) {
            service.copySnippetToClipboard(text)
            service.showClipboardNotice(service.getString(R.string.kb_history_copied))
            actions.visibility = View.GONE
        })
        actions.addView(actionChip(R.string.kb_history_delete, danger = true) {
            val repo = lastRepo
            val anchor = lastAnchor
            BackgroundWork.executeWithResult(
                block = { repo?.removeTranscription(text, timestamp) == true },
                onResult = { ok ->
                    if (ok == true && anchor != null && host.isAlive()) {
                        host.dismissPopups()
                        show(anchor, repo)
                    }
                },
            )
        })
        row.setOnLongClickListener {
            host.haptic(row)
            actions.visibility = if (actions.visibility == View.VISIBLE) View.GONE else View.VISIBLE
            true
        }
        wrap.addView(row)
        wrap.addView(actions)
        return wrap
    }

    private fun actionChip(label: Int, danger: Boolean, onClick: () -> Unit): TextView =
        TextView(service).apply {
            text = service.getString(label)
            setTextColor(color(if (danger) R.color.kb_danger else R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = KbFonts.body(service, strong = true)
            gravity = Gravity.CENTER
            minHeight = dp(36f)
            setPadding(dp(14f), 0, dp(14f), 0)
            background = android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = dp(999f).toFloat()
                setStroke(dp(1f), color(if (danger) R.color.kb_danger else R.color.hz_line))
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { leftMargin = dp(8f) }
            setOnClickListener { onClick() }
        }

    /** «22:13» hoy, «ayer», o «24/11» antes; vacío si la hora es ilegible. */
    private fun historyTimeLabel(timestamp: String): String {
        val instant = TranscriptionHistoryLogic.parseTimestamp(timestamp) ?: return ""
        return HistoryTime.label(
            instant,
            java.time.ZonedDateTime.now(),
            service.getString(R.string.kb_history_yesterday),
        )
    }
}

/** T9: etiqueta de hora del historial (pura, probada en HistoryTimeTest). */
internal object HistoryTime {
    fun label(instant: java.time.Instant, now: java.time.ZonedDateTime, yesterday: String): String {
        val t = instant.atZone(now.zone)
        val days = java.time.temporal.ChronoUnit.DAYS.between(t.toLocalDate(), now.toLocalDate())
        return when {
            days <= 0L -> String.format(java.util.Locale.ROOT, "%02d:%02d", t.hour, t.minute)
            days == 1L -> yesterday
            else -> String.format(java.util.Locale.ROOT, "%02d/%02d", t.dayOfMonth, t.monthValue)
        }
    }
}
