package com.royleguiza.voicebubblestt

import android.inputmethodservice.InputMethodService
import android.os.DeadObjectException
import android.os.RemoteException
import android.os.SystemClock
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.ExtractedTextRequest
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

internal fun commitOrWarn(
    service: InputMethodService,
    text: CharSequence,
    isSpanish: Boolean = true,
    onWarn: (() -> Unit)? = null,
): Boolean {
    val ic = service.currentInputConnection ?: run {
        if (onWarn != null) onWarn() else warnDeadConnection(service, isSpanish)
        return false
    }
    val ok = try {
        ic.commitText(text, 1)
    } catch (_: DeadObjectException) {
        false
    } catch (_: RemoteException) {
        false
    } catch (_: IllegalStateException) {
        false
    } catch (_: Exception) {
        false
    }
    if (!ok) {
        if (onWarn != null) onWarn() else warnDeadConnection(service, isSpanish)
        return false
    }
    return true
}

internal fun warnDeadConnection(service: InputMethodService, isSpanish: Boolean = true) {
    val msg = if (isSpanish) StatusLayer.NOTICE_DEAD_CONNECTION_ES else StatusLayer.NOTICE_DEAD_CONNECTION_EN
    val status = StatusLayer.activeInstance
    if (status != null) {
        status.show(msg)
    } else {
        try {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                service.showClipboardNotice(msg)
            }
        } catch (_: Exception) {
        }
    }
}

/**
 * Motor de edición (SPK-05, módulo 18 de N): máquina shift/caps,
 * commits al editor (letras, símbolos, pares), modificadores CTRL/ALT,
 * borrado (simple, palabra, selección, surrogate) y enter, extraído de
 * VoiceKeyboardService sin cambiar conducta. El estado de edición
 * (shift, modificadores, registro de teclas) es suyo; la capa snippets
 * entra por [snippets] (nula antes del primer input view) y lo demás por
 * [service] y [host]. PRIVACIDAD: jamás registra texto (ni en debug).
 */
class EditEngine(
    private val service: InputMethodService,
    private val snippets: () -> SnippetsLayer?,
    private val host: UiHost,
) {

    /** Lo mínimo que el motor exige al teclado. */
    interface UiHost {
        fun haptic(view: View)
        fun rootView(): LinearLayout
        fun currentLayer(): Layer
        fun isSpanish(): Boolean
        fun refreshModifiers()
        fun isPasswordField(): Boolean
        fun cycleNotice(message: String)
    }

    private var shiftState = ShiftState.OFF

    /** Uptime del ultimo tap en shift; detecta el doble pulso (caps lock). */
    private var lastShiftTapUptime = 0L
    private var ctrlActive = false
    private var altActive = false

    private val letterKeys = mutableListOf<Pair<TextView, Char>>()
    private val shiftKeyViews = mutableListOf<ImageView>()

    fun isShiftOn(): Boolean = shiftState != ShiftState.OFF

    fun isModifierActive(isCtrl: Boolean): Boolean = if (isCtrl) ctrlActive else altActive

    fun toggleModifier(isCtrl: Boolean) {
        if (isCtrl) ctrlActive = !ctrlActive else altActive = !altActive
    }

    fun trackLetter(key: TextView, base: Char) {
        letterKeys.add(Pair(key, base))
    }

    fun trackShift(key: ImageView) {
        shiftKeyViews.add(key)
    }

    fun clearKeyRegistry() {
        letterKeys.clear()
        shiftKeyViews.clear()
    }

    /** Reset de campo nuevo: shift apagado y modificadores sueltos. */
    fun resetForNewField() {
        deactivateShift()
        ctrlActive = false
        altActive = false
    }

    fun displayFor(base: Char): String =
        if (shiftState == ShiftState.OFF) base.toString() else base.uppercaseChar().toString()

    /**
     * Maquina de estados shift (P3): OFF -> MOMENTARY con un tap; doble pulso
     * rapido (<= 300 ms entre taps) escala a CAPS_LOCK desde OFF o MOMENTARY.
     * En CAPS_LOCK un solo tap vuelve directo a OFF. El emparejamiento es por
     * intervalo entre taps consecutivos (patron estandar de teclados), y el
     * timestamp se invalida al apagarse shift por via no-tactil para que un
     * tap posterior nunca herede un par fantasma.
     */
    fun toggleShift() {
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

    /** Estado de caso aplicado por el ciclo de ⇧ (MEJ-02, orden pedido por el dueño). */
    internal enum class CaseState { LOWER, TITLE, UPPER }

    /**
     * Title case por palabra (pedido explícito del dueño, override de D-M1
     * sentence case): primera letra de CADA palabra en mayúscula, resto en
     * minúsculas. Frontera de palabra = cualquier carácter sin caso
     * (espacios, guiones, `_`, dígitos, símbolos): `mi_funcion` →
     * `Mi_Funcion`, `hola mundo` → `Hola Mundo`. Acentos ES mapean 1:1.
     */
    internal fun toTitleCase(text: String): String {
        val lower = text.lowercase()
        val sb = StringBuilder(lower.length)
        var wordStart = true
        for (c in lower) {
            if (c.isLetter()) {
                sb.append(if (wordStart) c.uppercaseChar() else c)
                wordStart = false
            } else {
                sb.append(c)
                wordStart = true
            }
        }
        return sb.toString()
    }

    internal fun hasCasedLetter(text: String): Boolean = text.any { it.lowercaseChar() != it.uppercaseChar() }

    internal fun isTitleCase(text: String): Boolean =
        hasCasedLetter(text) && text == toTitleCase(text)

    /**
     * Siguiente estado del ciclo minúsculas → Title → MAYÚSCULAS → minúsculas.
     * Sin estado entre toques (D-M6): la decisión sale solo del contenido
     * actual de la selección, así que una selección perdida/colapsada por el
     * editor degrada honesto a shift normal en vez de ciclar fantasma.
     */
    internal fun nextCase(text: String): Pair<String, CaseState> {
        if (text == text.lowercase()) return Pair(toTitleCase(text), CaseState.TITLE)
        if (isTitleCase(text)) return Pair(text.uppercase(), CaseState.UPPER)
        if (text == text.uppercase()) return Pair(text.lowercase(), CaseState.LOWER)
        return Pair(text.lowercase(), CaseState.LOWER)
    }

    fun commitOrWarn(text: CharSequence): Boolean {
        return com.royleguiza.voicebubblestt.commitOrWarn(service, text, host.isSpanish()) {
            warnDeadConnection()
        }
    }

    private fun warnDeadConnection() {
        host.cycleNotice(if (host.isSpanish()) StatusLayer.NOTICE_DEAD_CONNECTION_ES else StatusLayer.NOTICE_DEAD_CONNECTION_EN)
    }

    /**
     * Ciclo de caso con ⇧ sobre la selección (MEJ-02, D-M1…D-M7).
     * Devuelve true si consumió el tap (no llamar a toggleShift).
     * Lectura puntual bajo demanda, en memoria, sin persistir ni loguear.
     */
    fun handleShiftTap(): Boolean {
        if (ctrlActive || altActive) return false
        if (host.isPasswordField()) return false
        if (host.currentLayer() == Layer.SNIPPETS && snippets()?.isSearchActive == true) return false
        val ic = service.currentInputConnection ?: return false
        val selected = try {
            ic.getSelectedText(0)?.toString()
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            null
        } catch (_: RemoteException) {
            warnDeadConnection()
            null
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            null
        } catch (_: Exception) {
            null
        }
        if (selected.isNullOrEmpty()) return false
        if (!hasCasedLetter(selected)) return false
        val (transformed, state) = nextCase(selected)
        if (transformed == selected) return false
        val req = ExtractedTextRequest()
        req.hintMaxChars = 0
        val sel = try {
            ic.getExtractedText(req, 0)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            null
        } catch (_: RemoteException) {
            warnDeadConnection()
            null
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            null
        } catch (_: Exception) {
            null
        }
        val start = sel?.selectionStart ?: -1
        val end = sel?.selectionEnd ?: -1
        var batchStarted = false
        val committed = try {
            batchStarted = ic.beginBatchEdit()
            val ok = ic.commitText(transformed, 1)
            if (ok && transformed.length == selected.length && start >= 0 && end >= 0 && end > start) {
                ic.setSelection(start, start + transformed.length)
            }
            ok
        } catch (_: DeadObjectException) {
            false
        } catch (_: RemoteException) {
            false
        } catch (_: IllegalStateException) {
            false
        } catch (_: Exception) {
            false
        } finally {
            if (batchStarted) {
                try {
                    ic.endBatchEdit()
                } catch (_: DeadObjectException) {
                } catch (_: RemoteException) {
                } catch (_: IllegalStateException) {
                } catch (_: Exception) {
                }
            }
        }
        if (!committed) {
            warnDeadConnection()
            return false
        }
        val es = host.isSpanish()
        host.cycleNotice(
            when (state) {
                CaseState.LOWER -> if (es) "Minúsculas" else "Lowercase"
                CaseState.TITLE -> if (es) "Mayúsculas iniciales" else "Title Case"
                CaseState.UPPER -> if (es) "MAYÚSCULAS" else "UPPERCASE"
            },
        )
        return true
    }

    fun applyCase() {
        for ((key, base) in letterKeys) {
            key.text = displayFor(base)
        }
        for (key in shiftKeyViews) {
            when (shiftState) {
                ShiftState.CAPS_LOCK -> {
                    key.setImageResource(R.drawable.ic_shift_caps)
                    key.contentDescription = if (host.isSpanish()) "bloqueo mayúsculas" else "caps lock"
                    key.setBackgroundResource(R.drawable.kb_key_accent)
                    key.setColorFilter(ContextCompat.getColor(service, R.color.kb_label_on_accent))
                }
                ShiftState.MOMENTARY -> {
                    key.setImageResource(R.drawable.ic_shift_on)
                    key.contentDescription = if (host.isSpanish()) "mayúsculas" else "shift"
                    key.setBackgroundResource(R.drawable.kb_key_accent)
                    key.setColorFilter(ContextCompat.getColor(service, R.color.kb_label_on_accent))
                }
                ShiftState.OFF -> {
                    key.setImageResource(R.drawable.ic_shift_off)
                    key.contentDescription = if (host.isSpanish()) "mayúsculas" else "shift"
                    key.setBackgroundResource(R.drawable.kb_key_alt)
                    key.setColorFilter(ContextCompat.getColor(service, R.color.kb_label))
                }
            }
        }
    }

    private fun insertTextToActiveEditor(text: String): Boolean =
        snippets()?.insertToEditor(text) == true

    private fun backspaceActiveEditor(count: Int = 1): Boolean =
        snippets()?.backspaceEditor(count) == true

    fun commitLetter(base: Char) {
        // C-17: Una sola vibración por tecla gestionada en la capa de gestos (KeyFactory en ACTION_DOWN).
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
        if (commitOrWarn(displayFor(base))) {
            releaseMomentaryShift()
        }
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

    fun commitSymbolText(text: String) {
        // C-17: Una sola vibración por tecla gestionada en la capa de gestos (KeyFactory en ACTION_DOWN).
        if (insertTextToActiveEditor(text)) return
        // Simbolos de la barra inferior (, .) en snippets: al query siempre.
        if (host.currentLayer() == Layer.SNIPPETS) snippets()?.ensureSearchMode()
        if (routeToSnippetQuery(text)) return
        if ((ctrlActive || altActive) && text.length == 1) {
            val c = text[0]
            if (keyCodeFor(c) != null) {
                sendModifiedChar(c)
                return
            }
        }
        if (commitOrWarn(text)) {
            consumeModifiers()
        }
    }

    fun commit(text: String): Boolean {
        if (insertTextToActiveEditor(text)) return true
        if (routeToSnippetQuery(text)) return true
        return commitOrWarn(text)
    }

    /**
     * Modo busqueda activo en la capa snippets: captura los commits del
     * propio teclado y los puebla en el query para filtrar, sin escribir
     * nunca en la app destino (patron estilo Gboard). Devuelve true si el
     * texto fue consumido por el modo busqueda.
     */
    private fun routeToSnippetQuery(text: String): Boolean =
        snippets()?.routeToQuery(text) == true

    /** Envio del caracter con META_CTRL/META_ALT via KeyEvent (patron Hacker's
     *  Keyboard). Sin codigo fisico (ej. ñ) la combinacion es imposible:
     *  AT-A15 comite el caracter tal cual para no comerse la pulsacion. */
    private fun sendModifiedChar(c: Char) {
        val code = keyCodeFor(c)
        if (code == null) {
            if (commitOrWarn(c.toString())) {
                consumeModifiers()
            }
            return
        }
        var meta = 0
        if (ctrlActive) meta = meta or KeyEvent.META_CTRL_ON
        if (altActive) meta = meta or KeyEvent.META_ALT_ON
        sendKeyEventWithMeta(code, meta)
        consumeModifiers()
    }

    fun sendKeyEventWithMeta(keyCode: Int, meta: Int) {
        if (isCursorKey(keyCode)) {
            val extend = (meta and KeyEvent.META_SHIFT_ON) != 0
            val s = snippets()
            if (s?.moveCursorInEditor(keyCode, extend) == true) return
            if (s?.moveCursorInQuery(keyCode, extend) == true) return
        }
        val ic = service.currentInputConnection ?: run {
            warnDeadConnection()
            return
        }
        val now = SystemClock.uptimeMillis()
        try {
            ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0, meta))
            ic.sendKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0, meta))
        } catch (_: DeadObjectException) {
            warnDeadConnection()
        } catch (_: RemoteException) {
            warnDeadConnection()
        } catch (_: IllegalStateException) {
            warnDeadConnection()
        } catch (_: Exception) {
            warnDeadConnection()
        }
    }

    fun sendKeyCode(keyCode: Int) {
        // C-17: Una sola vibración por tecla gestionada en la capa de gestos.
        if (isCursorKey(keyCode)) {
            val s = snippets()
            if (s?.moveCursorInEditor(keyCode, false) == true) return
            if (s?.moveCursorInQuery(keyCode, false) == true) return
        }
        if (service.currentInputConnection == null) {
            warnDeadConnection()
            return
        }
        try {
            service.sendDownUpKeyEvents(keyCode)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
        } catch (_: RemoteException) {
            warnDeadConnection()
        } catch (_: IllegalStateException) {
            warnDeadConnection()
        } catch (_: Exception) {
            warnDeadConnection()
        }
    }

    private fun isCursorKey(keyCode: Int): Boolean =
        keyCode == KeyEvent.KEYCODE_DPAD_LEFT ||
            keyCode == KeyEvent.KEYCODE_DPAD_RIGHT ||
            keyCode == KeyEvent.KEYCODE_DPAD_UP ||
            keyCode == KeyEvent.KEYCODE_DPAD_DOWN

    fun consumeModifiers() {
        ctrlActive = false
        altActive = false
        host.refreshModifiers()
    }

    fun handleBackspace() {
        handleBackspace(1)
    }

    fun handleBackspace(count: Int = 1) {
        val safeCount = count.coerceAtLeast(1)
        // C-17: Una sola vibración por tecla gestionada en la capa de gestos (KeyFactory: longPress/backspaceGestures).
        if (backspaceActiveEditor(safeCount)) return
        if (snippets()?.backspaceQuery(safeCount) == true) return
        val ic = service.currentInputConnection ?: run {
            warnDeadConnection()
            return
        }
        val selected = try {
            ic.getSelectedText(0)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            null
        } catch (_: RemoteException) {
            warnDeadConnection()
            null
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            null
        } catch (_: Exception) {
            null
        }
        if (!selected.isNullOrEmpty()) {
            commitOrWarn("")
            return
        }
        // AT-A5: mismo criterio sobre el documento via InputConnection.
        // C-18: ventana de lookback para los caracteres solicitados considerando pares sustitutos
        val lookback = (safeCount * 2).coerceAtLeast(2)
        val before = try {
            ic.getTextBeforeCursor(lookback, 0)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            null
        } catch (_: RemoteException) {
            warnDeadConnection()
            null
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            null
        } catch (_: Exception) {
            null
        }

        var toDeleteUnits = 0
        if (!before.isNullOrEmpty()) {
            var charsFound = 0
            var i = before.length - 1
            while (i >= 0 && charsFound < safeCount) {
                if (i > 0 && Character.isSurrogatePair(before[i - 1], before[i])) {
                    toDeleteUnits += 2
                    i -= 2
                } else {
                    toDeleteUnits += 1
                    i -= 1
                }
                charsFound++
            }
        }
        val count = if (toDeleteUnits > 0) toDeleteUnits else safeCount

        val deleted = try {
            ic.deleteSurroundingText(count, 0)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            false
        } catch (_: RemoteException) {
            warnDeadConnection()
            false
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            false
        } catch (_: Exception) {
            false
        }
        if (!deleted) {
            for (k in 0 until safeCount) {
                try {
                    service.sendDownUpKeyEvents(KeyEvent.KEYCODE_DEL)
                } catch (_: DeadObjectException) {
                    warnDeadConnection()
                    break
                } catch (_: RemoteException) {
                    warnDeadConnection()
                    break
                } catch (_: IllegalStateException) {
                    warnDeadConnection()
                    break
                } catch (_: Exception) {
                    warnDeadConnection()
                    break
                }
            }
        }
    }

    /**
     * Borrado por palabra para el gesto deslizante de ⌫ (P6). Con el editor
     * de snippets abierto opera sobre el campo activo (nunca toca el query
     * ni el documento); en la capa snippets sin editor opera sobre el query
     * (nunca toca el documento); en el resto usa deleteSurroundingText con
     * el limite de palabra calculado sobre una ventana previa. Si el cursor
     * esta pegado a separadores, consume primero ese tramo; palabras mas
     * largas que la ventana se recortan parciales (limite v1.1: no borra
     * frases completas de golpe).
     */
    fun deleteWordBeforeCursor() {
        fun wordStart(text: CharSequence, from: Int): Int {
            var start = from
            if (start == 0) return start
            val eatingWord = text[start - 1].isLetterOrDigit()
            while (start > 0 && text[start - 1].isLetterOrDigit() == eatingWord) start--
            return start
        }
        if (snippets()?.isEditorOpen == true) {
            snippets()?.deleteWordInEditor()
            return
        }
        if (host.currentLayer() == Layer.SNIPPETS) {
            snippets()?.deleteQueryWord()
            return
        }
        val ic = service.currentInputConnection ?: run {
            warnDeadConnection()
            return
        }
        val before = try {
            ic.getTextBeforeCursor(SWIPE_WORD_LOOKBACK_CHARS, 0)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
            null
        } catch (_: RemoteException) {
            warnDeadConnection()
            null
        } catch (_: IllegalStateException) {
            warnDeadConnection()
            null
        } catch (_: Exception) {
            null
        }
        if (before.isNullOrEmpty()) return
        val start = wordStart(before, before.length)
        val count = before.length - start
        if (count > 0) {
            try {
                ic.deleteSurroundingText(count, 0)
            } catch (_: DeadObjectException) {
                warnDeadConnection()
            } catch (_: RemoteException) {
                warnDeadConnection()
            } catch (_: IllegalStateException) {
                warnDeadConnection()
            } catch (_: Exception) {
                warnDeadConnection()
            }
        }
    }

    fun handleEnter() {
        // C-17: Una sola vibración por tecla gestionada en la capa de gestos (KeyFactory: fastTap en ACTION_DOWN).
        if (snippets()?.handleEnterInEditor() == true) return
        if (host.currentLayer() == Layer.SNIPPETS && snippets()?.isSearchActive == true) {
            snippets()?.exitSearchMode()
            return
        }
        if (service.currentInputConnection == null) {
            warnDeadConnection()
            return
        }
        try {
            service.sendDownUpKeyEvents(KeyEvent.KEYCODE_ENTER)
        } catch (_: DeadObjectException) {
            warnDeadConnection()
        } catch (_: RemoteException) {
            warnDeadConnection()
        } catch (_: IllegalStateException) {
            warnDeadConnection()
        } catch (_: Exception) {
            warnDeadConnection()
        }
    }
}
