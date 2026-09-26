package com.royleguiza.voicebubblestt

import org.json.JSONArray

/**
 * Modelos y helpers para el editor de notas del widget de Android.
 * Extraído de WidgetNoteEditActivity (C-25) para separar el parsing de estado de la Activity.
 */
internal data class PendingLoadResult(
    val pending: VbPending?,
    val unavailable: Boolean,
)

internal enum class ExistingNoteUiState {
    READY,
    NOT_FOUND,
    UNAVAILABLE,
}

internal fun parseWidgetPending(
    raw: String?,
    id: String,
    available: Boolean = true,
    fileExists: (String) -> Boolean,
): PendingLoadResult {
    if (!available) return PendingLoadResult(null, true)
    if (raw == null) return PendingLoadResult(null, true)
    if (raw.isBlank()) return PendingLoadResult(null, true)
    return try {
        val array = JSONArray(raw)
        var target: VbPending? = null
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index)
                ?: return PendingLoadResult(null, true)
            val itemId = item.opt("id") as? String
            val path = item.opt("audioPath") as? String
            val createdAt = item.opt("createdAtMs") as? Number
            if (itemId.isNullOrBlank() || path.isNullOrBlank() ||
                createdAt == null || createdAt.toLong() <= 0L) {
                return PendingLoadResult(null, true)
            }
            val pending = VbPending(itemId, path, createdAt.toLong())
            if (pending.id == id) target = pending
        }
        val selected = target ?: return PendingLoadResult(null, false)
        if (!fileExists(selected.audioPath)) return PendingLoadResult(null, true)
        PendingLoadResult(selected, false)
    } catch (_: Exception) {
        PendingLoadResult(null, true)
    }
}
