package com.royleguiza.voicebubblestt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

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
                updateRemoteViews(context, appWidgetManager, appWidgetId, state)
            } catch (_: Exception) {
                // Fallback mínimo: jamás dejar al launcher sin vista válida
                // ("No se puede mostrar"). Sin contenido de notas en el fallback.
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.widget_notes)
                    fallback.setViewVisibility(R.id.widget_note_1, View.GONE)
                    fallback.setViewVisibility(R.id.widget_note_2, View.GONE)
                    fallback.setViewVisibility(R.id.widget_note_0, View.VISIBLE)
                    fallback.setTextViewText(R.id.widget_note_title_0, "Notas")
                    fallback.setTextViewText(R.id.widget_note_body_0, "Toca Dictar para crear una nota")
                    fallback.setTextViewText(R.id.widget_note_time_0, "")
                    fallback.setTextViewText(R.id.widget_notes_count, "")
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

        private fun updateRemoteViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            state: String,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            val notes = NoteStore(context).load()
            val count = notes.size

            val isDark = (context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
            val primary = if (isDark) 0xFFF5F7FB.toInt() else 0xFF0B1220.toInt()
            val secondary = if (isDark) 0xFFA7B3C7.toInt() else 0xFF5B6B82.toInt()

            views.setTextViewText(R.id.widget_notes_count, "$count / 50")
            views.setTextColor(R.id.widget_notes_title, primary)
            views.setTextColor(R.id.widget_notes_count, secondary)
            views.setTextColor(R.id.widget_chrono, primary)
            views.setTextColor(R.id.widget_rec_label, primary)

            // Detecta altura por options: si el usuario estiro a 5x4, mostramos 3 notas.
            val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160)
            val visible = when {
                h < 200 -> 1
                h < 280 -> 2
                else -> 3
            }

            for (i in 0 until 3) {
                val containerId = when (i) {
                    0 -> R.id.widget_note_0
                    1 -> R.id.widget_note_1
                    else -> R.id.widget_note_2
                }
                val titleId = when (i) {
                    0 -> R.id.widget_note_title_0
                    1 -> R.id.widget_note_title_1
                    else -> R.id.widget_note_title_2
                }
                val bodyId = when (i) {
                    0 -> R.id.widget_note_body_0
                    1 -> R.id.widget_note_body_1
                    else -> R.id.widget_note_body_2
                }
                val timeId = when (i) {
                    0 -> R.id.widget_note_time_0
                    1 -> R.id.widget_note_time_1
                    else -> R.id.widget_note_time_2
                }
                views.setTextColor(titleId, primary)
                views.setTextColor(bodyId, secondary)
                views.setTextColor(timeId, secondary)
                if (i < visible && i < count) {
                    val n = notes[i]
                    val displayTitle = n.titulo.ifBlank { "Sin título" }
                    views.setViewVisibility(containerId, View.VISIBLE)
                    views.setTextViewText(titleId, displayTitle)
                    views.setTextViewText(bodyId, n.cuerpo)
                    views.setTextViewText(timeId, formatTime(n.updatedAt))
                    views.setContentDescription(containerId, "Abrir nota $displayTitle")
                    // Todo dentro del widget: overlay translucido, no MainActivity
                    val noteIntent = Intent(context, WidgetNoteEditActivity::class.java).apply {
                        putExtra("note_id", n.id)
                    }
                    val pi = PendingIntent.getActivity(
                        context, 100 + appWidgetId * 10 + i, noteIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    views.setOnClickPendingIntent(containerId, pi)
                } else if (i == 0 && count == 0) {
                    views.setViewVisibility(containerId, View.VISIBLE)
                    views.setTextViewText(titleId, "Sin notas")
                    views.setTextViewText(bodyId, "Toca Dictar para crear la primera nota")
                    views.setTextViewText(timeId, "")
                } else {
                    views.setViewVisibility(containerId, View.GONE)
                }
            }

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
            // Tap en el centro detiene y envía, X cancela.
            val pillVisible = recording || state == "transcribing" || state == "saved"
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

        private fun formatTime(iso: String): String {
            if (iso.isBlank()) return ""
            val fmt = java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm")
            return try {
                java.time.Instant.parse(iso).atZone(java.time.ZoneId.systemDefault()).let { fmt.format(it) }
            } catch (_: Exception) {
                try {
                    java.time.OffsetDateTime.parse(iso).atZoneSameInstant(java.time.ZoneId.systemDefault()).let { fmt.format(it) }
                } catch (_: Exception) {
                    try {
                        java.time.LocalDateTime.parse(iso).atZone(java.time.ZoneId.systemDefault()).let { fmt.format(it) }
                    } catch (_: Exception) {
                        // Fallback relativo
                        iso.take(16).replace('T', ' ')
                    }
                }
            }
        }
    }
}
