package com.royleguiza.voicebubblestt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class WidgetRowProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateOne(context, appWidgetManager, id)
        }
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
            val views = RemoteViews(context.packageName, R.layout.widget_row)
            val intent = Intent(context, WidgetDictationService::class.java).apply {
                action = WidgetDictationService.ACTION_TOGGLE
                putExtra(WidgetDictationService.EXTRA_WIDGET_ID, appWidgetId)
            }
            val pi = PendingIntent.getService(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_row_mic, pi)
            views.setOnClickPendingIntent(R.id.widget_row_title, pi)
            when (state) {
                "recording" -> {
                    views.setTextViewText(R.id.widget_row_title, "Grabando")
                    views.setTextViewText(R.id.widget_row_sub, "Toca para detener")
                    views.setViewVisibility(R.id.widget_row_time, android.view.View.GONE)
                }
                "transcribing" -> {
                    views.setTextViewText(R.id.widget_row_title, "Procesando")
                    views.setTextViewText(R.id.widget_row_sub, "")
                    views.setViewVisibility(R.id.widget_row_time, android.view.View.GONE)
                }
                "saved" -> {
                    views.setTextViewText(R.id.widget_row_title, "Nota guardada")
                    views.setTextViewText(R.id.widget_row_sub, "")
                    views.setViewVisibility(R.id.widget_row_time, android.view.View.GONE)
                }
                "error" -> {
                    views.setTextViewText(R.id.widget_row_title, "Permiso micrófono")
                    views.setTextViewText(R.id.widget_row_sub, "Actívalo en Ajustes")
                    views.setViewVisibility(R.id.widget_row_time, android.view.View.GONE)
                }
                else -> {
                    views.setTextViewText(R.id.widget_row_title, "Tocar para dictar")
                    views.setTextViewText(R.id.widget_row_sub, "")
                    views.setViewVisibility(R.id.widget_row_time, android.view.View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
