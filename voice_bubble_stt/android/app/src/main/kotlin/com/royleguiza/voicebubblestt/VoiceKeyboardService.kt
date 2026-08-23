package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Teclado del sistema VoiceBubble.
 * K1: QWERTY es/en + capa simbolos basicos + acentos por toque largo.
 * K2: capa codigo con pares auto-cerrados + fila terminal permanente
 *     (TAB/ESC/CTRL/ALT/flechas) con modificadores sticky para Termux.
 * Este teclado JAMAS registra, guarda ni transmite texto tecleado.
 */
class VoiceKeyboardService : InputMethodService() {

    private enum class Layer { LETTERS, SYMBOLS, CODE }

    private var layer = Layer.LETTERS
    private var lastLettersLayer = Layer.LETTERS
    private var spanishMode = true
    private var shiftActive = false
    private var ctrlActive = false
    private var altActive = false

    private lateinit var root: LinearLayout
    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private val shiftKeyViews = mutableListOf<TextView>()
    private val modifierKeyViews = mutableListOf<Pair<TextView, Boolean>>()

    private var activePopup: PopupWindow? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onCreateInputView(): View {
        root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setBackgroundResource(R.drawable.kb_surface_bg)
        applyBottomInsets()
        rebuild()
        return root
    }

    /**
     * Con targetSdk edge-to-edge la ventana del teclado se extiende bajo la
     * barra de gestos y los botones del sistema. Se aplica el inset de
     * navegacion como padding inferior para que la fila inferior quede
     * siempre por encima.
     */
    private fun applyBottomInsets() {
        val padH = dimen(R.dimen.kb_row_padding_h)
        val padV = dimen(R.dimen.kb_row_padding_v)
        root.setOnApplyWindowInsetsListener { view, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(
                    WindowInsets.Type.navigationBars()
                        or WindowInsets.Type.displayCutout()
                ).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            view.setPadding(padH, padV, padH, padV + bottom)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowInsets.CONSUMED
            } else {
                @Suppress("DEPRECATION")
                insets.consumeSystemWindowInsets()
            }
        }
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        layer = Layer.LETTERS
        lastLettersLayer = Layer.LETTERS
        shiftActive = false
        ctrlActive = false
        altActive = false
        rebuild()
    }

    override fun onWindowHidden() {
        super.onWindowHidden()
        dismissPopup()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        dismissPopup()
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Construccion de la vista
    // ------------------------------------------------------------------

    private fun rebuild() {
        dismissPopup()
        letterKeys.clear()
        shiftKeyViews.clear()
        modifierKeyViews.clear()
        root.removeAllViews()

        addRow(buildTerminalRow())
        when (layer) {
            Layer.LETTERS -> buildLetterRows()
            Layer.SYMBOLS -> buildSymbolRows()
            Layer.CODE -> buildCodeRows()
        }
        addRow(buildBottomBar())

        // Sincronizar estados visuales persistentes tras reconstruir la vista.
        applyCase()
        refreshModifierVisuals()
    }

    /** Fila terminal permanente en todas las capas (K2). */
    private fun buildTerminalRow(): LinearLayout {
        val row = horizontalRow()
        row.addView(makeSpecialKey("TAB", R.drawable.kb_key_alt, 1.5f, "tab") {
            sendKeyCode(KeyEvent.KEYCODE_TAB)
        })
        row.addView(makeSpecialKey("ESC", R.drawable.kb_key_alt, 1f, "escape") {
            sendKeyCode(KeyEvent.KEYCODE_ESCAPE)
        })
        row.addView(makeModifierKey("CTRL", true, 1.25f))
        row.addView(makeModifierKey("ALT", false, 1.25f))
        row.addView(makeArrowKey("←", KeyEvent.KEYCODE_DPAD_LEFT))
        row.addView(makeArrowKey("↑", KeyEvent.KEYCODE_DPAD_UP))
        row.addView(makeArrowKey("↓", KeyEvent.KEYCODE_DPAD_DOWN))
        row.addView(makeArrowKey("→", KeyEvent.KEYCODE_DPAD_RIGHT))
        return row
    }

    private fun makeArrowKey(glyph: String, code: Int): TextView =
        makeSpecialKey(glyph, R.drawable.kb_key_bg, 1f, null) {
            sendKeyCode(code)
        }

    /** CTRL/ALT sticky: tap activa/desactiva; la proxima tecla los consume. */
    private fun makeModifierKey(label: String, isCtrl: Boolean, weight: Float): TextView {
        val key = makeSpecialKey(label, R.drawable.kb_key_alt, weight, null) {}
        key.setOnClickListener {
            haptic(key)
            if (isCtrl) ctrlActive = !ctrlActive else altActive = !altActive
            refreshModifierVisuals()
        }
        modifierKeyViews.add(Pair(key, isCtrl))
        return key
    }

    private fun refreshModifierVisuals() {
        for ((key, isCtrl) in modifierKeyViews) {
            val active = if (isCtrl) ctrlActive else altActive
            if (active) {
                key.setBackgroundResource(R.drawable.kb_key_accent)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
            } else {
                key.setBackgroundResource(R.drawable.kb_key_alt)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            }
        }
    }

    private fun buildLetterRows() {
        addRow(letterRow("qwertyuiop"))
        addRow(letterRow(if (spanishMode) "asdfghjklñ" else "asdfghjkl;"))

        val row3 = horizontalRow()
        val shiftKey = makeSpecialKey("⇧", R.drawable.kb_key_alt, 1f, "mayúsculas") {
            toggleShift()
        }
        shiftKeyViews.add(shiftKey)
        row3.addView(shiftKey)
        for (c in "zxcvbnm") {
            row3.addView(makeLetterKey(c))
        }
        row3.addView(makeBackspaceKey())
        addRow(row3)
    }

    private fun buildSymbolRows() {
        addRow(symbolRow("1234567890"))
        addRow(symbolRow("@#\$%&-+()/"))

        val row3 = horizontalRow()
        for (c in "=*\"':;!?") {
            row3.addView(makeSymbolKey(c.toString()))
        }
        row3.addView(makeBackspaceKey())
        addRow(row3)
    }

    /** Capa codigo (K2): simbolos por frecuencia + pares auto-cerrados. */
    private fun buildCodeRows() {
        addRow(codeRow("{}[]()<>;:"))
        addRow(codeRow("'\"`\\|/!?=+"))

        val row3 = horizontalRow()
        for (c in "*&%\$#@^~_") {
            row3.addView(makeCodeKey(c))
        }
        row3.addView(makeBackspaceKey())
        addRow(row3)
    }

    private fun buildBottomBar(): LinearLayout {
        val row = horizontalRow()
        row.addView(makeSpecialKey(symbolsToggleLabel(), R.drawable.kb_key_alt, 1.5f, "símbolos") {
            layer = if (layer == Layer.SYMBOLS) Layer.LETTERS else Layer.SYMBOLS
            rebuild()
        })
        row.addView(makeSpecialKey("</>", R.drawable.kb_key_alt, 1f, "capa código") {
            toggleCodeLayer()
        })
        row.addView(makeSpecialKey(if (spanishMode) "ES" else "EN", R.drawable.kb_key_alt, 1f, "cambiar idioma") {
            spanishMode = !spanishMode
            rebuild()
        })
        row.addView(makeSymbolKey(","))
        row.addView(makeSpecialKey("", R.drawable.kb_key_bg, 3f, "espacio") {
            commit(" ")
        })
        row.addView(makeSymbolKey("."))
        row.addView(makeSpecialKey("↵", R.drawable.kb_key_accent, 1.5f, "enter") {
            handleEnter()
        })
        return row
    }

    private fun symbolsToggleLabel(): String = when (layer) {
        Layer.SYMBOLS -> "ABC"
        else -> "?123"
    }

    /** Cambiador de capas con memoria de la ultima capa no-codigo. */
    private fun toggleCodeLayer() {
        if (layer == Layer.CODE) {
            layer = lastLettersLayer
        } else {
            lastLettersLayer = if (layer == Layer.SYMBOLS) Layer.LETTERS else layer
            layer = Layer.CODE
        }
        rebuild()
    }

    private fun makeBackspaceKey(): TextView =
        makeSpecialKey("⌫", R.drawable.kb_key_alt, 1f, "borrar") {
            handleBackspace()
        }

    private fun horizontalRow(): LinearLayout {
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        return row
    }

    private fun letterRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeLetterKey(c))
        }
        return row
    }

    private fun symbolRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeSymbolKey(c.toString()))
        }
        return row
    }

    private fun codeRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            if (c == ' ') continue
            row.addView(makeCodeKey(c))
        }
        return row
    }

    private fun makeLetterKey(base: Char): TextView {
        val key = makeKey(
            displayFor(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size),
        )
        if (accentsFor(base).isEmpty()) {
            key.setOnClickListener { commitLetter(base) }
        } else {
            attachAccentLongPress(key, base)
        }
        letterKeys.add(Pair(key, base))
        return key
    }

    private fun makeSymbolKey(label: String): TextView {
        val key = makeKey(
            label,
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size_small),
        )
        key.contentDescription = label
        key.setOnClickListener { commitSymbolText(label) }
        return key
    }

    /** Tecla de capa codigo: toque corto el simbolo, toque largo el par cerrado. */
    private fun makeCodeKey(ch: Char): TextView {
        val key = makeKey(
            ch.toString(),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size_small),
        )
        key.contentDescription = ch.toString()
        attachPairLongPress(key, ch)
        return key
    }

    private fun makeSpecialKey(
        label: String,
        bgRes: Int,
        weight: Float,
        description: String?,
        onClick: () -> Unit,
    ): TextView {
        val key = makeKey(
            label,
            weight,
            bgRes,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size_small),
        )
        if (description != null) {
            key.contentDescription = description
        }
        key.setOnClickListener {
            haptic(key)
            onClick()
        }
        return key
    }

    private fun makeKey(
        label: String,
        weight: Float,
        bgRes: Int,
        colorRes: Int,
        textSizePx: Int,
    ): TextView {
        val key = TextView(this)
        key.text = label
        key.gravity = Gravity.CENTER
        key.isClickable = true
        key.isFocusable = true
        key.includeFontPadding = false
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setTextColor(ContextCompat.getColor(this, colorRes))
        key.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSizePx.toFloat())
        val lp = LinearLayout.LayoutParams(0, dimen(R.dimen.kb_key_height), weight)
        val m = dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        return key
    }

    private fun addRow(row: LinearLayout) {
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        if (root.childCount > 0) {
            lp.topMargin = dimen(R.dimen.kb_key_gap)
        }
        root.addView(row, lp)
    }

    // ------------------------------------------------------------------
    // Comportamiento de teclas
    // ------------------------------------------------------------------

    private fun displayFor(base: Char): String =
        if (shiftActive) base.uppercaseChar().toString() else base.toString()

    private fun toggleShift() {
        shiftActive = !shiftActive
        applyCase()
    }

    private fun applyCase() {
        for ((key, base) in letterKeys) {
            key.text = displayFor(base)
        }
        for (key in shiftKeyViews) {
            if (shiftActive) {
                key.setBackgroundResource(R.drawable.kb_key_accent)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
            } else {
                key.setBackgroundResource(R.drawable.kb_key_alt)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            }
        }
    }

    private fun commitLetter(base: Char) {
        haptic(root)
        if (ctrlActive || altActive) {
            sendModifiedChar(base.lowercaseChar())
            return
        }
        currentInputConnection?.commitText(displayFor(base), 1)
        if (shiftActive) {
            shiftActive = false
            applyCase()
        }
    }

    private fun commitSymbolText(text: String) {
        haptic(root)
        if ((ctrlActive || altActive) && text.length == 1) {
            val c = text[0]
            if (keyCodeFor(c) != null) {
                sendModifiedChar(c)
                return
            }
        }
        currentInputConnection?.commitText(text, 1)
        consumeModifiers()
    }

    private fun commit(text: String) {
        currentInputConnection?.commitText(text, 1)
    }

    /** Envio del caracter con META_CTRL/META_ALT via KeyEvent (patron Hacker's Keyboard). */
    private fun sendModifiedChar(c: Char) {
        val code = keyCodeFor(c)
        if (code == null) {
            consumeModifiers()
            return
        }
        var meta = 0
        if (ctrlActive) meta = meta or KeyEvent.META_CTRL_ON
        if (altActive) meta = meta or KeyEvent.META_ALT_ON
        sendKeyEventWithMeta(code, meta)
        consumeModifiers()
    }

    private fun sendKeyEventWithMeta(keyCode: Int, meta: Int) {
        val ic = currentInputConnection ?: return
        val now = SystemClock.uptimeMillis()
        ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0, meta))
        ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0, meta))
    }

    private fun sendKeyCode(keyCode: Int) {
        haptic(root)
        if (currentInputConnection == null) return
        sendDownUpKeyEvents(keyCode)
    }

    private fun consumeModifiers() {
        ctrlActive = false
        altActive = false
        refreshModifierVisuals()
    }

    private fun handleBackspace() {
        haptic(root)
        val ic = currentInputConnection ?: return
        val selected = try {
            ic.getSelectedText(0)
        } catch (_: Exception) {
            null
        }
        if (!selected.isNullOrEmpty()) {
            ic.commitText("", 1)
            return
        }
        if (!ic.deleteSurroundingText(1, 0)) {
            sendDownUpKeyEvents(KeyEvent.KEYCODE_DEL)
        }
    }

    private fun handleEnter() {
        haptic(root)
        if (currentInputConnection == null) return
        sendDownUpKeyEvents(KeyEvent.KEYCODE_ENTER)
    }

    private fun haptic(view: View) {
        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    /** Codigo de tecla fisica para combinaciones modificadoras (a-z y corchetes). */
    private fun keyCodeFor(c: Char): Int? = when {
        c in 'a'..'z' -> KeyEvent.KEYCODE_A + (c - 'a')
        c == '[' -> KeyEvent.KEYCODE_LEFT_BRACKET
        else -> null
    }

    // ------------------------------------------------------------------
    // Acentos por toque largo y pares auto-cerrados
    // ------------------------------------------------------------------

    private fun accentsFor(c: Char): List<String> = when (c) {
        'a' -> listOf("á", "à", "ä", "â", "ã")
        'e' -> listOf("é", "è", "ë", "ê")
        'i' -> listOf("í", "ì", "ï", "î")
        'o' -> listOf("ó", "ò", "ö", "ô", "õ")
        'u' -> listOf("ú", "ù", "ü", "û")
        'n' -> listOf("ñ")
        'c' -> listOf("ç")
        else -> emptyList()
    }

    /** Par auto-cerrado para la capa codigo; null si no aplica. */
    private fun pairCloseFor(open: Char): Char? = when (open) {
        '{' -> '}'
        '[' -> ']'
        '(' -> ')'
        '<' -> '>'
        '"' -> '"'
        '\'' -> '\''
        '`' -> '`'
        else -> null
    }

    /** Logica comun de toque largo: programa accion diferida y decide en UP. */
    private fun attachLongPress(
        key: TextView,
        onLongPress: () -> Unit,
        onTapUp: () -> Unit,
    ) {
        var pending: Runnable? = null
        var longPressFired = false
        key.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    longPressFired = false
                    val r = Runnable {
                        longPressFired = true
                        onLongPress()
                    }
                    pending = r
                    handler.postDelayed(r, LONG_PRESS_MILLIS)
                    false
                }
                MotionEvent.ACTION_UP -> {
                    pending?.let { handler.removeCallbacks(it) }
                    pending = null
                    if (!longPressFired) {
                        onTapUp()
                    }
                    v.isPressed = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    pending?.let { handler.removeCallbacks(it) }
                    pending = null
                    v.isPressed = false
                    true
                }
                else -> false
            }
        }
    }

    private fun attachAccentLongPress(key: TextView, base: Char) {
        attachLongPress(
            key,
            onLongPress = { showAccentPopup(key, base) },
            onTapUp = { commitLetter(base) },
        )
    }

    private fun attachPairLongPress(key: TextView, ch: Char) {
        val close = pairCloseFor(ch)
        attachLongPress(
            key,
            onLongPress = {
                if (close != null) {
                    commit("$ch$close")
                    sendKeyCode(KeyEvent.KEYCODE_DPAD_LEFT)
                }
            },
            onTapUp = { commitSymbolText(ch.toString()) },
        )
    }

    private fun showAccentPopup(anchor: View, base: Char) {
        dismissPopup()
        val options = accentsFor(base)
        if (options.isEmpty()) return
        val box = LinearLayout(this)
        box.orientation = LinearLayout.HORIZONTAL
        box.setBackgroundResource(R.drawable.kb_popup_bg)
        val pad = dimen(R.dimen.kb_popup_padding)
        box.setPadding(pad, pad, pad, pad)
        for (opt in options) {
            val tv = TextView(this)
            tv.text = opt
            tv.gravity = Gravity.CENTER
            tv.isClickable = true
            tv.isFocusable = true
            tv.setPadding(pad * 2, pad, pad * 2, pad)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size).toFloat())
            tv.setOnClickListener {
                commit(opt)
                dismissPopup()
            }
            box.addView(tv)
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
        activePopup = popup
        popup.showAtLocation(
            root,
            Gravity.NO_GRAVITY,
            loc[0],
            loc[1] - box.measuredHeight - dimen(R.dimen.kb_key_gap),
        )
    }

    private fun dismissPopup() {
        activePopup?.let { popup ->
            if (popup.isShowing) {
                popup.dismiss()
            }
        }
        activePopup = null
    }

    private fun dimen(resId: Int): Int = resources.getDimensionPixelSize(resId)

    companion object {
        private const val LONG_PRESS_MILLIS = 350L
    }
}
