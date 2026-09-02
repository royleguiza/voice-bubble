package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Typeface
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Vista de la Cinta Horizontal Deslizable (Filmstrip Reel) para el Portapapeles Multimodal.
 *
 * Implementa la Opción 2 del Laboratorio UI:
 * - Altura contenida (86dp) para no comprimir las filas de teclas.
 * - Tarjetas horizontales Liquid Glass (124dp x 74dp) con scroll inercial suave.
 * - Soporte para Badges de tipo (TXT, CODE, IMG, MATH, URL).
 * - Carga asíncrona de miniaturas con downsampling para 60/120 fps.
 * - Soporte para fijado (pin ★) y eliminación rápida.
 */
class ClipboardFilmstripLayout(
    context: Context,
    private val store: ClipboardStore,
    private val onClipClicked: (ClipboardItem) -> Unit,
    private val onClipLongClicked: (ClipboardItem, View) -> Unit,
    private val onClearClicked: () -> Unit
) : LinearLayout(context) {

    private val scrollView = HorizontalScrollView(context).apply {
        isHorizontalScrollBarEnabled = false
        overScrollMode = View.OVER_SCROLL_NEVER
    }

    private val cardsContainer = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }

    init {
        orientation = VERTICAL
        val hPx = dpToPx(86)
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, hPx)

        scrollView.addView(
            cardsContainer,
            LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT)
        )
        addView(
            scrollView,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        )
    }

    /**
     * Renderiza la lista de clips en la cinta horizontal.
     */
    fun renderClips(clips: List<ClipboardItem>) {
        cardsContainer.removeAllViews()

        if (clips.isEmpty()) {
            val emptyTv = TextView(context).apply {
                text = "Portapapeles vacío"
                setTextColor(ContextCompat.getColor(context, R.color.kb_label_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
                setPadding(dpToPx(16), 0, dpToPx(16), 0)
                gravity = Gravity.CENTER
            }
            cardsContainer.addView(emptyTv)
            return
        }

        // Botón rápido de limpieza de no-fijados
        val btnClear = createClearButton()
        cardsContainer.addView(btnClear)

        val cardWidthPx = dpToPx(124)
        val cardHeightPx = dpToPx(74)
        val marginPx = dpToPx(3)

        for (clip in clips) {
            val card = createClipCard(clip, cardWidthPx, cardHeightPx, marginPx)
            cardsContainer.addView(card)
        }
    }

    private fun createClipCard(clip: ClipboardItem, widthPx: Int, heightPx: Int, marginPx: Int): View {
        val card = LinearLayout(context).apply {
            orientation = VERTICAL
            val lp = LayoutParams(widthPx, heightPx).apply {
                setMargins(marginPx, marginPx, marginPx, marginPx)
            }
            layoutParams = lp
            setBackgroundResource(R.drawable.kb_key_bg)
            isClickable = true
            isFocusable = true
            setPadding(dpToPx(6), dpToPx(4), dpToPx(6), dpToPx(4))
        }

        // Header: Badge de tipo + Pin Indicator
        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        }

        val badge = TextView(context).apply {
            text = when (clip.type) {
                ClipType.CODE -> "</>"
                ClipType.IMAGE -> "IMG"
                ClipType.MATH -> "MATH"
                ClipType.URL -> "URL"
                ClipType.TEXT -> "TXT"
            }
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            setTypeface(Typeface.DEFAULT_BOLD)
            setTextColor(
                when (clip.type) {
                    ClipType.CODE -> ContextCompat.getColor(context, R.color.kb_key_bg_accent)
                    ClipType.IMAGE -> ContextCompat.getColor(context, R.color.kb_recording)
                    ClipType.MATH -> ContextCompat.getColor(context, R.color.kb_key_bg_accent)
                    ClipType.URL -> ContextCompat.getColor(context, R.color.kb_key_bg_accent)
                    ClipType.TEXT -> ContextCompat.getColor(context, R.color.kb_label_secondary)
                }
            )
            layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1.0f)
        }
        header.addView(badge)

        if (clip.isPinned) {
            val pinIndicator = TextView(context).apply {
                text = "★"
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                setTextColor(ContextCompat.getColor(context, R.color.kb_key_bg_accent))
            }
            header.addView(pinIndicator)
        }
        card.addView(header)

        // Cuerpo: Imagen o Texto
        if (clip.type == ClipType.IMAGE) {
            val iv = ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply {
                    topMargin = dpToPx(2)
                }
                setImageResource(R.drawable.ic_paste)
            }
            card.addView(iv)
            // Decodificación y carga asíncrona fuera del hilo principal
            store.loadThumbnailAsync(clip, widthPx, heightPx) { bmp ->
                if (bmp != null) {
                    iv.setImageBitmap(bmp)
                }
            }
        } else {
            val tv = TextView(context).apply {
                text = clip.preview ?: clip.text ?: ""
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
                maxLines = 3
                ellipsize = TextUtils.TruncateAt.END
                includeFontPadding = false
                setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                if (clip.type == ClipType.CODE) {
                    typeface = Typeface.MONOSPACE
                }
                layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply {
                    topMargin = dpToPx(2)
                }
            }
            card.addView(tv)
        }

        card.setOnClickListener { onClipClicked(clip) }
        card.setOnLongClickListener {
            onClipLongClicked(clip, card)
            true
        }

        return card
    }

    private fun createClearButton(): View {
        return TextView(context).apply {
            text = "Limpiar\nlibres"
            gravity = Gravity.CENTER
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f)
            setTypeface(Typeface.DEFAULT_BOLD)
            setTextColor(ContextCompat.getColor(context, R.color.kb_label_secondary))
            setBackgroundResource(R.drawable.kb_key_alt)
            val lp = LayoutParams(dpToPx(52), dpToPx(74)).apply {
                setMargins(dpToPx(3), dpToPx(3), dpToPx(3), dpToPx(3))
            }
            layoutParams = lp
            isClickable = true
            isFocusable = true
            setOnClickListener { onClearClicked() }
        }
    }

    private fun dpToPx(dp: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics).toInt()
}
