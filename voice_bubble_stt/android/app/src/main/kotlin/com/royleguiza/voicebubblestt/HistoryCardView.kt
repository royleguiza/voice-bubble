package com.royleguiza.voicebubblestt

import android.content.Context
import android.graphics.Color
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
 * SPK-11: vistas de tarjeta de historial (extraído de
 * BubbleHistoryController sin cambiar conducta). El controlador conserva la
 * orquesta (gestos, selección, copiar-todo) e inyecta callbacks.
 */
object HistoryCardView {

    fun cardBackground(density: Float, selected: Boolean, dark: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 12f * density
            if (selected) {
                setColor(Color.parseColor("#FF238636"))
                setStroke((1.5f * density).toInt(), Color.parseColor("#FF3FB950"))
            } else if (dark) {
                setColor(Color.parseColor("#12FFFFFF"))
                setStroke((1f * density).toInt(), Color.parseColor("#26FFFFFF"))
            } else {
                setColor(Color.parseColor("#0F000000"))
                setStroke((1f * density).toInt(), Color.parseColor("#1F000000"))
            }
        }
    }

    fun copyBackground(density: Float, dark: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 8f * density
            if (dark) {
                setColor(Color.parseColor("#1FFFFFFF"))
                setStroke((1f * density).toInt(), Color.parseColor("#26FFFFFF"))
            } else {
                setColor(Color.parseColor("#0F000000"))
                setStroke((1f * density).toInt(), Color.parseColor("#1F000000"))
            }
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
            setColorFilter(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF30D158"))
            }
            val s = (22 * density).toInt()
            layoutParams = FrameLayout.LayoutParams(s, s).apply {
                gravity = Gravity.TOP or Gravity.END
            }
            visibility = View.GONE
        }
    }

    fun emptyView(context: Context, density: Float, dark: Boolean): TextView {
        return TextView(context).apply {
            text = "Sin transcripciones todavía."
            setTextColor(if (dark) Color.parseColor("#FFAEAEB2") else Color.parseColor("#FF6E6E73"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            val pad = (16 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }
    }

    fun buildCard(
        context: Context,
        density: Float,
        dark: Boolean,
        text: String,
        key: String,
        onCopy: (card: ImageView) -> Unit,
        onAttach: (row: LinearLayout, tv: TextView, badge: ImageView) -> Unit,
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
        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = cardBackground(density, selected = false, dark = dark)
            val padH = (12 * density).toInt()
            setPadding(padH, (8 * density).toInt(), (8 * density).toInt(), (8 * density).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            tag = key
        }
        val tv = TextView(context).apply {
            this.text = "\"$text\""
            setTextColor(if (dark) Color.WHITE else Color.parseColor("#1C1C1E"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
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
            setColorFilter(if (dark) Color.WHITE else Color.parseColor("#3C3C43"))
            background = copyBackground(density, dark)
            val pad = (7 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val s = (32 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(s, s).apply {
                setMargins((10 * density).toInt(), 0, 0, 0)
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
