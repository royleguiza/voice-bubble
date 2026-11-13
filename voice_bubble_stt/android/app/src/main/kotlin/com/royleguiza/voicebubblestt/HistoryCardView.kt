package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
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
 * SPK-11: vistas de fila de historial (extraído de BubbleHistoryController
 * sin cambiar conducta). El controlador conserva la orquesta (gestos,
 * selección, copiar-todo) e inyecta callbacks.
 *
 * Horizonte (fase 4, design.md §13 «Historial»): filas sueltas sobre el
 * fondo de la tarjeta con separador hz_line, hora en mono en una columna
 * fija a la izquierda, texto en Inter y copiar como ícono fg2. Seleccionada
 * = brasa suave + borde brasa (igual que SnippetsCardView). Todo por token.
 */
object HistoryCardView {

    /** Columna fija de la hora (design.md §13: hora sola en mono a la izquierda). */
    const val TIME_COLUMN_DP = 44

    private fun token(context: Context, res: Int): Int = ContextCompat.getColor(context, res)

    /**
     * Fondo de la fila: en reposo, solo la línea inferior hz_line de 1 dp;
     * seleccionada, brasa suave con borde brasa (radio 10).
     */
    fun cardBackground(context: Context, density: Float, selected: Boolean): Drawable {
        if (selected) {
            return GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10f * density
                setColor(token(context, R.color.hz_ember_soft))
                setStroke((1.5f * density).toInt(), token(context, R.color.hz_ember))
            }
        }
        val line = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(token(context, R.color.hz_line))
        }
        return LayerDrawable(arrayOf<Drawable>(line)).apply {
            setLayerGravity(0, Gravity.BOTTOM or Gravity.FILL_HORIZONTAL)
            setLayerHeight(0, maxOf(1, density.toInt()))
        }
    }

    /**
     * Fondo de los botones de ícono de fila (copiar, editar snippet): sin
     * caja, el ícono fg2 va suelto; la forma (radio 10) la toma el
     * feedback de copiado.
     */
    fun copyBackground(density: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 10f * density
            setColor(Color.TRANSPARENT)
        }
    }

    fun checkBadge(context: Context, density: Float): ImageView {
        return ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.ic_check)
                } catch (_: Throwable) {}
            }
            setColorFilter(token(context, R.color.hz_on_ember))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(token(context, R.color.hz_ember))
            }
            val pad = (3 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val s = (22 * density).toInt()
            layoutParams = FrameLayout.LayoutParams(s, s).apply {
                gravity = Gravity.TOP or Gravity.END
            }
            visibility = View.GONE
        }
    }

    fun emptyView(context: Context, density: Float): TextView {
        return TextView(context).apply {
            text = "Sin transcripciones todavía."
            setTextColor(token(context, R.color.hz_fg2))
            typeface = KbFonts.body(context)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            val pad = (16 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }
    }

    /**
     * Fila de historial. [time] es la hora local ya formateada (HH:mm); si
     * es null o vacía la fila va sin columna de hora (no se inventa).
     */
    fun buildCard(
        context: Context,
        density: Float,
        text: String,
        key: String,
        time: String?,
        onCopy: (card: ImageView) -> Unit,
        onAttach: (row: LinearLayout, tv: TextView, badge: ImageView) -> Unit,
    ): View {
        val frame = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
            background = cardBackground(context, density, selected = false)
            val padV = (4 * density).toInt()
            setPadding((6 * density).toInt(), padV, 0, padV)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            tag = key
        }
        if (!time.isNullOrEmpty()) {
            val clock = TextView(context).apply {
                this.text = time
                typeface = KbFonts.mono(context)
                setTextColor(token(context, R.color.hz_fg2))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                maxLines = 1
                // Alineada con la primera línea del texto (que arranca a 10 dp).
                setPadding(0, (11 * density).toInt(), 0, 0)
                layoutParams = LinearLayout.LayoutParams(
                    (TIME_COLUMN_DP * density).toInt(),
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            }
            row.addView(clock)
        }
        val tv = TextView(context).apply {
            this.text = text
            typeface = KbFonts.body(context)
            setTextColor(token(context, R.color.hz_fg))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, (10 * density).toInt(), 0, (10 * density).toInt())
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }
        row.addView(tv)
        val copy = ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.ic_copy)
                } catch (_: Throwable) {}
            }
            setColorFilter(token(context, R.color.hz_fg2))
            background = copyBackground(density)
            val pad = (12 * density).toInt()
            setPadding(pad, pad, pad, pad)
            // Target táctil de 44 dp (design.md §9).
            val s = (44 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(s, s).apply {
                gravity = Gravity.CENTER_VERTICAL
                setMargins((4 * density).toInt(), 0, 0, 0)
            }
            contentDescription = "Copiar al portapapeles"
            setOnClickListener { onCopy(it as ImageView) }
        }
        row.addView(copy)
        val badge = checkBadge(context, density)
        frame.addView(row)
        frame.addView(badge)
        onAttach(row, tv, badge)
        return frame
    }
}
