package com.royleguiza.voicebubblestt

import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Build
import android.os.DeadObjectException
import android.os.Handler
import android.os.Looper
import android.os.RemoteException
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView

/**
 * Teclado del sistema VoiceBubble.
 * K1: QWERTY es/en + capa simbolos basicos + acentos por toque largo.
 * K2: capa codigo con pares auto-cerrados + fila terminal permanente
 *     (TAB/ESC/CTRL/ALT/flechas) con modificadores sticky para Termux.
 * K4: capa snippets (chips + busqueda) que inserta el contenido en el cursor.
 * MEJ-09: capa trackpad nativa Split Wings con cursor de mouse virtual.
 * Este teclado JAMAS registra, guarda ni transmite texto tecleado.
 */
class VoiceKeyboardService : InputMethodService(), CredentialsLayer.UiHost, DictationController.UiHost, TrackpadBridge.UiHost, ClipboardLayer.UiHost, SnippetsLayer.UiHost, HistoryLayer.UiHost, StatusLayer.UiHost, AccentLayer.UiHost, ToolbarLayer.UiHost, KeyFactory.UiHost, LayoutLayer.UiHost, SpacebarLayer.UiHost, EditEngine.UiHost {

    private var layer = Layer.LETTERS
    private var lastLettersLayer = Layer.LETTERS
    // @Volatile: el cliente STT lo consulta desde su hilo de fondo para
    // localizar los avisos de error (K5-T4).
    @Volatile
    private var spanishMode = true

    // --- Dictado (K3 + M4 Morph-to-Pill; máquina en DictationController) ---
    private lateinit var dictation: DictationController
    private var currentIsPasswordField = false
    private var spaceKeyView: View? = null
    private var commaKeyView: View? = null
    private var dotKeyView: View? = null

    // --- Espaciadora MEJ-25 (SPK-05 módulo 17: vive en SpacebarLayer) ---
    private lateinit var spacebar: SpacebarLayer

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
    // --- Fábrica de teclas (SPK-05 módulo 14: vive en KeyFactory) ---
    private lateinit var keys: KeyFactory
    // --- Filas y barra inferior (SPK-05 módulo 16: vive en LayoutLayer) ---
    private lateinit var layout: LayoutLayer
    // --- Motor de edición (SPK-05 módulo 18: vive en EditEngine) ---
    private lateinit var editor: EditEngine

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
        keys = KeyFactory(this, handler, this)
        layout = LayoutLayer(keys, this)
        spacebar = SpacebarLayer(this, this)
        editor = EditEngine(this, { if (::snippets.isInitialized) snippets else null }, this)
        root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.setBackgroundResource(R.drawable.kb_surface_bg)
        layout.applyBottomInsets()
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
            if (::editor.isInitialized) editor.resetForNewField()
        }
        // Sincronizar clips copiados mientras el teclado estaba cerrado.
        if (::clipboard.isInitialized) clipboard.onStartInputView(restarting)
        rebuild()
        root.requestApplyInsets()
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
        if (::editor.isInitialized) editor.clearKeyRegistry()
        if (::toolbar.isInitialized) toolbar.clearModifiers()
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
                Layer.LETTERS -> layout.buildLetterRows()
                Layer.SYMBOLS -> layout.buildSymbolRows()
                Layer.CODE -> layout.buildCodeRows()
                Layer.SNIPPETS -> buildSnippetRows()
                Layer.CREDENTIALS -> buildCredentialRows()
                Layer.TRACKPAD -> {}
            }
            addRow(layout.buildBottomBar())
            spaceKeyView = layout.spaceView
            commaKeyView = layout.commaView
            dotKeyView = layout.dotView
        }

        // Sincronizar estados visuales persistentes tras reconstruir la vista.
        if (::editor.isInitialized) editor.applyCase()
        refreshModifiers()
        if (::dictation.isInitialized) dictation.refreshMicVisual()
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
    ): TextView = keys.makeSpecialKey(label, bgRes, weight, description, textSizePx, isBold, onClick)
    override fun rebuildKeyboard() = rebuild()
    override fun snippetsToggle() = snippets.toggle()
    override fun credentialsToggle() = credentials.toggle()
    override fun clipboardToggle() = clipboard.toggle()
    override fun clipboardPasteLatest() = clipboard.pasteLatestOrToggle()
    override fun trackpadToggle() = trackpad.toggle()
    /** Cambiador de capas con memoria de la ultima capa no-codigo. */
    override fun codeToggle() {
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
    override fun sendCode(code: Int) = editor.sendKeyCode(code)
    override fun micKeyView(): View = dictation.makeMicKey()
    override fun micClearViews() = dictation.clearViews()
    override fun isTerminalRowPref(): Boolean = kbPrefs.terminalRowVisiblePref
    override fun toggleTerminalRowPref() { kbPrefs.terminalRowVisiblePref = !kbPrefs.terminalRowVisiblePref }
    override fun isCodeKeyPref(): Boolean = kbPrefs.codeKeyVisiblePref
    override fun isTrackpadToolbarAllowed(): Boolean = kbPrefs.trackpadEnabled && kbPrefs.trackpadToolbarVisible
    override fun isToolbarInverted(): Boolean = kbPrefs.invertToolbar
    override fun registerModifier(key: TextView, isCtrl: Boolean) = toolbar.registerModifier(key, isCtrl)
    override fun isModifierActive(isCtrl: Boolean): Boolean = editor.isModifierActive(isCtrl)
    override fun toggleModifier(isCtrl: Boolean) = editor.toggleModifier(isCtrl)
    override fun refreshModifiers() = toolbar.refreshModifiers()

    /** Shell SPK-05: la altura vive en TrackpadBridge; aquí solo el delegado para addRow. */
    private fun getTargetTrackpadHeightPx(): Int =
        if (::trackpad.isInitialized) trackpad.targetHeightPx() else {
            val totalKeyRows = if (kbPrefs.terminalRowVisiblePref) 5 else 4
            totalKeyRows * keyHeightPx() + (totalKeyRows - 1) * rowGapPx()
        }

    // --- TrackpadBridge.UiHost (módulo 6) + ClipboardLayer.UiHost (módulo 7):
    // currentLayer/isPasswordField/isSpanish/rootView/haptic ya existen
    // arriba y sirven a las cuatro interfaces (misma firma, una sola impl).
    override fun commitText(text: String) = editor.commit(text)

    // --- SnippetsLayer.UiHost (SPK-05 módulo 8). commitText no sirve aquí:
    // insertar un snippet debe saltear el ruteo al query (bucle), por eso
    // la capa comitea directo vía el InputConnection del servicio.
    // Punto único del espaciado anti-fantasma: solo los 3 gaps escalan
    // con el perfil (el resto pasa intacto; las alturas las dueña el
    // perfil de altura vía scaleV, jamás este factor).
    override fun dimenPx(resId: Int): Int {
        val base = dimen(resId)
        if (resId != R.dimen.kb_key_gap && resId != R.dimen.kb_key_gap_h && resId != R.dimen.kb_key_gap_v) {
            return base
        }
        return (base * kbPrefs.keySpacingFactor).toInt()
    }
    override fun addContentRow(view: View) = addRow(view)
    override fun showCenteredBox(box: LinearLayout, widthPx: Int) {
        if (::snippets.isInitialized) snippets.showCenteredBox(box, widthPx)
    }
    override fun showAnchoredBox(box: LinearLayout, anchor: View) {
        if (::snippets.isInitialized) snippets.showAnchoredBox(box, anchor)
    }
    override fun setLayer(next: Layer) { layer = next }
    override fun consumeModifiers() = editor.consumeModifiers()
    override fun lastLetters(): Layer = lastLettersLayer
    override fun setLastLetters(l: Layer) { lastLettersLayer = l }
    override fun rootView(): LinearLayout = root
    override fun beginTransition() = trackpad.playTransition()

    // --- KeyFactory.UiHost (SPK-05 módulo 14). isSpanish, dimenPx,
    // keyHeightPx, displayLetter, haptic, attachTap, attachPress,
    // attachBackspaceKey, commitLetterKey, commitText, sendCode,
    // deleteBackward, trackLetterKey, trackShiftKey y toggleShiftKey ya
    // existen arriba y sirven a esta interfaz (misma firma, una sola
    // implementación).
    override fun commitSymbolKey(text: String) = editor.commitSymbolText(text)
    override fun attachAccentKey(key: TextView, base: Char, onTapUp: () -> Unit) = accents.attachAccent(key, base, onTapUp)
    override fun attachPairKey(
        key: TextView,
        ch: Char,
        onCommit: (String) -> Unit,
        onAutoPair: (Char, Char) -> Unit,
    ) {
        accents.attachPair(key, ch, onCommit, onAutoPair)
    }

    override fun horizontalRow(): LinearLayout = keys.horizontalRow()

    override fun makeIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int,
        onClick: () -> Unit,
    ): ImageView = keys.makeIconKey(iconRes, bgRes, weight, description, tintColorRes, onClick)

    private fun addRow(row: View) = layout.addRow(row)

    /**
     * Gate central de vibracion (K5-T3): un unico punto por donde pasa
     * todo el feedback hapico del teclado. Si el usuario lo apago en Ajustes,
     * retorna sin vibrar. Default ON cuando la clave no existe.
     */
    override fun haptic(view: View) {
        if (!kbPrefs.hapticsEnabled) return
        when (kbPrefs.hapticStyle) {
            HAPTIC_STYLE_SUAVE -> vibrateOnce(15L, 90)
            HAPTIC_STYLE_FIRME -> vibrateOnce(30L, 220)
            else -> crispTap()
        }
    }

    /**
     * Clic seco anti-"rrrr": primitivas de hardware en API 30+ (CLICK
     * calibrado) y one-shot corto a tope en el resto. Todo best-effort:
     * jamás lanza (el teclado no puede morir por vibrar).
     */
    private fun crispTap() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val vib = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vib != null && vib.hasVibrator() &&
                    Vibrator.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_CLICK)
                ) {
                    vib.vibrate(
                        VibrationEffect.startComposition()
                            .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1.0f)
                            .compose()
                    )
                    return
                }
            } catch (_: Exception) {}
        }
        vibrateOnce(15L, 255)
    }

    private fun vibrateOnce(ms: Long, amplitude: Int) {
        try {
            val vib = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (vib == null || !vib.hasVibrator()) return
            vib.vibrate(VibrationEffect.createOneShot(ms, amplitude))
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
    override fun takePopup(popup: PopupWindow?) { activePopup = popup }
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
        addRow(keys.letterRow("qwertyuiop"))
    }

    // --- LayoutLayer.UiHost (SPK-05 módulo 16). isSpanish, dimenPx,
    // rowGap, rootView, toggleShiftKey, trackShiftKey, codeToggle y
    // addContentRow ya existen arriba y sirven a esta interfaz (misma
    // firma, una sola implementación).
    override fun trackpadHeightPx(): Int = getTargetTrackpadHeightPx()
    override fun pressSymbolsKey() {
        if (layer == Layer.SNIPPETS) {
            snippets.cycleSubLayerForSymbols()
        } else {
            layer = if (layer == Layer.SYMBOLS) Layer.LETTERS else Layer.SYMBOLS
            rebuild()
        }
    }
    override fun toggleLanguage() {
        spanishMode = !spanishMode
        rebuild()
    }
    override fun pressSpace() {
        // En snippets el espacio alimenta el query solo si no esta abierto el editor.
        if (layer == Layer.SNIPPETS && !snippets.isEditorOpen) snippets.ensureSearchMode()
        editor.commit(" ")
    }
    override fun pressEnter() = editor.handleEnter()
    override fun attachSpacebar(view: View) = spacebar.attachSpacebarGestures(view)
    // --- SpacebarLayer.UiHost (SPK-05 módulo 17). haptic, pressSpace,
    // currentInputView y sendCode ya existen arriba y sirven a esta
    // interfaz (misma firma, una sola implementación).
    override fun isShiftActive(): Boolean = editor.isShiftOn()
    override fun sendCodeWithMeta(code: Int, meta: Int) = editor.sendKeyEventWithMeta(code, meta)
    override fun spacebarTrackpadMode(): String = kbPrefs.spacebarTrackpadMode
    override fun symbolsLabel(): String = when {
        layer == Layer.SNIPPETS && (snippets.subLayer == Layer.SYMBOLS || snippets.subLayer == Layer.CODE) -> "ABC"
        layer == Layer.SYMBOLS || layer == Layer.CODE || layer == Layer.CREDENTIALS -> "ABC"
        else -> "?123"
    }
    override fun isLanguageKeyVisible(): Boolean = kbPrefs.languageKeyVisiblePref
    override fun spacebarAlignment(): String = kbPrefs.spacebarAlignment
    override fun bottomElevationDp(): Int = kbPrefs.bottomElevationDp

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
    override fun attachTap(view: View, onTap: () -> Unit) = keys.fastTap(view, onTap)
    override fun scaledDimen(resId: Int): Int = scaleV(dimen(resId))
    override fun rowGap(): Int = rowGapPx()

    // --- DictationController.UiHost (SPK-05 módulo 5). isSpanish,
    // tapFeedback e isServiceAlive ya existen arriba y sirven a ambas
    // interfaces (misma firma, una sola implementación).
    override fun pressHaptic(view: View) = haptic(view)
    override fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit) =
        keys.longPress(key, onLongPress = onLongPress, onTapUp = onTapUp)
    override fun standardKeyHeightPx(): Int = keyHeightPx()
    override fun showNotice(message: String, openSettingsOnClick: Boolean) {
        if (::status.isInitialized) status.show(message, openSettingsOnClick)
    }
    // --- StatusLayer.UiHost (SPK-05 módulo 10). rootView y dimenPx ya
    // existen arriba y sirven a esta interfaz (misma firma, una sola
    // implementación).
    override fun currentInputView(): View? = inputView
    override fun setRecordingActive(active: Boolean) { keyboardRecordingActive = active }
    override fun isRecordingActive(): Boolean = keyboardRecordingActive

    /** Shell SPK-05: el contenido vive en SnippetsLayer (módulo 13: hasta
     *  las filas QWERTY); aquí solo el despacho de subcapa. */
    private fun buildSnippetRows() {
        snippets.buildContent()
        when (snippets.subLayer) {
            Layer.SYMBOLS -> layout.buildSymbolRows()
            Layer.CODE -> layout.buildCodeRows()
            else -> snippets.buildLetterRows()
        }
    }

    // --- SnippetsLayer.UiHost: filas QWERTY (SPK-05 módulo 13). makeIconKey,
    // horizontalRow, addContentRow, dimenPx, isSpanish, haptic, attachPress y
    // attachTap ya existen arriba y sirven a esta interfaz (misma firma).
    override fun makeTextKey(
        label: String,
        weight: Float,
        bgRes: Int,
        colorRes: Int,
        textSizePx: Int,
    ): TextView = keys.makeKey(label, weight, bgRes, colorRes, textSizePx)
    override fun displayLetter(base: Char): String = editor.displayFor(base)
    override fun commitLetterKey(base: Char) = editor.commitLetter(base)
    override fun trackLetterKey(key: TextView, base: Char) = editor.trackLetter(key, base)
    override fun trackShiftKey(key: ImageView) = editor.trackShift(key)
    override fun toggleShiftKey() = editor.toggleShift()
    override fun showAccentsPopup(anchor: View, base: Char) {
        if (::accents.isInitialized) accents.showPopup(anchor, base)
    }
    override fun deleteBackward() = editor.handleBackspace()
    override fun deleteWord() = editor.deleteWordBeforeCursor()
    override fun attachBackspaceKey(key: View, action: () -> Unit) = keys.backspaceGestures(key, action)

    /** Shell SPK-05: el portapapeles vive en ClipboardLayer; aquí solo commit(). */

    // ------------------------------------------------------------------
    // Gestos de teclas (los acentos/pares viven en AccentLayer)
    // ------------------------------------------------------------------

    /**
     * Cancela los gestos pendientes de las teclas vigentes: long-press y
     * repeticiones de KeyFactory más el long-press de la espaciadora.
     * Se invoca en rebuild() antes de removeAllViews() y en onDestroy().
     */
    private fun cancelPendingKeyGestures() {
        if (::keys.isInitialized) keys.cancelPendingGestures()
        if (::spacebar.isInitialized) spacebar.cancelPending()
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
