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
        val shiftKey = keys.makeActionIconKey(
            R.drawable.ic_shift_off,
            R.drawable.kb_key_alt,
            1.3f,
            if (host.isSpanish()) "mayúsculas" else "shift",
            tintColorRes = R.color.kb_label,
        ) {
            host.toggleShiftKey()
        }
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

    fun buildBottomBar(): LinearLayout {
        val row = keys.horizontalRow()

        val btnSym = keys.makeSpecialKey(host.symbolsLabel(), R.drawable.kb_key_alt, 1.5f, if (host.isSpanish()) "símbolos" else "symbols", isBold = true) {
            host.pressSymbolsKey()
        }

        val btnLang = if (host.isLanguageKeyVisible()) {
            keys.makeSpecialKey(if (host.isSpanish()) "ES" else "EN", R.drawable.kb_key_alt, 1f, if (host.isSpanish()) "cambiar idioma" else "switch language", isBold = true) {
                host.toggleLanguage()
            }
        } else {
            null
        }

        val comma = keys.makeSymbolKey(",", host.dimenPx(R.dimen.kb_key_glyph_punct), isBold = true)
        commaView = comma

        val space = keys.makeSpecialKey("", R.drawable.kb_key_bg, 5.0f, if (host.isSpanish()) "espacio" else "space") {
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
            if (host.isSpanish()) "intro" else "enter",
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
            if (host.isSpanish()) "espacio" else "space",
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
                if (host.isSpanish()) "intro" else "enter",
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
        if (host.rootView().childCount > 0) {
            lp.topMargin = host.rowGap()
        }
        host.rootView().addView(row, lp)
    }

    /**
     * Con targetSdk edge-to-edge la ventana del teclado se extiende bajo la
     * barra de gestos y los botones del sistema. Se aplica el inset de
     * navegacion como padding inferior para que la fila inferior quede
     * siempre por encima.
     */
    fun applyBottomInsets() {
        val padH = host.dimenPx(R.dimen.kb_row_padding_h)
        val padV = host.dimenPx(R.dimen.kb_row_padding_v)
        host.rootView().setOnApplyWindowInsetsListener { view, insets ->
            val bottom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                insets.getInsets(
                    WindowInsets.Type.navigationBars()
                        or WindowInsets.Type.displayCutout(),
                ).bottom
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetBottom
            }
            val elevationPx = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                host.bottomElevationDp().toFloat(),
                host.rootView().resources.displayMetrics,
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
}
