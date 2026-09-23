package com.royleguiza.voicebubblestt

import android.content.Context
import org.json.JSONArray

/**
 * Pendientes offline compartidos entre el provider y la colección del
 * widget (misma clave `flutter.voice_notes_pending_v1` que Dart
 * `PendingNoteQueue`). Solo entradas con WAV válido en disco.
 */
data class VbPending(
    val id: String,
    val audioPath: String,
    val createdAtMs: Long,
)

object WidgetPendingStore {

    fun load(context: Context): List<VbPending> {
        return try {
            val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.voice_notes_pending_v1", null)
            if (raw.isNullOrBlank()) return emptyList()
            val arr = JSONArray(raw)
            val out = ArrayList<VbPending>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val id = o.optString("id")
                val path = o.optString("audioPath")
                if (id.isBlank() || path.isBlank()) continue
                try {
                    if (!java.io.File(path).exists()) continue
                } catch (_: Exception) {
                    continue
                }
                out.add(VbPending(id, path, o.optLong("createdAtMs")))
            }
            // Más reciente primero (igual que Dart: inserta al inicio).
            out.sortedByDescending { it.createdAtMs }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
