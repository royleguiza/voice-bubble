package com.royleguiza.voicebubblestt

import android.animation.ObjectAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextUtils
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Teclado del sistema VoiceBubble.
 * K1: QWERTY es/en + capa simbolos basicos + acentos por toque largo.
 * K2: capa codigo con pares auto-cerrados + fila terminal permanente
 *     (TAB/ESC/CTRL/ALT/flechas) con modificadores sticky para Termux.
 * K4: capa snippets (chips + busqueda) que inserta el contenido en el cursor.
 * Este teclado JAMAS registra, guarda ni transmite texto tecleado.
 */
class VoiceKeyboardService : InputMethodService() {

    private enum class Layer { LETTERS, SYMBOLS, CODE, SNIPPETS }

    private enum class MicState { IDLE, RECORDING, PROCESSING, BUSY }

    private var layer = Layer.LETTERS
    private var lastLettersLayer = Layer.LETTERS
    private var spanishMode = true
    private var shiftActive = false
    private var ctrlActive = false
    private var altActive = false

    // --- Dictado (K3) ---
    private lateinit var sttClient: SpeechToTextClient
    private var micState = MicState.IDLE
    private var currentIsPasswordField = false
    private var micKeyView: TextView? = null
    private var statusRowView: TextView? = null
    private var timeoutRunnable: Runnable? = null
    private var dismissStatusRunnable: Runnable? = null
    private var focusRequest: AudioFocusRequest? = null
    private var pulseAnimators: List<ObjectAnimator> = emptyList()

    // --- Snippets (K4) ---
    private lateinit var snippetStore: SnippetStore
    private var layerBeforeSnippets = Layer.LETTERS
    private var snippetsSeedAttempted = false
    private var snippetQuery = ""
    private var snippetGridContainer: LinearLayout? = null

    // K4-T3: con el campo de busqueda enfocado, los commits del propio
    // teclado se redirigen al query en vez del documento destino.
    private var snippetSearchActive = false
    private var snippetSearchField: EditText? = null

    private lateinit var root: LinearLayout
    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private val shiftKeyViews = mutableListOf<TextView>()
    private val modifierKeyViews = mutableListOf<Pair<TextView, Boolean>>()

    private var activePopup: PopupWindow? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onCreateInputView(): View {
        sttClient = SpeechToTextClient(this)
        snippetStore = SnippetStore(this)
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
        currentIsPasswordField = isPasswordInput(info)
        layer = Layer.LETTERS
        lastLettersLayer = Layer.LETTERS
        shiftActive = false
        ctrlActive = false
        altActive = false
        rebuild()
    }

    /** Campos de contraseña: sin micrófono, snippets ni sugerencias (K3). */
    private fun isPasswordInput(info: EditorInfo?): Boolean {
        if (info == null) return false
        val variation = info.inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
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
        removeStatusRow()
        letterKeys.clear()
        shiftKeyViews.clear()
        modifierKeyViews.clear()
        if (layer != Layer.SNIPPETS) {
            snippetQuery = ""
            snippetGridContainer = null
            snippetSearchActive = false
            snippetSearchField = null
        }
        root.removeAllViews()

        // K2.1: fila terminal ocultable desde Ajustes de la app (default visible).
        if (terminalRowVisible()) {
            addRow(buildTerminalRow())
        }
        when (layer) {
            Layer.LETTERS -> buildLetterRows()
            Layer.SYMBOLS -> buildSymbolRows()
            Layer.CODE -> buildCodeRows()
            Layer.SNIPPETS -> buildSnippetRows()
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
        val shiftKey = makeSpecialKey("⇧", R.drawable.kb_key_alt, 1.3f, "mayúsculas") {
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
        // K2.2: teclas de capa codigo e idioma ocultables desde Ajustes (default visibles).
        if (codeKeyVisible()) {
            row.addView(makeSpecialKey("</>", R.drawable.kb_key_alt, 1f, "capa código") {
                toggleCodeLayer()
            })
        }
        // K4: acceso a la capa snippets; oculto en campos de contrasena igual que el microfono.
        if (!currentIsPasswordField) {
            row.addView(makeSpecialKey("☰", R.drawable.kb_key_alt, 1f, "snippets") {
                toggleSnippetsLayer()
            })
        }
        if (languageKeyVisible()) {
            row.addView(makeSpecialKey(if (spanishMode) "ES" else "EN", R.drawable.kb_key_alt, 1f, "cambiar idioma") {
                spanishMode = !spanishMode
                rebuild()
            })
        }
        if (!currentIsPasswordField) {
            micKeyView = makeMicKey()
            row.addView(micKeyView)
        } else {
            micKeyView = null
        }
        row.addView(makeSymbolKey(","))
        row.addView(makeSpecialKey("", R.drawable.kb_key_bg, 2.6f, "espacio") {
            commit(" ")
        })
        row.addView(makeSymbolKey("."))
        row.addView(makeSpecialKey("↵", R.drawable.kb_key_accent, 1.8f, "enter") {
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
            // Desde snippets no se pisa la memoria: volver conserva el origen.
            if (layer != Layer.SNIPPETS) {
                lastLettersLayer = if (layer == Layer.SYMBOLS) Layer.LETTERS else layer
            }
            layer = Layer.CODE
        }
        rebuild()
    }

    private fun makeBackspaceKey(): TextView =
        makeSpecialKey("⌫", R.drawable.kb_key_alt, 1.3f, "borrar") {
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
        if (routeToSnippetQuery(displayFor(base))) {
            if (shiftActive) {
                shiftActive = false
                applyCase()
            }
            return
        }
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
        if (routeToSnippetQuery(text)) return
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
        if (routeToSnippetQuery(text)) return
        currentInputConnection?.commitText(text, 1)
    }

    /**
     * Modo busqueda activo en la capa snippets: captura los commits del
     * propio teclado y los puebla en el query para filtrar, sin escribir
     * nunca en la app destino (patron estilo Gboard). Devuelve true si el
     * texto fue consumido por el modo busqueda.
     */
    private fun routeToSnippetQuery(text: String): Boolean {
        if (layer != Layer.SNIPPETS || !snippetSearchActive) return false
        val et = snippetSearchField ?: return false
        val editable = et.text
        if (editable.length >= SNIPPET_QUERY_MAX_CHARS) return true
        val remaining = SNIPPET_QUERY_MAX_CHARS - editable.length
        val chunk = if (text.length > remaining) text.substring(0, remaining) else text
        editable.append(chunk)
        et.setSelection(editable.length)
        refreshSnippetGrid()
        return true
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
        if (layer == Layer.SNIPPETS && snippetSearchActive) {
            val et = snippetSearchField ?: return
            val text = et.text
            if (!text.isNullOrEmpty()) {
                text.delete(text.length - 1, text.length)
                et.setSelection(text.length)
                refreshSnippetGrid()
            }
            return
        }
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
        if (layer == Layer.SNIPPETS && snippetSearchActive) {
            exitSnippetSearchMode()
            return
        }
        if (currentInputConnection == null) return
        sendDownUpKeyEvents(KeyEvent.KEYCODE_ENTER)
    }

    /** Apaga el modo busqueda y restaura el fondo inactivo del campo. */
    private fun exitSnippetSearchMode() {
        snippetSearchActive = false
        snippetSearchField?.clearFocus()
        applySnippetSearchVisual()
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
    // Dictado por voz (K3)
    // ------------------------------------------------------------------

    private fun makeMicKey(): TextView {
        val key = makeKey(
            "🎤",
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size_small),
        )
        key.contentDescription = "dictar"
        attachLongPress(
            key,
            onLongPress = {
                when (micState) {
                    MicState.RECORDING -> cancelDictation()
                    MicState.IDLE, MicState.BUSY -> showHistoryPopup(key)
                    MicState.PROCESSING -> { /* transcribiendo: ignorar */ }
                }
            },
            onTapUp = { handleMicTap() },
        )
        applyMicVisual(key)
        return key
    }

    private fun handleMicTap() {
        haptic(root)
        when (micState) {
            MicState.IDLE, MicState.BUSY -> startDictation()
            MicState.RECORDING -> finishDictation()
            MicState.PROCESSING -> { /* en curso: ignorar toques */ }
        }
    }

    private fun bubbleBusy(): Boolean =
        FloatingBubbleService.isRunning && FloatingBubbleService.lastVisualState != "idle"

    private fun startDictation() {
        if (bubbleBusy()) {
            micState = MicState.BUSY
            refreshMicVisual()
            showStatus("Ocupado: la burbuja está grabando.")
            return
        }
        val config = sttClient.loadConfig()
        if (config.apiKey.isBlank()) {
            micState = MicState.IDLE
            refreshMicVisual()
            showStatus("Falta la API key. Toca este aviso para abrir Ajustes.", openSettingsOnClick = true)
            return
        }
        if (!sttClient.hasMicPermission()) {
            showStatus("Permiso de micrófono denegado. Concedelo desde Ajustes.", openSettingsOnClick = true)
            return
        }
        keyboardRecordingActive = true
        gainAudioFocus()
        val started = sttClient.startRecording()
        if (!started) {
            abandonAudioFocus()
            keyboardRecordingActive = false
            showStatus("No se pudo iniciar la grabación.")
            return
        }
        micState = MicState.RECORDING
        refreshMicVisual()
        val t = Runnable { if (micState == MicState.RECORDING) finishDictation() }
        timeoutRunnable = t
        handler.postDelayed(t, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun finishDictation() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.PROCESSING
        refreshMicVisual()
        val config = sttClient.loadConfig()
        Thread {
            val wav = sttClient.stopRecording()
            abandonAudioFocus()
            keyboardRecordingActive = false
            if (sttClient.isEmptyCapture(wav)) {
                runOnMain {
                    micIdle()
                    showStatus("No se detectó voz.")
                }
                return@Thread
            }
            sttClient.transcribe(
                wav,
                config,
                onDone = { text ->
                    runOnMain {
                        micIdle()
                        if (text.isNullOrBlank()) {
                            showStatus("No se detectó voz.")
                        } else {
                            commit(text)
                            addToSharedHistory(text)
                        }
                    }
                },
                onError = { message ->
                    runOnMain {
                        micIdle()
                        showStatus(message)
                    }
                },
            )
        }.apply { name = "VbKeyboardFinish"; start() }
    }

    private fun cancelDictation() {
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.IDLE
        refreshMicVisual()
        Thread {
            sttClient.cancelRecording()
            abandonAudioFocus()
            keyboardRecordingActive = false
        }.start()
    }

    private fun micIdle() {
        micState = MicState.IDLE
        refreshMicVisual()
    }

    private fun runOnMain(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }

    private fun refreshMicVisual() {
        micKeyView?.let { applyMicVisual(it) }
    }

    private fun applyMicVisual(key: TextView) {
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()
        when (micState) {
            MicState.IDLE -> {
                key.setBackgroundResource(R.drawable.kb_key_bg)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
                key.text = "🎤"
                key.alpha = 1f
            }
            MicState.RECORDING -> {
                key.setBackgroundResource(R.drawable.kb_mic_recording)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
                key.text = "⏺"
                key.alpha = 1f
                if (!reducedMotion()) {
                    val x = ObjectAnimator.ofFloat(key, View.SCALE_X, 1f, 1.08f)
                    val y = ObjectAnimator.ofFloat(key, View.SCALE_Y, 1f, 1.08f)
                    listOf(x, y).forEach { a ->
                        a.repeatCount = ObjectAnimator.INFINITE
                        a.repeatMode = ObjectAnimator.REVERSE
                        a.duration = 450
                        a.start()
                    }
                    pulseAnimators = listOf(x, y)
                }
            }
            MicState.PROCESSING -> {
                key.setBackgroundResource(R.drawable.kb_key_alt)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
                key.text = "···"
                key.alpha = 1f
            }
            MicState.BUSY -> {
                key.setBackgroundResource(R.drawable.kb_key_alt)
                key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
                key.text = "🎤"
                key.alpha = 0.5f
            }
        }
    }

    private fun reducedMotion(): Boolean =
        Settings.Global.getFloat(
            contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) == 0f

    private fun gainAudioFocus() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val request = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
            ).setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            ).build()
            am.requestAudioFocus(request)
            focusRequest = request
        } catch (_: Exception) {}
    }

    private fun abandonAudioFocus() {
        try {
            focusRequest?.let { request ->
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.abandonAudioFocusRequest(request)
            }
        } catch (_: Exception) {}
        focusRequest = null
    }

    /**
     * Alta en el historial FIFO-20 compartido con la app. El plugin
     * shared_preferences guarda la lista como Set nativo sin orden garantizado:
     * se reordena por timestamp descendente (el mismo criterio semantico de la
     * app: mas nuevo primero) para que el contrato sea determinista.
     */
    private fun addToSharedHistory(text: String) {
        try {
            val prefs = getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val raw = prefs.getStringSet("flutter.transcriptions", emptySet())
                ?: emptySet()
            val entries = ArrayList<JSONObject>()
            for (entry in raw) {
                try { entries.add(JSONObject(entry)) } catch (_: Exception) {}
            }
            val newEntry = JSONObject()
                .put("text", text)
                .put("timestamp", java.time.Instant.now().toString())
                .put("isLocal", false)
            entries.add(newEntry)
            val sorted = entries.sortedByDescending { obj ->
                try {
                    java.time.Instant.parse(obj.optString("timestamp"))
                } catch (_: Exception) {
                    java.time.Instant.EPOCH
                }
            }
            val out = LinkedHashSet<String>()
            for (obj in sorted.take(20)) {
                out.add(obj.toString())
            }
            prefs.edit().putStringSet("flutter.transcriptions", out).apply()
        } catch (_: Exception) {}
    }

    /**
     * Ventana con las ultimas transcripciones del historial compartido para
     * insertar una en el cursor (toque largo en el microfono en reposo u
     * ocupado). Insertar NO agrega al historial: no es dictado nuevo.
     * PRIVACIDAD: el contenido jamas se registra en Log; la ventana vive solo
     * en memoria y se cierra al insertar o tocar afuera. Los campos de
     * contrasena ya ocultan la tecla de microfono, asi que no hace falta un
     * chequeo adicional aqui.
     */
    private fun showHistoryPopup(anchor: View) {
        dismissPopup()
        val entries = sharedHistoryEntries()
        val pad = dimen(R.dimen.kb_popup_padding)
        val content = LinearLayout(this)
        content.orientation = LinearLayout.VERTICAL
        var first = true
        for (obj in entries) {
            val text = obj.optString("text")
            if (text.isBlank()) continue
            if (!first) {
                val sep = View(this)
                sep.setBackgroundColor(ContextCompat.getColor(this, R.color.kb_key_stroke))
                content.addView(
                    sep,
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        TypedValue.applyDimension(
                            TypedValue.COMPLEX_UNIT_DIP, 1f, resources.displayMetrics,
                        ).toInt(),
                    ),
                )
            }
            first = false
            val tv = TextView(this)
            tv.text = text
            tv.maxLines = 2
            tv.ellipsize = TextUtils.TruncateAt.END
            tv.isClickable = true
            tv.isFocusable = true
            tv.setPadding(pad * 2, pad, pad * 2, pad)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            tv.setOnClickListener {
                commit(text)
                dismissPopup()
            }
            content.addView(tv)
        }
        if (first) {
            val empty = TextView(this)
            empty.text = "Sin transcripciones todavía."
            empty.setPadding(pad * 2, pad, pad * 2, pad)
            empty.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            empty.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            content.addView(empty)
        }
        val scroll = ScrollView(this)
        scroll.addView(content)
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.setBackgroundResource(R.drawable.kb_popup_bg)
        box.setPadding(pad, pad, pad, pad)
        box.addView(scroll)
        // Medida natural y tope del area scrolleable (~40% de la pantalla):
        // si el contenido excede el tope, el ScrollView recorta y scrollea.
        box.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val maxContentHeight = (resources.displayMetrics.heightPixels * 0.4f).toInt()
        val popupHeight = minOf(box.measuredHeight, maxContentHeight)
        val popupWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 300f, resources.displayMetrics,
        ).toInt()
        val popup = PopupWindow(box, popupWidth, popupHeight, true)
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        activePopup = popup
        popup.showAtLocation(
            root,
            Gravity.NO_GRAVITY,
            loc[0],
            loc[1] - popupHeight - dimen(R.dimen.kb_key_gap),
        )
    }

    /**
     * Historial compartido parseado con tolerancia (entradas corruptas se
     * descartan) y ordenado por timestamp descendente: mismo criterio de
     * lectura que addToSharedHistory y la app.
     */
    private fun sharedHistoryEntries(): List<JSONObject> {
        return try {
            val prefs = getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val raw = prefs.getStringSet("flutter.transcriptions", emptySet())
                ?: emptySet()
            val entries = ArrayList<JSONObject>()
            for (entry in raw) {
                try { entries.add(JSONObject(entry)) } catch (_: Exception) {}
            }
            entries.sortedByDescending { obj ->
                try {
                    java.time.Instant.parse(obj.optString("timestamp"))
                } catch (_: Exception) {
                    java.time.Instant.EPOCH
                }
            }.take(20)
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Aviso inline no bloqueante; auto-descarta a los 3.5 s. */
    private fun showStatus(message: String, openSettingsOnClick: Boolean = false) {
        root.post {
            if (!::root.isInitialized) return@post
            removeStatusRow()
            val tv = TextView(this)
            tv.text = message
            tv.gravity = Gravity.CENTER
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            tv.setPadding(dimen(R.dimen.kb_popup_padding), dimen(R.dimen.kb_popup_padding), dimen(R.dimen.kb_popup_padding), dimen(R.dimen.kb_popup_padding))
            tv.setBackgroundResource(R.drawable.kb_popup_bg)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            if (openSettingsOnClick) {
                tv.isClickable = true
                tv.setOnClickListener { openAppUi() }
            }
            statusRowView = tv
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            lp.bottomMargin = dimen(R.dimen.kb_key_gap)
            root.addView(tv, 0, lp)
            val dismiss = Runnable { removeStatusRow() }
            dismissStatusRunnable = dismiss
            handler.postDelayed(dismiss, 3500L)
        }
    }

    private fun removeStatusRow() {
        dismissStatusRunnable?.let { handler.removeCallbacks(it) }
        dismissStatusRunnable = null
        statusRowView?.let {
            (it.parent as? ViewGroup)?.removeView(it)
        }
        statusRowView = null
    }

    /** Abre la UI principal de la app (Ajustes) desde el teclado. */
    private fun openAppUi() {
        try {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {}
    }

    // ------------------------------------------------------------------
    // Capa snippets (K4)
    // ------------------------------------------------------------------

    /**
     * Apertura/cierre de la capa snippets. Al abrir: siembra los seeds solo en
     * la primera apertura (idempotencia interna del store), recarga siempre
     * desde prefs (recarga viva: los cambios hechos en la app aparecen al
     * reabrir sin reiniciar nada) y recuerda la capa de origen para volver.
     */
    private fun toggleSnippetsLayer() {
        if (layer == Layer.SNIPPETS) {
            layer = layerBeforeSnippets
            snippetSearchActive = false
            snippetSearchField = null
            rebuild()
            return
        }
        layerBeforeSnippets = layer
        if (!snippetsSeedAttempted) {
            snippetsSeedAttempted = true
            snippetStore.seedIfFirstOpen()
        }
        snippetStore.reload()
        snippetQuery = ""
        layer = Layer.SNIPPETS
        rebuild()
    }

    /** Fila de busqueda + grid scrolleable de chips (2 por fila). */
    private fun buildSnippetRows() {
        addRow(buildSnippetSearchRow())
        val scroll = ScrollView(this)
        scroll.isVerticalScrollBarEnabled = false
        val grid = LinearLayout(this)
        grid.orientation = LinearLayout.VERTICAL
        snippetGridContainer = grid
        scroll.addView(grid)
        refreshSnippetGrid()
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dimen(R.dimen.kb_snippets_grid_height),
        )
        lp.topMargin = dimen(R.dimen.kb_key_gap)
        root.addView(scroll, lp)
    }

    private fun buildSnippetSearchRow(): LinearLayout {
        val row = horizontalRow()
        val pad = dimen(R.dimen.kb_popup_padding)
        val et = EditText(this)
        et.hint = if (spanishMode) "Buscar snippets" else "Search snippets"
        et.setSingleLine(true)
        et.maxLines = 1
        et.inputType = InputType.TYPE_CLASS_TEXT
        et.imeOptions = EditorInfo.IME_ACTION_SEARCH
        et.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
        et.setHintTextColor(ContextCompat.getColor(this, R.color.kb_label_secondary))
        et.setBackgroundResource(R.drawable.kb_key_bg)
        et.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        et.setPadding(pad * 2, pad, pad * 2, pad)
        // Filtra por nombre en tiempo real repoblando solo el grid, para no
        // reconstruir la vista y perder el foco del campo de busqueda.
        et.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                snippetQuery = s?.toString() ?: ""
                refreshSnippetGrid()
            }
        })
        if (snippetQuery.isNotEmpty()) {
            et.setText(snippetQuery)
        }
        // Referencia para el enrutado de commits; campo nuevo arranca inactivo.
        snippetSearchActive = false
        snippetSearchField = et
        et.onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
            snippetSearchActive = hasFocus
            applySnippetSearchVisual()
        }
        et.setOnClickListener { v ->
            if (!v.hasFocus()) v.requestFocus()
            snippetSearchActive = true
            applySnippetSearchVisual()
        }
        val lp = LinearLayout.LayoutParams(0, dimen(R.dimen.kb_key_height), 1f)
        val m = dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        row.addView(et, lp)
        return row
    }

    /** Feedback visual del modo busqueda: fondo acentuado cuando esta activo. */
    private fun applySnippetSearchVisual() {
        val et = snippetSearchField ?: return
        et.setBackgroundResource(
            if (snippetSearchActive) R.drawable.kb_key_accent else R.drawable.kb_key_bg,
        )
    }

    /** Repuebla el grid con el filtro actual sobre el cache fresco del store. */
    private fun refreshSnippetGrid() {
        val container = snippetGridContainer ?: return
        container.removeAllViews()
        val query = snippetQuery.trim()
        val all = snippetStore.get()
        val filtered = if (query.isEmpty()) {
            all
        } else {
            all.filter { it.nombre.contains(query, ignoreCase = true) }
        }
        if (filtered.isEmpty()) {
            container.addView(emptySnippetsView())
            return
        }
        var i = 0
        while (i < filtered.size) {
            val row = horizontalRow()
            row.addView(makeSnippetChip(filtered[i]))
            if (i + 1 < filtered.size) {
                row.addView(makeSnippetChip(filtered[i + 1]))
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dimen(R.dimen.kb_key_height),
            )
            if (container.childCount > 0) {
                lp.topMargin = dimen(R.dimen.kb_key_gap)
            }
            container.addView(row, lp)
            i += 2
        }
    }

    /** Chip con el nombre del snippet: tap inserta, toque largo abre menu. */
    private fun makeSnippetChip(snippet: VbSnippet): TextView {
        val chip = TextView(this)
        chip.text = snippet.nombre
        chip.gravity = Gravity.CENTER
        chip.isClickable = true
        chip.isFocusable = true
        chip.includeFontPadding = false
        chip.maxLines = 1
        chip.ellipsize = TextUtils.TruncateAt.END
        chip.setPadding(
            dimen(R.dimen.kb_popup_padding), 0,
            dimen(R.dimen.kb_popup_padding), 0,
        )
        chip.setBackgroundResource(R.drawable.kb_key_bg)
        chip.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
        chip.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        chip.contentDescription = snippet.nombre
        attachLongPress(
            chip,
            onLongPress = { showSnippetMenu(chip, snippet) },
            onTapUp = { insertSnippet(snippet) },
        )
        val lp = LinearLayout.LayoutParams(0, dimen(R.dimen.kb_key_height), 1f)
        val m = dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        chip.layoutParams = lp
        return chip
    }

    private fun emptySnippetsView(): TextView {
        val pad = dimen(R.dimen.kb_popup_padding)
        val tv = TextView(this)
        tv.text = if (spanishMode) "Sin snippets todavía." else "No snippets yet."
        tv.gravity = Gravity.CENTER
        tv.setPadding(pad, pad * 2, pad, pad * 2)
        tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label_secondary))
        tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        return tv
    }

    /**
     * Insercion del contenido completo en el cursor via commitText (soporta
     * multilinea con \n) y regreso a la capa de origen.
     * PRIVACIDAD: ni contenido ni nombre ni id se registran en Log.
     */
    private fun insertSnippet(snippet: VbSnippet) {
        haptic(root)
        consumeModifiers()
        currentInputConnection?.commitText(snippet.contenido, 1)
        snippetSearchActive = false
        snippetSearchField = null
        layer = layerBeforeSnippets
        rebuild()
    }

    /** Menu contextual del chip: insertar, copiar o abrir la app para editar. */
    private fun showSnippetMenu(anchor: View, snippet: VbSnippet) {
        dismissPopup()
        val pad = dimen(R.dimen.kb_popup_padding)
        val box = LinearLayout(this)
        box.orientation = LinearLayout.VERTICAL
        box.setBackgroundResource(R.drawable.kb_popup_bg)
        box.setPadding(pad, pad, pad, pad)

        fun addOption(label: String, action: () -> Unit) {
            val tv = TextView(this)
            tv.text = label
            tv.isClickable = true
            tv.isFocusable = true
            tv.setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            tv.setOnClickListener {
                haptic(it)
                dismissPopup()
                action()
            }
            box.addView(tv)
        }
        addOption(if (spanishMode) "Insertar" else "Insert") { insertSnippet(snippet) }
        addOption(if (spanishMode) "Copiar al portapapeles" else "Copy to clipboard") {
            copySnippetToClipboard(snippet.contenido)
        }
        addOption(if (spanishMode) "Abrir app para editar" else "Open app to edit") {
            openAppUi()
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

    /** Copia al portapapeles del sistema; accion iniciada por el usuario. */
    private fun copySnippetToClipboard(text: String) {
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("VoiceBubble", text))
        } catch (_: Exception) {}
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

    /**
     * Preferencia escrita por los Ajustes de la app (Flutter shared_preferences
     * guarda con prefijo "flutter." en el archivo FlutterSharedPreferences).
     * Parseo tolerante: ante cualquier error se muestra la fila (default true).
     */
    private fun terminalRowVisible(): Boolean = try {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_terminal_row_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla "</>" de capa codigo ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    private fun codeKeyVisible(): Boolean = try {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_code_key_visible", true)
    } catch (_: Exception) {
        true
    }

    /**
     * Preferencia escrita por los Ajustes de la app (mismo puente K2.1):
     * tecla ES/EN de idioma ocultable; ante cualquier error se muestra
     * la tecla (default true).
     */
    private fun languageKeyVisible(): Boolean = try {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.kb_language_key_visible", true)
    } catch (_: Exception) {
        true
    }

    companion object {
        private const val LONG_PRESS_MILLIS = 350L

        /** Tope del query de busqueda de snippets. */
        private const val SNIPPET_QUERY_MAX_CHARS = 50

        /** Exclusion mutua de microfono: visible para MainActivity/burbuja. */
        @Volatile
        var keyboardRecordingActive: Boolean = false
    }
}
