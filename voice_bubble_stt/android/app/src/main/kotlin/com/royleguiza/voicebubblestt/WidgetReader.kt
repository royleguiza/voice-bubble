package com.royleguiza.voicebubblestt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import java.util.concurrent.ConcurrentHashMap

/**
 * Lectura de notas DENTRO del widget: tocar una nota cambia el widget a la
 * vista de la nota (texto completo con scroll, copiar, título y resumen con
 * IA) sin abrir ninguna ventana. Solo "Editar" abre la hoja con teclado.
 *
 * Estado por widget en prefs privadas (no las de Flutter). Sin logs de
 * contenido jamás.
 */
object WidgetReader {

    private const val PREFS = "vb_widget_reader"
    private const val KEY_OPEN = "open_"
    private const val KEY_BUSY = "busy_"
    private const val KEY_BUSY_AT = "busy_at_"
    private const val KEY_STATUS = "status_"
    private const val KEY_SUMMARY = "summary_"

    const val AI_TITLE = "titulo"
    const val AI_SUMMARY = "resumir"

    /** Más corto que en la app: el receptor tiene ~60 s de vida. */
    private const val WIDGET_AI_TIMEOUT_MS = 20_000
    private const val BUSY_STALE_MS = 90_000L
    private const val MAX_TITLE_CHARS = 80

    internal sealed class Open {
        data class Note(val id: String) : Open()
        data class Pending(val id: String) : Open()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    internal fun openState(context: Context, widgetId: Int): Open? {
        val raw = try {
            prefs(context).getString(KEY_OPEN + widgetId, null)
        } catch (_: Exception) {
            null
        } ?: return null
        val id = raw.substringAfter(':', "")
        if (!WidgetNoteEditActivity.isValidUuid(id)) return null
        return when (raw.substringBefore(':')) {
            "note" -> Open.Note(id)
            "pending" -> Open.Pending(id)
            else -> null
        }
    }

    fun openNote(context: Context, widgetId: Int, noteId: String) =
        setOpen(context, widgetId, "note:$noteId")

    fun openPending(context: Context, widgetId: Int, pendingId: String) =
        setOpen(context, widgetId, "pending:$pendingId")

    private fun setOpen(context: Context, widgetId: Int, value: String) {
        try {
            prefs(context).edit()
                .putString(KEY_OPEN + widgetId, value)
                .remove(KEY_STATUS + widgetId)
                .remove(KEY_SUMMARY + widgetId)
                .commit()
        } catch (_: Exception) {}
    }

    fun close(context: Context, widgetId: Int) {
        try {
            prefs(context).edit()
                .remove(KEY_OPEN + widgetId)
                .remove(KEY_STATUS + widgetId)
                .remove(KEY_SUMMARY + widgetId)
                .remove(KEY_BUSY + widgetId)
                .remove(KEY_BUSY_AT + widgetId)
                .commit()
        } catch (_: Exception) {}
    }

    internal fun busy(context: Context, widgetId: Int): String? = try {
        val p = prefs(context)
        val at = p.getLong(KEY_BUSY_AT + widgetId, 0L)
        val action = p.getString(KEY_BUSY + widgetId, null)
        if (action != null && System.currentTimeMillis() - at < BUSY_STALE_MS) action else null
    } catch (_: Exception) {
        null
    }

    private fun setBusy(context: Context, widgetId: Int, action: String?) {
        try {
            val edit = prefs(context).edit()
            if (action == null) {
                edit.remove(KEY_BUSY + widgetId).remove(KEY_BUSY_AT + widgetId)
            } else {
                edit.putString(KEY_BUSY + widgetId, action)
                    .putLong(KEY_BUSY_AT + widgetId, System.currentTimeMillis())
                    .remove(KEY_STATUS + widgetId)
            }
            edit.commit()
        } catch (_: Exception) {}
    }

    internal fun status(context: Context, widgetId: Int): String? = try {
        prefs(context).getString(KEY_STATUS + widgetId, null)
    } catch (_: Exception) {
        null
    }

    private fun setStatus(context: Context, widgetId: Int, message: String?) {
        try {
            val edit = prefs(context).edit()
            if (message == null) edit.remove(KEY_STATUS + widgetId) else edit.putString(KEY_STATUS + widgetId, message)
            edit.commit()
        } catch (_: Exception) {}
    }

    internal fun summary(context: Context, widgetId: Int): String? = try {
        prefs(context).getString(KEY_SUMMARY + widgetId, null)
    } catch (_: Exception) {
        null
    }

    private fun setSummary(context: Context, widgetId: Int, text: String?) {
        try {
            val edit = prefs(context).edit()
            if (text == null) edit.remove(KEY_SUMMARY + widgetId) else edit.putString(KEY_SUMMARY + widgetId, text)
            edit.commit()
        } catch (_: Exception) {}
    }

    /** Párrafos para la lista con scroll (líneas vacías separan). */
    internal fun paragraphs(text: String): List<String> =
        text.replace("\r\n", "\n").split(Regex("\n\\s*\n"))
            .map { it.trim('\n') }
            .filter { it.isNotBlank() }

    // ---- Caché en memoria para que "Editar" abra con el texto al instante.

    private val noteCache = ConcurrentHashMap<String, VbNote>()

    internal fun cachedNote(id: String): VbNote? = noteCache[id]

    private fun cache(note: VbNote) {
        if (noteCache.size > 8) noteCache.clear()
        noteCache[note.id] = note
    }

    // ---- Render dentro del widget.

    /**
     * Dibuja la nota/pendiente abierto. Devuelve false si no hay nada
     * abierto (o ya no existe) para que el proveedor dibuje la lista.
     */
    internal fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        notes: List<VbNote>,
        pendings: List<VbPending>,
    ): Boolean {
        val open = openState(context, widgetId) ?: return false
        val views = RemoteViews(context.packageName, R.layout.widget_note_detail)
        val primary = ContextCompat.getColor(context, R.color.kb_label)
        val secondary = ContextCompat.getColor(context, R.color.kb_label_secondary)
        views.setTextColor(R.id.widget_detail_title, primary)
        views.setTextColor(R.id.widget_detail_meta, secondary)
        views.setTextColor(R.id.widget_detail_status, primary)
        views.setTextColor(R.id.widget_detail_empty, secondary)
        views.setOnClickPendingIntent(R.id.widget_detail_back, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_CLOSE))

        when (open) {
            is Open.Note -> {
                val note = notes.firstOrNull { it.id == open.id }
                if (note == null) {
                    close(context, widgetId)
                    return false
                }
                cache(note)
                renderNote(context, views, widgetId, note)
            }
            is Open.Pending -> {
                val pending = pendings.firstOrNull { it.id == open.id }
                if (pending == null) {
                    close(context, widgetId)
                    return false
                }
                renderPending(context, views, widgetId, pending)
            }
        }
        views.setRemoteAdapter(R.id.widget_detail_body, bodyIntent(context, widgetId))
        views.setEmptyView(R.id.widget_detail_body, R.id.widget_detail_empty)
        appWidgetManager.updateAppWidget(widgetId, views)
        try {
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_detail_body)
        } catch (_: Exception) {}
        return true
    }

    private fun renderNote(context: Context, views: RemoteViews, widgetId: Int, note: VbNote) {
        val summary = summary(context, widgetId)
        val busy = busy(context, widgetId)
        val status = when (busy) {
            AI_TITLE -> "Generando título…"
            AI_SUMMARY -> "Resumiendo…"
            else -> status(context, widgetId)
        }
        views.setTextViewText(R.id.widget_detail_title, note.titulo.ifBlank { "Sin título" })
        views.setTextViewText(
            R.id.widget_detail_meta,
            if (summary != null) "Resumen sugerido · reemplaza el texto" else formatTime(note.updatedAt),
        )
        views.setViewVisibility(R.id.widget_detail_status, if (status.isNullOrBlank()) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.widget_detail_status, status ?: "")
        views.setTextViewText(R.id.widget_detail_empty, "Nota vacía")

        views.setViewVisibility(R.id.widget_detail_edit, View.VISIBLE)
        views.setOnClickPendingIntent(R.id.widget_detail_edit, editPi(context, widgetId, note.id))
        views.setViewVisibility(R.id.widget_detail_open_pending, View.GONE)

        val previewing = summary != null
        views.setViewVisibility(R.id.widget_detail_actions, if (previewing) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_detail_summary_actions, if (previewing) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.widget_detail_copy, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_COPY))
        views.setOnClickPendingIntent(R.id.widget_detail_ai_title, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_AI_TITLE))
        views.setOnClickPendingIntent(R.id.widget_detail_ai_summary, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_AI_SUMMARY))
        views.setOnClickPendingIntent(R.id.widget_detail_summary_discard, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_SUMMARY_DISCARD))
        views.setOnClickPendingIntent(R.id.widget_detail_summary_apply, actionPi(context, widgetId, WidgetReaderReceiver.ACTION_SUMMARY_APPLY))

        views.setViewVisibility(R.id.widget_detail_ai_title_icon, if (busy == AI_TITLE) View.INVISIBLE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_detail_ai_title_progress, if (busy == AI_TITLE) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.widget_detail_ai_summary_icon, if (busy == AI_SUMMARY) View.INVISIBLE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_detail_ai_summary_progress, if (busy == AI_SUMMARY) View.VISIBLE else View.GONE)
    }

    private fun renderPending(context: Context, views: RemoteViews, widgetId: Int, pending: VbPending) {
        views.setTextViewText(R.id.widget_detail_title, "Audio sin transcribir")
        views.setTextViewText(R.id.widget_detail_meta, formatEpoch(pending.createdAtMs))
        views.setViewVisibility(R.id.widget_detail_status, View.GONE)
        views.setTextViewText(R.id.widget_detail_empty, "Todavía no tiene texto. Escuchalo o transcribilo.")
        views.setViewVisibility(R.id.widget_detail_edit, View.GONE)
        views.setViewVisibility(R.id.widget_detail_actions, View.GONE)
        views.setViewVisibility(R.id.widget_detail_summary_actions, View.GONE)
        views.setViewVisibility(R.id.widget_detail_open_pending, View.VISIBLE)
        val intent = Intent(context, WidgetNoteEditActivity::class.java).apply {
            putExtra("pending_id", pending.id)
        }
        views.setOnClickPendingIntent(
            R.id.widget_detail_open_pending,
            PendingIntent.getActivity(
                context, 700 + widgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
    }

    private fun bodyIntent(context: Context, widgetId: Int): Intent =
        Intent(context, WidgetNoteDetailService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            // Data única por widget: si no, el launcher reutiliza la misma fábrica.
            data = Uri.parse("vbwidget://detail/$widgetId")
        }

    private fun editPi(context: Context, widgetId: Int, noteId: String): PendingIntent {
        val intent = Intent(context, WidgetNoteEditActivity::class.java).apply {
            putExtra("note_id", noteId)
        }
        return PendingIntent.getActivity(
            context, 600 + widgetId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    internal fun actionPi(context: Context, widgetId: Int, action: String): PendingIntent {
        val intent = Intent(context, WidgetReaderReceiver::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("vbwidget://action/$widgetId/$action")
        }
        return PendingIntent.getBroadcast(
            context, widgetId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Plantilla de filas de la lista: el fill-in agrega note_id/pending_id. */
    internal fun rowTemplatePi(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, WidgetReaderReceiver::class.java).apply {
            action = WidgetReaderReceiver.ACTION_ROW
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("vbwidget://row/$widgetId")
        }
        // MUTABLE a propósito: el launcher combina la plantilla con el
        // fill-in de cada fila. Componente explícito + receptor no exportado.
        return PendingIntent.getBroadcast(
            context, 500 + widgetId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private fun formatTime(iso: String): String {
        if (iso.isBlank()) return ""
        val fmt = java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm")
        return try {
            fmt.format(java.time.Instant.parse(iso).atZone(java.time.ZoneId.systemDefault()))
        } catch (_: Exception) {
            try {
                fmt.format(java.time.OffsetDateTime.parse(iso).atZoneSameInstant(java.time.ZoneId.systemDefault()))
            } catch (_: Exception) {
                iso.take(16).replace('T', ' ')
            }
        }
    }

    private fun formatEpoch(ms: Long): String = try {
        java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm")
            .format(java.time.Instant.ofEpochMilli(ms).atZone(java.time.ZoneId.systemDefault()))
    } catch (_: Exception) {
        ""
    }

    // ---- Acciones (corren fuera del hilo principal).

    internal fun refresh(context: Context, widgetId: Int) {
        WidgetNotesProvider.updateNow(context, AppWidgetManager.getInstance(context), widgetId)
    }

    internal fun copy(context: Context, widgetId: Int) {
        val note = currentNote(context, widgetId) ?: return
        val ok = try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("nota", note.cuerpo))
            true
        } catch (_: Exception) {
            false
        }
        setStatus(context, widgetId, if (ok) "Contenido copiado" else "No se pudo copiar")
    }

    internal fun runAi(context: Context, widgetId: Int, action: String) {
        if (busy(context, widgetId) != null) return
        val note = currentNote(context, widgetId) ?: return
        val texto = note.cuerpo.trim()
        if (texto.isEmpty()) {
            setStatus(context, widgetId, "La nota está vacía")
            return
        }
        val key = GeminiNoteClient.readKey(context)
        if (key == null) {
            setStatus(context, widgetId, "Falta la clave de Google AI: agregala en Ajustes de la app")
            return
        }
        setBusy(context, widgetId, action)
        refresh(context, widgetId)
        try {
            val client = GeminiNoteClient(key, WIDGET_AI_TIMEOUT_MS)
            if (action == AI_TITLE) {
                val raw = client.sugerirTitulo(texto)
                val title = if (raw.length > MAX_TITLE_CHARS) raw.substring(0, MAX_TITLE_CHARS) else raw
                // Relee por si la nota cambió mientras esperaba a la IA.
                val fresh = currentNote(context, widgetId)
                val saved = fresh != null && title.isNotBlank() &&
                    NoteStore(context).saveNote(fresh.id, title, fresh.cuerpo) == NoteSaveResult.SAVED
                setBusy(context, widgetId, null)
                setStatus(context, widgetId, if (saved) "Título generado" else "No se pudo guardar el título")
                if (saved) WidgetNotesProvider.requestListRefresh(context, AppWidgetManager.getInstance(context))
            } else {
                val text = client.resumir(texto)
                setBusy(context, widgetId, null)
                setSummary(context, widgetId, text)
                setStatus(context, widgetId, null)
            }
        } catch (e: GeminiNoteClient.GeminiError) {
            setBusy(context, widgetId, null)
            setStatus(context, widgetId, "Error de IA: ${e.message ?: "desconocido"}")
        } catch (_: Exception) {
            setBusy(context, widgetId, null)
            setStatus(context, widgetId, "Error inesperado de IA")
        }
    }

    internal fun applySummary(context: Context, widgetId: Int) {
        val text = summary(context, widgetId) ?: return
        val note = currentNote(context, widgetId)
        val saved = note != null &&
            NoteStore(context).saveNote(note.id, note.titulo, text) == NoteSaveResult.SAVED
        setSummary(context, widgetId, null)
        setStatus(context, widgetId, if (saved) "Texto reemplazado por el resumen" else "No se pudo guardar el resumen")
        if (saved) WidgetNotesProvider.requestListRefresh(context, AppWidgetManager.getInstance(context))
    }

    internal fun discardSummary(context: Context, widgetId: Int) {
        setSummary(context, widgetId, null)
        setStatus(context, widgetId, null)
    }

    private fun currentNote(context: Context, widgetId: Int): VbNote? {
        val open = openState(context, widgetId) as? Open.Note ?: return null
        val snapshot = NoteStore(context).loadSnapshot()
        if (!isAuthoritativeNoteSnapshot(snapshot)) return null
        return snapshot.notes.firstOrNull { it.id == open.id }
    }
}

/** Receptor NO exportado de las acciones del widget (solo nuestros PendingIntent). */
class WidgetReaderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ROW = "com.royleguiza.voicebubblestt.widget.ROW"
        const val ACTION_CLOSE = "com.royleguiza.voicebubblestt.widget.CLOSE"
        const val ACTION_COPY = "com.royleguiza.voicebubblestt.widget.COPY"
        const val ACTION_AI_TITLE = "com.royleguiza.voicebubblestt.widget.AI_TITLE"
        const val ACTION_AI_SUMMARY = "com.royleguiza.voicebubblestt.widget.AI_SUMMARY"
        const val ACTION_SUMMARY_APPLY = "com.royleguiza.voicebubblestt.widget.SUMMARY_APPLY"
        const val ACTION_SUMMARY_DISCARD = "com.royleguiza.voicebubblestt.widget.SUMMARY_DISCARD"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val action = intent.action ?: return
        val app = context.applicationContext
        // goAsync: la IA puede tardar; el sistema da hasta ~60 s a un
        // broadcast de fondo y el cliente corta a los 20 s por tramo.
        val pending = goAsync()
        BackgroundWork.execute {
            try {
                when (action) {
                    ACTION_ROW -> {
                        val noteId = intent.getStringExtra("note_id")
                        val pendingId = intent.getStringExtra("pending_id")
                        when {
                            WidgetNoteEditActivity.isValidUuid(noteId) -> WidgetReader.openNote(app, widgetId, noteId!!)
                            WidgetNoteEditActivity.isValidUuid(pendingId) -> WidgetReader.openPending(app, widgetId, pendingId!!)
                        }
                    }
                    ACTION_CLOSE -> WidgetReader.close(app, widgetId)
                    ACTION_COPY -> WidgetReader.copy(app, widgetId)
                    ACTION_AI_TITLE -> WidgetReader.runAi(app, widgetId, WidgetReader.AI_TITLE)
                    ACTION_AI_SUMMARY -> WidgetReader.runAi(app, widgetId, WidgetReader.AI_SUMMARY)
                    ACTION_SUMMARY_APPLY -> WidgetReader.applySummary(app, widgetId)
                    ACTION_SUMMARY_DISCARD -> WidgetReader.discardSummary(app, widgetId)
                }
                WidgetReader.refresh(app, widgetId)
            } catch (_: Exception) {
            } finally {
                try {
                    pending.finish()
                } catch (_: Exception) {}
            }
        }
    }
}

/** Texto de la nota abierta como lista con scroll dentro del widget. */
class WidgetNoteDetailService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetNoteDetailFactory(
            applicationContext,
            intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID),
        )
}

private class WidgetNoteDetailFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<String> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items = try {
            val summary = WidgetReader.summary(context, widgetId)
            val open = WidgetReader.openState(context, widgetId)
            when {
                open !is WidgetReader.Open.Note -> emptyList()
                summary != null -> WidgetReader.paragraphs(summary)
                else -> {
                    val snapshot = NoteStore(context).loadSnapshot()
                    val note = snapshot.notes.firstOrNull { it.id == open.id }
                    WidgetReader.paragraphs(note?.cuerpo.orEmpty())
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_detail_paragraph)
        views.setTextViewText(R.id.widget_detail_paragraph, items.getOrNull(position).orEmpty())
        views.setTextColor(R.id.widget_detail_paragraph, ContextCompat.getColor(context, R.color.kb_label))
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}
