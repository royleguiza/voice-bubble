package com.royleguiza.voicebubblestt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class WidgetCompactProvider : AppWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.widget_compact)
            val intent = Intent(context, WidgetDictationService::class.java).apply {
                action = WidgetDictationService.ACTION_TOGGLE
                putExtra(WidgetDictationService.EXTRA_WIDGET_ID, appWidgetId)
            }
            val pi = PendingIntent.getService(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_mic_wrap, pi)
            views.setOnClickPendingIntent(R.id.widget_mic_icon, pi)
            when (state) {
                "recording" -> {
                    views.setTextViewText(R.id.widget_subtitle, "Grabando")
                    views.setTextViewText(R.id.widget_hint, "Toca para detener")
                }
                "transcribing" -> {
                    views.setTextViewText(R.id.widget_subtitle, "Procesando")
                    views.setTextViewText(R.id.widget_hint, "")
                }
                "saved" -> {
                    views.setTextViewText(R.id.widget_subtitle, "Nota guardada")
                    views.setTextViewText(R.id.widget_hint, "")
                }
                "error" -> {
                    views.setTextViewText(R.id.widget_subtitle, "Permiso micrófono")
                    views.setTextViewText(R.id.widget_hint, "Actívalo en Ajustes")
                }
                else -> {
                    views.setTextViewText(R.id.widget_subtitle, "Tocar para dictar")
                    views.setTextViewText(R.id.widget_hint, "")
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
