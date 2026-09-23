package com.royleguiza.voicebubblestt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

class WidgetNotesProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateOne(context, appWidgetManager, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?,
    ) {
        updateOne(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    companion object {
        fun updateOne(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) = updateOneWithState(context, appWidgetManager, appWidgetId, "idle")

        fun updateOneWithState(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            state: String,
        ) {
            try {
                // La colección re-consulta sus datos (notas + pendientes).
                requestListRefresh(context, appWidgetManager)
                updateRemoteViews(context, appWidgetManager, appWidgetId, state)
            } catch (_: Exception) {
                // Fallback mínimo: jamás dejar al launcher sin vista válida
                // ("No se puede mostrar"). Sin contenido de notas en el fallback.
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.widget_notes)
                    fallback.setTextViewText(R.id.widget_notes_title, "Notas")
                    fallback.setTextViewText(R.id.widget_notes_count, "")
                    fallback.setViewVisibility(R.id.widget_pending_count, View.GONE)
                    fallback.setViewVisibility(R.id.widget_notes_list, View.GONE)
                    fallback.setViewVisibility(R.id.widget_notes_empty, View.VISIBLE)
                    fallback.setTextViewText(R.id.widget_notes_empty, "Toca Dictar para crear una nota")
                    fallback.setViewVisibility(R.id.widget_rec_pill, View.GONE)
                    fallback.setViewVisibility(R.id.widget_bottom_spacer, View.VISIBLE)
                    fallback.setViewVisibility(R.id.widget_notes_add, View.VISIBLE)
                    fallback.setViewVisibility(R.id.widget_notes_add_right, View.GONE)
                    fallback.setViewVisibility(R.id.widget_notes_mic_left, View.GONE)
                    fallback.setViewVisibility(R.id.widget_notes_mic, View.VISIBLE)
                    appWidgetManager.updateAppWidget(appWidgetId, fallback)
                } catch (_: Exception) { }
            }
        }

        /** La ListView re-consulta notas + pendientes en su fábrica. */
        fun requestListRefresh(context: Context, appWidgetManager: AppWidgetManager) {
            try {
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, WidgetNotesProvider::class.java),
                )
                if (ids.isNotEmpty()) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(ids, R.id.widget_notes_list)
                }
            } catch (_: Exception) {}
        }

        private fun updateRemoteViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            state: String,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            val notes = NoteStore(context).load()
            val count = notes.size

            // Colores adaptativos claro/oscuro desde la fuente unica
            // (res/values + values-night): el cambio automatico por horario
            // del sistema resuelve el valor vigente sin hex duplicados.
            val primary = ContextCompat.getColor(context, R.color.kb_label)
            val secondary = ContextCompat.getColor(context, R.color.kb_label_secondary)

            views.setTextViewText(R.id.widget_notes_count, "$count / 50")
            views.setTextColor(R.id.widget_notes_title, primary)
            views.setTextColor(R.id.widget_notes_count, secondary)
            views.setTextColor(R.id.widget_pending_count, secondary)
            views.setTextColor(R.id.widget_chrono, primary)
            views.setTextColor(R.id.widget_rec_label, primary)

            // Pendientes offline (cola Dart + widget): el audio grabado sin
            // red se ve también en el widget, no solo en la app.
            val pending = WidgetPendingStore.load(context).size
            if (pending > 0) {
                views.setViewVisibility(R.id.widget_pending_count, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_pending_count,
                    if (pending == 1) "· 1 pendiente" else "· $pending pendientes",
                )
            } else {
                views.setViewVisibility(R.id.widget_pending_count, View.GONE)
                views.setTextViewText(R.id.widget_pending_count, "")
            }

            // Colección con scroll: pendientes arriba + notas debajo, sin
            // tope visual (la altura del widget solo cambia cuánto se ve
            // sin desplazar). Los taps van directo a la modal del widget
            // (un toque abre: nota → ver/editar, pendiente → ver/escuchar).
            val listIntent = Intent(context, WidgetNotesListService::class.java)
            views.setRemoteAdapter(R.id.widget_notes_list, listIntent)
            views.setEmptyView(R.id.widget_notes_list, R.id.widget_notes_empty)
            views.setTextColor(R.id.widget_notes_empty, secondary)
            val rowTemplate = Intent(context, WidgetNoteEditActivity::class.java)
            // MUTABLE a proposito: el launcher combina esta plantilla con el
            // fill-in de cada fila (note_id/pending_id); con IMMUTABLE el
            // sistema ignora el fill-in y la modal abria vacia. Componente
            // fijo + actividad no exportada: sin superficie extra.
            val rowTemplatePi = PendingIntent.getActivity(
                context, 500 + appWidgetId, rowTemplate,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setPendingIntentTemplate(R.id.widget_notes_list, rowTemplatePi)

            // Mic posicion configurable: izq/der desde Ajustes (flutter.widget_mic_position).
            // El + queda siempre del lado opuesto (derecha por defecto: + abajo-izq).
            val micPos = try {
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .getString("flutter.widget_mic_position", "right") ?: "right"
            } catch (_: Exception) { "right" }
            val micLeft = micPos == "left"
            val recording = state == "recording"

            // Píldora de estado estilo teclado: en reposo no hay texto (solo
            // + y mic); la píldora roja aparece al grabar/procesar/guardar.
            // "pending" = offline encolado: el audio quedó guardado para
            // transcribirlo desde la app. Tap en el centro detiene y envía,
            // X cancela.
            val pillVisible = recording || state == "transcribing" || state == "saved" || state == "pending"
            views.setViewVisibility(
                R.id.widget_notes_add,
                if (!micLeft) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_notes_add_right,
                if (micLeft) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_notes_mic_left,
                if (!pillVisible && micLeft) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_notes_mic,
                if (!pillVisible && !micLeft) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_rec_pill,
                if (pillVisible) View.VISIBLE else View.GONE,
            )
            // En reposo el espaciador empuja el mic al borde opuesto del +.
            views.setViewVisibility(
                R.id.widget_bottom_spacer,
                if (pillVisible) View.GONE else View.VISIBLE,
            )
            views.setViewVisibility(
                R.id.widget_rec_dot,
                if (recording) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_chrono,
                if (recording) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_cancel,
                if (recording) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(
                R.id.widget_rec_label,
                when (state) {
                    "transcribing" -> "Procesando"
                    "saved" -> "Nota guardada"
                    "pending" -> "Audio guardado"
                    else -> "Grabando"
                },
            )
            if (recording) {
                views.setChronometer(
                    R.id.widget_chrono, android.os.SystemClock.elapsedRealtime(), null, true,
                )
            }

            val dictateIntent = Intent(context, WidgetDictationService::class.java).apply {
                action = WidgetDictationService.ACTION_TOGGLE
                putExtra(WidgetDictationService.EXTRA_WIDGET_ID, appWidgetId)
            }
            val dictatePi = PendingIntent.getService(
                context, appWidgetId, dictateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_notes_mic, dictatePi)
            views.setOnClickPendingIntent(R.id.widget_notes_mic_left, dictatePi)
            // Centro de la píldora detiene y envía (igual que el teclado).
            views.setOnClickPendingIntent(R.id.widget_rec_pill, dictatePi)
            views.setOnClickPendingIntent(R.id.widget_rec_dot, dictatePi)
            views.setOnClickPendingIntent(R.id.widget_chrono, dictatePi)
            views.setOnClickPendingIntent(R.id.widget_rec_label, dictatePi)

            val cancelIntent = Intent(context, WidgetDictationService::class.java).apply {
                action = WidgetDictationService.ACTION_CANCEL
            }
            val cancelPi = PendingIntent.getService(
                context, 400 + appWidgetId, cancelIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_cancel, cancelPi)
            // Add (+) abre el overlay de edición con teclado, sin salir del
            // widget ni abrir la app (RemoteViews no admite EditText inline).
            val addIntent = Intent(context, WidgetNoteEditActivity::class.java)
            val addPi = PendingIntent.getActivity(
                context, 300 + appWidgetId, addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_notes_add, addPi)
            views.setOnClickPendingIntent(R.id.widget_notes_add_right, addPi)

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("widget_action", "open_notes")
            }
            val openPi = PendingIntent.getActivity(
                context, 200 + appWidgetId, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_notes_title, openPi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
