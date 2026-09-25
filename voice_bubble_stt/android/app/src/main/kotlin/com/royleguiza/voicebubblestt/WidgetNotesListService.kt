package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import java.io.File
import org.json.JSONArray

internal data class WidgetPendingSnapshot(
    val items: List<VbPending>,
    val state: NoteIndexState,
) {
    val available: Boolean
        get() = state == NoteIndexState.EMPTY || state == NoteIndexState.VALID
}

internal fun loadWidgetPendingSnapshot(context: Context): WidgetPendingSnapshot {
    val raw = try {
        context.getSharedPreferences(NoteStore.PREFS_NAME, Context.MODE_PRIVATE)
            .getString(NoteStore.PENDING_KEY, null)
    } catch (_: Exception) {
        return WidgetPendingSnapshot(emptyList(), NoteIndexState.UNAVAILABLE)
    }
    if (raw == null) return WidgetPendingSnapshot(emptyList(), NoteIndexState.MISSING)
    if (raw.isBlank()) return WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
    return try {
        val array = JSONArray(raw)
        val items = ArrayList<VbPending>(array.length())
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index)
                ?: return WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
            val id = item.opt("id") as? String
            val path = item.opt("audioPath") as? String
            val created = item.opt("createdAtMs") as? Number
            if (id.isNullOrBlank() || path.isNullOrBlank() ||
                created == null || created.toLong() <= 0L) {
                return WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
            }
            val audio = File(path)
            if (!audio.exists() || !audio.isFile) {
                return WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
            }
            items.add(VbPending(id, path, created.toLong()))
        }
        WidgetPendingSnapshot(
            items.sortedByDescending { it.createdAtMs },
            if (array.length() == 0) NoteIndexState.EMPTY else NoteIndexState.VALID,
        )
    } catch (_: Exception) {
        WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
    }
}

private fun isAuthoritativeWidgetState(state: NoteIndexState): Boolean {
    return isAuthoritativeNoteState(state)
}

/**
 * Colección con scroll del widget de notas: pendientes offline arriba
 * (entrada tocable con logo de grabación) + notas transcritas debajo.
 *
 * La lista hace scroll dentro del widget (ya no hay tope visual de 3):
 * cuantas más notas, más filas; el tamaño del widget solo cambia cuánto
 * se ve sin desplazar. Sin logs de contenido jamás.
 */
class WidgetNotesListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetNotesFactory(applicationContext)
}

private class WidgetNotesFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var pendings: List<VbPending> = emptyList()
    private var notes: List<VbNote> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val snapshot = NoteStore(context).loadSnapshot()
        val pendingSnapshot = loadWidgetPendingSnapshot(context)
        if (!isAuthoritativeWidgetState(snapshot.fileState) ||
            !isAuthoritativeWidgetState(snapshot.prefsState) ||
            !isAuthoritativeWidgetState(pendingSnapshot.state)
        ) {
            return
        }
        pendings = pendingSnapshot.items
        notes = snapshot.notes
    }

    override fun onDestroy() {
        pendings = emptyList()
        notes = emptyList()
    }

    override fun getCount(): Int = pendings.size + notes.size

    override fun getViewTypeCount(): Int = 2

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        return try {
            if (position < pendings.size) pendingView(pendings[position])
            else noteView(notes[position - pendings.size])
        } catch (_: Exception) {
            RemoteViews(context.packageName, R.layout.widget_pending_item)
        }
    }

    /** Entrada superior: audio sin transcribir, abre la modal del widget. */
    private fun pendingView(p: VbPending): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_pending_item)
        // Texto adaptativo claro/oscuro (el XML ya usa @color, esto cubre
        // vistas cacheadas tras el cambio automatico por horario).
        views.setTextColor(R.id.widget_pending_title, ContextCompat.getColor(context, R.color.kb_label))
        views.setTextColor(R.id.widget_pending_time, ContextCompat.getColor(context, R.color.kb_label_secondary))
        views.setTextViewText(R.id.widget_pending_title, "Audio sin transcribir")
        views.setTextViewText(
            R.id.widget_pending_time,
            "Toca para verlo y escucharlo · ${relativeTime(p.createdAtMs)}",
        )
        views.setContentDescription(
            R.id.widget_pending_root,
            "Abrir audio sin transcribir",
        )
        // Directo a la modal del widget (modo pendiente: ver + play,
        // sin transcribir). Un toque abre.
        val fill = Intent().apply {
            putExtra("pending_id", p.id)
        }
        views.setOnClickFillInIntent(R.id.widget_pending_root, fill)
        return views
    }

    private fun noteView(n: VbNote): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_note_item)
        views.setTextColor(R.id.widget_item_title, ContextCompat.getColor(context, R.color.kb_label))
        views.setTextColor(R.id.widget_item_body, ContextCompat.getColor(context, R.color.kb_label_secondary))
        views.setTextColor(R.id.widget_item_time, ContextCompat.getColor(context, R.color.kb_label_secondary))
        views.setTextViewText(
            R.id.widget_item_title,
            n.titulo.ifBlank { "Sin título" },
        )
        views.setTextViewText(R.id.widget_item_body, n.cuerpo)
        views.setTextViewText(R.id.widget_item_time, formatTime(n.updatedAt))
        views.setContentDescription(
            R.id.widget_item_root,
            "Abrir nota ${n.titulo.ifBlank { "Sin título" }}",
        )
        if (n.audioPath.isNotBlank()) {
            try {
                if (java.io.File(n.audioPath).exists()) {
                    views.setViewVisibility(R.id.widget_item_audio, View.VISIBLE)
                    views.setContentDescription(R.id.widget_item_audio, "Nota con audio original")
                } else {
                    views.setViewVisibility(R.id.widget_item_audio, View.GONE)
                }
            } catch (_: Exception) {
                views.setViewVisibility(R.id.widget_item_audio, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_item_audio, View.GONE)
        }
        // Directo a la modal del widget (un toque abre, ver + editar).
        val fill = Intent().apply {
            putExtra("note_id", n.id)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fill)
        return views
    }

    private fun relativeTime(epochMs: Long): String {
        if (epochMs <= 0L) return "reciente"
        return try {
            val diffMin = (System.currentTimeMillis() - epochMs) / 60000L
            when {
                diffMin < 1L -> "recién"
                diffMin < 60L -> "hace ${diffMin}m"
                diffMin < 1440L -> "hace ${diffMin / 60L}h"
                diffMin < 10080L -> "hace ${diffMin / 1440L}d"
                else -> "anterior"
            }
        } catch (_: Exception) {
            "reciente"
        }
    }

    private fun formatTime(iso: String): String {
        if (iso.isBlank()) return ""
        val fmt = java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm")
        return try {
            java.time.Instant.parse(iso).atZone(java.time.ZoneId.systemDefault()).let { fmt.format(it) }
        } catch (_: Exception) {
            try {
                java.time.OffsetDateTime.parse(iso).atZoneSameInstant(java.time.ZoneId.systemDefault()).let { fmt.format(it) }
            } catch (_: Exception) {
                iso.take(16).replace('T', ' ')
            }
        }
    }
}
