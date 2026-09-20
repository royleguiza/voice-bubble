package com.royleguiza.voicebubblestt

import android.content.Context
import android.util.Log
import org.json.JSONArray

/**
 * Notas del widget — independiente de TranscriptionHistoryRepository.
 * Lee `flutter.voice_notes_v1` (prefs) y ofrece lista ordenada por updatedAt.
 * Sin logs de contenido jamas.
 */
data class VbNote(
    val id: String,
    val titulo: String,
    val cuerpo: String,
    val createdAt: String,
    val updatedAt: String,
)

class NoteStore(private val context: Context) {

    companion object {
        private const val TAG = "VbNoteStore"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_DATA = "flutter.voice_notes_v1"
        const val MAX_NOTES = 50
    }

    fun load(): List<VbNote> {
        val raw = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_DATA, null)
        } catch (_: Exception) {
            null
        }
        return parse(raw)
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
