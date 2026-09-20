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
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            val notes = NoteStore(context).load()
            val count = notes.size

            views.setTextViewText(R.id.widget_notes_count, "$count / 50")

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
                if (i < visible && i < count) {
                    val n = notes[i]
                    views.setViewVisibility(containerId, View.VISIBLE)
                    views.setTextViewText(titleId, n.titulo.ifBlank { "Nota" })
                    views.setTextViewText(bodyId, n.cuerpo)
                    views.setTextViewText(timeId, formatTime(n.updatedAt))
                    val noteIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                        putExtra("widget_action", "open_note")
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

            val dictateIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("widget_action", "dictate_note")
            }
            val dictatePi = PendingIntent.getActivity(
                context, appWidgetId, dictateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_notes_mic, dictatePi)
            views.setOnClickPendingIntent(R.id.widget_notes_add, dictatePi)

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
            return try {
                val dt = java.time.Instant.parse(iso)
                val local = dt.atZone(java.time.ZoneId.systemDefault())
                val fmt = java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm")
                fmt.format(local)
            } catch (_: Exception) {
                iso.take(16)
            }
        }
    }
}
