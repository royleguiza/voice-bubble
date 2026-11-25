package com.royleguiza.voicebubblestt

import android.content.res.Configuration
import android.inputmethodservice.InputMethodService
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.emoji2.emojipicker.EmojiPickerView

/**
 * T14 (K7) · Panel de emojis: ocupa el lugar de las teclas con el selector
 * oficial de AndroidX (categorías, recientes, tonos de piel y solo los
 * emojis que el teléfono sabe dibujar). Abajo, una fila con ABC (vuelve a
 * las letras), espacio y ⌫ (borra el emoji entero). La barra de
 * herramientas de arriba no cambia. PRIVACIDAD: nada se registra en Log;
 * los recientes los guarda la librería en el teléfono.
 */
class EmojiLayer(
    private val service: InputMethodService,
    private val keys: KeyFactory,
    private val host: UiHost,
) {
    interface UiHost {
        fun keyHeightPx(): Int
        fun rowGap(): Int
        fun commitText(text: String)
        fun closeEmojiPanel()
        fun pressSpace()
        fun addContentRow(view: View)
    }

    fun buildRows() {
        val night = (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val themed = ContextThemeWrapper(
            service,
            if (night) android.R.style.Theme_DeviceDefault else android.R.style.Theme_DeviceDefault_Light,
        )
        val picker = EmojiPickerView(themed).apply {
            emojiGridColumns = 8
            setOnEmojiPickedListener { item -> host.commitText(item.emoji) }
        }
        val height = host.keyHeightPx() * 3 + host.rowGap() * 2
        val box = LinearLayout(service).apply { orientation = LinearLayout.VERTICAL }
        box.addView(picker, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height))
        host.addContentRow(box)

        val row = keys.horizontalRow()
        row.addView(
            keys.makeSpecialKey("ABC", R.drawable.kb_key_alt, 1.5f, keys.getString(R.string.kb_a11y_letters)) {
                host.closeEmojiPanel()
            },
        )
        row.addView(
            keys.makeSpecialKey("", R.drawable.kb_key_bg, 5f, keys.getString(R.string.kb_a11y_space)) {
                host.pressSpace()
            },
        )
        row.addView(keys.makeBackspaceKey(weight = 1.5f))
        host.addContentRow(row)
    }
}
