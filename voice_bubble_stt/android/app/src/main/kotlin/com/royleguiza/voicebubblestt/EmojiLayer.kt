package com.royleguiza.voicebubblestt

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.inputmethodservice.InputMethodService
import android.util.LruCache
import android.util.TypedValue
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.view.inputmethod.EditorInfoCompat
import androidx.core.view.inputmethod.InputConnectionCompat
import androidx.core.view.inputmethod.InputContentInfoCompat
import androidx.emoji2.emojipicker.EmojiPickerView
import java.io.File

/**
 * T14 (K7) + T16 · Panel de medios: ocupa el lugar de las teclas con dos
 * pestañas abajo, Emojis (selector oficial de AndroidX: categorías,
 * recientes y tonos de piel) y Stickers (webp propios de 512 × 512 que se
 * mandan con commitContent; si la app no acepta imágenes, se copian al
 * portapapeles y se avisa). La fila de abajo: ABC · pestaña · espacio · ⌫.
 * PRIVACIDAD: nada se registra en Log.
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
        fun rebuildKeyboard()
        fun isSpanish(): Boolean
    }

    /** Pestaña visible del panel (se recuerda mientras viva el teclado). */
    private var showStickers = false
    private var markedForDelete: File? = null
    private val stickers by lazy { StickerStore(service) }
    private val thumbs = object : LruCache<String, android.graphics.Bitmap>(6 * 1024 * 1024) {
        override fun sizeOf(key: String, value: android.graphics.Bitmap): Int = value.byteCount
    }

    private fun dp(v: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, service.resources.displayMetrics).toInt()

    fun buildRows() {
        val height = host.keyHeightPx() * 3 + host.rowGap() * 2
        val content = if (showStickers) buildStickerGrid() else buildEmojiPicker()
        val box = LinearLayout(service).apply { orientation = LinearLayout.VERTICAL }
        box.addView(content, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height))
        host.addContentRow(box)

        val row = keys.horizontalRow()
        row.addView(
            keys.makeSpecialKey("ABC", R.drawable.kb_key_alt, 1.3f, keys.getString(R.string.kb_a11y_letters)) {
                markedForDelete = null
                host.closeEmojiPanel()
            },
        )
        row.addView(
            keys.makeSpecialKey(
                if (showStickers) "😊" else keys.getString(R.string.kb_stickers_tab),
                R.drawable.kb_key_alt,
                1.7f,
                keys.getString(if (showStickers) R.string.kb_a11y_emoji else R.string.kb_stickers_tab),
                isBold = false,
            ) {
                showStickers = !showStickers
                markedForDelete = null
                host.rebuildKeyboard()
            },
        )
        row.addView(
            keys.makeSpecialKey("", R.drawable.kb_key_bg, 3.5f, keys.getString(R.string.kb_a11y_space)) {
                host.pressSpace()
            },
        )
        row.addView(keys.makeBackspaceKey(weight = 1.5f))
        host.addContentRow(row)
    }

    private fun buildEmojiPicker(): View {
        val night = (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val themed = ContextThemeWrapper(
            service,
            if (night) android.R.style.Theme_DeviceDefault else android.R.style.Theme_DeviceDefault_Light,
        )
        return EmojiPickerView(themed).apply {
            emojiGridColumns = 8
            setOnEmojiPickedListener { item -> host.commitText(item.emoji) }
        }
    }

    private fun buildStickerGrid(): View {
        val files = stickers.list()
        val columns = 4
        val list = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4f), dp(4f), dp(4f), dp(4f))
        }
        val cells = ArrayList<View>(files.size + 1)
        cells.add(addCell())
        files.forEach { cells.add(stickerCell(it)) }
        var row: LinearLayout? = null
        cells.forEachIndexed { index, cell ->
            if (index % columns == 0) {
                row = LinearLayout(service).apply { orientation = LinearLayout.HORIZONTAL }
                list.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(84f)))
            }
            row?.addView(cell, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f).apply {
                setMargins(dp(3f), dp(3f), dp(3f), dp(3f))
            })
        }
        // Relleno para que la última fila no estire sus celdas.
        val rest = (columns - cells.size % columns) % columns
        repeat(rest) {
            row?.addView(View(service), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f).apply {
                setMargins(dp(3f), dp(3f), dp(3f), dp(3f))
            })
        }
        if (files.isEmpty()) {
            list.addView(TextView(service).apply {
                text = service.getString(R.string.kb_stickers_empty)
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setPadding(dp(16f), dp(12f), dp(16f), dp(12f))
            })
        }
        return ScrollView(service).apply {
            isVerticalScrollBarEnabled = true
            addView(list)
        }
    }

    private fun addCell(): View = TextView(service).apply {
        text = "+"
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
        setTextColor(ContextCompat.getColor(service, R.color.hz_ember_t))
        setBackgroundResource(R.drawable.kb_key_alt)
        contentDescription = service.getString(R.string.kb_stickers_add)
        setOnClickListener {
            try {
                service.startActivity(
                    Intent(service, StickerImportActivity::class.java)
                        .setAction(StickerImportActivity.ACTION_PICK)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (_: Exception) {}
        }
    }

    private fun stickerCell(file: File): View {
        val frame = FrameLayout(service).apply { setBackgroundResource(R.drawable.kb_key_bg) }
        val image = ImageView(service).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(dp(4f), dp(4f), dp(4f), dp(4f))
            contentDescription = service.getString(R.string.kb_stickers_tab)
        }
        frame.addView(image, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        val cached = thumbs.get(file.name)
        if (cached != null) {
            image.setImageBitmap(cached)
        } else {
            BackgroundWork.executeWithResult(
                block = {
                    BitmapFactory.decodeFile(file.absolutePath, BitmapFactory.Options().apply { inSampleSize = 2 })
                },
                onResult = { bmp ->
                    if (bmp != null) {
                        thumbs.put(file.name, bmp)
                        image.setImageBitmap(bmp)
                    }
                },
            )
        }
        val marked = markedForDelete == file
        if (marked) {
            frame.addView(TextView(service).apply {
                text = service.getString(R.string.kb_stickers_delete)
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_danger))
                setBackgroundColor(ContextCompat.getColor(service, R.color.kb_danger))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setOnClickListener {
                    stickers.delete(file)
                    thumbs.remove(file.name)
                    markedForDelete = null
                    service.showClipboardNotice(service.getString(R.string.kb_stickers_deleted))
                    host.rebuildKeyboard()
                }
            }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(28f), Gravity.BOTTOM))
        }
        frame.setOnClickListener {
            if (markedForDelete != null) {
                markedForDelete = null
                host.rebuildKeyboard()
            } else {
                commitSticker(file)
            }
        }
        frame.setOnLongClickListener {
            markedForDelete = file
            host.rebuildKeyboard()
            true
        }
        return frame
    }

    /** commitContent si la app acepta imágenes; si no, al portapapeles. */
    private fun commitSticker(file: File) {
        val uri = try {
            FileProvider.getUriForFile(service, "${service.packageName}.clipboardfileprovider", file)
        } catch (_: Exception) {
            return
        }
        val info = service.currentInputEditorInfo
        val ic = service.currentInputConnection
        val accepts = info != null && try {
            EditorInfoCompat.getContentMimeTypes(info).any {
                ClipDescription.compareMimeTypes(StickerStore.MIME, it)
            }
        } catch (_: Exception) {
            false
        }
        if (accepts && ic != null) {
            val ok = try {
                InputConnectionCompat.commitContent(
                    ic,
                    info!!,
                    InputContentInfoCompat(uri, ClipDescription("Sticker", arrayOf(StickerStore.MIME)), null),
                    InputConnectionCompat.INPUT_CONTENT_GRANT_READ_URI_PERMISSION,
                    null,
                )
            } catch (_: Exception) {
                false
            }
            if (ok) return
        }
        try {
            val cm = service.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newUri(service.contentResolver, "Sticker", uri))
            service.showClipboardNotice(service.getString(R.string.kb_stickers_copied))
        } catch (_: Exception) {}
    }
}
