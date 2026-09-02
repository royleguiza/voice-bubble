package com.royleguiza.voicebubblestt

import android.animation.ObjectAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
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
import android.transition.ChangeBounds
import android.transition.Fade
import android.transition.TransitionManager
import android.transition.TransitionSet
import android.view.animation.DecelerateInterpolator
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
import android.widget.FrameLayout
import android.widget.ImageView
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

    // --- Dictado (K3 + M4 Morph-to-Pill) ---
    private lateinit var sttClient: SpeechToTextClient
    private var micState = MicState.IDLE
    private var currentIsPasswordField = false
    private var micKeyView: View? = null
    private var micNormalView: ImageView? = null
    private var micProcView: View? = null
    private var micProcDots: List<View> = emptyList()
    private var micPillView: View? = null
    private var micPillDot: TextView? = null
    private var micPillTimer: TextView? = null
    private var micPillCancel: TextView? = null
    private var spaceKeyView: View? = null
    private var commaKeyView: View? = null
    private var dotKeyView: View? = null
    private var statusRowView: TextView? = null
    private var statusMessage: String? = null
    private var timeoutRunnable: Runnable? = null
    private var recordingTimerRunnable: Runnable? = null
    private var dismissStatusRunnable: Runnable? = null
    private var recordingStartMs: Long = 0L

    // AT-A1: token de generacion del dictado. Cada cancelacion lo avanza;
    // los callbacks onDone/onError capturan su valor y se abortan si difiere,
    // asi un cambio de campo/app durante PROCESSING nunca comete texto en
    // el campo equivocado.
    private var transcriptionGeneration = 0
    private var focusRequest: AudioFocusRequest? = null
    private var pulseAnimators: List<ObjectAnimator> = emptyList()

    // --- Snippets (K4) ---
    private enum class SnippetMode { NORMAL, EDIT, DELETE }
    private var snippetMode = SnippetMode.NORMAL
    private var btnSnippetEditView: View? = null
    private var btnSnippetDeleteView: View? = null
    private var isSnippetEditorOpen: Boolean = false
    private var editingSnippet: VbSnippet? = null
    private var activeSnippetEditorField: EditText? = null
    private var etSnippetNameField: EditText? = null
    private var etSnippetContentField: EditText? = null
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
    // AT-A13: se leen UNA VEZ por ciclo del campo (loadKeyboardPrefs en
    // onStartInputView, que siempre corre tras onCreateInputView) y quedan
    // cacheadas aca para no golpear SharedPreferences en cada tecla.
    // Caducidad honesta: un cambio hecho en Ajustes se aplica al abrirse el
    // proximo campo, no en vivo. heightFactor escala solo alturas propias
    // del teclado, jamas el padding inferior por insets.
    private var heightFactor = HEIGHT_FACTOR_MEDIA
    private var hapticsEnabled = true
    private var bottomElevationDp = 24
    private var invertToolbar = false
    private var spacebarAlignment = "center"

    // AT-A8: cache de visibilidad leida junto a lo anterior; rebuild jamas
    // consulta SharedPreferences.
    private var terminalRowVisiblePref = true
    private var codeKeyVisiblePref = true
    private var languageKeyVisiblePref = true

    private lateinit var root: LinearLayout

    // AT-A9: vista vigente devuelta al sistema por onCreateInputView. Los
    // avisos la comparan por identidad antes de tocar root, porque
    // ::root.isInitialized no detecta que root ya fue reemplazado.
    private var inputView: View? = null
    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private val shiftKeyViews = mutableListOf<ImageView>()
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
        root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setBackgroundResource(R.drawable.kb_surface_bg)
        applyBottomInsets()
        rebuild()
        inputView = root
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
            val elevationPx = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                bottomElevationDp.toFloat(),
                resources.displayMetrics
            ).toInt()
            view.setPadding(padH, padV, padH, padV + bottom + elevationPx)
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
        // AT-A4: BUSY es espejo del estado de la burbuja; si ella ya solto
        // el microfono, el teclado arranca este campo en IDLE.
        if (micState == MicState.BUSY && !bubbleBusy()) micIdle()
        layer = Layer.LETTERS
        lastLettersLayer = Layer.LETTERS
        deactivateShift()
        ctrlActive = false
        altActive = false
        rebuild()
        root.requestApplyInsets()
    }

    /** Campos de contraseña: sin micrófono, snippets ni sugerencias (K3). */
    private fun isPasswordInput(info: EditorInfo?): Boolean {
        if (info == null) return false
        val variation = info.inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
            variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
    }

    /** K5-T5: al cerrarse el campo actual, corta dictado y popups vivos. */
    override fun onFinishInputView(finishingInput: Boolean) {
        stopRecordingTimer()
        cancelDictationIfActive()
        dismissPopup()
        super.onFinishInputView(finishingInput)
    }

    override fun onWindowHidden() {
        super.onWindowHidden()
        dismissPopup()
    }

    override fun onDestroy() {
        stopRecordingTimer()
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()
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
        stopRecordingTimer()
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()
        letterKeys.clear()
        shiftKeyViews.clear()
        modifierKeyViews.clear()
        micKeyView = null
        micNormalView = null
        micProcView = null
        micProcDots = emptyList()
        micPillView = null
        micPillDot = null
        micPillTimer = null
        micPillCancel = null
        spaceKeyView = null
        commaKeyView = null
        dotKeyView = null
        if (layer != Layer.SNIPPETS) {
            snippetQuery = ""
            snippetGridContainer = null
            snippetSearchActive = false
            snippetSearchField = null
            snippetMode = SnippetMode.NORMAL
            btnSnippetEditView = null
            btnSnippetDeleteView = null
            isSnippetEditorOpen = false
            editingSnippet = null
            activeSnippetEditorField = null
            etSnippetNameField = null
            etSnippetContentField = null
        }
        root.removeAllViews()

        // K2.1: fila terminal ocultable desde Ajustes de la app (default visible).
        // Y ahora Toolbar Interactiva Superior con Mic, Portapapeles, etc.
        val toolbar = buildInteractiveToolbar()
        if (toolbar != null) {
            addRow(toolbar)
        }
        if (terminalRowVisiblePref) {
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
        applyMicVisual()
    }
    private fun buildInteractiveToolbar(): LinearLayout? {
        val row = LinearLayout(this)
        row.orientation = LinearLayout.HORIZONTAL
        
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        val m = dimen(R.dimen.kb_key_gap)
        lp.setMargins(m, m, m, m)
        row.layoutParams = lp
        row.setPadding(0, 0, 0, 0)
        
        val items = mutableListOf<View>()
        
        // Elementos borde (Snippets):
        if (!currentIsPasswordField) {
            val btnSnippets = makeIconKey(
                R.drawable.ic_snippets,
                R.drawable.kb_key_alt,
                1.0f,
                if (spanishMode) "fragmentos" else "snippets",
            ) {
                toggleSnippetsLayer()
            }
            items.add(btnSnippets)
        }

        // Elementos centrales:
        val btnSettings = makeIconKey(R.drawable.ic_settings, R.drawable.kb_key_alt, 1.0f, "ajustes") {
            openAppUi()
        }
        items.add(btnSettings)

        if (terminalRowVisiblePref) {
            val btnTerminal = makeIconKey(
                R.drawable.ic_terminal,
                R.drawable.kb_key_alt,
                1.0f,
                if (spanishMode) "fila terminal" else "terminal row",
            ) {
                terminalRowVisiblePref = !terminalRowVisiblePref
                rebuild()
            }
            items.add(btnTerminal)
        }

        val btnPaste = makeIconKey(R.drawable.ic_paste, R.drawable.kb_key_alt, 1.0f, if (spanishMode) "pegar" else "paste") {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            if (clipboard.hasPrimaryClip()) {
                val item = clipboard.primaryClip?.getItemAt(0)
                item?.text?.let { commit(it.toString()) }
            }
        }
        items.add(btnPaste)

        if (codeKeyVisiblePref) {
            val btnCode = makeIconKey(
                R.drawable.ic_code,
                R.drawable.kb_key_alt,
                1.0f,
                if (spanishMode) "capa código" else "code layer",
            ) {
                toggleCodeLayer()
            }
            items.add(btnCode)
        }

        // Elementos borde (Micrófono):
        if (!currentIsPasswordField) {
            val mic = makeMicKey()
            micKeyView = mic
            
            // Adjust mic layout params to use weight 1.0f
            val hPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, resources.displayMetrics).toInt()
            val micLp = LinearLayout.LayoutParams(0, hPx, 1.0f)
            val micM = dimen(R.dimen.kb_key_gap) / 2
            micLp.setMargins(micM, micM, micM, micM)
            mic.layoutParams = micLp
            
            items.add(mic)
        } else {
            micKeyView = null
            micNormalView = null
            micProcView = null
            micProcDots = emptyList()
            micPillView = null
            micPillDot = null
            micPillTimer = null
            micPillCancel = null
        }

        if (invertToolbar) {
            items.reverse()
        }
        
        items.forEach { row.addView(it) }

        return row
    }

    /** Fila terminal permanente en todas las capas (K2). */
    private fun buildTerminalRow(): LinearLayout {
        val row = horizontalRow()
        row.addView(makeSpecialKey("TAB", R.drawable.kb_key_alt, 1.5f, "tab", isBold = true) {
            sendKeyCode(KeyEvent.KEYCODE_TAB)
        })
        row.addView(makeSpecialKey("ESC", R.drawable.kb_key_alt, 1f, "escape", isBold = true) {
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
        makeSpecialKey(glyph, R.drawable.kb_key_bg, 1f, description, isBold = true) {
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
            isBold = true,
        ) {
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
        val shiftKey = makeActionIconKey(
            R.drawable.ic_shift_off,
            R.drawable.kb_key_alt,
            1.3f,
            if (spanishMode) "mayúsculas" else "shift",
            tintColorRes = R.color.kb_label,
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
        addRow(symbolRow("@#$%&-+()/"))

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
        for (c in "*&%$#@^~_") {
            row3.addView(makeCodeKey(c))
        }
        row3.addView(makeBackspaceKey())
        addRow(row3)
    }

    private fun buildBottomBar(): LinearLayout {
        val row = horizontalRow()

        val btnSym = makeSpecialKey(symbolsToggleLabel(), R.drawable.kb_key_alt, 1.5f, if (spanishMode) "símbolos" else "symbols", isBold = true) {
            layer = if (layer == Layer.SYMBOLS) Layer.LETTERS else Layer.SYMBOLS
            rebuild()
        }

        val btnLang = if (languageKeyVisiblePref) {
            makeSpecialKey(if (spanishMode) "ES" else "EN", R.drawable.kb_key_alt, 1f, if (spanishMode) "cambiar idioma" else "switch language", isBold = true) {
                spanishMode = !spanishMode
                rebuild()
            }
        } else null

        val comma = makeSymbolKey(",", dimen(R.dimen.kb_key_glyph_punct), isBold = true)
        commaKeyView = comma

        val space = makeSpecialKey("", R.drawable.kb_key_bg, 5.0f, if (spanishMode) "espacio" else "space") {
            // En snippets el espacio alimenta el query, nunca el documento.
            if (layer == Layer.SNIPPETS) ensureSnippetSearchMode()
            commit(" ")
        }
        spaceKeyView = space

        val dot = makeSymbolKey(".", dimen(R.dimen.kb_key_glyph_punct), isBold = true)
        dotKeyView = dot

        val enter = makeActionIconKey(
            R.drawable.ic_enter,
            R.drawable.kb_key_accent,
            1.8f,
            if (spanishMode) "intro" else "enter",
            tintColorRes = R.color.kb_label_on_accent,
        ) {
            handleEnter()
        }

        // Orden de la fila inferior segun la preferencia de alineacion.
        // Siempre arranca con Sym/Lang, luego el bloque configurable, y termina con Enter.
        row.addView(btnSym)
        if (btnLang != null) {
            row.addView(btnLang)
        }

        when (spacebarAlignment) {
            "left" -> {
                row.addView(space)
                row.addView(comma)
                row.addView(dot)
            }
            "right" -> {
                row.addView(comma)
                row.addView(dot)
                row.addView(space)
            }
            else -> { // "center" default
                row.addView(comma)
                row.addView(space)
                row.addView(dot)
            }
        }
        
        row.addView(enter)
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

    private fun attachFastKeyTouch(key: View, onClick: () -> Unit) {
        key.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    haptic(v)
                    v.isPressed = true
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (v.isPressed) {
                        onClick()
                    }
                    v.isPressed = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.isPressed = false
                    true
                }
                else -> false
            }
        }
    }

    private fun makeActionIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(this)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(this, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        val lp = LinearLayout.LayoutParams(0, keyHeightPx(), weight)
        val m = dimen(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        attachFastKeyTouch(key, onClick)
        return key
    }

    private fun makeBackspaceKey(): ImageView {
        val key = makeActionIconKey(
            R.drawable.ic_backspace,
            R.drawable.kb_key_alt,
            1.3f,
            if (spanishMode) "borrar" else "delete",
            tintColorRes = R.color.kb_label,
        ) {
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
            attachFastKeyTouch(key) { commitLetter(base) }
        } else {
            attachAccentLongPress(key, base)
        }
        letterKeys.add(Pair(key, base))
        return key
    }

    private fun makeSymbolKey(
        label: String,
        textSizePx: Int = dimen(R.dimen.kb_key_text_size_small),
        isBold: Boolean = false,
    ): TextView {
        val key = makeKey(
            label,
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            textSizePx,
            isBold = isBold,
        )
        key.contentDescription = label
        attachFastKeyTouch(key) { commitSymbolText(label) }
        return key
    }

    /** Tecla de capa codigo: toque corto el simbolo, toque largo el par cerrado
     *  (solo si existe pareja; si no, tap plano). */
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
        isBold: Boolean = true,
        onClick: () -> Unit,
    ): TextView {
        val key = makeKey(
            label,
            weight,
            bgRes,
            R.color.kb_label,
            textSizePx,
            isBold = isBold,
        )
        if (description != null) {
            key.contentDescription = description
        }
        attachFastKeyTouch(key, onClick)
        return key
    }

    private fun makeIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(this)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(this, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        key.setPadding(0, 0, 0, 0)
        
        val hPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, resources.displayMetrics).toInt()
        val lp = LinearLayout.LayoutParams(0, hPx, weight)
        val m = dimen(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, m, m, m)
        key.layoutParams = lp
        
        attachFastKeyTouch(key, onClick)
        return key
    }

    private fun makeFixedTextKey(
        label: String,
        bgRes: Int,
        weight: Float,
        description: String?,
        onClick: () -> Unit,
    ): TextView {
        val key = TextView(this)
        key.text = label
        key.gravity = Gravity.CENTER
        key.isClickable = true
        key.isFocusable = true
        key.includeFontPadding = false
        key.setBackgroundResource(bgRes)
        key.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
        key.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        key.setTypeface(null, Typeface.BOLD)
        if (description != null) {
            key.contentDescription = description
        }
        val hPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, resources.displayMetrics).toInt()
        val lp = LinearLayout.LayoutParams(0, hPx, weight)
        val m = dimen(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, m, m, m)
        key.layoutParams = lp
        
        attachFastKeyTouch(key, onClick)
        return key
    }

    private fun makeKey(
        label: String,
        weight: Float,
        bgRes: Int,
        colorRes: Int,
        textSizePx: Int,
        isBold: Boolean = false,
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
        if (isBold) {
            key.setTypeface(null, Typeface.BOLD)
        }
        val lp = LinearLayout.LayoutParams(0, keyHeightPx(), weight)
        val m = dimen(R.dimen.kb_key_gap_h) / 2
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
            when (shiftState) {
                ShiftState.CAPS_LOCK -> {
                    key.setImageResource(R.drawable.ic_shift_caps)
                    key.contentDescription = if (spanishMode) "bloqueo mayúsculas" else "caps lock"
                    key.setBackgroundResource(R.drawable.kb_key_accent)
                    key.setColorFilter(ContextCompat.getColor(this, R.color.kb_label_on_accent))
                }
                ShiftState.MOMENTARY -> {
                    key.setImageResource(R.drawable.ic_shift_on)
                    key.contentDescription = if (spanishMode) "mayúsculas" else "shift"
                    key.setBackgroundResource(R.drawable.kb_key_accent)
                    key.setColorFilter(ContextCompat.getColor(this, R.color.kb_label_on_accent))
                }
                ShiftState.OFF -> {
                    key.setImageResource(R.drawable.ic_shift_off)
                    key.contentDescription = if (spanishMode) "mayúsculas" else "shift"
                    key.setBackgroundResource(R.drawable.kb_key_alt)
                    key.setColorFilter(ContextCompat.getColor(this, R.color.kb_label))
                }
            }
        }
    }

    private fun insertTextToActiveEditor(text: String): Boolean {
        if (!isSnippetEditorOpen) return false
        val et = activeSnippetEditorField ?: etSnippetNameField ?: return false
        val start = et.selectionStart.coerceAtLeast(0)
        val end = et.selectionEnd.coerceAtLeast(0)
        val min = minOf(start, end)
        val max = maxOf(start, end)
        et.text.replace(min, max, text)
        et.setSelection(min + text.length)
        return true
    }

    private fun backspaceActiveEditor(): Boolean {
        if (!isSnippetEditorOpen) return false
        val et = activeSnippetEditorField ?: etSnippetNameField ?: return false
        val start = et.selectionStart.coerceAtLeast(0)
        val end = et.selectionEnd.coerceAtLeast(0)
        if (start != end) {
            val min = minOf(start, end)
            val max = maxOf(start, end)
            et.text.delete(min, max)
            et.setSelection(min)
            return true
        }
        if (start > 0) {
            val text = et.text
            val count = if (start >= 2 && Character.isSurrogatePair(text[start - 2], text[start - 1])) 2 else 1
            text.delete(start - count, start)
            et.setSelection(start - count)
            return true
        }
        return true
    }

    private fun commitLetter(base: Char) {
        haptic(root)
        if (insertTextToActiveEditor(displayFor(base))) {
            releaseMomentaryShift()
            return
        }
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
        if (insertTextToActiveEditor(text)) return
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
        if (insertTextToActiveEditor(text)) return
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
        var chunk = if (text.length > remaining) text.substring(0, remaining) else text
        // AT-A5: el recorte nunca deja un high surrogate suelto al final.
        if (chunk.isNotEmpty() && Character.isHighSurrogate(chunk.last())) {
            chunk = chunk.dropLast(1)
        }
        editable.append(chunk)
        et.setSelection(editable.length)
        refreshSnippetGrid()
        return true
    }

    /** Envio del caracter con META_CTRL/META_ALT via KeyEvent (patron Hacker's
     *  Keyboard). Sin codigo fisico (ej. ñ) la combinacion es imposible:
     *  AT-A15 comite el caracter tal cual para no comerse la pulsacion. */
    private fun sendModifiedChar(c: Char) {
        val code = keyCodeFor(c)
        if (code == null) {
            currentInputConnection?.commitText(c.toString(), 1)
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
        if (backspaceActiveEditor()) return
        if (layer == Layer.SNIPPETS && snippetSearchActive) {
            val et = snippetSearchField ?: return
            val text = et.text
            if (!text.isNullOrEmpty()) {
                // AT-A5: un par surrogate (emoji) se borra entero, no de a medio.
                val count = if (
                    text.length >= 2 &&
                    Character.isSurrogatePair(text[text.length - 2], text[text.length - 1])
                ) {
                    2
                } else {
                    1
                }
                text.delete(text.length - count, text.length)
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
        // AT-A5: mismo criterio sobre el documento via InputConnection.
        val before = try {
            ic.getTextBeforeCursor(2, 0)
        } catch (_: Exception) {
            null
        }
        val count = if (
            before != null && before.length == 2 &&
            Character.isSurrogatePair(before[0], before[1])
        ) {
            2
        } else {
            1
        }
        if (!ic.deleteSurroundingText(count, 0)) {
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
        if (isSnippetEditorOpen) {
            if (activeSnippetEditorField == etSnippetNameField) {
                etSnippetContentField?.requestFocus()
                etSnippetContentField?.setSelection(etSnippetContentField?.text?.length ?: 0)
                activeSnippetEditorField = etSnippetContentField
            } else if (activeSnippetEditorField == etSnippetContentField) {
                insertTextToActiveEditor("\n")
            }
            return
        }
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
    // Dictado por voz (K3 + M4 Morph-to-Pill)
    // ------------------------------------------------------------------

    private fun makeMicKey(): View {
        val container = FrameLayout(this)
        val lp = LinearLayout.LayoutParams(0, keyHeightPx(), 1f)
        val m = dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        container.layoutParams = lp

        // Vista normal en reposo / ocupado (icono vectorial kb_ic_mic)
        val normal = ImageView(this)
        normal.scaleType = ImageView.ScaleType.CENTER_INSIDE
        normal.setImageResource(R.drawable.kb_ic_mic)
        normal.isClickable = true
        normal.isFocusable = true
        normal.minimumWidth = 0
        normal.minimumHeight = 0
        normal.setPadding(0, 0, 0, 0)
        normal.setBackgroundResource(R.drawable.kb_key_bg)
        normal.setColorFilter(ContextCompat.getColor(this, R.color.kb_label))
        normal.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        attachLongPress(
            normal,
            onLongPress = {
                haptic(normal)
                when (micState) {
                    MicState.RECORDING -> cancelDictation()
                    MicState.IDLE, MicState.BUSY -> showHistoryPopup(container)
                    MicState.PROCESSING -> { /* transcribiendo: ignorar */ }
                }
            },
            onTapUp = { handleMicTap() },
        )
        container.addView(normal)

        // Vista de procesamiento / transcripción (3 puntos suspensivos pulsantes)
        val proc = LinearLayout(this)
        proc.orientation = LinearLayout.HORIZONTAL
        proc.gravity = Gravity.CENTER
        proc.setBackgroundResource(R.drawable.kb_key_alt)
        proc.isClickable = true
        proc.isFocusable = true
        proc.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        val dotSizePx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 5f, resources.displayMetrics,
        ).toInt()
        val dotGapPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics,
        ).toInt()
        val dots = mutableListOf<View>()
        for (i in 0 until 3) {
            val dot = View(this)
            dot.setBackgroundResource(R.drawable.kb_proc_dot)
            val dotLp = LinearLayout.LayoutParams(dotSizePx, dotSizePx)
            if (i > 0) {
                dotLp.leftMargin = dotGapPx
            }
            proc.addView(dot, dotLp)
            dots.add(dot)
        }
        container.addView(proc)

        // Vista pastilla (M4 Pill) en grabación
        val pill = LinearLayout(this)
        pill.orientation = LinearLayout.HORIZONTAL
        pill.gravity = Gravity.CENTER_VERTICAL
        pill.setBackgroundResource(R.drawable.kb_mic_pill)
        val padH = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 12f, resources.displayMetrics,
        ).toInt()
        pill.setPadding(padH, 0, padH, 0)
        pill.isClickable = true
        pill.isFocusable = true
        pill.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        attachLongPress(
            pill,
            onLongPress = {
                haptic(pill)
                cancelDictation()
            },
            onTapUp = {
                haptic(pill)
                finishDictation()
            },
        )

        // Punto pulsante ●
        val dot = TextView(this)
        dot.text = "●"
        dot.gravity = Gravity.CENTER
        dot.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
        dot.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 10f)
        val dotLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        pill.addView(dot, dotLp)

        // Cronómetro en vivo
        val timer = TextView(this)
        timer.text = "0:00"
        timer.gravity = Gravity.CENTER_VERTICAL
        timer.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
        timer.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
        timer.setTypeface(null, Typeface.BOLD)
        val timerLp = LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1f,
        )
        val timerMargin = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 6f, resources.displayMetrics,
        ).toInt()
        timerLp.setMargins(timerMargin, 0, timerMargin, 0)
        pill.addView(timer, timerLp)

        // Botón cancelar ✕
        val cancel = TextView(this)
        cancel.text = "✕"
        cancel.gravity = Gravity.CENTER
        cancel.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
        cancel.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14f)
        cancel.setTypeface(null, Typeface.BOLD)
        cancel.isClickable = true
        cancel.isFocusable = true
        cancel.minimumWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 44f, resources.displayMetrics,
        ).toInt()
        val cancelPad = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics,
        ).toInt()
        cancel.setPadding(cancelPad, 0, cancelPad, 0)
        val cancelLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        cancel.setOnClickListener {
            haptic(cancel)
            cancelDictation()
        }
        pill.addView(cancel, cancelLp)

        container.addView(pill)

        micNormalView = normal
        micProcView = proc
        micProcDots = dots
        micPillView = pill
        micPillDot = dot
        micPillTimer = timer
        micPillCancel = cancel

        applyMicVisual()
        return container
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
        recordingStartMs = SystemClock.elapsedRealtime()
        micPillTimer?.text = "0:00"
        refreshMicVisual()
        startRecordingTimer()
        val t = Runnable { if (micState == MicState.RECORDING) finishDictation() }
        timeoutRunnable = t
        handler.postDelayed(t, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun finishDictation() {
        stopRecordingTimer()
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        micState = MicState.PROCESSING
        refreshMicVisual()
        val config = sttClient.loadConfig()
        // AT-A1: los callbacks capturan la generacion vigente; si una
        // cancelacion la avanza mientras transcribiamos, se abortan solos.
        val generation = transcriptionGeneration
        Thread {
            val wav = sttClient.stopRecording()
            abandonAudioFocus()
            keyboardRecordingActive = false
            if (sttClient.isEmptyCapture(wav)) {
                runOnMain {
                    if (generation != transcriptionGeneration) return@runOnMain
                    micIdle()
                    showStatus(if (spanishMode) "No se detectó voz." else "No voice detected.")
                }
                return@Thread
            }
            sttClient.transcribe(
                wav,
                config,
                onDone = { text ->
                    // AT-A3: historial (lectura de disco + XML + prefs) en el
                    // hilo de fondo del cliente; sus callbacks jamas llegan
                    // por el hilo principal.
                    if (!text.isNullOrBlank()) addToSharedHistory(text)
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        if (text.isNullOrBlank()) {
                            showStatus(if (spanishMode) "No se detectó voz." else "No voice detected.")
                        } else {
                            // AT-A10: el dictado se comete directo en el campo
                            // destino; jamas alimenta el query de snippets.
                            currentInputConnection?.commitText(text, 1)
                        }
                    }
                },
                onError = { message ->
                    runOnMain {
                        if (generation != transcriptionGeneration) return@runOnMain
                        micIdle()
                        showStatus(message)
                    }
                },
            )
        }.apply { name = "VbKeyboardFinish"; start() }
    }

    private fun cancelDictation() {
        stopRecordingTimer()
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
        stopRecordingTimer()
        if (micState == MicState.IDLE && !keyboardRecordingActive) return
        val client = if (::sttClient.isInitialized) sttClient else null
        keyboardRecordingActive = false
        timeoutRunnable?.let { handler.removeCallbacks(it) }
        timeoutRunnable = null
        transcriptionGeneration++
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
        stopRecordingTimer()
        micState = MicState.IDLE
        refreshMicVisual()
    }

    private fun startRecordingTimer() {
        stopRecordingTimer()
        val r = object : Runnable {
            override fun run() {
                if (micState != MicState.RECORDING) return
                val elapsedSec = (SystemClock.elapsedRealtime() - recordingStartMs) / 1000
                val m = elapsedSec / 60
                val s = elapsedSec % 60
                micPillTimer?.text = String.format(java.util.Locale.US, "%d:%02d", m, s)
                handler.postDelayed(this, 1000L)
            }
        }
        recordingTimerRunnable = r
        handler.postDelayed(r, 1000L)
    }

    private fun stopRecordingTimer() {
        recordingTimerRunnable?.let { handler.removeCallbacks(it) }
        recordingTimerRunnable = null
    }

    private fun runOnMain(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }

    private fun refreshMicVisual() {
        // AT-A4: sin cambio de campo no hay otro punto que reevalue la
        // burbuja; si ella dejo de grabar, BUSY zombi vuelve a IDLE.
        if (micState == MicState.BUSY && !bubbleBusy()) {
            micState = MicState.IDLE
        }
        applyMicVisual()
    }

    private fun applyMicVisual() {
        pulseAnimators.forEach { it.cancel() }
        pulseAnimators = emptyList()

        val container = micKeyView ?: return
        val normal = micNormalView
        val proc = micProcView
        val pill = micPillView
        val dot = micPillDot
        val timer = micPillTimer
        val parentRow = container.parent as? ViewGroup

        val isRecording = (micState == MicState.RECORDING)
        val rm = reducedMotion()

        if (!rm && parentRow != null) {
            try {
                val transition = TransitionSet().apply {
                    ordering = TransitionSet.ORDERING_TOGETHER
                    addTransition(ChangeBounds().apply {
                        duration = 200L
                        interpolator = DecelerateInterpolator()
                    })
                    addTransition(Fade().apply {
                        duration = 150L
                    })
                }
                TransitionManager.beginDelayedTransition(parentRow, transition)
            } catch (_: Exception) {}
        }

        val lp = container.layoutParams as? LinearLayout.LayoutParams
        if (isRecording) {
            // Ya no ocultamos la barra espaciadora porque el mic no está en la misma fila!
            if (lp != null && lp.weight != 5.0f) {
                lp.weight = 5.0f // Un peso más grande para empujar y comprimir a los demás iconos suavemente
                container.layoutParams = lp
            }
            container.background = null
            normal?.visibility = View.GONE
            proc?.visibility = View.GONE
            pill?.visibility = View.VISIBLE
            container.contentDescription = if (spanishMode) "grabando dictado" else "recording dictation"

            val elapsed = (SystemClock.elapsedRealtime() - recordingStartMs) / 1000
            micPillTimer?.text = String.format("%d:%02d", elapsed / 60, elapsed % 60)
            if (recordingTimerRunnable == null) {
                startRecordingTimer()
            }

            if (dot != null) {
                dot.scaleX = 1f
                dot.scaleY = 1f
                dot.alpha = 1f
                if (!rm) {
                    val sx = ObjectAnimator.ofFloat(dot, View.SCALE_X, 1f, 1.35f)
                    val sy = ObjectAnimator.ofFloat(dot, View.SCALE_Y, 1f, 1.35f)
                    val alpha = ObjectAnimator.ofFloat(dot, View.ALPHA, 1f, 0.4f)
                    listOf(sx, sy, alpha).forEach { a ->
                        a.repeatCount = ObjectAnimator.INFINITE
                        a.repeatMode = ObjectAnimator.REVERSE
                        a.duration = 600
                        a.start()
                    }
                    pulseAnimators = listOf(sx, sy, alpha)
                }
            }
        } else {
            if (lp != null && lp.weight != 1.0f) {
                lp.weight = 1.0f
                container.layoutParams = lp
            }
            pill?.visibility = View.GONE

            when (micState) {
                MicState.IDLE -> {
                    container.background = null
                    proc?.visibility = View.GONE
                    normal?.visibility = View.VISIBLE
                    normal?.setBackgroundResource(R.drawable.kb_key_bg)
                    normal?.setImageResource(R.drawable.kb_ic_mic)
                    normal?.setColorFilter(ContextCompat.getColor(this, R.color.kb_label))
                    normal?.alpha = 1f
                    normal?.contentDescription = if (spanishMode) "dictar" else "dictate"
                    container.contentDescription = if (spanishMode) "dictar" else "dictate"
                }
                MicState.PROCESSING -> {
                    normal?.visibility = View.GONE
                    proc?.visibility = View.VISIBLE
                    proc?.setBackgroundResource(R.drawable.kb_key_alt)
                    container.setBackgroundResource(R.drawable.kb_key_alt)
                    proc?.contentDescription = if (spanishMode) "procesando" else "processing"
                    container.contentDescription = if (spanishMode) "procesando" else "processing"

                    if (!rm) {
                        val animators = mutableListOf<ObjectAnimator>()
                        micProcDots.forEachIndexed { index, dotView ->
                            dotView.scaleX = 0.8f
                            dotView.scaleY = 0.8f
                            dotView.alpha = 0.25f

                            val alphaAnim = ObjectAnimator.ofFloat(dotView, View.ALPHA, 0.25f, 1.0f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            val scaleXAnim = ObjectAnimator.ofFloat(dotView, View.SCALE_X, 0.8f, 1.25f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            val scaleYAnim = ObjectAnimator.ofFloat(dotView, View.SCALE_Y, 0.8f, 1.25f).apply {
                                duration = 540L
                                startDelay = index * 180L
                                repeatCount = ObjectAnimator.INFINITE
                                repeatMode = ObjectAnimator.REVERSE
                            }
                            alphaAnim.start()
                            scaleXAnim.start()
                            scaleYAnim.start()
                            animators.add(alphaAnim)
                            animators.add(scaleXAnim)
                            animators.add(scaleYAnim)
                        }
                        pulseAnimators = animators
                    } else {
                        micProcDots.forEach { dotView ->
                            dotView.scaleX = 1.0f
                            dotView.scaleY = 1.0f
                            dotView.alpha = 1.0f
                        }
                    }
                }
                MicState.BUSY -> {
                    container.background = null
                    proc?.visibility = View.GONE
                    normal?.visibility = View.VISIBLE
                    normal?.setBackgroundResource(R.drawable.kb_key_alt)
                    normal?.setImageResource(R.drawable.kb_ic_mic)
                    normal?.setColorFilter(ContextCompat.getColor(this, R.color.kb_label))
                    normal?.alpha = 0.5f
                    normal?.contentDescription = if (spanishMode) "micrófono ocupado" else "microphone busy"
                    container.contentDescription = if (spanishMode) "micrófono ocupado" else "microphone busy"
                }
                MicState.RECORDING -> { /* no-op */ }
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

        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad, pad, pad, pad)
        }

        // Encabezado de la ventana
        val header = TextView(this).apply {
            text = if (spanishMode) "Historial de transcripciones" else "Transcription history"
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            alpha = 0.75f
            setPadding(pad * 2, pad, pad * 2, pad)
        }
        box.addView(header)

        val headerSep = View(this).apply {
            setBackgroundColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_key_stroke))
        }
        box.addView(
            headerSep,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, resources.displayMetrics).toInt(),
            ),
        )

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        var count = 0
        for (obj in entries) {
            val text = obj.optString("text")
            if (text.isBlank()) continue
            if (count > 0) {
                val sep = View(this).apply {
                    setBackgroundColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_key_stroke))
                }
                content.addView(
                    sep,
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 1f, resources.displayMetrics).toInt(),
                    ),
                )
            }
            count++
            val tv = TextView(this).apply {
                this.text = text
                maxLines = 2
                ellipsize = TextUtils.TruncateAt.END
                isClickable = true
                isFocusable = true
                setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
                setBackgroundResource(R.drawable.kb_menu_item)
                setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
                setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
                setOnClickListener {
                    haptic(this)
                    commit(text)
                    dismissPopup()
                }
            }
            content.addView(tv)
        }

        if (count == 0) {
            val empty = TextView(this).apply {
                this.text = if (spanishMode) "Sin transcripciones todavía." else "No transcriptions yet."
                gravity = Gravity.CENTER
                setPadding(pad * 2, pad * 4, pad * 2, pad * 4)
                setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
                setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            }
            content.addView(empty)
        }

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = true
            scrollBarStyle = View.SCROLLBARS_INSIDE_OVERLAY
            addView(content)
        }
        val scrollLp = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        box.addView(scroll, scrollLp)

        val dm = resources.displayMetrics
        val minHeightPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 220f, dm).toInt()
        val maxHeightPx = (dm.heightPixels * 0.45f).toInt().coerceAtLeast(minHeightPx)

        box.measure(
            View.MeasureSpec.makeMeasureSpec((dm.widthPixels * 0.85f).toInt(), View.MeasureSpec.AT_MOST),
            View.MeasureSpec.UNSPECIFIED,
        )

        val popupHeight = box.measuredHeight.coerceIn(minHeightPx, maxHeightPx)
        val desiredWidthPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 320f, dm).toInt()
        val gap = dimen(R.dimen.kb_key_gap)
        val maxAllowedWidth = dm.widthPixels - (gap * 2)
        val popupWidth = minOf(desiredWidthPx, maxAllowedWidth)

        val popup = PopupWindow(box, popupWidth, popupHeight, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = R.style.VoiceHistoryPopupAnimation
        }

        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val anchorCenterX = loc[0] + anchor.width / 2
        val rawX = if (anchorCenterX > dm.widthPixels / 2) {
            loc[0] + anchor.width - popupWidth
        } else {
            loc[0]
        }
        val posX = rawX.coerceIn(gap, dm.widthPixels - popupWidth - gap)
        val posY = maxOf(gap, loc[1] - popupHeight - gap)

        val isRightAligned = (posX + popupWidth / 2) > (dm.widthPixels / 2)
        box.pivotX = if (isRightAligned) popupWidth.toFloat() else 0f
        box.pivotY = popupHeight.toFloat()
        box.alpha = 0f
        box.scaleX = 0.8f
        box.scaleY = 0.8f

        activePopup = popup
        popup.showAtLocation(root, Gravity.NO_GRAVITY, posX, posY)

        box.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(200)
            .setInterpolator(android.view.animation.DecelerateInterpolator(1.8f))
            .start()
    }

    /**
     * Historial compartido parseado para la ventana: tolerante (los candidatos
     * que no son objetos JSON validos se descartan en silencio), ordenado por
     * timestamp descendente y con dedup por timestamp parseado
     * (una misma entrada presente en dos serializaciones ocupa una sola fila;
     * entradas con timestamp imposible no participan del dedup y nunca se
     * pierden). Mismo criterio de lectura que addToSharedHistory y la app.
     */
    private fun sharedHistoryEntries(): List<JSONObject> {
        val parsed = ArrayList<JSONObject>()
        for (raw in sharedHistoryRaw()) {
            try {
                parsed.add(JSONObject(raw))
            } catch (_: Exception) {}
        }
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
     * volcadas sin resucitar entradas borradas desde la app.
     */
    private fun writableHistoryBase(): ArrayList<JSONObject> {
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
            } catch (_: Exception) {}
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
                            continue
                        }
                        val ts = historyEntryInstantOrNull(obj)
                        val alreadyOnDisk =
                            (ts != null && diskTimes.contains(ts)) || diskRaw.contains(raw)
                        if (!alreadyOnDisk) base.add(obj)
                    }
                }
        } catch (_: Exception) {}
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
        val view = root
        view.post {
            // AT-A9: identidad contra la vista vigente; una vista vieja ya
            // reemplazada nunca crea ni borra avisos.
            if (view !== inputView) return@post
            // AT-A9: un aviso identico aun vivo conserva su timer original.
            if (message == statusMessage && statusRowView != null) return@post
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
            statusMessage = message
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
        statusMessage = null
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
            isSnippetEditorOpen = false
            editingSnippet = null
            activeSnippetEditorField = null
            etSnippetNameField = null
            etSnippetContentField = null
            rebuild()
            return
        }
        layerBeforeSnippets = layer
        if (!snippetsSeedAttempted) {
            snippetsSeedAttempted = true
            snippetStore.seedIfFirstOpen()
        }
        snippetStore.load()
        snippetQuery = ""
        layer = Layer.SNIPPETS
        rebuild()
    }

    private fun openSnippetEditor(snippet: VbSnippet?) {
        dismissPopup()
        isSnippetEditorOpen = true
        editingSnippet = snippet
        snippetSearchActive = false
        rebuild()
    }

    private fun closeSnippetEditor() {
        isSnippetEditorOpen = false
        editingSnippet = null
        activeSnippetEditorField = null
        etSnippetNameField = null
        etSnippetContentField = null
        snippetMode = SnippetMode.NORMAL
        rebuild()
    }

    /** Fila de busqueda/editor inline + grid scrolleable de chips + filas QWERTY. */
    private fun buildSnippetRows() {
        if (isSnippetEditorOpen) {
            addRow(buildSnippetEditorInline())
        } else {
            addRow(buildSnippetSearchRow())
            val scroll = ScrollView(this).apply {
                isVerticalScrollBarEnabled = false
            }
            val grid = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }
            snippetGridContainer = grid
            scroll.addView(grid)
            refreshSnippetGrid()
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                scaleV(dimen(R.dimen.kb_snippets_grid_height)),
            )
            lp.topMargin = rowGapPx()
            root.addView(scroll, lp)
        }
        addSnippetLetterRows()
    }

    private fun buildSnippetEditorInline(): LinearLayout {
        val pad = dimen(R.dimen.kb_popup_padding)
        val m = dimen(R.dimen.kb_key_gap) / 2
        val isEdit = editingSnippet != null

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad, pad, pad, pad)
        }

        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(this).apply {
            text = if (isEdit) (if (spanishMode) "Editar snippet" else "Edit snippet")
            else (if (spanishMode) "Nuevo snippet" else "New snippet")
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
        }
        val lpTitle = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        headerRow.addView(title, lpTitle)

        val btnCancel = TextView(this).apply {
            text = if (spanishMode) "Cancelar" else "Cancel"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setOnClickListener {
                haptic(this)
                closeSnippetEditor()
            }
        }
        val lpCancel = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, scaleV(dimen(R.dimen.kb_snippet_chip_height)))
        lpCancel.rightMargin = pad
        headerRow.addView(btnCancel, lpCancel)

        val btnSave = TextView(this).apply {
            text = if (spanishMode) "Guardar" else "Save"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_accent)
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_on_accent))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener {
                haptic(this)
                val name = etSnippetNameField?.text?.toString()?.trim().orEmpty()
                val content = etSnippetContentField?.text?.toString()?.trim().orEmpty()
                if (name.isNotEmpty()) {
                    val toSave = if (isEdit && editingSnippet != null) {
                        editingSnippet!!.copy(nombre = name, contenido = content)
                    } else {
                        VbSnippet(id = "", nombre = name, contenido = content, orden = 0)
                    }
                    snippetStore.saveSnippet(toSave)
                    closeSnippetEditor()
                }
            }
        }
        val lpSave = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, scaleV(dimen(R.dimen.kb_snippet_chip_height)))
        headerRow.addView(btnSave, lpSave)
        container.addView(headerRow)

        val etName = EditText(this).apply {
            hint = if (spanishMode) "Nombre (ej. Git commit)" else "Name"
            setSingleLine(true)
            maxLines = 1
            inputType = InputType.TYPE_CLASS_TEXT
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
            setHintTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_secondary))
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(pad, pad, pad, pad)
            if (isEdit) setText(editingSnippet?.nombre.orEmpty())
            onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
                if (hasFocus) activeSnippetEditorField = this
            }
            setOnClickListener {
                activeSnippetEditorField = this
            }
        }
        etSnippetNameField = etName
        val lpName = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, scaleV(dimen(R.dimen.kb_snippet_search_height)))
        lpName.topMargin = pad
        container.addView(etName, lpName)

        val etContent = EditText(this).apply {
            hint = if (spanishMode) "Contenido o comando..." else "Content or command..."
            setSingleLine(false)
            maxLines = 2
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
            setHintTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_secondary))
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(pad, pad, pad, pad)
            if (isEdit) setText(editingSnippet?.contenido.orEmpty())
            onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
                if (hasFocus) activeSnippetEditorField = this
            }
            setOnClickListener {
                activeSnippetEditorField = this
            }
        }
        etSnippetContentField = etContent
        val lpContent = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, scaleV(dimen(R.dimen.kb_snippet_search_height)))
        lpContent.topMargin = pad
        container.addView(etContent, lpContent)

        activeSnippetEditorField = etName
        etName.post {
            etName.requestFocus()
            etName.setSelection(etName.text.length)
        }

        val lpContainer = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        lpContainer.setMargins(m, 0, m, 0)
        container.layoutParams = lpContainer
        return container
    }

    /**
     * Filas QWERTY dentro de la capa snippets: conservan la altura keyHeightPx()
     * configurada por el usuario sin achicarse artificialmente.
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

    /** Tecla alfabetica; mismo estilo y tamano estándar que la capa letras. */
    private fun makeSnippetLetterKey(base: Char): TextView {
        val key = makeKey(
            displayFor(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            dimen(R.dimen.kb_key_text_size),
        )
        if (accentsFor(base).isEmpty()) {
            attachFastKeyTouch(key) { commitSnippetLetter(base) }
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
        letterKeys.add(Pair(key, base))
        return key
    }

    /** Backspace: borra del query, del editor activo o del documento. */
    private fun makeSnippetBackspaceKey(): ImageView {
        val key = makeActionIconKey(
            R.drawable.ic_backspace,
            R.drawable.kb_key_alt,
            1.3f,
            if (spanishMode) "borrar" else "delete",
            tintColorRes = R.color.kb_label,
        ) {
            ensureSnippetSearchMode()
            handleBackspace()
        }
        attachBackspaceGestures(key) {
            ensureSnippetSearchMode()
            handleBackspace()
        }
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
        et.hint = if (spanishMode) "Buscar snippets..." else "Search snippets..."
        et.setSingleLine(true)
        et.maxLines = 1
        et.inputType = InputType.TYPE_CLASS_TEXT
        et.imeOptions = EditorInfo.IME_ACTION_SEARCH
        et.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
        et.setHintTextColor(ContextCompat.getColor(this, R.color.kb_label_secondary))
        et.setBackgroundResource(R.drawable.kb_key_bg)
        et.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        et.setPadding(pad, pad, pad, pad)
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

        val btnH = scaleV(dimen(R.dimen.kb_snippet_search_height))
        val btnW = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, resources.displayMetrics).toInt()

        // Boton [+] Nuevo
        val btnPlus = makeIconKey(R.drawable.ic_add, R.drawable.kb_key_bg, 0f, if (spanishMode) "nuevo snippet" else "new snippet") {
            openSnippetEditor(null)
        }
        val lpPlus = LinearLayout.LayoutParams(btnW, btnH)
        lpPlus.setMargins(m, 0, m, 0)
        btnPlus.layoutParams = lpPlus
        row.addView(btnPlus)

        // Boton [✏️] Editar
        val btnEdit = makeIconKey(
            R.drawable.ic_edit,
            if (snippetMode == SnippetMode.EDIT) R.drawable.kb_key_accent else R.drawable.kb_key_bg,
            0f,
            if (spanishMode) "editar snippet" else "edit snippet",
        ) {
            snippetMode = if (snippetMode == SnippetMode.EDIT) SnippetMode.NORMAL else SnippetMode.EDIT
            updateSnippetModeVisuals()
            refreshSnippetGrid()
        }
        btnSnippetEditView = btnEdit
        val lpEdit = LinearLayout.LayoutParams(btnW, btnH)
        lpEdit.setMargins(m, 0, m, 0)
        btnEdit.layoutParams = lpEdit
        row.addView(btnEdit)

        // Boton [🗑️] Eliminar
        val btnDelete = makeIconKey(
            R.drawable.ic_delete,
            if (snippetMode == SnippetMode.DELETE) R.drawable.kb_key_danger else R.drawable.kb_key_bg,
            0f,
            if (spanishMode) "eliminar snippet" else "delete snippet",
        ) {
            snippetMode = if (snippetMode == SnippetMode.DELETE) SnippetMode.NORMAL else SnippetMode.DELETE
            updateSnippetModeVisuals()
            refreshSnippetGrid()
        }
        btnSnippetDeleteView = btnDelete
        val lpDelete = LinearLayout.LayoutParams(btnW, btnH)
        lpDelete.setMargins(m, 0, m, 0)
        btnDelete.layoutParams = lpDelete
        row.addView(btnDelete)

        return row
    }

    private fun updateSnippetModeVisuals() {
        btnSnippetEditView?.setBackgroundResource(
            if (snippetMode == SnippetMode.EDIT) R.drawable.kb_key_accent else R.drawable.kb_key_bg,
        )
        (btnSnippetEditView as? ImageView)?.setColorFilter(
            if (snippetMode == SnippetMode.EDIT) ContextCompat.getColor(this, R.color.kb_label_on_accent)
            else ContextCompat.getColor(this, R.color.kb_label),
        )
        btnSnippetDeleteView?.setBackgroundResource(
            if (snippetMode == SnippetMode.DELETE) R.drawable.kb_key_danger else R.drawable.kb_key_bg,
        )
        (btnSnippetDeleteView as? ImageView)?.setColorFilter(
            if (snippetMode == SnippetMode.DELETE) ContextCompat.getColor(this, R.color.kb_label_on_accent)
            else ContextCompat.getColor(this, R.color.kb_label),
        )
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

    /** Chip con el nombre del snippet: tap inserta, o activa accion segun modo. */
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

        when (snippetMode) {
            SnippetMode.EDIT -> {
                chip.setBackgroundResource(R.drawable.kb_key_accent)
                chip.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
                chip.setOnClickListener {
                    haptic(chip)
                    openSnippetEditor(snippet)
                }
            }
            SnippetMode.DELETE -> {
                chip.setBackgroundResource(R.drawable.kb_key_danger)
                chip.setTextColor(ContextCompat.getColor(this, R.color.kb_label_on_accent))
                chip.setOnClickListener {
                    haptic(chip)
                    showSnippetDeleteConfirmation(snippet)
                }
            }
            SnippetMode.NORMAL -> {
                chip.setBackgroundResource(R.drawable.kb_key_bg)
                chip.setTextColor(ContextCompat.getColor(this, R.color.kb_label))
                attachLongPress(
                    chip,
                    onLongPress = {
                        haptic(chip)
                        showSnippetMenu(chip, snippet)
                    },
                    onTapUp = { insertSnippet(snippet) },
                )
            }
        }

        chip.setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
        chip.contentDescription = snippet.nombre

        val lp = LinearLayout.LayoutParams(0, scaleV(dimen(R.dimen.kb_snippet_chip_height)), 1f)
        val m = dimen(R.dimen.kb_key_gap) / 2
        lp.setMargins(m, 0, m, 0)
        chip.layoutParams = lp
        return chip
    }

    private fun showSnippetDeleteConfirmation(snippet: VbSnippet) {
        dismissPopup()
        val pad = dimen(R.dimen.kb_popup_padding)
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
        }

        val title = TextView(this).apply {
            text = if (spanishMode) "¿Eliminar snippet?" else "Delete snippet?"
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size).toFloat())
            setTypeface(null, Typeface.BOLD)
        }
        box.addView(title)

        val desc = TextView(this).apply {
            text = snippet.nombre
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_recording))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(0, pad / 2, 0, pad * 2)
        }
        box.addView(desc)

        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        val btnCancel = TextView(this).apply {
            text = if (spanishMode) "Cancelar" else "Cancel"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setOnClickListener {
                haptic(this)
                dismissPopup()
            }
        }
        val lpCancel = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, scaleV(dimen(R.dimen.kb_snippet_chip_height)))
        lpCancel.rightMargin = pad
        actionsRow.addView(btnCancel, lpCancel)

        val btnDelete = TextView(this).apply {
            text = if (spanishMode) "Eliminar" else "Delete"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_danger)
            setTextColor(ContextCompat.getColor(this@VoiceKeyboardService, R.color.kb_label_on_accent))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, dimen(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener {
                haptic(this)
                snippetStore.deleteSnippet(snippet.id)
                snippetMode = SnippetMode.NORMAL
                updateSnippetModeVisuals()
                dismissPopup()
                refreshSnippetGrid()
            }
        }
        val lpDelete = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, scaleV(dimen(R.dimen.kb_snippet_chip_height)))
        actionsRow.addView(btnDelete, lpDelete)

        box.addView(actionsRow)

        val dm = resources.displayMetrics
        val popupWidth = minOf(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 300f, dm).toInt(), dm.widthPixels - pad * 4)
        val popup = PopupWindow(box, popupWidth, ViewGroup.LayoutParams.WRAP_CONTENT, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = R.style.VoiceHistoryPopupAnimation
        }
        activePopup = popup
        popup.showAtLocation(root, Gravity.CENTER, 0, 0)
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
        val gap = dimen(R.dimen.kb_key_gap)
        activePopup = popup
        popup.showAtLocation(
            root,
            Gravity.NO_GRAVITY,
            loc[0],
            // AT-A12: jamas Y negativo; si no cabe arriba se solapa con el ancla.
            maxOf(gap, loc[1] - box.measuredHeight - gap),
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
     * AT-A16: PROHIBIDO setOnLongClickListener sobre teclas cableadas aqui —
     * este touch listener consume el UP y dejaria zombi el chequeo de long
     * press del framework.
     */
    private fun attachLongPress(
        key: View,
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
                    haptic(v)
                    v.isPressed = true
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
                    true
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
                    true
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
    private fun attachBackspaceGestures(key: View, action: () -> Unit) {
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

    /** AT-A11: sin pareja que insertar en toque largo, la tecla lleva un click
     *  plano (mismo commit que el tap) sin maquinaria de long-press. */
    private fun attachPairLongPress(key: TextView, ch: Char) {
        val close = pairCloseFor(ch)
        if (close == null) {
            key.setOnClickListener { commitSymbolText(ch.toString()) }
            return
        }
        attachLongPress(
            key,
            onLongPress = {
                commit("$ch$close")
                sendKeyCode(KeyEvent.KEYCODE_DPAD_LEFT)
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
        val gap = dimen(R.dimen.kb_key_gap)
        activePopup = popup
        popup.showAtLocation(
            root,
            Gravity.NO_GRAVITY,
            loc[0],
            // AT-A12: jamas Y negativo; si no cabe arriba se solapa con el ancla.
            maxOf(gap, loc[1] - box.measuredHeight - gap),
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
     * K5-T2/T3 + AT-A8: lectura UNICA por ciclo del campo (onStartInputView)
     * de las preferencias de aspecto escritas por Ajustes (archivo
     * FlutterSharedPreferences, claves con prefijo "flutter."). Parseo
     * tolerante: valor desconocido o error cae al default. Todo queda cacheado
     * en campos (heightFactor, hapticsEnabled y las tres visibilidades) y ni
     * rebuild ni ninguna tecla vuelven a tocar SharedPreferences; los cambios
     * hechos en Ajustes se aplican al abrirse el proximo campo.
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
        bottomElevationDp = try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getLong("flutter.kb_bottom_elevation_dp", 24L).toInt()
        } catch (_: Exception) {
            24
        }
        invertToolbar = try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getBoolean("flutter.kb_invert_toolbar", false)
        } catch (_: Exception) {
            false
        }
        spacebarAlignment = try {
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.kb_spacebar_alignment", "center") ?: "center"
        } catch (_: Exception) {
            "center"
        }
        terminalRowVisiblePref = terminalRowVisible()
        codeKeyVisiblePref = codeKeyVisible()
        languageKeyVisiblePref = languageKeyVisible()
    }

    /** Altura de tecla estandar escalada por el perfil activo. */
    private fun keyHeightPx(): Int = scaleV(dimen(R.dimen.kb_key_height))

    /** Altura de teclas QWERTY de snippets: unificada al perfil estándar activo. */
    private fun snippetKeyHeightPx(): Int = keyHeightPx()

    /** Margen vertical entre filas, escalado ergonómico estilo Gboard. */
    private fun rowGapPx(): Int = scaleV(dimen(R.dimen.kb_key_gap_v))

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
