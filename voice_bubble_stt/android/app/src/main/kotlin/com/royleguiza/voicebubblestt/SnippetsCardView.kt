package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * SPK-11: vistas de tarjeta de snippet estilo fieldset/legend (extraído de
 * BubbleHistoryController sin cambiar conducta). Estructura gemela a
 * historial (frame[box con tag, badge]) para reutilizar selección,
 * copiar-todo y gestos del controlador.
 */
object SnippetsCardView {

    fun snippetBoxBackground(density: Float, dark: Boolean, selected: Boolean = false): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 12f * density
            if (selected) {
                setColor(Color.parseColor("#FF238636"))
                setStroke((1.5f * density).toInt(), Color.parseColor("#FF3FB950"))
            } else {
                // Caja transparente: solo el borde sutil (el fondo lo pone la modal).
                setColor(Color.TRANSPARENT)
                if (dark) {
                    setStroke((1f * density).toInt(), Color.parseColor("#26FFFFFF"))
                } else {
                    setStroke((1f * density).toInt(), Color.parseColor("#1F000000"))
                }
            }
        }
    }

    fun emptyView(context: Context, density: Float, dark: Boolean): TextView {
        return TextView(context).apply {
            text = "Sin snippets todavía. Crealos en la app."
            setTextColor(if (dark) Color.parseColor("#FFAEAEB2") else Color.parseColor("#FF6E6E73"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            val pad = (16 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }
    }

    fun buildSnippetCard(
        context: Context,
        density: Float,
        dark: Boolean,
        snippet: VbSnippet,
        key: String,
        onCopy: (card: ImageView) -> Unit,
        onEdit: () -> Unit,
        onAttach: (box: LinearLayout, tv: TextView, badge: ImageView) -> Unit,
    ): View {
        val frame = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                val mV = (3 * density).toInt()
                setMargins(0, mV, 0, mV)
            }
        }
        val box = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = snippetBoxBackground(density, dark)
            val padH = (12 * density).toInt()
            // Arriba hay aire para que la leyenda muerda el borde a la mitad.
            setPadding(padH, (14 * density).toInt(), padH, (10 * density).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                // La mitad de la leyenda (~8 dp) solapa el borde superior.
                topMargin = (8 * density).toInt()
            }
            tag = key
        }
        val tx = TextView(context).apply {
            text = snippet.contenido
            typeface = Typeface.MONOSPACE
            setTextColor(if (dark) Color.WHITE else Color.parseColor("#1C1C1E"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        box.addView(tx)
        val ops = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (8 * density).toInt()
            }
        }
        val edit = ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_edit))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.ic_edit)
                } catch (_: Throwable) {}
            }
            setColorFilter(if (dark) Color.WHITE else Color.parseColor("#3C3C43"))
            background = HistoryCardView.copyBackground(density, dark)
            val pad = (7 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val sz = (36 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(sz, sz)
            contentDescription = "Editar snippet"
            setOnClickListener { onEdit() }
        }
        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }
        val copy = ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.ic_copy)
                } catch (_: Throwable) {}
            }
            setColorFilter(if (dark) Color.WHITE else Color.parseColor("#3C3C43"))
            background = HistoryCardView.copyBackground(density, dark)
            val pad = (7 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val sz = (36 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(sz, sz)
            contentDescription = "Copiar snippet"
            setOnClickListener { onCopy(it as ImageView) }
        }
        ops.addView(edit)
        ops.addView(spacer)
        ops.addView(copy)
        box.addView(ops)
        val legend = TextView(context).apply {
            text = snippet.nombre.ifBlank { "Snippet" }
            setTextColor(if (dark) Color.parseColor("#FFAEAEB2") else Color.parseColor("#FF6E6E73"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 4f * density
                setColor(ContextCompat.getColor(context, R.color.bubble_legend_bg))
            }
            val padH = (6 * density).toInt()
            setPadding(padH, 0, padH, 0)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                leftMargin = (10 * density).toInt()
            }
        }
        val badge = HistoryCardView.checkBadge(context, density)
        frame.addView(box)
        // Orden gemelo al de historial (box=0, badge=1): resetCardSelections
        // y copySelected caminan hijos por índice. La leyenda va última
        // (arriba de todo; no solapa al badge: extremos opuestos).
        frame.addView(badge)
        frame.addView(legend)
        // Mismos gestos que historial: tap inserta+copia+cierra, largo
        // expande, lateral selecciona. El pintado respeta el outlined.
        onAttach(box, tx, badge)
        return frame
    }
}
