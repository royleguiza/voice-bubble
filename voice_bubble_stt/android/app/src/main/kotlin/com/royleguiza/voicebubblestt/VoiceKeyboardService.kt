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
import android.util.Xml
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import kotlin.math.abs

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

    /** Shift en tres estados: momentaneo tras un tap, persistente tras doble pulso. */
    private enum class ShiftState { OFF, MOMENTARY, CAPS_LOCK }

    private var layer = Layer.LETTERS
    private var lastLettersLayer = Layer.LETTERS
    // @Volatile: el cliente STT lo consulta desde su hilo de fondo para
    // localizar los avisos de error (K5-T4).
    @Volatile
    private var spanishMode = true
    private var shiftState = ShiftState.OFF

    /** Uptime del ultimo tap en shift; detecta el doble pulso (caps lock). */
    private var lastShiftTapUptime = 0L
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

    // --- Preferencias de aspecto (K5-T2/T3, puente Flutter) ---
    // Se leen UNA VEZ por apertura (loadKeyboardPrefs en onCreateInputView y
    // onStartInputView) y quedan cacheadas aca para no golpear SharedPreferences
    // en cada tecla. heightFactor escala solo alturas propias del teclado,
    // jamas el padding inferior por insets.
    private var heightFactor = HEIGHT_FACTOR_MEDIA
    private var hapticsEnabled = true

    private lateinit var root: LinearLayout
    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private val shiftKeyViews = mutableListOf<TextView>()
    private val modifierKeyViews = mutableListOf<Pair<TextView, Boolean>>()

    private var activePopup: PopupWindow? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onCreateInputView(): View {
        // K5-T5: recreacion de vista (ej. rotacion) nunca debe dejar una
        // grabacion fantasma del cliente anterior colgada.
        cancelDictationIfActive()
        sttClient = SpeechToTextClient(this) { spanishMode }
        snippetStore = SnippetStore(this)
        loadKeyboardPrefs()
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
        // K5-T5: defensa extra; nunca arrancar un campo con dictado vivo.
        cancelDictationIfActive()
        loadKeyboardPrefs()
        currentIsPasswordField = isPasswordInput(info)
        layer = Layer.LETTERS
        lastLettersLayer = Layer.LETTERS
        deactivateShift()
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

    /** K5-T5: al cerrarse el campo actual, corta dictado y popups vivos. */
    override fun onFinishInputView(finishingInput: Boolean) {
        cancelDictationIfActive()
        dismissPopup()
        super.onFinishInputView(finishingInput)
    }

    override fun onWindowHidden() {
        super.onWindowHidden()
        dismissPopup()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        dismissPopup()
        // K5-T5: destruccion del servicio con dictado vivo = grabacion fantasma.
        cancelDictationIfActive()
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
        row.addView(
            makeArrowKey(
                "←", KeyEvent.KEYCODE_DPAD_LEFT,
                if (spanishMode) "flecha izquierda" else "left arrow",
            )
        )
        row.addView(
            makeArrowKey(
                "↑", KeyEvent.KEYCODE_DPAD_UP,
                if (spanishMode) "flecha arriba" else "up arrow",
            )
        )
        row.addView(
            makeArrowKey(
                "↓", KeyEvent.KEYCODE_DPAD_DOWN,
                if (spanishMode) "flecha abajo" else "down arrow",
            )
        )
        row.addView(
            makeArrowKey(
                "→", KeyEvent.KEYCODE_DPAD_RIGHT,
                if (spanishMode) "flecha derecha" else "right arrow",
            )
        )
        return row
    }

    private fun makeArrowKey(glyph: String, code: Int, description: String?): TextView =
        makeSpecialKey(glyph, R.drawable.kb_key_bg, 1f, description) {
            sendKeyCode(code)
        }

    /** CTRL/ALT sticky: tap activa/desactiva; la proxima tecla los consume. */
    private fun makeModifierKey(label: String, isCtrl: Boolean, weight: Float): TextView {
        val key = makeSpecialKey(
            label,
            R.drawable.kb_key_alt,
            weight,
            if (isCtrl) {
                if (spanishMode) "tecla control" else "control key"
            } else {
                if (spanishMode) "tecla alt" else "alt key"
            },
        ) {}
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
        val shiftKey = makeSpecialKey(
            "⇧",
            R.drawable.kb_key_alt,
            1.3f,
            if (spanishMode) "mayúsculas" else "shift",
            dimen(R.dimen.kb_key_glyph_shift),
        ) {
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
        row.addView(makeSpecialKey(symbolsToggleLabel(), R.drawable.kb_key_alt, 1.5f, if (spanishMode) "símbolos" else "symbols") {
            layer = if (layer == Layer.SYMBOLS) Layer.LETTERS else Layer.SYMBOLS
            rebuild()
        })
        // K2.2: teclas de capa codigo e idioma ocultables desde Ajustes (default visibles).
        if (codeKeyVisible()) {
            row.addView(makeSpecialKey("</>", R.drawable.kb_key_alt, 1f, if (spanishMode) "capa código" else "code layer") {
                toggleCodeLayer()
            })
        }
        if (languageKeyVisible()) {
            row.addView(makeSpecialKey(if (spanishMode) "ES" else "EN", R.drawable.kb_key_alt, 1f, if (spanishMode) "cambiar idioma" else "switch language") {
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
        row.addView(makeSymbolKey(",", dimen(R.dimen.kb_key_glyph_punct)))
        row.addView(makeSpecialKey("", R.drawable.kb_key_bg, 3.0f, if (spanishMode) "espacio" else "space") {
            // En snippets el espacio alimenta el query, nunca el documento.
            if (layer == Layer.SNIPPETS) ensureSnippetSearchMode()
            commit(" ")
        })
        row.addView(makeSymbolKey(".", dimen(R.dimen.kb_key_glyph_punct)))
        // K4: acceso a la capa snippets; oculto en campos de contrasena igual que el microfono.
        if (!currentIsPasswordField) {
            row.addView(makeSpecialKey("☰", R.drawable.kb_key_alt, 1f, "snippets") {
                toggleSnippetsLayer()
            })
        }
        row.addView(
            makeSpecialKey(
                "↵",
                R.drawable.kb_key_accent,
                1.8f,
                "enter",
                dimen(R.dimen.kb_key_glyph_enter),
            ) {
                handleEnter()
            },
        )
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

    private fun makeBackspaceKey(): TextView {
        val key = makeSpecialKey("⌫", R.drawable.kb_key_alt, 1.3f, if (spanishMode) "borrar" else "delete") {
            handleBackspace()
        }
        attachBackspaceGestures(key) {
            handleBackspace()
        }
        return key
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

    private fun makeSymbolKey(
        label: String,
        textSizePx: Int = dimen(R.dimen.kb_key_text_size_small),
    ): TextView {
        val key = makeKey(
            label,
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            textSizePx,
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
        textSizePx: Int = dimen(R.dimen.kb_key_text_size_small),
        onClick: () -> Unit,
    ): TextView {
        val key = makeKey(
            label,
            weight,
            bgRes,
            R.color.kb_label,
            textSizePx,
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
        val lp = LinearLayout.LayoutParams(0, keyHeightPx(), weight)
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
            lp.topMargin = rowGapPx()
        }
        root.addView(row, lp)
    }

    // ------------------------------------------------------------------
    // Comportamiento de teclas
    // ------------------------------------------------------------------

    private fun displayFor(base: Char): String =
        if (shiftState == ShiftState.OFF) base.toString() else base.uppercaseChar().toString()

    /**
     * Maquina de estados shift (P3): OFF -> MOMENTARY con un tap; doble pulso
     * rapido (<= 300 ms entre taps) escala a CAPS_LOCK desde OFF o MOMENTARY.
     * En CAPS_LOCK un solo tap vuelve directo a OFF. El emparejamiento es por
     * intervalo entre taps consecutivos (patron estandar de teclados), y el
     * timestamp se invalida al apagarse shift por via no-tactil para que un
     * tap posterior nunca herede un par fantasma.
     */
    private fun toggleShift() {
        val now = SystemClock.uptimeMillis()
        val quickPair = now - lastShiftTapUptime <= SHIFT_DOUBLE_TAP_MILLIS
        lastShiftTapUptime = now
        shiftState = when {
            shiftState == ShiftState.CAPS_LOCK -> ShiftState.OFF
            quickPair -> ShiftState.CAPS_LOCK
            shiftState == ShiftState.OFF -> ShiftState.MOMENTARY
            else -> ShiftState.OFF
        }
        applyCase()
    }

    private fun applyCase() {
        val upper = shiftState != ShiftState.OFF
        for ((key, base) in letterKeys) {
            key.text = displayFor(base)
        }
        for (key in shiftKeyViews) {
            // Caps lock comparte fondo accent pero se distingue por el glifo ⇪.
            key.text = if (shiftState == ShiftState.CAPS_LOCK) "⇪" else "⇧"
            key.contentDescription =
                if (shiftState == ShiftState.CAPS_LOCK) {
                    if (spanishMode) "bloqueo mayúsculas" else "caps lock"
                } else {
                    if (spanishMode) "mayúsculas" else "shift"
                }
            if (upper) {
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
            releaseMomentaryShift()
            return
        }
        if (ctrlActive || altActive) {
            sendModifiedChar(base.lowercaseChar())
            return
        }
        currentInputConnection?.commitText(displayFor(base), 1)
        releaseMomentaryShift()
    }

    /** El shift momentaneo muere tras cada commit; caps lock persiste. */
    private fun releaseMomentaryShift() {
        if (shiftState == ShiftState.MOMENTARY) {
            deactivateShift()
            applyCase()
        }
    }

    /** Apagado por via no-tactil: invalida tambien el par del doble pulso. */
    private fun deactivateShift() {
        shiftState = ShiftState.OFF
        lastShiftTapUptime = 0L
    }

    private fun commitSymbolText(text: String) {
        haptic(root)
        // Simbolos de la barra inferior (, .) en snippets: al query siempre.
        if (layer == Layer.SNIPPETS) ensureSnippetSearchMode()
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

    /**
     * Borrado por palabra para el gesto deslizante de ⌫ (P6). En la capa
     * snippets opera SIEMPRE sobre el query (nunca toca el documento); en el
     * resto usa deleteSurroundingText con el limite de palabra calculado
     * sobre una ventana previa. Si el cursor esta pegado a separadores,
     * consume primero ese tramo; palabras mas largas que la ventana se
     * recortan parciales (limite v1.1: no borra frases completas de golpe).
     */
    private fun deleteWordBeforeCursor() {
        fun wordStart(text: CharSequence, from: Int): Int {
            var start = from
            if (start == 0) return start
            val eatingWord = text[start - 1].isLetterOrDigit()
            while (start > 0 && text[start - 1].isLetterOrDigit() == eatingWord) start--
            return start
        }
        if (layer == Layer.SNIPPETS) {
            ensureSnippetSearchMode()
            val et = snippetSearchField ?: return
            val text = et.text ?: return
            val start = wordStart(text, text.length)
            if (start < text.length) {
                text.delete(start, text.length)
                et.setSelection(start)
                refreshSnippetGrid()
            }
            return
        }
        val ic = currentInputConnection ?: return
        val before = try {
            ic.getTextBeforeCursor(SWIPE_WORD_LOOKBACK_CHARS, 0)
        } catch (_: Exception) {
            null
        }
        if (before.isNullOrEmpty()) return
        val start = wordStart(before, before.length)
        val count = before.length - start
        if (count > 0) {
            ic.deleteSurroundingText(count, 0)
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

    /** Enciende el modo busqueda bajo demanda (teclado de la propia capa). */
    private fun ensureSnippetSearchMode() {
        if (!snippetSearchActive) {
            snippetSearchActive = true
            applySnippetSearchVisual()
        }
    }

    /**
     * Gate central de vibracion (K5-T3): un unico punto por donde pasa
     * todo el feedback hapico del teclado. Si el usuario lo apago en Ajustes,
     * retorna sin vibrar. Default ON cuando la clave no existe.
     */
    private fun haptic(view: View) {
        if (!hapticsEnabled) return
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
        key.contentDescription = if (spanishMode) "dictar" else "dictate"
        attachLongPress(
            key,
            onLongPress = {
                haptic(key)
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
            showStatus(if (spanishMode) "Ocupado: la burbuja está grabando." else "Busy: the bubble is recording.")
            return
        }
        val config = sttClient.loadConfig()
        if (config.apiKey.isBlank()) {
            micState = MicState.IDLE
            refreshMicVisual()
            showStatus(
                if (spanishMode) "Falta la API key. Toca este aviso para abrir Ajustes."
                else "Missing API key. Tap this notice to open Settings.",
                openSettingsOnClick = true,
            )
            return
        }
        if (!sttClient.hasMicPermission()) {
            showStatus(
                if (spanishMode) "Permiso de micrófono denegado. Concedelo desde Ajustes."
                else "Microphone permission denied. Allow it from Settings.",
                openSettingsOnClick = true,
            )
            return
        }
        keyboardRecordingActive = true
        gainAudioFocus()
        val started = sttClient.startRecording()
        if (!started) {
            abandonAudioFocus()
            keyboardRecordingActive = false
            showStatus(if (spanishMode) "No se pudo iniciar la grabación." else "Could not start recording.")
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
                    showStatus(if (spanishMode) "No se detectó voz." else "No voice detected.")
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
                            showStatus(if (spanishMode) "No se detectó voz." else "No voice detected.")
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

    /**
     * K5-T5: apagado defensivo del dictado para los escenarios hostiles
     * (recreacion de vista, cambio de campo/app, destruccion). Idempotente:
     * sin dictado activo no hace nada. La parte que puede bloquear (corte de
     * captura y audio focus) corre en hilo de fondo con la referencia local
     * del cliente, igual que cancelDictation.
     */
    private fun cancelDictationIfActive() {
        if (micState == MicState.IDLE && !keyboardRecordingActive) return
        val client = if (::sttClient.isInitialized) sttClient else null
        keyboardRecordingActive = false
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micIdle()
        if (client != null) {
            Thread {
                try {
                    client.cancelRecording()
                } catch (_: Exception) {}
                abandonAudioFocus()
            }.start()
        }
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
            ).setOnAudioFocusChangeListener { change ->
                // K5-T5: llamada entrante u otro foco de audio. Perder el
                // foco cancela el dictado y devuelve el microfono a IDLE
                // (el listener llega en el looper del hilo que registro).
                if (change == AudioManager.AUDIOFOCUS_LOSS ||
                    change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                ) {
                    if (micState == MicState.RECORDING) {
                        cancelDictation()
                    }
                }
            }.build()
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
     * Descartes de la ultima operacion sobre el historial (candidatos crudos
     * que no produjeron un objeto JSON valido). Diagnostico EXCLUSIVAMENTE
     * numerico: jamas contiene ni expone contenido ni claves (regla
     * transversal 4).
     */
    @Volatile
    private var lastHistoryDiscarded = 0

    /**
     * Alta en el historial FIFO-20 compartido con la app. La base de
     * escritura es writableHistoryBase(): lectura fresca de disco mas las
     * entradas de la cache cuyo timestamp no exista ya en disco (merge por
     * timestamp parseado), asi el dictado recien aplicado (apply aun no
     * volcado) nunca se pierde y las entradas borradas desde la app NO
     * resucitan al proximo dictado. El plugin shared_preferences guarda la
     * lista como Set nativo sin orden garantizado: se reordena por timestamp
     * descendente (mismo criterio semantico de la app: mas nuevo primero).
     */
    private fun addToSharedHistory(text: String) {
        try {
            val entries = writableHistoryBase()
            val newEntry = JSONObject()
                .put("text", text)
                .put("timestamp", java.time.Instant.now().toString())
                .put("isLocal", false)
            entries.add(newEntry)
            val sorted = entries.sortedByDescending { historyEntryInstant(it) }
            val out = LinkedHashSet<String>()
            for (obj in sorted.take(20)) {
                out.add(obj.toString())
            }
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putStringSet(SHARED_HISTORY_KEY, out)
                .apply()
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
            tv.setBackgroundResource(R.drawable.kb_menu_item)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            tv.setOnClickListener {
                haptic(tv)
                commit(text)
                dismissPopup()
            }
            content.addView(tv)
        }
        if (first) {
            val empty = TextView(this)
            empty.text = if (spanishMode) "Sin transcripciones todavía." else "No transcriptions yet."
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
     * Historial compartido parseado para la ventana: tolerante (los candidatos
     * que no son objetos JSON validos se descartan y quedan contados en
     * [lastHistoryDiscarded], diagnostico solo numerico, jamas contenido),
     * ordenado por timestamp descendente y con dedup por timestamp parseado
     * (una misma entrada presente en dos serializaciones ocupa una sola fila;
     * entradas con timestamp imposible no participan del dedup y nunca se
     * pierden). Mismo criterio de lectura que addToSharedHistory y la app.
     */
    private fun sharedHistoryEntries(): List<JSONObject> {
        var discarded = 0
        val parsed = ArrayList<JSONObject>()
        for (raw in sharedHistoryRaw()) {
            try {
                parsed.add(JSONObject(raw))
            } catch (_: Exception) {
                discarded++
            }
        }
        lastHistoryDiscarded = discarded
        val seen = HashSet<java.time.Instant>()
        val out = ArrayList<JSONObject>(20)
        for (obj in parsed.sortedByDescending { historyEntryInstant(it) }) {
            val ts = historyEntryInstantOrNull(obj)
            if (ts != null && !seen.add(ts)) continue
            out.add(obj)
            if (out.size >= 20) break
        }
        return out
    }

    /**
     * Candidatos crudos del historial con lectura fresca garantizada. El
     * framework Android cachea el archivo por proceso y SharedPreferences no
     * expone reload() publico, asi que se relee el XML directamente desde
     * disco y se une a la vista cacheada del framework (la cache cubre
     * escrituras apply() aun no volcadas; el disco, cambios externos). Ambas
     * fuentes son copiadas a estructuras propias: el Set devuelto por
     * getStringSet es la referencia interna viva y mutarlo corrompe la cache.
     */
    private fun sharedHistoryRaw(): Set<String> {
        val merged = LinkedHashSet<String>()
        try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getStringSet(SHARED_HISTORY_KEY, emptySet())
                ?.let { cached -> merged.addAll(cached) }
        } catch (_: Exception) {
            // Tipo almacenado inesperado: la lectura fresca de disco puede
            // rescatar igualmente las entradas.
        }
        try {
            readFreshHistoryFromDisk()?.let { fresh -> merged.addAll(fresh) }
        } catch (_: Exception) {}
        return expandHistoryCandidates(merged)
    }

    /**
     * Base de ESCRITURA del historial (P5-F2): SOLO la lectura fresca de
     * disco, mas de la cache del proceso las entradas cuyo timestamp parseado
     * no exista ya en disco (las de timestamp imposible cuentan como "solo
     * cache" unicamente si su texto crudo no esta en disco, para no duplicar
     * el espejo cache-disco). Asi sobreviven las escrituras apply() aun no
     * volcadas sin resucitar entradas borradas desde la app. Los descartes de
     * ambas fuentes quedan contados en [lastHistoryDiscarded] (solo numeros).
     */
    private fun writableHistoryBase(): ArrayList<JSONObject> {
        var discarded = 0
        val diskRaw = try {
            readFreshHistoryFromDisk()
        } catch (_: Exception) {
            null
        } ?: emptySet()
        val base = ArrayList<JSONObject>(diskRaw.size)
        val diskTimes = HashSet<java.time.Instant>()
        for (raw in diskRaw) {
            try {
                val obj = JSONObject(raw)
                historyEntryInstantOrNull(obj)?.let { diskTimes.add(it) }
                base.add(obj)
            } catch (_: Exception) {
                discarded++
            }
        }
        try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getStringSet(SHARED_HISTORY_KEY, emptySet())
                ?.let { cached ->
                    // Copia defensiva antes de usar: el set interno vivo del
                    // framework jamas se muta ni se retiene.
                    for (raw in expandHistoryCandidates(cached.toList())) {
                        val obj = try {
                            JSONObject(raw)
                        } catch (_: Exception) {
                            discarded++
                            continue
                        }
                        val ts = historyEntryInstantOrNull(obj)
                        val alreadyOnDisk =
                            (ts != null && diskTimes.contains(ts)) || diskRaw.contains(raw)
                        if (!alreadyOnDisk) base.add(obj)
                    }
                }
        } catch (_: Exception) {}
        lastHistoryDiscarded = discarded
        return base
    }

    /**
     * Lectura directa del XML de preferencias compartidas, sin pasar por la
     * cache del proceso. Tolerante al formato real almacenado por el plugin:
     * <set> con hijos <string> (caso setStringList), <string> escalar bajo la
     * clave, y ausencia total del archivo (devuelve null). Cualquier error de
     * lectura se propaga al llamador, que captura todo.
     */
    private fun readFreshHistoryFromDisk(): Set<String>? {
        val file = File(applicationInfo.dataDir, "shared_prefs/FlutterSharedPreferences.xml")
        if (!file.exists()) return null
        val parser = Xml.newPullParser()
        InputStreamReader(FileInputStream(file), Charsets.UTF_8).use { reader ->
            parser.setInput(reader)
            val out = LinkedHashSet<String>()
            val chunk = StringBuilder()
            var inSet = false
            var captureScalar = false
            fun flushChunk() {
                if (chunk.isNotEmpty()) {
                    val value = chunk.toString()
                    if (value.isNotBlank()) out.add(value)
                    chunk.setLength(0)
                }
            }
            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                when (event) {
                    // Todo START_TAG cierra el texto previo (asi la sangria
                    // entre elementos hijos nunca contamina una entrada).
                    XmlPullParser.START_TAG -> {
                        flushChunk()
                        when {
                            parser.name == "set" &&
                                parser.getAttributeValue(null, "name") == SHARED_HISTORY_KEY -> {
                                inSet = true
                            }
                            parser.name == "string" && !inSet && !captureScalar &&
                                parser.getAttributeValue(null, "name") == SHARED_HISTORY_KEY -> {
                                captureScalar = true
                            }
                        }
                    }
                    XmlPullParser.TEXT -> if (inSet || captureScalar) {
                        chunk.append(parser.text)
                    }
                    XmlPullParser.END_TAG -> when (parser.name) {
                        "set" -> if (inSet) {
                            flushChunk()
                            inSet = false
                        }
                        "string" -> if (captureScalar) {
                            flushChunk()
                            captureScalar = false
                        }
                    }
                }
                event = parser.next()
            }
            flushChunk()
            return out
        }
    }

    /**
     * Tolerancia de formato: si algun candidato es un JSON array de strings,
     * se expande a entradas individuales; cualquier otro valor se conserva
     * tal cual para que el parseo posterior decida.
     */
    private fun expandHistoryCandidates(candidates: Collection<String>): LinkedHashSet<String> {
        val out = LinkedHashSet<String>()
        for (raw in candidates) {
            val trimmed = raw.trim()
            var expanded = false
            if (trimmed.startsWith("[")) {
                try {
                    val arr = JSONArray(trimmed)
                    for (i in 0 until arr.length()) {
                        val item = arr.optString(i)
                        if (!item.isNullOrBlank()) out.add(item)
                    }
                    expanded = true
                } catch (_: Exception) {}
            }
            if (!expanded) out.add(raw)
        }
        return out
    }

    /**
     * Timestamp normalizado para ordenar. La app guarda DateTime.now() en ISO
     * local SIN zona ("2026-08-23T10:00:00.000"), que Instant.parse rechaza;
     * se interpreta entonces como hora local. Si nada parsea cae a EPOCH.
     */
    private fun historyEntryInstant(obj: JSONObject): java.time.Instant =
        historyEntryInstantOrNull(obj) ?: java.time.Instant.EPOCH

    /**
     * Timestamp normalizado o null si no es interpretable (ni UTC ni local).
     * Esas entradas se tratan como "solo cache" en el merge de escritura y no
     * participan del dedup por timestamp en la ventana.
     */
    private fun historyEntryInstantOrNull(obj: JSONObject): java.time.Instant? = try {
        java.time.Instant.parse(obj.optString("timestamp"))
    } catch (_: Exception) {
        try {
            java.time.LocalDateTime.parse(obj.optString("timestamp"))
                .atZone(java.time.ZoneId.systemDefault())
                .toInstant()
        } catch (_: Exception) {
            null
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

    /** Fila de busqueda + grid scrolleable de chips (3 por fila). */
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
            scaleV(dimen(R.dimen.kb_snippets_grid_height)),
        )
        lp.topMargin = rowGapPx()
        root.addView(scroll, lp)
        addSnippetLetterRows()
    }

    /**
     * Filas QWERTY compactas dentro de la capa snippets (K5-T1): letras,
     * espacio y backspace operan SIEMPRE sobre el query de busqueda
     * (activan el modo si esta apagado) y jamas escriben en el documento.
     */
    private fun addSnippetLetterRows() {
        addRow(snippetLetterRow("qwertyuiop"))
        addRow(snippetLetterRow(if (spanishMode) "asdfghjklñ" else "asdfghjkl;"))
        val row3 = horizontalRow()
        for (c in "zxcvbnm") {
            row3.addView(makeSnippetLetterKey(c))
        }
        row3.addView(makeSnippetBackspaceKey())
        addRow(row3)
    }

    private fun snippetLetterRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeSnippetLetterKey(c))
        }
        return row
    }

    /** Tecla alfabetica compacta; mismo estilo que la capa letras. */
    private fun makeSnippetLetterKey(base: Char): TextView {
        val key = makeKey(
            displayFor(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size),
        )
        val lp = key.layoutParams as LinearLayout.LayoutParams
        lp.height = snippetKeyHeightPx()
        key.layoutParams = lp
        if (accentsFor(base).isEmpty()) {
            key.setOnClickListener { commitSnippetLetter(base) }
        } else {
            attachLongPress(
                key,
                onLongPress = {
                    haptic(key)
                    ensureSnippetSearchMode()
                    showAccentPopup(key, base)
                },
                onTapUp = { commitSnippetLetter(base) },
            )
        }
        // Registro para que applyCase refleje el shift tambien en esta capa.
        letterKeys.add(Pair(key, base))
        return key
    }

    /** Backspace compacto: borra del query, nunca del documento destino. */
    private fun makeSnippetBackspaceKey(): TextView {
        val key = makeSpecialKey("⌫", R.drawable.kb_key_alt, 1.3f, if (spanishMode) "borrar" else "delete") {
            ensureSnippetSearchMode()
            handleBackspace()
        }
        attachBackspaceGestures(key) {
            ensureSnippetSearchMode()
            handleBackspace()
        }
        val lp = key.layoutParams as LinearLayout.LayoutParams
        lp.height = snippetKeyHeightPx()
        key.layoutParams = lp
        return key
    }

    /** Commit alfabetico con activacion garantizada del modo busqueda. */
    private fun commitSnippetLetter(base: Char) {
        ensureSnippetSearchMode()
        commitLetter(base)
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
        et.setPadding(pad, pad, pad, pad)
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
        val lp = LinearLayout.LayoutParams(0, scaleV(dimen(R.dimen.kb_snippet_search_height)), 1f)
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
            val inRow = minOf(SNIPPET_GRID_COLUMNS, filtered.size - i)
            val row = horizontalRow()
            for (j in 0 until inRow) {
                val chip = makeSnippetChip(filtered[i + j])
                val lp = chip.layoutParams as LinearLayout.LayoutParams
                lp.weight = SNIPPET_GRID_COLUMNS.toFloat() / inRow
                row.addView(chip)
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                scaleV(dimen(R.dimen.kb_snippet_chip_height)),
            )
            if (container.childCount > 0) {
                lp.topMargin = rowGapPx()
            }
            container.addView(row, lp)
            i += inRow
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
            onLongPress = {
                haptic(chip)
                showSnippetMenu(chip, snippet)
            },
            onTapUp = { insertSnippet(snippet) },
        )
        val lp = LinearLayout.LayoutParams(0, scaleV(dimen(R.dimen.kb_snippet_chip_height)), 1f)
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
            tv.setBackgroundResource(R.drawable.kb_menu_item)
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

    /**
     * Logica comun de toque largo: programa accion diferida y decide en UP.
     * Modo autorrepeticion (onRepeat != null, usado por ⌫ / P6): al disparar
     * el long press se ejecuta onLongPress UNA vez y arrancan repeticiones
     * de onRepeat; la primera a REPEAT_INITIAL_DELAY_MS y en cada ciclo el
     * intervalo se multiplica por REPEAT_ACCEL hasta el piso
     * REPEAT_MIN_INTERVAL_MS. El haptic pertenece SOLO al long press
     * inicial (lo pone el llamador); repeticiones y gesto son silenciosos.
     * Politica de gesto deslizante (onSwipeStep != null, ⌫): si el dedo se
     * mueve mas que touchSlop, la pulsacion pasa a modo gesto — cancela el
     * long press pendiente y TODA repeticion para esa pulsacion, y cada
     * SWIPE_DELETE_STEP_DP recorridos hacia la IZQUIERDA desde el ultimo
     * umbral borra una palabra (arrastres largos = varias palabras). Un
     * recorrido derecho/arriba solo anula tap y long press. En UP nunca hay
     * onTapUp si hubo long press o gesto; un toque corto sin movimiento
     * sigue siendo tap normal.
     */
    private fun attachLongPress(
        key: TextView,
        onLongPress: () -> Unit,
        onTapUp: () -> Unit,
        onRepeat: (() -> Unit)? = null,
        onSwipeStep: (() -> Unit)? = null,
    ) {
        var pending: Runnable? = null
        var repeating: Runnable? = null
        var repeatIntervalMs = 0L
        var longPressFired = false
        var swipeMode = false
        var swipeAnchorX = 0f
        val touchSlopPx = ViewConfiguration.get(key.context).scaledTouchSlop
        val swipeStepPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, SWIPE_DELETE_STEP_DP, resources.displayMetrics,
        )

        fun cancelPending() {
            pending?.let { handler.removeCallbacks(it) }
            pending = null
        }

        fun cancelRepeating() {
            repeating?.let { handler.removeCallbacks(it) }
            repeating = null
        }

        key.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    longPressFired = false
                    swipeMode = false
                    swipeAnchorX = ev.rawX
                    val r = Runnable {
                        longPressFired = true
                        onLongPress()
                        if (onRepeat != null && !swipeMode) {
                            repeatIntervalMs = REPEAT_INITIAL_DELAY_MS
                            val rr = object : Runnable {
                                override fun run() {
                                    // Doble guarda: el gesto puede entrar entre ciclos.
                                    if (!longPressFired || swipeMode || repeating !== this) return
                                    onRepeat?.invoke()
                                    repeatIntervalMs = maxOf(
                                        REPEAT_MIN_INTERVAL_MS,
                                        (repeatIntervalMs * REPEAT_ACCEL).toLong(),
                                    )
                                    handler.postDelayed(this, repeatIntervalMs)
                                }
                            }
                            repeating = rr
                            handler.postDelayed(rr, repeatIntervalMs)
                        }
                    }
                    pending = r
                    handler.postDelayed(r, LONG_PRESS_MILLIS)
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    if (onSwipeStep != null) {
                        if (!swipeMode && abs(ev.rawX - swipeAnchorX) > touchSlopPx) {
                            // Deslizamiento confirmado: ya no es ni tap ni
                            // repeticion; queda solo el borrado por umbral.
                            cancelPending()
                            cancelRepeating()
                            swipeMode = true
                        }
                        if (swipeMode) {
                            while (ev.rawX <= swipeAnchorX - swipeStepPx) {
                                swipeAnchorX -= swipeStepPx
                                onSwipeStep?.invoke()
                            }
                        }
                    }
                    false
                }
                MotionEvent.ACTION_UP -> {
                    cancelPending()
                    cancelRepeating()
                    if (!longPressFired && !swipeMode) {
                        onTapUp()
                    }
                    v.isPressed = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    cancelPending()
                    cancelRepeating()
                    v.isPressed = false
                    true
                }
                else -> false
            }
        }
    }

    /** Cablea una tecla ⌫ (P6): tap = 1 caracter, mantener = borrado
     *  continuo acelerado con haptic unico, deslizar a la izquierda =
     *  borrar palabra por umbral de distancia. */
    private fun attachBackspaceGestures(key: TextView, action: () -> Unit) {
        attachLongPress(
            key,
            onLongPress = {
                haptic(key)
                action()
            },
            onTapUp = action,
            onRepeat = action,
            onSwipeStep = { deleteWordBeforeCursor() },
        )
    }

    private fun attachAccentLongPress(key: TextView, base: Char) {
        attachLongPress(
            key,
            onLongPress = {
                haptic(key)
                showAccentPopup(key, base)
            },
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
            tv.setBackgroundResource(R.drawable.kb_menu_item)
            tv.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size).toFloat())
            tv.setOnClickListener {
                haptic(it)
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

    /**
     * K5-T2/T3: lectura unica por apertura de las preferencias de aspecto
     * escritas por Ajustes (archivo FlutterSharedPreferences, claves con
     * prefijo "flutter."). Parseo tolerante: valor desconocido o error
     * cae al default (media / hapticos ON). El resultado queda cacheado
     * en campos y no se re-lee hasta la proxima apertura.
     */
    private fun loadKeyboardPrefs() {
        heightFactor = try {
            when (
                getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString("flutter.kb_height_profile", HEIGHT_PROFILE_MEDIA)
            ) {
                HEIGHT_PROFILE_BAJA -> HEIGHT_FACTOR_BAJA
                HEIGHT_PROFILE_ALTA -> HEIGHT_FACTOR_ALTA
                else -> HEIGHT_FACTOR_MEDIA
            }
        } catch (_: Exception) {
            HEIGHT_FACTOR_MEDIA
        }
        hapticsEnabled = try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_haptics_enabled", true)
        } catch (_: Exception) {
            true
        }
    }

    /** Altura de tecla estandar escalada por el perfil activo. */
    private fun keyHeightPx(): Int = scaleV(dimen(R.dimen.kb_key_height))

    /** Altura compacta de las teclas QWERTY de la capa snippets. */
    private fun snippetKeyHeightPx(): Int = scaleV(dimen(R.dimen.kb_snippet_key_height))

    /** Margen vertical entre filas, escalado igual que las teclas. */
    private fun rowGapPx(): Int = scaleV(dimen(R.dimen.kb_key_gap))

    /**
     * Escala una dimension vertical propia del contenido del teclado con el
     * factor del perfil. NUNCA aplicar sobre insets ni paddings derivados de
     * WindowInsets (leccion 9.1-20).
     */
    private fun scaleV(px: Int): Int = (px * heightFactor).toInt()

    companion object {
        private const val LONG_PRESS_MILLIS = 350L

        /** Autorrepeticion de ⌫ (P6): primer ciclo y aceleracion geometrica
         *  hasta el piso (250 -> 212 -> 180 ... -> 50 ms). */
        private const val REPEAT_INITIAL_DELAY_MS = 250L
        private const val REPEAT_MIN_INTERVAL_MS = 50L
        private const val REPEAT_ACCEL = 0.85f

        /** Gesto ⌫ (P6): recorrido izquierdo que borra una palabra completa. */
        private const val SWIPE_DELETE_STEP_DP = 48f

        /** Ventana previa examinada para hallar el limite de palabra. */
        private const val SWIPE_WORD_LOOKBACK_CHARS = 64

        /** Umbral de doble pulso sobre shift para activar caps lock (P3). */
        private const val SHIFT_DOUBLE_TAP_MILLIS = 300L

        /** Tope del query de busqueda de snippets. */
        private const val SNIPPET_QUERY_MAX_CHARS = 50

        /** Columnas del grid de chips de snippets. */
        private const val SNIPPET_GRID_COLUMNS = 3

        /** Valores del perfil de altura escritos por Ajustes (K5-T2). */
        private const val HEIGHT_PROFILE_BAJA = "baja"
        private const val HEIGHT_PROFILE_MEDIA = "media"
        private const val HEIGHT_PROFILE_ALTA = "alta"

        /** Factores aplicados a alturas verticales propias del teclado. */
        private const val HEIGHT_FACTOR_BAJA = 0.85f
        private const val HEIGHT_FACTOR_MEDIA = 1f
        private const val HEIGHT_FACTOR_ALTA = 1.15f

        /** Exclusion mutua de microfono: visible para MainActivity/burbuja. */
        @Volatile
        var keyboardRecordingActive: Boolean = false

        /** Clave del historial compartido con la app (prefijo flutter.). */
        private const val SHARED_HISTORY_KEY = "flutter.transcriptions"
    }
}
