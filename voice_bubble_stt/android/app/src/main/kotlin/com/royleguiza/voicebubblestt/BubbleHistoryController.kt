package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import org.json.JSONObject

/**
 * Modal de historial para la BURBUJA CLÁSICA (hito B1–B7): nace por morph
 * desde el punto de la burbuja hacia el
 * diagonal con más espacio, sin títulos ni textos — solo micrófono (estilo
 * `kb_ic_mic`, abajo-derecha) y rayita inferior (siempre abajo) que contrae
 * de vuelta al origen.
 *
 * Gestos por card (sin conflictos entre sí):
 * - toque = insertar en cursor (`commitFromExternal`) + copiar + contraer;
 * - toque largo (450 ms, se cancela al scrollear) = expandir para leer;
 * - deslizamiento lateral (umbral 48 dp, retorno elástico) = seleccionar.
 * Con 2+ seleccionadas aparece el botón copiar-todo abajo-izquierda
 * (icon-only, slot permanente para no descentrar la rayita).
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs de textos; el contenido jamás toca
 * disco extra (solo el historial unificado existente) ni red.
 */
class BubbleHistoryController(
    private val context: Context,
    private val windowManager: WindowManager,
    private val onMicTap: () -> Unit,
    private val onClosed: () -> Unit
) {

    companion object {
        private const val BUBBLE_DP = 64
        private const val MARGIN_DP = 12
        private const val MODAL_W_DP = 300
        private const val MODAL_H_DP = 400
        private const val MORPH_MS = 320L
        private const val LONG_PRESS_MS = 450L
        private const val SWIPE_ARM_DP = 48
        private const val SWIPE_MAX_DP = 72

        /** Switch propio (Ajustes → General → Burbuja). Default ON. */
        fun isEnabled(context: Context): Boolean {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.getBoolean("flutter.bubble_history_enabled", true)
            } catch (_: Throwable) {
                true
            }
        }
    }

    private val density = context.resources.displayMetrics.density
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private var overlay: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var bgDrawable: GradientDrawable? = null
    private var cardsList: LinearLayout? = null
    private var copyAllBtn: ImageView? = null
    private var morphAnimator: ValueAnimator? = null
    private var originX = 0
    private var originY = 0
    private var originSize = 0
    // Selección estable por CLAVE (timestamp|texto), jamás por texto solo:
    // dos dictados idénticos son tarjetas distintas y seleccionar una no
    // debe arrastrar a la otra ni duplicarla en copiar-todo.
    private val selected = LinkedHashSet<String>()
    // Clave -> texto visible de las tarjetas vigentes (se reconstruye con ellas).
    private val keyToText = LinkedHashMap<String, String>()
    private var isShowing = false

    /**
     * Clave estable de selección. El repositorio no da ids, así que se
     * compone con timestamp ISO + texto.
     * Colisión residual documentada: dos dictados con el MISMO texto en el
     * MISMO instante comparten selección (el repo estampa Instant.now() por
     * inserción, así que requiere dos adds en el mismo milisegundo con texto
     * idéntico: despreciable y sin pérdida de datos, solo UX de selección).
     */
    private fun selectionKey(timestamp: String, text: String): String = "$timestamp|$text"

    private fun isDarkUi(): Boolean {
        return try {
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        } catch (_: Throwable) {
            true
        }
    }

    private fun reducedMotion(): Boolean {
        return try {
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f
            ) == 0f
        } catch (_: Throwable) {
            false
        }
    }

    fun isOpen(): Boolean = isShowing

    /** Muestra la modal naciendo desde el rect de la burbuja. */
    fun showFrom(bubbleX: Int, bubbleY: Int, bubblePx: Int) {
        try {
            if (isShowing) return
            val dm = context.resources.displayMetrics
            val screenW = dm.widthPixels
            val screenH = dm.heightPixels
            val margin = (MARGIN_DP * density).toInt()
            val modalW = min((MODAL_W_DP * density).toInt(), screenW - margin * 2)
            val modalH = min((MODAL_H_DP * density).toInt(), screenH - margin * 2)

            // Cuadrante inteligente: el diagonal con más área libre.
            val cx = bubbleX + bubblePx / 2f
            val cy = bubbleY + bubblePx / 2f
            val goLeft = (cx - margin) >= (screenW - cx - margin)
            val goUp = (cy - margin) >= (screenH - cy - margin)
            var tx = if (goLeft) (cx + bubblePx / 2f - modalW).toInt() else (cx - bubblePx / 2f).toInt()
            var ty = if (goUp) (cy + bubblePx / 2f - modalH).toInt() else (cy - bubblePx / 2f).toInt()
            tx = tx.coerceIn(margin, max(margin, screenW - modalW - margin))
            ty = ty.coerceIn(margin, max(margin, screenH - modalH - margin))

            originX = bubbleX
            originY = bubbleY
            originSize = bubblePx

            buildOverlay(modalW, modalH)
            populateCards()

            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            params = WindowManager.LayoutParams(
                bubblePx, bubblePx, flag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = bubbleX
                y = bubbleY
            }
            windowManager.addView(overlay, params)
            isShowing = true
            morphTo(tx, ty, modalW, modalH, opening = true)
        } catch (_: Throwable) {
            try {
                overlay?.let { windowManager.removeView(it) }
            } catch (_: Throwable) {}
            overlay = null
            isShowing = false
        }
    }

    /** Contae la modal de vuelta al punto de origen y la destruye. */
    fun close() {
        try {
            if (!isShowing) return
            morphTo(originX, originY, originSize, originSize, opening = false)
        } catch (_: Throwable) {
            destroy()
        }
    }

    fun destroy() {
        try {
            morphAnimator?.cancel()
        } catch (_: Throwable) {}
        morphAnimator = null
        try {
            overlay?.let { windowManager.removeView(it) }
        } catch (_: Throwable) {}
        overlay = null
        params = null
        selected.clear()
        keyToText.clear()
        if (isShowing) {
            isShowing = false
            try {
                onClosed()
            } catch (_: Throwable) {}
        } else {
            try {
                onClosed()
            } catch (_: Throwable) {}
        }
    }

    private fun morphTo(tx: Int, ty: Int, tw: Int, th: Int, opening: Boolean) {
        val p = params ?: return
        val root = overlay ?: return
        val startX = p.x
        val startY = p.y
        val startW = p.width
        val startH = p.height
        try {
            morphAnimator?.cancel()
        } catch (_: Throwable) {}
        morphAnimator = null
        if (reducedMotion()) {
            p.x = tx
            p.y = ty
            p.width = tw
            p.height = th
            try {
                windowManager.updateViewLayout(root, p)
            } catch (_: Throwable) {}
            if (opening) {
                cardsList?.alpha = 1f
            } else {
                destroy()
            }
            return
        }
        val bg = bgDrawable
        val startR = if (opening) BUBBLE_DP * density / 2f else 20f * density
        val endR = if (opening) 20f * density else BUBBLE_DP * density / 2f
        if (opening) {
            cardsList?.alpha = 0f
        }
        morphAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = MORPH_MS
            interpolator = android.view.animation.DecelerateInterpolator()
            addUpdateListener { anim ->
                try {
                    val f = anim.animatedValue as Float
                    p.x = (startX + (tx - startX) * f).toInt()
                    p.y = (startY + (ty - startY) * f).toInt()
                    p.width = (startW + (tw - startW) * f).toInt()
                    p.height = (startH + (th - startH) * f).toInt()
                    try {
                        bg?.cornerRadius = startR + (endR - startR) * f
                    } catch (_: Throwable) {}
                    if (opening) {
                        cardsList?.alpha = f
                    }
                    windowManager.updateViewLayout(root, p)
                } catch (_: Throwable) {}
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    try {
                        p.x = tx
                        p.y = ty
                        p.width = tw
                        p.height = th
                        windowManager.updateViewLayout(root, p)
                        if (opening) {
                            cardsList?.alpha = 1f
                        } else {
                            destroy()
                        }
                    } catch (_: Throwable) {
                        if (!opening) destroy()
                    }
                }
            })
            start()
        }
    }

    private fun modalBackground(): GradientDrawable {
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = BUBBLE_DP * density / 2f
            setColor(ContextCompat.getColor(context, R.color.bubble_idle_bg))
            setStroke(
                (1.5f * density).toInt(),
                ContextCompat.getColor(context, R.color.bubble_idle_border)
            )
        }
        bgDrawable = bg
        return bg
    }

    private fun buildOverlay(modalW: Int, modalH: Int) {
        val dark = isDarkUi()
        val root = FrameLayout(context).apply {
            background = modalBackground()
        }
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        val scroll = ScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
            )
            isVerticalScrollBarEnabled = false
        }
        val list = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val pad = (12 * density).toInt()
            setPadding(pad, (14 * density).toInt(), pad, (4 * density).toInt())
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        cardsList = list
        scroll.addView(list)
        column.addView(scroll)

        // Pie: copiar-todo (slot permanente) + rayita centrada + mic.
        val foot = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val padH = (14 * density).toInt()
            setPadding(padH, (6 * density).toInt(), padH, (8 * density).toInt())
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        val slotSize = (48 * density).toInt()
        val slot = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(slotSize, slotSize)
        }
        val copyAll = ImageView(context).apply {
            layoutParams = FrameLayout.LayoutParams(slotSize, slotSize)
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.ic_copy)
                } catch (_: Throwable) {}
            }
            setColorFilter(if (dark) Color.WHITE else Color.parseColor("#1C1C1E"))
            background = circleBackground(
                if (dark) Color.parseColor("#3A3A3C") else Color.parseColor("#E4E4E8")
            )
            val pad = (13 * density).toInt()
            setPadding(pad, pad, pad, pad)
            contentDescription = "Copiar seleccionados"
            visibility = View.INVISIBLE
            setOnClickListener { copySelected() }
        }
        copyAllBtn = copyAll
        slot.addView(copyAll)

        val handleWrap = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            isClickable = true
            isFocusable = true
            contentDescription = "Contraer"
            setOnClickListener { close() }
        }
        val handleBar = View(context).apply {
            layoutParams = LinearLayout.LayoutParams((38 * density).toInt(), (4.5f * density).toInt())
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10f * density
                setColor(if (dark) Color.parseColor("#FF8E8E93") else Color.parseColor("#FFAEAEB2"))
            }
        }
        handleWrap.addView(handleBar)

        val mic = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(slotSize, slotSize)
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.kb_ic_mic))
            } catch (_: Throwable) {
                try {
                    setImageResource(R.drawable.kb_ic_mic)
                } catch (_: Throwable) {}
            }
            setColorFilter(ContextCompat.getColor(context, R.color.kb_recording))
            background = circleBackground(
                if (dark) Color.parseColor("#3A3A3C") else Color.parseColor("#E4E4E8")
            )
            val pad = (12 * density).toInt()
            setPadding(pad, pad, pad, pad)
            contentDescription = "Dictar"
            setOnClickListener {
                try {
                    onMicTap()
                } catch (_: Throwable) {}
            }
        }
        foot.addView(slot)
        foot.addView(handleWrap)
        foot.addView(mic)
        column.addView(foot)
        root.addView(column)
        overlay = root
    }

    private fun circleBackground(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }
    }

    private fun populateCards() {
        val list = cardsList ?: return
        try {
            list.removeAllViews()
        } catch (_: Throwable) {}
        selected.clear()
        keyToText.clear()
        refreshCopyAll()
        // I/O fuera del main (disco + XML + prefs del repositorio): el render
        // vuelve al main y pinta solo si la modal sigue abierta.
        BackgroundWork.executeWithResult(
            block = {
                try {
                    TranscriptionHistoryRepository(context).loadHistory()
                } catch (_: Exception) {
                    emptyList()
                }
            },
            onResult = { items -> renderCards(items ?: emptyList()) }
        )
    }

    private fun renderCards(items: List<JSONObject>) {
        if (!isShowing) return
        val list = cardsList ?: return
        if (items.isEmpty()) {
            val dark = isDarkUi()
            val empty = TextView(context).apply {
                text = "Sin transcripciones todavía."
                setTextColor(if (dark) Color.parseColor("#FFAEAEB2") else Color.parseColor("#FF6E6E73"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                gravity = Gravity.CENTER
                val pad = (16 * density).toInt()
                setPadding(pad, pad, pad, pad)
            }
            list.addView(empty)
            return
        }
        for (obj in items) {
            val text = try {
                obj.optString("text", "")
            } catch (_: Throwable) {
                ""
            }
            if (text.isEmpty()) continue
            val timestamp = try {
                obj.optString("timestamp", "")
            } catch (_: Throwable) {
                ""
            }
            list.addView(buildCard(text, timestamp))
        }
    }

    private fun cardBackground(selected: Boolean, dark: Boolean): GradientDrawable {
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

    private fun copyBackgroundFor(dark: Boolean): GradientDrawable {
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

    private fun buildCard(text: String, timestamp: String): View {
        val dark = isDarkUi()
        val key = selectionKey(timestamp, text)
        keyToText[key] = text
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
            background = cardBackground(selected = false, dark = dark)
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
            background = copyBackgroundFor(dark)
            val pad = (7 * density).toInt()
            setPadding(pad, pad, pad, pad)
            val s = (32 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(s, s).apply {
                setMargins((10 * density).toInt(), 0, 0, 0)
            }
            contentDescription = "Copiar al portapapeles"
            setOnClickListener {
                try {
                    copyToClipboard(text)
                    showCopied(it as ImageView, dark)
                } catch (_: Throwable) {}
            }
        }
        row.addView(copy)

        val badge = ImageView(context).apply {
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
        frame.addView(row)
        frame.addView(badge)
        attachCardGestures(row = row, tv = tv, badge = badge, text = text, key = key, dark = dark)
        return frame
    }

    private fun attachCardGestures(
        row: LinearLayout,
        tv: TextView,
        badge: ImageView,
        text: String,
        key: String,
        dark: Boolean
    ) {
        val armPx = SWIPE_ARM_DP * density
        val maxPx = SWIPE_MAX_DP * density
        var longRunnable: Runnable? = null
        var longFired = false
        var downX = 0f
        var downY = 0f
        var swiping = false
        var suppressTap = false

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
                    mainHandler.postDelayed(r, LONG_PRESS_MS)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downX
                    val dy = event.rawY - downY
                    if (longRunnable != null && Math.hypot(dx.toDouble(), dy.toDouble()) > 10 * density) {
                        longRunnable?.let { mainHandler.removeCallbacks(it) }
                        longRunnable = null
                    }
                    if (!swiping && abs(dx) > 14 * density && abs(dx) > abs(dy) * 1.4f) {
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
                                row.background = cardBackground(selected = false, dark = dark)
                            } else {
                                selected.add(key)
                                badge.visibility = View.VISIBLE
                                row.background = cardBackground(selected = true, dark = dark)
                            }
                            refreshCopyAll()
                            try {
                                v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                            } catch (_: Throwable) {}
                        } else {
                            badge.visibility = if (selected.contains(key)) View.VISIBLE else View.GONE
                        }
                    } else if (!longFired) {
                        handleCardTap(tv = tv, text = text)
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

    private fun handleCardTap(tv: TextView, text: String) {
        try {
            if (tv.maxLines == Int.MAX_VALUE) {
                tv.maxLines = 2
                return
            }
            // Inserción directa si el teclado propio está activo; el texto
            // siempre queda además en el portapapeles.
            try {
                VoiceKeyboardService.commitFromExternal(text)
            } catch (_: Throwable) {}
            copyToClipboard(text)
            close()
        } catch (_: Throwable) {
            try {
                close()
            } catch (_: Throwable) {}
        }
    }

    private fun refreshCopyAll() {
        try {
            copyAllBtn?.visibility = if (selected.size >= 2) View.VISIBLE else View.INVISIBLE
        } catch (_: Throwable) {}
    }

    private fun copySelected() {
        try {
            if (selected.size < 2) return
            val list = cardsList ?: return
            // Recorrido en orden visual: cada tarjeta aporta su texto UNA sola
            // vez (clave estable por tarjeta, no por texto). Sin duplicados
            // por construcción: el loop visita cada hija una vez y cada clave
            // seleccionada corresponde a una sola tarjeta. Dos dictados con
            // texto idéntico aportan sus dos líneas (son dictados distintos).
            val ordered = ArrayList<String>()
            for (i in 0 until list.childCount) {
                val frame = list.getChildAt(i) as? FrameLayout ?: continue
                val row = frame.getChildAt(0) as? LinearLayout ?: continue
                val key = row.tag as? String ?: continue
                if (!selected.contains(key)) continue
                val text = keyToText[key] ?: continue
                ordered.add(text)
            }
            if (ordered.isEmpty()) return
            copyToClipboard(ordered.joinToString("\n"))
            val btn = copyAllBtn ?: return
            val dark = isDarkUi()
            try {
                btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
            } catch (_: Throwable) {
                try {
                    btn.setImageResource(R.drawable.ic_check)
                } catch (_: Throwable) {}
            }
            btn.setColorFilter(Color.WHITE)
            btn.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF238636"))
            }
            mainHandler.postDelayed({
                try {
                    btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                } catch (_: Throwable) {
                    try {
                        btn.setImageResource(R.drawable.ic_copy)
                    } catch (_: Throwable) {}
                }
                btn.setColorFilter(if (dark) Color.WHITE else Color.parseColor("#1C1C1E"))
                btn.background = circleBackground(
                    if (dark) Color.parseColor("#3A3A3C") else Color.parseColor("#E4E4E8")
                )
                selected.clear()
                resetCardSelections()
                refreshCopyAll()
            }, 1100)
        } catch (_: Throwable) {}
    }

    private fun resetCardSelections() {
        try {
            val list = cardsList ?: return
            val dark = isDarkUi()
            for (i in 0 until list.childCount) {
                val frame = list.getChildAt(i) as? FrameLayout ?: continue
                val row = frame.getChildAt(0) as? LinearLayout ?: continue
                val badge = frame.getChildAt(1) as? ImageView ?: continue
                badge.visibility = View.GONE
                row.background = cardBackground(selected = false, dark = dark)
            }
        } catch (_: Throwable) {}
    }

    private fun showCopied(btn: ImageView, dark: Boolean) {
        try {
            btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
        } catch (_: Throwable) {
            try {
                btn.setImageResource(R.drawable.ic_check)
            } catch (_: Throwable) {}
        }
        btn.setColorFilter(Color.WHITE)
        btn.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 8f * density
            setColor(Color.parseColor("#FF238636"))
            setStroke((1f * density).toInt(), Color.parseColor("#FF3FB950"))
        }
        mainHandler.postDelayed({
            try {
                btn.setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
            } catch (_: Throwable) {
                try {
                    btn.setImageResource(R.drawable.ic_copy)
                } catch (_: Throwable) {}
            }
            btn.setColorFilter(if (dark) Color.WHITE else Color.parseColor("#3C3C43"))
            btn.background = copyBackgroundFor(dark)
        }, 1200)
    }

    /**
     * Copia al portapapeles del sistema. Decisión documentada: NO se vacía
     * con clearPrimaryClip ni expira el contenido (eso rompería el flujo
     * copiar-acá → pegar-allá). Lo que expira es el feedback visual (check
     * verde → icono copiar a los ~1100 ms) y la selección tras copiar-todo.
     */
    private fun copyToClipboard(text: String) {
        try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            val clip = ClipData.newPlainText("VoiceBubble STT", text)
            clipboard?.setPrimaryClip(clip)
        } catch (_: Throwable) {}
    }
}
