package com.royleguiza.voicebubblestt

import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.view.View
import android.widget.LinearLayout
import androidx.core.content.FileProvider
import androidx.core.view.inputmethod.EditorInfoCompat
import androidx.core.view.inputmethod.InputConnectionCompat
import androidx.core.view.inputmethod.InputContentInfoCompat

/**
 * Capa Portapapeles (SPK-05, módulo 7 de N): filmstrip multimodal
 * FIFO-25 con imágenes, extraída de VoiceKeyboardService sin cambiar
 * conducta. Todo lo que necesita del teclado entra por [service]
 * (sistema), [handler] y [host]; el store, la vista y el listener son
 * suyos. Privacidad: los clips sensibles del sistema se ignoran y nada
 * se registra en Log.
 */
class ClipboardLayer(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {

    /** Lo mínimo que el portapapeles exige al teclado. */
    interface UiHost {
        fun isSpanish(): Boolean
        fun rootView(): LinearLayout
        fun haptic(view: View)
        fun commitText(text: String)
        fun currentLayer(): Layer
        fun showLayer(next: Layer)
    }

    private lateinit var store: ClipboardStore
    private var filmstripView: ClipboardFilmstripLayout? = null
    private var origin = Layer.LETTERS

    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        handlePrimaryClipChanged()
    }

    fun onCreate() {
        store = ClipboardStore(service)
        val cm = service.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        try {
            cm?.addPrimaryClipChangedListener(clipboardListener)
        } catch (_: Exception) {}
    }

    fun onDestroy() {
        val cm = service.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        try {
            cm?.removePrimaryClipChangedListener(clipboardListener)
        } catch (_: Exception) {}
        try {
            if (::store.isInitialized) {
                store.shutdown()
            }
        } catch (_: Exception) {}
    }

    fun onStartInputView(restarting: Boolean) {
        handlePrimaryClipChanged()
    }

    /**
     * Capa propia excluyente (como Claves): una sola sección visible a la
     * vez. El carrusel vive en el flujo donde estaba, reemplazando el
     * contenido en vez de apilarse: no empuja teclas ni esconde mitades.
     */
    fun toggle() {
        if (host.currentLayer() == Layer.CLIPBOARD) {
            host.showLayer(origin)
            return
        }
        origin = host.currentLayer()
        host.showLayer(Layer.CLIPBOARD)
    }

    /** Contenido de la capa: la cinta de siempre, visible y cargada. */
    fun buildRows(): ClipboardFilmstripLayout {
        val filmstrip = ClipboardFilmstripLayout(
            context = service,
            store = store,
            onClipClicked = { clip ->
                pasteClip(clip, autoClose = true)
            },
            onClipLongClicked = { clip, _ ->
                store.togglePin(clip.id)
                refreshIfVisible()
            },
            onClearClicked = {
                store.clearAllUnpinned()
                refreshIfVisible()
            }
        )
        filmstripView = filmstrip
        loadAsync(filmstrip)
        return filmstrip
    }

    /** Long-press del botón pegar: pega lo último o abre la cinta. */
    fun pasteLatestOrToggle() {
        val latest = try {
            store.getLatestClip()
        } catch (_: Exception) {
            null
        }
        if (latest != null) {
            pasteClip(latest, autoClose = false)
        } else {
            toggle()
        }
    }

    private fun handlePrimaryClipChanged() {
        val cm = service.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
        if (!cm.hasPrimaryClip()) return

        val clipData = try {
            cm.primaryClip
        } catch (_: Exception) {
            null
        } ?: return

        if (clipData.itemCount == 0) return

        val item = clipData.getItemAt(0)
        val description = clipData.description

        // Privacidad: ignorar clips marcados como confidenciales (passwords, OTPs, etc.)
        if (description != null) {
            val isSensitive = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                description.extras?.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE, false) ?: false
            } else {
                description.extras?.getBoolean("android.content.extra.IS_SENSITIVE", false) ?: false
            }
            if (isSensitive) return
        }

        if (description != null && description.hasMimeType("image/*") && item.uri != null) {
            val mime = description.getMimeType(0) ?: "image/png"
            store.addImageClip(item.uri, mime) {
                handler.post { refreshIfVisible() }
            }
        } else {
            val text = item.text?.toString() ?: item.coerceToText(service)?.toString()
            if (!text.isNullOrEmpty()) {
                store.addTextClip(text) {
                    handler.post { refreshIfVisible() }
                }
            }
        }
    }

    /**
     * Carga de clips fuera del main (I/O de disco vía BackgroundWork) con
     * render en el main solo si la vista sigue vigente y expandida: un
     * rebuild en el medio no debe pintar sobre el filmstrip descartado.
     */
    private fun loadAsync(target: ClipboardFilmstripLayout) {
        BackgroundWork.executeWithResult(
            block = {
                try {
                    store.loadItems()
                } catch (_: Exception) {
                    emptyList()
                }
            },
            onResult = { clips ->
                if (filmstripView === target) {
                    try {
                        target.renderClips(clips ?: emptyList())
                    } catch (_: Exception) {}
                }
            }
        )
    }

    private fun refreshIfVisible() {
        filmstripView?.let { loadAsync(it) }
    }

    private fun pasteClip(clip: ClipboardItem, autoClose: Boolean = true) {
        host.haptic(host.rootView())
        // Al pegar desde la capa, volver al origen como hace Claves.
        if (autoClose && host.currentLayer() == Layer.CLIPBOARD) {
            host.showLayer(origin)
        }
        when (clip.type) {
            ClipType.TEXT, ClipType.CODE, ClipType.MATH, ClipType.URL -> {
                clip.text?.let { host.commitText(it) }
            }
            ClipType.IMAGE -> {
                commitImageClip(clip, autoClose)
            }
        }
    }

    private fun commitImageClip(clip: ClipboardItem, autoClose: Boolean) {
        val file = store.getMediaFile(clip)
        if (file == null) {
            service.showClipboardNotice(if (host.isSpanish()) "Imagen no disponible" else "Image unavailable")
            return
        }

        val editorInfo = service.currentInputEditorInfo
        val inputConnection = service.currentInputConnection
        if (editorInfo == null || inputConnection == null) return

        val supportedMimes = try {
            EditorInfoCompat.getContentMimeTypes(editorInfo)
        } catch (_: Exception) {
            emptyArray<String>()
        }

        val isSupported = supportedMimes.any { mime ->
            ClipDescription.compareMimeTypes(clip.mimeType, mime)
        }

        if (isSupported) {
            try {
                val contentUri = FileProvider.getUriForFile(
                    service,
                    "${service.packageName}.clipboardfileprovider",
                    file
                )
                val description = ClipDescription("Clipboard Image", arrayOf(clip.mimeType))
                val inputContentInfo = InputContentInfoCompat(contentUri, description, null)
                val flags = InputConnectionCompat.INPUT_CONTENT_GRANT_READ_URI_PERMISSION

                val success = InputConnectionCompat.commitContent(
                    inputConnection,
                    editorInfo,
                    inputContentInfo,
                    flags,
                    null
                )
                if (!success) {
                    service.showClipboardNotice(if (host.isSpanish()) "La app no aceptó la imagen" else "App rejected image")
                }
            } catch (_: Exception) {
                service.showClipboardNotice(if (host.isSpanish()) "Error al insertar imagen" else "Error inserting image")
            }
        } else {
            service.showClipboardNotice(if (host.isSpanish()) "Este campo no acepta imágenes" else "Field does not support images")
        }
    }
}
