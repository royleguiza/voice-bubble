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

/**
 * C-46: reproductor expandible del pendiente. Reloj `00:17 / 00:56` con
 * minutos de dos dígitos; total estimado por tamaño (PCM16 mono 16kHz
 * propio, 32000 B/s); apertura en dos burbujas al 30% del ancho con
 * aire mínimo de 96dp y tope de 150dp (el cierre es la inversa).
 */
internal fun formatPlayerClock(positionMs: Long, totalMs: Long): String {
    fun part(ms: Long): String {
        val total = (ms.coerceAtLeast(0) / 1000).toInt()
        return String.format(java.util.Locale.US, "%02d:%02d", total / 60, total % 60)
    }
    return "${part(positionMs)} / ${part(totalMs)}"
}

internal fun estimatePlayerTotalMs(fileLength: Long): Long {
    if (fileLength <= 44) return 0L
    return ((fileLength - 44) / 32000.0 * 1000).toLong().coerceAtLeast(1000L)
}

internal fun playerGapPx(containerWidthPx: Float, density: Float): Float {
    val d = if (density > 0) density else 1f
    return (containerWidthPx * 0.30f).coerceIn(96f * d, 150f * d)
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
