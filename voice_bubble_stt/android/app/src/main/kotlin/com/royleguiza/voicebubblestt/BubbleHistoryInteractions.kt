package com.royleguiza.voicebubblestt

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * BubbleHistoryInteractions - Gestos táctiles y operaciones de copiado de la modal de burbuja.
 * Extraído de BubbleHistoryController (C-25) para aislar la interacción táctil y el portapapeles.
 */
object BubbleHistoryInteractions {

    fun copyToClipboard(context: Context, text: String): Boolean {
        return try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            val clip = ClipData.newPlainText("VoiceBubble STT", text)
            clipboard?.setPrimaryClip(clip)
            true
        } catch (_: Throwable) {
            false
        }
    }

    fun showCopied(
        btn: ImageView,
        dark: Boolean,
        density: Float,
        mainHandler: Handler,
        context: Context,
        copyBackgroundFor: (Boolean) -> GradientDrawable,
    ) {
        try {
            try {
                btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
            } catch (_: Throwable) {
                try {
                    btn.setImageResource(R.drawable.ic_check)
                } catch (_: Throwable) {}
            }
            // Copiado (Horizonte): brasa suave + borde brasa, check en ember-t.
            btn.setColorFilter(ContextCompat.getColor(context, R.color.hz_ember_t))
            btn.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10f * density
                setColor(ContextCompat.getColor(context, R.color.hz_ember_soft))
                setStroke((1f * density).toInt(), ContextCompat.getColor(context, R.color.hz_ember))
            }
            mainHandler.postDelayed({
                try {
                    btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                } catch (_: Throwable) {
                    try {
                        btn.setImageResource(R.drawable.ic_copy)
                    } catch (_: Throwable) {}
                }
                btn.setColorFilter(ContextCompat.getColor(context, R.color.hz_fg2))
                btn.background = copyBackgroundFor(dark)
            }, 1200)
        } catch (_: Throwable) {}
    }

    fun attachCardGestures(
        row: LinearLayout,
        tv: TextView,
        badge: ImageView,
        text: String,
        key: String,
        dark: Boolean,
        density: Float,
        selected: MutableSet<String>,
        mainHandler: Handler,
        paintBackground: ((selected: Boolean) -> Unit)?,
        defaultCardBackground: (Boolean, Boolean) -> Drawable,
        onTapAction: (TextView, String) -> Unit,
        onSelectionChanged: () -> Unit,
    ) {
        val armPx = GestureTuning.BUBBLE_SWIPE_ARM_DP * density
        val maxPx = GestureTuning.BUBBLE_SWIPE_MAX_DP * density
        var longRunnable: Runnable? = null
        var longFired = false
        var downX = 0f
        var downY = 0f
        var swiping = false
        var suppressTap = false
        val paint: (Boolean) -> Unit =
            paintBackground ?: { sel -> row.background = defaultCardBackground(sel, dark) }

        row.isClickable = true
        row.isFocusable = true
        row.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    longFired = false
                    swiping = false
                    suppressTap = false
                    downX = event.rawX
                    downY = event.rawY
                    row.animate().cancel()
                    row.translationX = 0f
                    val r = Runnable {
                        longFired = true
                        try {
                            val expanded = tv.maxLines == Int.MAX_VALUE
                            tv.maxLines = if (expanded) 2 else Int.MAX_VALUE
                        } catch (_: Throwable) {}
                    }
                    longRunnable = r
                    mainHandler.postDelayed(r, GestureTuning.LONG_PRESS_MS)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (longRunnable != null && Math.hypot(dx.toDouble(), dy.toDouble()) > 10 * density) {
                        longRunnable?.let { mainHandler.removeCallbacks(it) }
                        longRunnable = null
                    }
                    if (!swiping && abs(dx) > GestureTuning.SPACEBAR_THRESHOLD_DP * density && abs(dx) > abs(dy) * GestureTuning.SWIPE_SLOP_RATIO) {
                        swiping = true
                    }
                    if (swiping) {
                        val clamped = dx.coerceIn(-maxPx, maxPx)
                        row.translationX = clamped
                        badge.visibility = if (abs(clamped) >= armPx || selected.contains(key)) {
                            View.VISIBLE
                        } else {
                            View.GONE
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    longRunnable?.let { mainHandler.removeCallbacks(it) }
                    longRunnable = null
                    if (swiping) {
                        swiping = false
                        val armed = abs(row.translationX) >= armPx
                        try {
                            row.animate().translationX(0f).setDuration(220).start()
                        } catch (_: Throwable) {
                            row.translationX = 0f
                        }
                        suppressTap = true
                        if (armed) {
                            if (selected.contains(key)) {
                                selected.remove(key)
                                badge.visibility = View.GONE
                                paint(false)
                            } else {
                                selected.add(key)
                                badge.visibility = View.VISIBLE
                                paint(true)
                            }
                            onSelectionChanged()
                            try {
                                v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            } catch (_: Throwable) {}
                        } else {
                            badge.visibility = if (selected.contains(key)) View.VISIBLE else View.GONE
                        }
                    } else if (!longFired) {
                        onTapAction(tv, text)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    longRunnable?.let { mainHandler.removeCallbacks(it) }
                    longRunnable = null
                    if (swiping) {
                        swiping = false
                        try {
                            row.animate().translationX(0f).setDuration(220).start()
                        } catch (_: Throwable) {
                            row.translationX = 0f
                        }
                        suppressTap = true
                        badge.visibility = if (selected.contains(key)) View.VISIBLE else View.GONE
                    }
                    true
                }
                else -> false
            }
        }
    }
}
