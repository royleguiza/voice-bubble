package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

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
        pendings = WidgetPendingStore.load(context)
        notes = NoteStore(context).load()
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
