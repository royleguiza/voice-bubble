package com.royleguiza.voicebubblestt

import android.content.Context
import android.util.Log
import org.json.JSONArray
import java.io.File

/**
 * Notas del widget — espejo EXACTO de Dart `NotesService._loadMerged`.
 *
 * Lee prefs `flutter.voice_notes_v1` + archivo `voice_notes.json` (el mismo
 * que Dart escribe atomico en filesDir), fusiona con dedup por id ganando
 * el mas reciente por updatedAt, ordena desc y topa en 50. Sin esta paridad
 * la app (merge) y el widget (antes solo prefs, sin dedup) podian mostrar
 * contenido distinto para la misma nota. Sin logs de contenido jamas.
 */
data class VbNote(
    val id: String,
    val titulo: String,
    val cuerpo: String,
    val createdAt: String,
    val updatedAt: String,
    val audioPath: String = "",
)

class NoteStore(private val context: Context) {

    companion object {
        private const val TAG = "VbNoteStore"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_DATA = "flutter.voice_notes_v1"
        const val NOTES_FILE = "voice_notes.json"
        const val MAX_NOTES = 50

        fun filesDirOf(context: Context): File = File(context.filesDir, NOTES_FILE)

        /** Espejo atomico tmp+rename como Dart `_saveFile` (write-through). */
        fun writeFileMirror(context: Context, jsonArray: String) {
            try {
                val target = filesDirOf(context)
                val tmp = File(target.parent, "${target.name}.tmp")
                tmp.writeText(jsonArray)
                if (!tmp.renameTo(target)) {
                    tmp.copyTo(target, overwrite = true)
                    try {
                        tmp.delete()
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {}
        }
    }

    fun load(): List<VbNote> {
        val prefsRaw = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_DATA, null)
        } catch (_: Exception) {
            null
        }
        val fileRaw = try {
            val f = filesDirOf(context)
            if (f.exists()) f.readText() else null
        } catch (_: Exception) {
            null
        }
        // Orden de fusion identico a Dart: archivo primero, prefs despues.
        // En empate gana el primero (archivo); en conflicto, el mas reciente.
        return merge(fileRaw, prefsRaw)
    }

    private fun merge(vararg raws: String?): List<VbNote> {
        val byId = LinkedHashMap<String, VbNote>()
        for (raw in raws) {
            for (n in parse(raw)) {
                if (n.id.isEmpty()) continue
                val cur = byId[n.id]
                if (cur == null || parseEpoch(n.updatedAt) > parseEpoch(cur.updatedAt)) {
                    byId[n.id] = n
                }
            }
        }
        val out = byId.values.sortedByDescending { parseEpoch(it.updatedAt) }
        return if (out.size > MAX_NOTES) out.subList(0, MAX_NOTES) else out
    }

    private fun parse(raw: String?): List<VbNote> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<VbNote>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                out.add(
                    VbNote(
                        id = obj.optString("id"),
                        titulo = obj.optString("titulo"),
                        cuerpo = obj.optString("cuerpo"),
                        createdAt = obj.optString("createdAt"),
                        updatedAt = obj.optString("updatedAt"),
                        audioPath = obj.optString("audioPath"),
                    )
                )
            }
            out.sortedByDescending { parseEpoch(it.updatedAt) }
        } catch (_: Exception) {
            Log.w(TAG, "json invalido")
            emptyList()
        }
    }

    private fun parseEpoch(iso: String): Long {
        if (iso.isBlank()) return 0L
        return try {
            java.time.Instant.parse(iso).toEpochMilli()
        } catch (_: Exception) {
            try {
                java.time.OffsetDateTime.parse(iso).toInstant().toEpochMilli()
            } catch (_: Exception) {
                try {
                    java.time.LocalDateTime.parse(iso)
                        .atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
                } catch (_: Exception) {
                    0L
                }
            }
        }
    }
}
