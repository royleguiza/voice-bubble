package com.royleguiza.voicebubblestt

import android.inputmethodservice.InputMethodService
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Toolbar (SPK-05, módulo 12 de N): barra interactiva superior con
 * accesos (snippets, credenciales, ajustes, terminal, portapapeles, código,
 * trackpad, mic) + fila terminal permanente con modificadores sticky,
 * extraída de VoiceKeyboardService sin cambiar conducta. Todo lo que
 * necesita del teclado entra por [service] (contexto/sistema) y [host];
 * el estado de modificadores (CTRL/ALT) sigue en el servicio porque lo
 * consume el motor de edición. PRIVACIDAD: nada se registra en Log.
 */
class ToolbarLayer(
    private val service: InputMethodService,
    private val host: UiHost,
) {

    private val modifierViews = mutableListOf<Pair<TextView, Boolean>>()

    /** Lo mínimo que la barra exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun isPasswordField(): Boolean
        fun currentLayer(): Layer
        fun dimenPx(resId: Int): Int
        fun horizontalRow(): LinearLayout
        fun makeIconKey(
            iconRes: Int,
            bgRes: Int,
            weight: Float,
            description: String?,
            tintColorRes: Int = R.color.kb_label,
            onClick: () -> Unit,
        ): ImageView
        fun makeSpecial(
            label: String,
            bgRes: Int,
            weight: Float,
            description: String?,
            textSizePx: Int,
            isBold: Boolean,
            onClick: () -> Unit,
        ): TextView
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun rebuildKeyboard()
        fun snippetsToggle()
        fun credentialsToggle()
        fun clipboardToggle()
        fun clipboardPasteLatest()
        fun trackpadToggle()
        fun codeToggle()
        fun sendCode(code: Int)
        fun micKeyView(): View
        fun micClearViews()
        fun isTerminalRowPref(): Boolean
        fun toggleTerminalRowPref()
        fun isCodeKeyPref(): Boolean
        fun isCredentialsKeyPref(): Boolean
        fun isTrackpadToolbarAllowed(): Boolean
        fun isToolbarInverted(): Boolean
        fun isMiniMode(): Boolean
        fun miniToggle()
        fun registerModifier(key: TextView, isCtrl: Boolean)
        fun isModifierActive(isCtrl: Boolean): Boolean
        fun toggleModifier(isCtrl: Boolean)
        fun refreshModifiers()
    }

    fun registerModifier(key: TextView, isCtrl: Boolean) {
        modifierViews.add(Pair(key, isCtrl))
    }

    fun refreshModifiers() {
        for ((key, isCtrl) in modifierViews) {
            val active = host.isModifierActive(isCtrl)
            if (active) {
                key.setBackgroundResource(R.drawable.kb_key_accent)
                key.setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
            } else {
                key.setBackgroundResource(R.drawable.kb_key_alt)
                key.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            }
        }
    }

    fun clearModifiers() {
        modifierViews.clear()
    }

    fun buildToolbar(): LinearLayout {
        val row = LinearLayout(service)
        row.orientation = LinearLayout.HORIZONTAL

        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        val m = host.dimenPx(R.dimen.kb_key_gap)
        lp.setMargins(m, m, m, m)
        row.layoutParams = lp
        row.setPadding(0, 0, 0, 0)

        val items = mutableListOf<View>()

        // Elementos borde (Snippets):
        if (!host.isPasswordField()) {
            val btnSnippets = host.makeIconKey(
                R.drawable.ic_snippets,
                R.drawable.kb_key_alt,
                1.0f,
                if (host.isSpanish()) "fragmentos" else "snippets",
            ) {
                host.snippetsToggle()
            }
            items.add(btnSnippets)
        }

        // Llave de credenciales: visible salvo pref en OFF (Ajustes →
        // Claves). En contraseñas sigue disponible si la pref está ON
        // (ahí es donde se necesita: relleno explícito usuario+clave).
        if (host.isCredentialsKeyPref()) {
            val btnCredentials = host.makeIconKey(
                R.drawable.ic_key,
                if (host.currentLayer() == Layer.CREDENTIALS) R.drawable.kb_key_accent else R.drawable.kb_key_alt,
                1.0f,
                if (host.isSpanish()) "credenciales" else "credentials",
                tintColorRes = if (host.currentLayer() == Layer.CREDENTIALS) R.color.kb_label_on_accent else R.color.kb_label,
            ) {
                host.credentialsToggle()
            }
            items.add(btnCredentials)
        }

        // Elementos centrales:
        val btnSettings = host.makeIconKey(R.drawable.ic_settings, R.drawable.kb_key_alt, 1.0f, "ajustes") {
            service.openAppUi()
        }
        items.add(btnSettings)

        if (host.isTerminalRowPref()) {
            val btnTerminal = host.makeIconKey(
                R.drawable.ic_terminal,
                R.drawable.kb_key_alt,
                1.0f,
                if (host.isSpanish()) "fila terminal" else "terminal row",
            ) {
                host.toggleTerminalRowPref()
                host.rebuildKeyboard()
            }
            items.add(btnTerminal)
        }

        val btnPaste = host.makeIconKey(
            R.drawable.ic_paste,
            R.drawable.kb_key_alt,
            1.0f,
            if (host.isSpanish()) "portapapeles" else "clipboard",
        ) {
            host.clipboardToggle()
        }
        host.attachPress(
            btnPaste,
            onLongPress = {
                host.clipboardPasteLatest()
            },
            onTapUp = {
                host.clipboardToggle()
            },
        )
        items.add(btnPaste)

        if (host.isCodeKeyPref()) {
            val btnCode = host.makeIconKey(
                R.drawable.ic_code,
                R.drawable.kb_key_alt,
                1.0f,
                if (host.isSpanish()) "capa código" else "code layer",
            ) {
                host.codeToggle()
            }
            items.add(btnCode)
        }

        if (!host.isPasswordField() && host.isTrackpadToolbarAllowed()) {
            val isTp = (host.currentLayer() == Layer.TRACKPAD)
            val btnTrackpad = host.makeIconKey(
                if (isTp) R.drawable.ic_keyboard else R.drawable.ic_trackpad,
                if (isTp) R.drawable.kb_key_accent else R.drawable.kb_key_alt,
                1.0f,
                if (isTp) (if (host.isSpanish()) "teclado" else "keyboard") else "trackpad",
                tintColorRes = if (isTp) R.color.kb_label_on_accent else R.color.kb_label,
            ) {
                host.trackpadToggle()
            }
            items.add(btnTrackpad)
        }

        // Modo mini (MEJ-12): teclado+flecita abajo para compactar (pedido
        // del dueño); al estar en mini el icono es expandir (flecha arriba).
        // Va al borde, junto al micrófono.
        val btnMicro = host.makeIconKey(
            if (host.isMiniMode()) R.drawable.ic_micro_expand else R.drawable.ic_micro_collapse,
            R.drawable.kb_key_alt,
            1.0f,
            if (host.isSpanish()) {
                if (host.isMiniMode()) "teclado completo" else "mini-teclado"
            } else {
                if (host.isMiniMode()) "full keyboard" else "mini keyboard"
            },
        ) {
            host.miniToggle()
        }
        items.add(btnMicro)

        // Elementos borde (Micrófono):
        if (!host.isPasswordField()) {
            val mic = host.micKeyView()

            // Adjust mic layout params to use weight 1.0f
            val hPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 38f, service.resources.displayMetrics).toInt()
            val micLp = LinearLayout.LayoutParams(0, hPx, 1.0f)
            val micM = host.dimenPx(R.dimen.kb_key_gap) / 2
            micLp.setMargins(micM, micM, micM, micM)
            mic.layoutParams = micLp

            items.add(mic)
        } else {
            host.micClearViews()
        }

        if (host.isToolbarInverted()) {
            items.reverse()
        }

        items.forEach { row.addView(it) }

        return row
    }

    /** Fila terminal permanente en todas las capas (K2). */
    fun buildTerminalRow(): LinearLayout {
        val row = host.horizontalRow()
        row.addView(host.makeSpecial("TAB", R.drawable.kb_key_alt, 1.5f, "tab", host.dimenPx(R.dimen.kb_key_text_size_small), true) {
            host.sendCode(android.view.KeyEvent.KEYCODE_TAB)
        })
        row.addView(host.makeSpecial("ESC", R.drawable.kb_key_alt, 1f, "escape", host.dimenPx(R.dimen.kb_key_text_size_small), true) {
            host.sendCode(android.view.KeyEvent.KEYCODE_ESCAPE)
        })
        row.addView(makeModifierKey("CTRL", true, 1.25f))
        row.addView(makeModifierKey("ALT", false, 1.25f))
        row.addView(
            makeArrowKey(
                "←", android.view.KeyEvent.KEYCODE_DPAD_LEFT,
                if (host.isSpanish()) "flecha izquierda" else "left arrow",
            ),
        )
        row.addView(
            makeArrowKey(
                "↑", android.view.KeyEvent.KEYCODE_DPAD_UP,
                if (host.isSpanish()) "flecha arriba" else "up arrow",
            ),
        )
        row.addView(
            makeArrowKey(
                "↓", android.view.KeyEvent.KEYCODE_DPAD_DOWN,
                if (host.isSpanish()) "flecha abajo" else "down arrow",
            ),
        )
        row.addView(
            makeArrowKey(
                "→", android.view.KeyEvent.KEYCODE_DPAD_RIGHT,
                if (host.isSpanish()) "flecha derecha" else "right arrow",
            ),
        )
        return row
    }

    private fun makeArrowKey(glyph: String, code: Int, description: String?): TextView =
        host.makeSpecial(glyph, R.drawable.kb_key_bg, 1f, description, host.dimenPx(R.dimen.kb_key_text_size_small), true) {
            host.sendCode(code)
        }

    /** CTRL/ALT sticky: tap activa/desactiva; la proxima tecla los consume. */
    private fun makeModifierKey(label: String, isCtrl: Boolean, weight: Float): TextView {
        val key = host.makeSpecial(
            label,
            R.drawable.kb_key_alt,
            weight,
            if (isCtrl) {
                if (host.isSpanish()) "tecla control" else "control key"
            } else {
                if (host.isSpanish()) "tecla alt" else "alt key"
            },
            host.dimenPx(R.dimen.kb_key_text_size_small),
            true,
        ) {
            host.toggleModifier(isCtrl)
            host.refreshModifiers()
        }
        registerModifier(key, isCtrl)
        return key
    }
}
