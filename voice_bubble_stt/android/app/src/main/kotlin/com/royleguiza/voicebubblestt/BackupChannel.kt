package com.royleguiza.voicebubblestt

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * T1 · Canal de la copia de seguridad: abre el selector de archivos de
 * Android (crear o abrir documento, sin permisos de almacenamiento) y corre
 * [BackupManager] en un hilo aparte. Responde a Dart con un mapa
 * `{status: saved|imported|cancelled|error, reason?, …conteos}`.
 */
class BackupChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private var pending: MethodChannel.Result? = null
    private var pendingAppVersion: String = ""
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "export" -> {
                if (!claim(result)) return
                pendingAppVersion = call.argument<String>("appVersion") ?: ""
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = MIME_ZIP
                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("fileName") ?: "orison-copia.zip")
                }
                launch(intent, REQUEST_EXPORT)
            }
            "import" -> {
                if (!claim(result)) return
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(MIME_ZIP, "application/x-zip-compressed", "application/octet-stream"),
                    )
                }
                launch(intent, REQUEST_IMPORT)
            }
            else -> result.notImplemented()
        }
    }

    /** Una operación por vez: un segundo pedido mientras hay otro abierto se rechaza. */
    private fun claim(result: MethodChannel.Result): Boolean {
        if (pending != null) {
            result.success(mapOf("status" to "error", "reason" to "busy"))
            return false
        }
        pending = result
        return true
    }

    private fun launch(intent: Intent, request: Int) {
        try {
            activity.startActivityForResult(intent, request)
        } catch (_: Exception) {
            finish(mapOf("status" to "error", "reason" to "no_picker"))
        }
    }

    /** Devuelve true si el resultado era de este canal. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_EXPORT && requestCode != REQUEST_IMPORT) return false
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finish(mapOf("status" to "cancelled"))
            return true
        }
        val appContext = activity.applicationContext
        val appVersion = pendingAppVersion
        Thread({
            val response: Map<String, Any> = try {
                val manager = BackupManager(appContext)
                if (requestCode == REQUEST_EXPORT) {
                    val summary = appContext.contentResolver.openOutputStream(uri, "wt")?.use {
                        manager.export(it, appVersion)
                    } ?: throw BackupManager.BackupException(BackupManager.REASON_IO)
                    mapOf("status" to "saved") + summary.toMap()
                } else {
                    val summary = appContext.contentResolver.openInputStream(uri)?.use {
                        manager.import(it)
                    } ?: throw BackupManager.BackupException(BackupManager.REASON_IO)
                    mapOf("status" to "imported") + summary.toMap()
                }
            } catch (error: BackupManager.BackupException) {
                if (requestCode == REQUEST_EXPORT) discard(uri)
                mapOf("status" to "error", "reason" to error.reason)
            } catch (_: Exception) {
                if (requestCode == REQUEST_EXPORT) discard(uri)
                mapOf("status" to "error", "reason" to BackupManager.REASON_IO)
            }
            main.post { finish(response) }
        }, "orison-backup").start()
        return true
    }

    /** Un archivo a medio escribir no sirve como copia: se borra. */
    private fun discard(uri: Uri) {
        try {
            DocumentsContract.deleteDocument(activity.applicationContext.contentResolver, uri)
        } catch (_: Exception) {
        }
    }

    private fun finish(response: Map<String, Any>) {
        val result = pending ?: return
        pending = null
        result.success(response)
    }

    companion object {
        const val CHANNEL = "com.royleguiza.voicebubblestt/backup"
        private const val REQUEST_EXPORT = 3101
        private const val REQUEST_IMPORT = 3102
        private const val MIME_ZIP = "application/zip"
    }
}
