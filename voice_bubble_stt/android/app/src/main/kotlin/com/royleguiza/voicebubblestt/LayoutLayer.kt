package com.royleguiza.voicebubblestt

import android.os.Build
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.ImageView
import android.widget.LinearLayout

/**
 * Capa Layout (SPK-05, módulo 16 de N): filas de letras/símbolos/código,
 * barra inferior (símbolos, idioma, coma/espacio/punto, enter) y apilado
 * de filas, extraída de VoiceKeyboardService sin cambiar conducta. Los
 * constructores de teclas entran por [keys]; el comportamiento (capas,
 * idioma, espaciadora, enter) entra por [host]. Las vistas de coma,
 * espacio y punto se publican para los gestos del servicio.
 * PRIVACIDAD: nada se registra en Log.
 */
class LayoutLayer(
    private val keys: KeyFactory,
    private val host: UiHost,
) {

    /** Lo mínimo que el layout exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun dimenPx(resId: Int): Int
        fun rowGap(): Int
        fun rootView(): LinearLayout
        fun trackpadHeightPx(): Int
        fun addContentRow(view: View)
        fun toggleShiftKey()
        fun trackShiftKey(view: ImageView)
        fun pressSymbolsKey()
        fun pressNumericKey()
        fun pressSymbolsFromNumeric()
        fun toggleLanguage()
        fun pressSpace()
        fun pressEnter()
        fun attachSpacebar(view: View)
        fun symbolsLabel(): String
        fun isLanguageKeyVisible(): Boolean
        fun spacebarAlignment(): String
        fun bottomElevationDp(): Int
        fun miniKeyHeightPx(): Int
    }

    var spaceView: View? = null
        private set
    var commaView: View? = null
        private set
    var dotView: View? = null
        private set

    fun buildLetterRows() {
        host.addContentRow(keys.letterRow("qwertyuiop"))
        host.addContentRow(keys.letterRow(if (host.isSpanish()) "asdfghjklñ" else "asdfghjkl;"))

        val row3 = keys.horizontalRow()
        val shiftAction: () -> Unit = { host.toggleShiftKey() }
        val shiftKey = keys.makeActionIconKey(
            R.drawable.ic_shift_off,
            R.drawable.kb_key_alt,
            1.3f,
            keys.getString(R.string.kb_a11y_shift),
            tintColorRes = R.color.kb_label,
            onClick = shiftAction,
        )
        shiftKey.tag = shiftAction
        host.trackShiftKey(shiftKey)
        row3.addView(shiftKey)
        for (c in "zxcvbnm") {
            row3.addView(keys.makeLetterKey(c))
        }
        row3.addView(keys.makeBackspaceKey())
        host.addContentRow(row3)
    }

    fun buildSymbolRows() {
        host.addContentRow(keys.symbolRow("1234567890"))
        host.addContentRow(keys.symbolRow("@#$%&-+()/"))

        val row3 = keys.horizontalRow()
        for (c in "=*\"':;!?") {
            row3.addView(keys.makeSymbolKey(c.toString()))
        }
        row3.addView(keys.makeBackspaceKey())
        host.addContentRow(row3)
    }

    /** Capa codigo (K2): simbolos por frecuencia + pares auto-cerrados. */
    fun buildCodeRows() {
        host.addContentRow(keys.codeRow("{}[]()<>;:"))
        host.addContentRow(keys.codeRow("'\"`\\|/!?=+"))

        val row3 = keys.horizontalRow()
        for (c in "*&%$#@^~_") {
            row3.addView(keys.makeCodeKey(c))
        }
        row3.addView(keys.makeBackspaceKey())
        host.addContentRow(row3)
    }

    /**
     * Capa numérica (calculadora): bloque central de dígitos con fondo
     * principal + operadores laterales con fondo secundario. Misma
     * fábrica y gestos que el resto (⌫ con repetición y swipe-palabra).
     * Grilla simétrica de 5 columnas: bordes (operadores/borrar) de
     * ancho de borde + 3 dígitos centrales más anchos (las divas).
     * Total por fila = 5.0, idéntico en las 3 filas y en la inferior.
     */
    fun buildNumericRows() {
        val es = host.isSpanish()
        val row1 = keys.horizontalRow()
        row1.addView(keys.makeAltSymbolKey("-", keys.getString(R.string.kb_a11y_minus), weight = NUM_EDGE_W))
        for (c in "789") {
            row1.addView(keys.makeSymbolKey(c.toString(), weight = NUM_DIGIT_W))
        }
        row1.addView(keys.makeAltSymbolKey("+", keys.getString(R.string.kb_a11y_plus), weight = NUM_EDGE_W))
        host.addContentRow(row1)

        val row2 = keys.horizontalRow()
        row2.addView(keys.makeAltSymbolKey("*", keys.getString(R.string.kb_a11y_multiply), weight = NUM_EDGE_W))
        for (c in "456") {
            row2.addView(keys.makeSymbolKey(c.toString(), weight = NUM_DIGIT_W))
        }
        row2.addView(keys.makeAltSymbolKey("%", keys.getString(R.string.kb_a11y_percent), weight = NUM_EDGE_W))
        host.addContentRow(row2)

        val row3 = keys.horizontalRow()
        row3.addView(keys.makeAltSymbolKey("/", keys.getString(R.string.kb_a11y_divide), weight = NUM_EDGE_W))
        for (c in "123") {
            row3.addView(keys.makeSymbolKey(c.toString(), weight = NUM_DIGIT_W))
        }
        row3.addView(keys.makeBackspaceKey(weight = NUM_EDGE_W))
        host.addContentRow(row3)
    }

    /**
     * Fila inferior numérica (sin espacio, por pedido): ABC pastilla,
     * !?# junto a ABC, coma, cero central del ancho de la columna 3,
     * punto, igual junto al Enter y el mismo Enter accent del resto.
     * Simetría: bordes ABC/Enter = columnas laterales; !?# e igual
     * espejados; coma y punto pequeños espejados (ws + wp = dígito).
     */
    fun buildNumericBottomRow(): LinearLayout {
        val row = keys.horizontalRow()
        val es = host.isSpanish()

        val btnAbc = keys.makeSpecialKeyWithLongPress(
            "ABC",
            R.drawable.kb_key_alt,
            NUM_EDGE_W,
            keys.getString(R.string.kb_a11y_letters),
            isBold = true,
            onTap = { host.pressSymbolsKey() },
            onLongPress = { host.pressSymbolsKey() },
        )
        row.addView(btnAbc)
        val btnSym = keys.makeSpecialKey(
            "!?#",
            R.drawable.kb_key_alt,
            NUM_SYM_W,
            keys.getString(R.string.kb_a11y_symbols),
            isBold = true,
        ) {
            host.pressSymbolsFromNumeric()
        }
        row.addView(btnSym)
        row.addView(keys.makeSymbolKey(",", weight = NUM_PUNCT_W))
        row.addView(keys.makeSymbolKey("0", weight = NUM_DIGIT_W))
        row.addView(keys.makeSymbolKey(".", weight = NUM_PUNCT_W))
        row.addView(keys.makeAltSymbolKey("=", keys.getString(R.string.kb_a11y_equals), weight = NUM_SYM_W))

        val enter = keys.makeActionIconKey(
            R.drawable.ic_enter,
            R.drawable.kb_key_accent,
            NUM_EDGE_W,
            keys.getString(R.string.kb_a11y_enter),
            tintColorRes = R.color.kb_label_on_accent,
        ) {
            host.pressEnter()
        }
        row.addView(enter)
        return row
    }

    companion object {
        /** Ancho de columnas laterales (operadores, ⌫, ABC, Enter). */
        const val NUM_EDGE_W = 0.85f

        /** Ancho de dígitos (las divas; el 0 iguala la columna 3). */
        const val NUM_DIGIT_W = 1.1f

        /** !?# e igual, espejados. */
        const val NUM_SYM_W = 0.7f

        /** Coma y punto pequeños, espejados (sym + punct = dígito). */
        const val NUM_PUNCT_W = 0.4f
    }

    fun buildBottomBar(): LinearLayout {
        val row = keys.horizontalRow()

        // Tap = alternar símbolos; mantener = capa numérica (con pista para TalkBack).
        val symDesc = keys.getString(R.string.kb_a11y_symbols_hold_numbers)
        val btnSym = keys.makeSpecialKeyWithLongPress(
            host.symbolsLabel(),
            R.drawable.kb_key_alt,
            1.5f,
            symDesc,
            isBold = true,
            onTap = { host.pressSymbolsKey() },
            onLongPress = { host.pressNumericKey() },
        )

        val btnLang = if (host.isLanguageKeyVisible()) {
            keys.makeSpecialKey(if (host.isSpanish()) "ES" else "EN", R.drawable.kb_key_alt, 1f, keys.getString(R.string.kb_a11y_switch_language), isBold = true) {
                host.toggleLanguage()
            }
        } else {
            null
        }

        val comma = keys.makeSymbolKey(",", host.dimenPx(R.dimen.kb_key_glyph_punct), isBold = true)
        commaView = comma

        val space = keys.makeSpecialKey("", R.drawable.kb_key_bg, 5.0f, keys.getString(R.string.kb_a11y_space)) {
            host.pressSpace()
        }
        spaceView = space
        host.attachSpacebar(space)

        val dot = keys.makeSymbolKey(".", host.dimenPx(R.dimen.kb_key_glyph_punct), isBold = true)
        dotView = dot

        val enter = keys.makeActionIconKey(
            R.drawable.ic_enter,
            R.drawable.kb_key_accent,
            1.8f,
            keys.getString(R.string.kb_a11y_enter),
            tintColorRes = R.color.kb_label_on_accent,
        ) {
            host.pressEnter()
        }

        // Orden de la fila inferior segun la preferencia de alineacion.
        // Siempre arranca con Sym/Lang, luego el bloque configurable, y termina con Enter.
        row.addView(btnSym)
        if (btnLang != null) {
            row.addView(btnLang)
        }

        when (host.spacebarAlignment()) {
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

    /**
     * Fila única del modo mini (MEJ-12): borrar (con sus gestos: tap,
     * repetición y swipe-palabra) + espacio (con gestos de la espaciadora)
     * + enter, a altura compacta. Sin gap-tolerancia (fila mixta, igual que
     * las row3 del modo completo).
     */
    fun buildMiniRow() {
        val row = keys.horizontalRow()
        val h = host.miniKeyHeightPx()

        row.addView(keys.makeBackspaceKey(h))

        val space = keys.makeSpecialKey(
            "",
            R.drawable.kb_key_bg,
            5.0f,
            keys.getString(R.string.kb_a11y_space),
            heightPx = h,
        ) {
            host.pressSpace()
        }
        host.attachSpacebar(space)
        row.addView(space)

        row.addView(
            keys.makeActionIconKey(
                R.drawable.ic_enter,
                R.drawable.kb_key_accent,
                1.8f,
                keys.getString(R.string.kb_a11y_enter),
                tintColorRes = R.color.kb_label_on_accent,
                heightPx = h,
            ) {
                host.pressEnter()
            },
        )
        host.addContentRow(row)
    }

    fun addRow(row: View) {
        val lp = if (row is VirtualTrackpadView) {
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                host.trackpadHeightPx(),
            )
        } else {
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
        val root = host.rootView()
        if (root.childCount > 0) {
            val gap = host.rowGap()
            val previous = root.getChildAt(root.childCount - 1)
            if (row is KeyRow) {
                // T5: el hueco entre filas pasa a ser relleno de las filas
                // (mitad arriba, mitad abajo de la anterior si también es de
                // teclas): mismo dibujo, pero el toque ahí tiene dueño.
                if (previous is KeyRow) {
                    val half = gap / 2
                    previous.setPadding(previous.paddingLeft, previous.paddingTop, previous.paddingRight, gap - half)
                    row.setPadding(row.paddingLeft, half, row.paddingRight, row.paddingBottom)
                } else {
                    row.setPadding(row.paddingLeft, gap, row.paddingRight, row.paddingBottom)
                }
            } else {
                lp.topMargin = gap
            }
        }
        root.addView(row, lp)
    }

    /**
     * Con targetSdk edge-to-edge la ventana del teclado se extiende bajo la
     * barra de gestos y los botones del sistema. El relleno inferior (barra
     * + elevación de Ajustes) lo aplica [KeyboardRootLayout] en cada
     * medición, así la fila inferior nunca queda cortada (ver esa clase).
     */
    fun applyBottomInsets(root: KeyboardRootLayout) {
        root.padH = host.dimenPx(R.dimen.kb_row_padding_h)
        root.padV = host.dimenPx(R.dimen.kb_row_padding_v)
        root.bottomPaddingFor = { insets -> navBottomPx(insets) + elevationPx() }
    }

    private fun elevationPx(): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        host.bottomElevationDp().coerceIn(0, 64).toFloat(),
        host.rootView().resources.displayMetrics,
    ).toInt()

    /**
     * Alto de la barra del sistema bajo el teclado. Se toma el mayor entre
     * el valor visible y el que ignora visibilidad: el visible puede valer
     * 0 un instante (barra transitoria, apps inmersivas) y hacer saltar la
     * altura del teclado.
     */
    private fun navBottomPx(insets: WindowInsets?): Int {
        if (insets == null) return 0
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val types = WindowInsets.Type.navigationBars() or
                WindowInsets.Type.displayCutout()
            maxOf(
                insets.getInsets(types).bottom,
                insets.getInsetsIgnoringVisibility(types).bottom,
            )
        } else {
            @Suppress("DEPRECATION")
            insets.systemWindowInsetBottom
        }
    }
}
