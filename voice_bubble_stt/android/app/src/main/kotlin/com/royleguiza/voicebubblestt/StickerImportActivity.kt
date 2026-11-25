package com.royleguiza.voicebubblestt

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast

/**
 * T16 · Importar stickers sin abrir la app: la usa el «+» de la pestaña
 * Stickers del teclado (abre el selector de imágenes, varias a la vez) y
 * el «Compartir con Orison» de cualquier app (una o varias imágenes).
 * Invisible: importa en un hilo aparte, avisa cuántos sumó y se cierra.
 */
class StickerImportActivity : Activity() {

    companion object {
        const val ACTION_PICK = "${BuildConfig.APPLICATION_ID}.PICK_STICKERS"
        private const val REQUEST_PICK = 4101
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return
        when (intent?.action) {
            Intent.ACTION_SEND -> importAll(listOfNotNull(streamOf(intent)))
            Intent.ACTION_SEND_MULTIPLE -> importAll(streamsOf(intent))
            ACTION_PICK -> pick()
            else -> finish()
        }
    }

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamsOf(intent: Intent): List<Uri> =
        intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()

    private fun pick() {
        val pick = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(pick, REQUEST_PICK)
        } catch (_: Exception) {
            finish()
        }
    }

    @Deprecated("Activity entrega el resultado por esta vía")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK || resultCode != RESULT_OK || data == null) {
            finish()
            return
        }
        val uris = buildList {
            data.data?.let { add(it) }
            val clip = data.clipData
            if (clip != null) for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { add(it) }
        }.distinct()
        importAll(uris)
    }

    private fun importAll(uris: List<Uri>) {
        if (uris.isEmpty()) {
            finish()
            return
        }
        val app = applicationContext
        Thread({
            val store = StickerStore(app)
            val added = uris.count { store.import(it) != null }
            runOnUiThread {
                val msg = if (added > 0) {
                    app.resources.getQuantityString(R.plurals.sticker_import_added, added, added)
                } else {
                    app.getString(R.string.sticker_import_none)
                }
                Toast.makeText(app, msg, Toast.LENGTH_SHORT).show()
                finish()
            }
        }, "orison-stickers").start()
    }
}
