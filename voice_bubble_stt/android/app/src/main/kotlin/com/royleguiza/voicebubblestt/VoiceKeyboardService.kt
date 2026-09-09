package com.royleguiza.voicebubblestt

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.DeadObjectException
import android.os.Handler
import android.os.Looper
import android.os.RemoteException
import android.os.SystemClock
import android.text.InputType
import android.transition.ChangeBounds
import android.transition.Fade
import android.transition.TransitionManager
import android.transition.TransitionSet
import android.view.animation.DecelerateInterpolator
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.inputmethod.EditorInfo
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * Teclado del sistema VoiceBubble.
 * K1: QWERTY es/en + capa simbolos basicos + acentos por toque largo.
 * K2: capa codigo con pares auto-cerrados + fila terminal permanente
 *     (TAB/ESC/CTRL/ALT/flechas) con modificadores sticky para Termux.
 * K4: capa snippets (chips + busqueda) que inserta el contenido en el cursor.
 * MEJ-09: capa trackpad nativa Split Wings con cursor de mouse virtual.
 * Este teclado JAMAS registra, guarda ni transmite texto tecleado.
 */
class VoiceKeyboardService : InputMethodService(), CredentialsLayer.UiHost, DictationController.UiHost, TrackpadBridge.UiHost, ClipboardLayer.UiHost, SnippetsLayer.UiHost, HistoryLayer.UiHost, StatusLayer.UiHost, AccentLayer.UiHost, ToolbarLayer.UiHost {

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

    // --- Dictado (K3 + M4 Morph-to-Pill; máquina en DictationController) ---
    private lateinit var dictation: DictationController
    private var currentIsPasswordField = false
    private var spaceKeyView: View? = null
    private var commaKeyView: View? = null
    private var dotKeyView: View? = null

    // Handler/runnable vigentes de la barra espaciadora: attachSpacebarGestures
    // los publica acá para poder cancelarlos en rebuild/onDestroy (sin esto
    // el blank-out disparaba sobre vistas ya removidas).
    private var spacebarGestureHandler: Handler? = null
    private var spacebarLongPressRunnable: Runnable? = null

    // Canceladores de los long-press pendientes de attachLongPress: rebuild
    // los invoca a todos antes de removeAllViews para no dejar disparos
    // zombis sobre teclas descartadas.
    private val longPressCancellations = mutableListOf<() -> Unit>()

    // --- Snippets (K4: vive en SnippetsLayer; aquí solo el shell) ---
    private lateinit var snippets: SnippetsLayer
    // Claves: solo lectura desde Ajustes; el teclado jamas escribe ni borra.
    private lateinit var credentialStore: CredentialStore
    private lateinit var credentials: CredentialsLayer

    // --- Preferencias de aspecto (K5-T2/T3, puente Flutter) ---
    private lateinit var trackpad: TrackpadBridge

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

    // --- Portapapeles Multimodal (Opción 2: Cinta Horizontal Deslizable) ---
    private lateinit var clipboard: ClipboardLayer
    private lateinit var kbPrefs: KeyboardPrefs
    private lateinit var transcriptionRepo: TranscriptionHistoryRepository
    // --- Historial (SPK-05 módulo 9: vive en HistoryLayer; aquí solo el shell) ---
    private lateinit var history: HistoryLayer
    // --- Aviso inline (SPK-05 módulo 10: vive en StatusLayer; aquí solo el shell) ---
    private lateinit var status: StatusLayer
    // --- Acentos y pares (SPK-05 módulo 11: vive en AccentLayer; aquí solo el shell) ---
    private lateinit var accents: AccentLayer
    // --- Toolbar y fila terminal (SPK-05 módulo 12: vive en ToolbarLayer) ---
    private lateinit var toolbar: ToolbarLayer

    override fun onCreate() {
        super.onCreate()
        instance = this
        kbPrefs = KeyboardPrefs(this)
        clipboard = ClipboardLayer(this, handler, this)
        clipboard.onCreate()
        trackpad = TrackpadBridge(this, kbPrefs, this)
        transcriptionRepo = TranscriptionHistoryRepository(this)
        dictation = DictationController(this, handler, this)
        // Historial persistente FIFO-20: sin purga (borraba lo dictado con
        // la píldora/la app cada vez que el IME se recreaba).
    }

    override fun onEvaluateFullscreenMode(): Boolean = false

    override fun onCreateInputView(): View {
        // K5-T5: recreacion de vista (ej. rotacion) nunca debe dejar una
        // grabacion fantasma del cliente anterior colgada.
        dictation.onCreateInputView()
        snippets = SnippetsLayer(this, this)
        snippets.onCreateInputView()
        credentialStore = CredentialStore(this)
        credentials = CredentialsLayer(this, credentialStore, handler, this)
        history = HistoryLayer(this, this)
        status = StatusLayer(this, handler, this)
        accents = AccentLayer(this, this)
        toolbar = ToolbarLayer(this, this)
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
                kbPrefs.bottomElevationDp.toFloat(),
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
        dictation.cancelDictationIfActive()
        kbPrefs.load()
        currentIsPasswordField = isPasswordInput(info)
        if (currentIsPasswordField && (layer == Layer.TRACKPAD || layer == Layer.SNIPPETS)) {
            layer = Layer.LETTERS
        }
        trackpad.hide()
        // AT-A4: BUSY es espejo del estado de la burbuja; si ella ya solto
        // el microfono, el teclado arranca este campo en IDLE.
        dictation.syncBubbleState()
        // FIX ?123 persistente: los restart de la app destino (restarting=true,
        // ej. navegadores/WebView tras cada commit) no deben tumbar la capa
        // SYMBOLS/CODE. Solo un campo nuevo resetea a LETTERS.
        if (!restarting) {
            layer = Layer.LETTERS
            lastLettersLayer = Layer.LETTERS
            deactivateShift()
            ctrlActive = false
            altActive = false
        }
        // Sincronizar clips copiados mientras el teclado estaba cerrado.
        if (::clipboard.isInitialized) clipboard.onStartInputView(restarting)
        rebuild()
        root.requestApplyInsets()
    }

    /** Campos de contraseña: sin micrófono, snippets, trackpad ni sugerencias (K3, MEJ-09). */
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
        dictation.cancelDictationIfActive()
        dismissPopup()
        trackpad.hide()
        super.onFinishInputView(finishingInput)
    }

    override fun onWindowHidden() {
        super.onWindowHidden()
        dismissPopup()
        trackpad.hide()
    }

    override fun onDestroy() {
        if (::clipboard.isInitialized) clipboard.onDestroy()
        dictation.onDestroy()
        cancelPendingKeyGestures()
        handler.removeCallbacksAndMessages(null)
        dismissPopup()
        if (::trackpad.isInitialized) trackpad.destroy()
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Construccion de la vista
    // ------------------------------------------------------------------

    override fun rebuild() {
        dismissPopup()
        if (::status.isInitialized) status.hide()
        dictation.onViewsDiscarded()
        // Los pendings referencian las vistas viejas: cancelarlos ANTES de
        // soltarlas o sus long-press disparan sobre teclas descartadas.
        cancelPendingKeyGestures()
        letterKeys.clear()
        shiftKeyViews.clear()
        modifierKeyViews.clear()
        spaceKeyView = null
        commaKeyView = null
        dotKeyView = null
        if (layer != Layer.SNIPPETS && ::snippets.isInitialized) {
            snippets.resetState()
        }
        root.removeAllViews()

        // K2.1: fila terminal ocultable desde Ajustes de la app (default visible).
        // Y ahora Toolbar Interactiva Superior con Mic, Portapapeles, etc.
        // (SPK-05 módulo 12: vive en ToolbarLayer).
        addRow(toolbar.buildToolbar())
        val filmstrip = clipboard.buildFilmstrip()
        addRow(filmstrip)

        if (layer == Layer.TRACKPAD) {
            addRow(trackpad.buildLayer())
        } else {
            trackpad.hide()
            if (kbPrefs.terminalRowVisiblePref) {
                addRow(toolbar.buildTerminalRow())
            }
            when (layer) {
                Layer.LETTERS -> buildLetterRows()
                Layer.SYMBOLS -> buildSymbolRows()
                Layer.CODE -> buildCodeRows()
                Layer.SNIPPETS -> buildSnippetRows()
                Layer.CREDENTIALS -> buildCredentialRows()
                Layer.TRACKPAD -> {}
            }
            addRow(buildBottomBar())
        }

        // Sincronizar estados visuales persistentes tras reconstruir la vista.
        applyCase()
        refreshModifierVisuals()
        applyMicVisual()
    }
    // --- ToolbarLayer.UiHost (SPK-05 módulo 12). isSpanish,
    // isPasswordField, currentLayer, dimenPx, horizontalRow, makeIconKey y
    // attachPress ya existen arriba y sirven a esta interfaz (misma firma,
    // una sola implementación).
    override fun makeSpecial(
        label: String,
        bgRes: Int,
        weight: Float,
        description: String?,
        textSizePx: Int,
        isBold: Boolean,
        onClick: () -> Unit,
    ): TextView = makeSpecialKey(label, bgRes, weight, description, textSizePx, isBold, onClick)
    override fun rebuildKeyboard() = rebuild()
    override fun snippetsToggle() {
        snippets.toggle()
    }
    override fun credentialsToggle() {
        credentials.toggle()
    }
    override fun clipboardToggle() {
        clipboard.toggle()
    }
    override fun clipboardPasteLatest() {
        clipboard.pasteLatestOrToggle()
    }
    override fun trackpadToggle() {
        trackpad.toggle()
    }
    override fun codeToggle() {
        toggleCodeLayer()
    }
    override fun sendCode(code: Int) {
        sendKeyCode(code)
    }
    override fun micKeyView(): View = dictation.makeMicKey()
    override fun micClearViews() {
        dictation.clearViews()
    }
    override fun isTerminalRowPref(): Boolean = kbPrefs.terminalRowVisiblePref
    override fun toggleTerminalRowPref() {
        kbPrefs.terminalRowVisiblePref = !kbPrefs.terminalRowVisiblePref
    }
    override fun isCodeKeyPref(): Boolean = kbPrefs.codeKeyVisiblePref
    override fun isTrackpadToolbarAllowed(): Boolean = kbPrefs.trackpadEnabled && kbPrefs.trackpadToolbarVisible
    override fun isToolbarInverted(): Boolean = kbPrefs.invertToolbar
    override fun registerModifier(key: TextView, isCtrl: Boolean) {
        modifierKeyViews.add(Pair(key, isCtrl))
    }
    override fun isModifierActive(isCtrl: Boolean): Boolean = if (isCtrl) ctrlActive else altActive
    override fun toggleModifier(isCtrl: Boolean) {
        if (isCtrl) ctrlActive = !ctrlActive else altActive = !altActive
    }
    override fun refreshModifiers() = refreshModifierVisuals()

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
            if (layer == Layer.SNIPPETS) {
                snippets.cycleSubLayerForSymbols()
            } else {
                layer = if (layer == Layer.SYMBOLS) Layer.LETTERS else Layer.SYMBOLS
                rebuild()
            }
        }

        val btnLang = if (kbPrefs.languageKeyVisiblePref) {
            makeSpecialKey(if (spanishMode) "ES" else "EN", R.drawable.kb_key_alt, 1f, if (spanishMode) "cambiar idioma" else "switch language", isBold = true) {
                spanishMode = !spanishMode
                rebuild()
            }
        } else null

        val comma = makeSymbolKey(",", dimen(R.dimen.kb_key_glyph_punct), isBold = true)
        commaKeyView = comma

        val space = makeSpecialKey("", R.drawable.kb_key_bg, 5.0f, if (spanishMode) "espacio" else "space") {
            // En snippets el espacio alimenta el query solo si no esta abierto el editor.
            if (layer == Layer.SNIPPETS && !snippets.isEditorOpen) snippets.ensureSearchMode()
            commit(" ")
        }
        spaceKeyView = space
        attachSpacebarGestures(space)

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

        when (kbPrefs.spacebarAlignment) {
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

    private fun symbolsToggleLabel(): String = when {
        layer == Layer.SNIPPETS && (snippets.subLayer == Layer.SYMBOLS || snippets.subLayer == Layer.CODE) -> "ABC"
        layer == Layer.SYMBOLS || layer == Layer.CODE || layer == Layer.CREDENTIALS -> "ABC"
        else -> "?123"
    }

    /** Cambiador de capas con memoria de la ultima capa no-codigo. */
    private fun toggleCodeLayer() {
        if (layer == Layer.SNIPPETS) {
            snippets.cycleSubLayerForCode()
            return
        }
        if (layer == Layer.CODE) {
            layer = lastLettersLayer
        } else {
            // Desde snippets no se pisa la memoria: volver conserva el origen.
            lastLettersLayer = if (layer == Layer.SYMBOLS) Layer.LETTERS else layer
            layer = Layer.CODE
        }
        rebuild()
    }

    /** Shell SPK-05: la altura vive en TrackpadBridge; aquí solo el delegado para addRow. */
    private fun getTargetTrackpadHeightPx(): Int =
        if (::trackpad.isInitialized) trackpad.targetHeightPx() else {
            val totalKeyRows = if (kbPrefs.terminalRowVisiblePref) 5 else 4
            totalKeyRows * keyHeightPx() + (totalKeyRows - 1) * rowGapPx()
        }

    private fun beginKeyboardTransition() {
        if (!reducedMotion()) {
            try {
                val transition = TransitionSet().apply {
                    ordering = TransitionSet.ORDERING_TOGETHER
                    addTransition(ChangeBounds().apply {
                        duration = 180L
                        interpolator = DecelerateInterpolator()
                    })
                    addTransition(Fade().apply {
                        duration = 140L
                    })
                }
                TransitionManager.beginDelayedTransition(root, transition)
            } catch (_: Exception) {}
        }
    }

    // --- TrackpadBridge.UiHost (módulo 6) + ClipboardLayer.UiHost (módulo 7):
    // currentLayer/isPasswordField/isSpanish/rootView/haptic ya existen
    // arriba y sirven a las cuatro interfaces (misma firma, una sola impl).
    override fun commitText(text: String) {
        commit(text)
    }

    // --- SnippetsLayer.UiHost (SPK-05 módulo 8). commitText no sirve aquí:
    // insertar un snippet debe saltear el ruteo al query (bucle), por eso
    // la capa comitea directo vía el InputConnection del servicio.
    override fun dimenPx(resId: Int): Int = dimen(resId)
    override fun addContentRow(view: View) = addRow(view)
    override fun showCenteredBox(box: LinearLayout, widthPx: Int) {
        val popup = PopupWindow(box, widthPx, ViewGroup.LayoutParams.WRAP_CONTENT, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = R.style.VoiceHistoryPopupAnimation
        }
        activePopup = popup
        popup.showAtLocation(root, Gravity.CENTER, 0, 0)
    }
    override fun showAnchoredBox(box: LinearLayout, anchor: View) {
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
    override fun setLayer(next: Layer) {
        layer = next
    }
    override fun lastLetters(): Layer = lastLettersLayer
    override fun setLastLetters(l: Layer) {
        lastLettersLayer = l
    }
    override fun rootView(): LinearLayout = root
    override fun beginTransition() = beginKeyboardTransition()

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

    override fun horizontalRow(): LinearLayout {
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
            accents.attachAccent(key, base) { commitLetter(base) }
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
        accents.attachPair(
            key,
            ch,
            onCommit = { commitSymbolText(it) },
            onAutoPair = { open, close ->
                commit("$open$close")
                sendKeyCode(KeyEvent.KEYCODE_DPAD_LEFT)
            },
        )
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

    override fun makeIconKey(
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

    private fun addRow(row: View) {
        val lp = if (row is VirtualTrackpadView) {
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                getTargetTrackpadHeightPx(),
            )
        } else {
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
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

    private fun insertTextToActiveEditor(text: String): Boolean =
        if (::snippets.isInitialized) snippets.insertToEditor(text) else false

    private fun backspaceActiveEditor(): Boolean =
        if (::snippets.isInitialized) snippets.backspaceEditor() else false

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
     * Shell SPK-05: la lógica vive en SnippetsLayer.
     */
    private fun routeToSnippetQuery(text: String): Boolean =
        if (::snippets.isInitialized) snippets.routeToQuery(text) else false

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

    override fun consumeModifiers() {
        ctrlActive = false
        altActive = false
        refreshModifierVisuals()
    }

    private fun handleBackspace() {
        haptic(root)
        if (backspaceActiveEditor()) return
        if (::snippets.isInitialized && snippets.backspaceQuery()) return
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
            if (::snippets.isInitialized) snippets.deleteQueryWord()
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
        if (::snippets.isInitialized && snippets.handleEnterInEditor()) return
        if (layer == Layer.SNIPPETS && ::snippets.isInitialized && snippets.isSearchActive) {
            snippets.exitSearchMode()
            return
        }
        if (currentInputConnection == null) return
        sendDownUpKeyEvents(KeyEvent.KEYCODE_ENTER)
    }

    /** Apaga el modo busqueda y restaura el fondo inactivo del campo. Shell SPK-05. */
    private fun exitSnippetSearchMode() {
        if (::snippets.isInitialized) snippets.exitSearchMode()
    }

    /** Enciende el modo busqueda bajo demanda (teclado de la propia capa). Shell SPK-05. */
    private fun ensureSnippetSearchMode() {
        if (::snippets.isInitialized) snippets.ensureSearchMode()
    }

    /**
     * Gate central de vibracion (K5-T3): un unico punto por donde pasa
     * todo el feedback hapico del teclado. Si el usuario lo apago en Ajustes,
     * retorna sin vibrar. Default ON cuando la clave no existe.
     */
    override fun haptic(view: View) {
        if (!kbPrefs.hapticsEnabled) return
        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
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
    override fun showHistoryPopup(anchor: View) {
        dismissPopup()
        if (!::history.isInitialized) return
        val repo = if (::transcriptionRepo.isInitialized) transcriptionRepo else null
        history.show(anchor, repo)
    }

    // --- HistoryLayer.UiHost (SPK-05 módulo 9). isSpanish, haptic,
    // commitText, rootView y dimenPx ya existen arriba y sirven a esta
    // interfaz (misma firma, una sola implementación).
    override fun isAlive(): Boolean = instance === this
    override fun takePopup(popup: PopupWindow?) {
        activePopup = popup
    }
    override fun currentPopup(): PopupWindow? = activePopup
    override fun dismissPopups() = dismissPopup()

    // ------------------------------------------------------------------
    // Capa snippets (K4: vive en SnippetsLayer; aquí solo filas QWERTY +
    // ganchos finos de commit/backspace/enter + shell de subcapa)
    // ------------------------------------------------------------------

    /**
     * Apertura/cierre de la capa de credenciales (contrato Claves). Al abrir
     * recuerda la capa de origen para volver; al cerrar o tras pegar vuelve
     * a ella. Sin busqueda ni cierre manual extra: la lista scrollea con el
     * dedo y cada fila pega directo. La password JAMAS se muestra ni se
     * registra en Log: solo nombre (+usuario si el usuario lo activo).
     */
    /** Shell SPK-05: la capa vive en CredentialsLayer; aquí solo el compacto. */
    private fun buildCredentialRows() {
        credentials.buildRows(root)
        // Teclado compacto debajo (letras) para no dejar la capa vacia.
        addRow(letterRow("qwertyuiop"))
    }

    // --- CredentialsLayer.UiHost (SPK-05 módulo 3): 9 delegaciones de una línea. ---
    override fun currentLayer(): Layer = layer
    override fun showLayer(next: Layer) {
        layer = next
        rebuild()
    }
    override fun tapFeedback() = haptic(root)
    override fun isSpanish(): Boolean = spanishMode
    override fun isPasswordField(): Boolean = currentIsPasswordField
    override fun isServiceAlive(): Boolean = instance === this
    override fun attachTap(view: View, onTap: () -> Unit) = attachFastKeyTouch(view, onTap)
    override fun scaledDimen(resId: Int): Int = scaleV(dimen(resId))
    override fun rowGap(): Int = rowGapPx()

    // --- DictationController.UiHost (SPK-05 módulo 5). isSpanish,
    // tapFeedback e isServiceAlive ya existen arriba y sirven a ambas
    // interfaces (misma firma, una sola implementación).
    override fun pressHaptic(view: View) = haptic(view)
    override fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit) =
        attachLongPress(key, onLongPress = onLongPress, onTapUp = onTapUp)
    override fun standardKeyHeightPx(): Int = keyHeightPx()
    override fun showNotice(message: String, openSettingsOnClick: Boolean) {
        if (::status.isInitialized) status.show(message, openSettingsOnClick)
    }
    // --- StatusLayer.UiHost (SPK-05 módulo 10). rootView y dimenPx ya
    // existen arriba y sirven a esta interfaz (misma firma, una sola
    // implementación).
    override fun currentInputView(): View? = inputView
    override fun setRecordingActive(active: Boolean) {
        keyboardRecordingActive = active
    }
    override fun isRecordingActive(): Boolean = keyboardRecordingActive

    private fun saveSnippetDraftState() {
        if (::snippets.isInitialized) snippets.saveDraftState()
    }

    /** Shell SPK-05: el contenido vive en SnippetsLayer; aquí solo las filas de subcapa. */
    private fun buildSnippetRows() {
        snippets.buildContent()
        when (snippets.subLayer) {
            Layer.SYMBOLS -> buildSymbolRows()
            Layer.CODE -> buildCodeRows()
            else -> addSnippetLetterRows()
        }
    }

    /**
     * Filas QWERTY dentro de la capa snippets: conservan la altura keyHeightPx()
     * configurada por el usuario sin achicarse artificialmente.
     */
    private fun addSnippetLetterRows() {
        addRow(snippetLetterRow("qwertyuiop"))
        addRow(snippetLetterRow(if (spanishMode) "asdfghjklñ" else "asdfghjkl;"))
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
                    if (::accents.isInitialized) accents.showPopup(key, base)
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


    /** Shell SPK-05: el portapapeles vive en ClipboardLayer; aquí solo commit(). */

    // ------------------------------------------------------------------
    // Gestos de teclas (los acentos/pares viven en AccentLayer)
    // ------------------------------------------------------------------

    /**
     * Cancela los gestos pendientes de las teclas vigentes: long-press y
     * repeticiones de attachLongPress más el long-press de la espaciadora.
     * Se invoca en rebuild() antes de removeAllViews() y en onDestroy().
     */
    private fun cancelPendingKeyGestures() {
        for (cancel in longPressCancellations) {
            try {
                cancel()
            } catch (_: Exception) {}
        }
        longPressCancellations.clear()
        try {
            spacebarLongPressRunnable?.let { spacebarGestureHandler?.removeCallbacks(it) }
        } catch (_: Exception) {}
        spacebarLongPressRunnable = null
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

        // Registrar el cancelador para que rebuild() lo invoque antes de
        // soltar las vistas (sin esto el long-press disparaba en zombi).
        longPressCancellations.add { cancelPending(); cancelRepeating() }

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

    /**
     * MEJ-25: Control de cursor y modo trackpad 2D en barra espaciadora.
     * - Deslizamiento horizontal (estilo Gboard): arrastre a izq/der desplaza el cursor.
     * - Pulsación larga (>300ms, estilo iOS): efecto blank-out atenuando glifos de teclas
     *   y transformando el teclado completo en una superficie continua de navegación 2D.
     * - Selección de texto: soporte multitáctil (segundo dedo) o tecla shift activa despacha
     *   eventos DPAD con META_SHIFT_ON para selección precisa.
     */
     private fun setTrackpadBlankOutMode(enabled: Boolean) {
        val targetAlpha = if (enabled) 0.0f else 1.0f
        fun fadeGlyphs(view: View) {
            if (view === spaceKeyView) return
            if (view is TextView || (view is ImageView && view !== spaceKeyView)) {
                view.animate().cancel()
                view.animate().alpha(targetAlpha).setDuration(120L).start()
            } else if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    fadeGlyphs(view.getChildAt(i))
                }
            }
        }
        inputView?.let { fadeGlyphs(it) }
    }

    private fun attachSpacebarGestures(space: View) {
        // El listener anterior muere con su vista en rebuild: cancelar su
        // long-press pendiente acá mismo además del barrido de rebuild().
        try {
            spacebarLongPressRunnable?.let { spacebarGestureHandler?.removeCallbacks(it) }
        } catch (_: Exception) {}
        val gestureHandler = Handler(Looper.getMainLooper())
        spacebarGestureHandler = gestureHandler
        space.setOnTouchListener(object : View.OnTouchListener {
            private var startX = 0f
            private var startY = 0f
            private var lastX = 0f
            private var lastY = 0f
            private var isLongPressTriggered = false
            private var isDragNavTriggered = false
            private var isSelecting = false
            private val longPressRunnable = Runnable {
                if (kbPrefs.spacebarTrackpadMode == "ios_2d") {
                    isLongPressTriggered = true
                    setTrackpadBlankOutMode(true)
                    haptic(space)
                }
            }

            init {
                // Publicar el runnable vigente para cancelarlo en
                // rebuild/onDestroy aunque su vista ya no exista.
                spacebarLongPressRunnable = longPressRunnable
            }

            private fun dispatchNavKey(keyCode: Int) {
                if (isSelecting || shiftState != ShiftState.OFF) {
                    sendKeyEventWithMeta(keyCode, KeyEvent.META_SHIFT_ON)
                } else {
                    sendKeyCode(keyCode)
                }
                haptic(space)
            }

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val density = resources.displayMetrics.density
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        v.parent?.requestDisallowInterceptTouchEvent(true)
                        startX = event.rawX
                        startY = event.rawY
                        lastX = event.rawX
                        lastY = event.rawY
                        isLongPressTriggered = false
                        isDragNavTriggered = false
                        isSelecting = false
                        v.isPressed = true
                        gestureHandler.postDelayed(longPressRunnable, 300L)
                        return true
                    }
                    MotionEvent.ACTION_POINTER_DOWN -> {
                        // Toque con un segundo dedo mientras se navega activa selección de texto estilo iOS
                        if (isLongPressTriggered || isDragNavTriggered) {
                            isSelecting = true
                            haptic(space)
                        }
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val threshold = 14f * density
                        if (isLongPressTriggered) {
                            val deltaX = event.rawX - lastX
                            val stepsX = (abs(deltaX) / threshold).toInt()
                            if (stepsX > 0) {
                                val key = if (deltaX > 0) KeyEvent.KEYCODE_DPAD_RIGHT else KeyEvent.KEYCODE_DPAD_LEFT
                                for (i in 0 until stepsX) {
                                    dispatchNavKey(key)
                                }
                                lastX += stepsX * threshold * (if (deltaX > 0) 1 else -1)
                            }

                            val deltaY = event.rawY - lastY
                            val stepsY = (abs(deltaY) / threshold).toInt()
                            if (stepsY > 0) {
                                val key = if (deltaY > 0) KeyEvent.KEYCODE_DPAD_DOWN else KeyEvent.KEYCODE_DPAD_UP
                                for (i in 0 until stepsY) {
                                    dispatchNavKey(key)
                                }
                                lastY += stepsY * threshold * (if (deltaY > 0) 1 else -1)
                            }
                        } else {
                            if (abs(event.rawX - startX) > (16f * density)) {
                                gestureHandler.removeCallbacks(longPressRunnable)
                                isDragNavTriggered = true
                            }
                            if (isDragNavTriggered) {
                                val deltaX = event.rawX - lastX
                                val stepsX = (abs(deltaX) / threshold).toInt()
                                if (stepsX > 0) {
                                    val key = if (deltaX > 0) KeyEvent.KEYCODE_DPAD_RIGHT else KeyEvent.KEYCODE_DPAD_LEFT
                                    for (i in 0 until stepsX) {
                                        dispatchNavKey(key)
                                    }
                                    lastX += stepsX * threshold * (if (deltaX > 0) 1 else -1)
                                }
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        gestureHandler.removeCallbacks(longPressRunnable)
                        v.isPressed = false
                        if (isLongPressTriggered) {
                            setTrackpadBlankOutMode(false)
                            haptic(space)
                        } else if (!isDragNavTriggered) {
                            if (layer == Layer.SNIPPETS && !snippets.isEditorOpen) snippets.ensureSearchMode()
                            commit(" ")
                        }
                        isSelecting = false
                        return true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        gestureHandler.removeCallbacks(longPressRunnable)
                        v.isPressed = false
                        if (isLongPressTriggered) {
                            setTrackpadBlankOutMode(false)
                        }
                        isSelecting = false
                        return true
                    }
                }
                return false
            }
        })
    }

    override fun dismissPopup() {
        activePopup?.let { popup ->
            if (popup.isShowing) {
                popup.dismiss()
            }
        }
        activePopup = null
    }


    /** Altura de tecla estandar escalada por el perfil activo. */
    override fun keyHeightPx(): Int = scaleV(dimen(R.dimen.kb_key_height))

    /** Margen vertical entre filas, escalado ergonómico estilo Gboard. */
    override fun rowGapPx(): Int = scaleV(dimen(R.dimen.kb_key_gap_v))

    /**
     * Escala una dimension vertical propia del contenido del teclado con el
     * factor del perfil. NUNCA aplicar sobre insets ni paddings derivados de
     * WindowInsets (leccion 9.1-20).
     */
    private fun scaleV(px: Int): Int = (px * kbPrefs.heightFactor).toInt()

    companion object {
        /** Exclusion mutua de microfono: visible para MainActivity/burbuja. */
        @Volatile
        var keyboardRecordingActive: Boolean = false

        /** Singleton accesible para inyeccion directa en cursor desde overlays. */
        @Volatile
        var instance: VoiceKeyboardService? = null
            private set

        fun commitFromExternal(text: String): Boolean {
            return try {
                // Snapshot local: instance puede nularse en otro hilo
                // (onDestroy) entre el chequeo y el uso.
                val service = instance ?: return false
                val ic = service.currentInputConnection ?: return false
                ic.commitText(text, 1)
            } catch (_: DeadObjectException) {
                // El editor murió a mitad del commit (proceso destino caído).
                false
            } catch (_: RemoteException) {
                // Binder roto con el InputMethodManager.
                false
            } catch (_: IllegalStateException) {
                // Conexión de entrada ya inactiva.
                false
            } catch (_: Exception) {
                // Red de seguridad: un SecurityException/NPE inesperado del
                // binder jamás debe tumbar el IME; se informa false.
                false
            }
        }
    }
}
