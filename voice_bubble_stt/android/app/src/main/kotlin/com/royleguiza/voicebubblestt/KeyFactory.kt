package com.royleguiza.voicebubblestt

import android.graphics.Typeface
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.abs

/**
 * Fábrica de teclas (SPK-05, módulos 14–15 de N): constructores de teclas
 * de texto, icono y filas QWERTY/símbolos/código + primitivas de gesto
 * (tap rápido, toque largo con repetición y borrado por deslizamiento),
 * extraídos de VoiceKeyboardService sin cambiar conducta. Todo lo que
 * necesita del teclado entra por [service] (contexto/sistema), [handler]
 * y [host]; los commits concretos entran por el host (cada capa comite
 * distinto) y el registro visual (mayúsculas, shift) vuelve al servicio.
 * PRIVACIDAD: nada se registra en Log.
 */
class KeyFactory(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {

    /** Lo mínimo que la fábrica exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun dimenPx(resId: Int): Int
        fun keyHeightPx(): Int
        fun displayLetter(base: Char): String
        fun haptic(view: View)
        fun attachTap(view: View, onTap: () -> Unit)
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun attachAccentKey(key: TextView, base: Char, onTapUp: () -> Unit)
        fun attachSymbolKey(key: TextView, base: Char, onTapUp: () -> Unit)
        fun isLongPressSymbolsEnabled(): Boolean
        fun longPressDelayMs(): Long
        fun attachPairKey(
            key: TextView,
            ch: Char,
            onCommit: (String) -> Unit,
            onAutoPair: (Char, Char) -> Unit,
        )
        fun attachBackspaceKey(key: View, action: () -> Unit)
        fun commitLetterKey(base: Char)
        fun commitSymbolKey(text: String)
        fun commitText(text: String)
        fun sendCode(code: Int)
        fun deleteBackward()
        fun deleteWord()
        fun trackLetterKey(key: TextView, base: Char)
        fun trackShiftKey(key: ImageView)
        fun toggleShiftKey()
    }

    /** Canceladores de long-press pendientes: rebuild() los invoca antes de
     *  soltar las vistas para no dejar disparos zombis sobre teclas
     *  descartadas. */
    private val cancellations = mutableListOf<() -> Unit>()

    /**
     * Fila horizontal con línea única garantizada: sin alineación por
     * baseline (los glifos de 14/19/20sp la romperían) y centrada
     * verticalmente para que iconos y texto compartan la misma línea.
     */
    fun horizontalRow(): LinearLayout {
        val row = LinearLayout(service)
        row.orientation = LinearLayout.HORIZONTAL
        row.setBaselineAligned(false)
        row.gravity = Gravity.CENTER_VERTICAL
        return row
    }

    fun fastTap(key: View, onClick: () -> Unit) {
        key.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    host.haptic(v)
                    v.isPressed = true
                    pressPop(v, true)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (v.isPressed) {
                        onClick()
                    }
                    v.isPressed = false
                    pressPop(v, false)
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.isPressed = false
                    pressPop(v, false)
                    true
                }
                else -> false
            }
        }
    }

    /**
     * Pop visual de escritura (confianza a velocidad): la tecla crece un 7%
     * al apoyar el dedo y vuelve al soltar. Escala instantánea (sin
     * animador: no interfiere con pump de tests ni con popups) y apagada
     * con Reduced Motion (anti-patrón §8: jamás overriding de animaciones).
     */
    private fun pressPop(v: View, down: Boolean) {
        if (service.reducedMotion()) return
        val s = if (down) 1.07f else 1f
        v.scaleX = s
        v.scaleY = s
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
    fun longPress(
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
            TypedValue.COMPLEX_UNIT_DIP, SWIPE_DELETE_STEP_DP, service.resources.displayMetrics,
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
        cancellations.add { cancelPending(); cancelRepeating() }

        key.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    longPressFired = false
                    swipeMode = false
                    swipeAnchorX = ev.rawX
                    host.haptic(v)
                    v.isPressed = true
                    pressPop(v, true)
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
                    val delayMs = try {
                        host.longPressDelayMs()
                    } catch (_: Exception) {
                        LONG_PRESS_MILLIS
                    }
                    handler.postDelayed(r, delayMs)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (onSwipeStep != null) {
                        if (!swipeMode && abs(ev.rawX - swipeAnchorX) > touchSlopPx) {
                            // Deslizamiento confirmado: ya no es ni tap ni
                            // repetición; queda solo el borrado por umbral.
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
                    pressPop(v, false)
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    cancelPending()
                    cancelRepeating()
                    v.isPressed = false
                    pressPop(v, false)
                    true
                }
                else -> false
            }
        }
    }

    /** Cablea una tecla ⌫ (P6): tap = 1 carácter, mantener = borrado
     *  continuo acelerado con haptic único, deslizar a la izquierda =
     *  borrar palabra por umbral de distancia. */
    fun backspaceGestures(key: View, action: () -> Unit) {
        longPress(
            key,
            onLongPress = {
                host.haptic(key)
                action()
            },
            onTapUp = action,
            onRepeat = action,
            onSwipeStep = { host.deleteWord() },
        )
    }

    fun cancelPendingGestures() {
        for (cancel in cancellations) {
            try {
                cancel()
            } catch (_: Exception) {}
        }
        cancellations.clear()
    }

    fun letterRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeLetterKey(c))
        }
        makeGapTolerant(row)
        return row
    }

    fun symbolRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeSymbolKey(c.toString()))
        }
        makeGapTolerant(row)
        return row
    }

    fun codeRow(chars: String): LinearLayout {
        val row = horizontalRow()
        for (c in chars) {
            row.addView(makeCodeKey(c))
        }
        makeGapTolerant(row)
        return row
    }

    /**
     * Filas gap-tolerantes (precisión de escritura): la fila captura los
     * toques que caen en gaps/márgenes (ningún hijo los consume: antes no
     * escribían nada) y los resuelve a la tecla hija más cercana,
     * disparando su commit de tap (guardado en `tag`). Los toques sobre
     * teclas siguen su ruta original intacta; las filas mixtas (shift/⌫)
     * quedan fuera a propósito (gestos propios).
     */
    private fun makeGapTolerant(row: LinearLayout) {
        row.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> true
                MotionEvent.ACTION_UP -> {
                    nearestChild(row, ev.x, ev.y)?.let { child ->
                        child.isPressed = true
                        handler.postDelayed({ child.isPressed = false }, 80L)
                        @Suppress("UNCHECKED_CAST")
                        (child.tag as? () -> Unit)?.invoke()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> true
                else -> false
            }
        }
    }

    private fun nearestChild(row: LinearLayout, x: Float, y: Float): View? {
        var best: View? = null
        var bestDist = Float.MAX_VALUE
        for (i in 0 until row.childCount) {
            val c = row.getChildAt(i)
            val dx = x - (c.left + c.width / 2f)
            val dy = y - (c.top + c.height / 2f)
            val d = dx * dx + dy * dy
            if (d < bestDist) {
                bestDist = d
                best = c
            }
        }
        return best
    }

    fun makeLetterKey(base: Char): TextView {
        val key = makeKey(
            host.displayLetter(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            host.dimenPx(R.dimen.kb_key_text_size),
        )
        // Commit de tap en el tag: lo usa la fila gap-tolerante para
        // resolver toques entre teclas (misma lambda, cero duplicación).
        val commit: () -> Unit = { host.commitLetterKey(base) }
        key.tag = commit
        if (accentsFor(base).isEmpty()) {
            host.attachTap(key, commit)
        } else {
            host.attachAccentKey(key, base, commit)
        }
        host.trackLetterKey(key, base)
        return key
    }

    /**
     * Tecla de símbolo en negrita (consistencia con letras y coma/punto):
     * el grosor iguala el peso visual en todas las capas.
     * MEJ-05: coma y punto abren menú de pulsación larga (símbolos);
     * el resto queda tap plano.
     */
    fun makeSymbolKey(
        label: String,
        textSizePx: Int = host.dimenPx(R.dimen.kb_key_text_size_small),
        isBold: Boolean = true,
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
        val commit: () -> Unit = { host.commitSymbolKey(label) }
        key.tag = commit
        val base = label.singleOrNull()
        if (base != null && symbolsFor(base).isNotEmpty()) {
            host.attachSymbolKey(key, base, commit)
        } else {
            host.attachTap(key, commit)
        }
        return key
    }

    /** Tecla de capa código: toque corto el símbolo, toque largo el par
     *  cerrado (solo si existe pareja; si no, tap plano). Negrita como
     *  el resto de símbolos. */
    fun makeCodeKey(ch: Char): TextView {
        val key = makeKey(
            ch.toString(),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            host.dimenPx(R.dimen.kb_key_text_size_small),
            isBold = true,
        )
        key.contentDescription = ch.toString()
        val onTapCommit: (String) -> Unit = { host.commitSymbolKey(it) }
        // El toque en gap resuelve al tap corto (nunca al par auto-cerrado).
        key.tag = { onTapCommit(ch.toString()) }
        host.attachPairKey(
            key,
            ch,
            onCommit = onTapCommit,
            onAutoPair = { open, close ->
                host.commitText("$open$close")
                host.sendCode(android.view.KeyEvent.KEYCODE_DPAD_LEFT)
            },
        )
        return key
    }

    fun makeSpecialKey(
        label: String,
        bgRes: Int,
        weight: Float,
        description: String?,
        textSizePx: Int = host.dimenPx(R.dimen.kb_key_text_size_small),
        isBold: Boolean = true,
        heightPx: Int? = null,
        onClick: () -> Unit,
    ): TextView {
        val key = makeKey(
            label,
            weight,
            bgRes,
            R.color.kb_label,
            textSizePx,
            isBold = isBold,
            heightPx = heightPx,
        )
        if (description != null) {
            key.contentDescription = description
        }
        host.attachTap(key, onClick)
        return key
    }

    fun makeActionIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        heightPx: Int? = null,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(service)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(service, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        val lp = LinearLayout.LayoutParams(0, heightPx ?: host.keyHeightPx(), weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        host.attachTap(key, onClick)
        return key
    }

    fun makeBackspaceKey(heightPx: Int? = null): ImageView {
        val key = makeActionIconKey(
            R.drawable.ic_backspace,
            R.drawable.kb_key_alt,
            1.3f,
            if (host.isSpanish()) "borrar" else "delete",
            tintColorRes = R.color.kb_label,
            heightPx = heightPx,
        ) {
            host.deleteBackward()
        }
        host.attachBackspaceKey(key) {
            host.deleteBackward()
        }
        return key
    }

    fun makeIconKey(
        iconRes: Int,
        bgRes: Int,
        weight: Float,
        description: String?,
        tintColorRes: Int = R.color.kb_label,
        useKeyHeight: Boolean = false,
        onClick: () -> Unit,
    ): ImageView {
        val key = ImageView(service)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.setBackgroundResource(bgRes)
        key.setColorFilter(ContextCompat.getColor(service, tintColorRes))
        if (description != null) {
            key.contentDescription = description
        }
        key.setPadding(0, 0, 0, 0)

        // useKeyHeight: filas de teclas a altura completa (misma que las
        // letras); por defecto conserva el compacto 38dp de la toolbar.
        val hPx = if (useKeyHeight) {
            host.keyHeightPx()
        } else {
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, service.resources.displayMetrics).toInt()
        }
        val lp = LinearLayout.LayoutParams(0, hPx, weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        if (useKeyHeight) {
            lp.setMargins(m, 0, m, 0)
        } else {
            lp.setMargins(m, m, m, m)
        }
        key.layoutParams = lp

        host.attachTap(key, onClick)
        return key
    }

    fun makeKey(
        label: String,
        weight: Float,
        bgRes: Int,
        colorRes: Int,
        textSizePx: Int,
        isBold: Boolean = false,
        heightPx: Int? = null,
    ): TextView {
        val key = TextView(service)
        key.text = label
        key.gravity = Gravity.CENTER
        key.isClickable = true
        key.isFocusable = true
        key.includeFontPadding = false
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(bgRes)
        key.setTextColor(ContextCompat.getColor(service, colorRes))
        key.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSizePx.toFloat())
        if (isBold) {
            key.setTypeface(null, Typeface.BOLD)
        }
        val lp = LinearLayout.LayoutParams(0, heightPx ?: host.keyHeightPx(), weight)
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        lp.setMargins(m, 0, m, 0)
        key.layoutParams = lp
        return key
    }
}
