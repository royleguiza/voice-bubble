package com.royleguiza.voicebubblestt

import android.content.Context
import android.widget.RemoteViews

/**
 * Textos fijos del widget puestos desde el código (Ruta IA, etapa 4).
 *
 * Un `@string/…` escrito en el XML de un diseño de RemoteViews lo resuelve
 * el LAUNCHER al inflarlo, con el idioma del teléfono y no con el idioma
 * por app elegido en VoiceBubble: con la app en inglés y el teléfono en
 * español, «Descartar / Reemplazar» salían en español. Por eso cada
 * RemoteViews del widget pasa por acá y todo texto o descripción accesible
 * se resuelve en NUESTRO proceso (que sí tiene el idioma de la app; en
 * Android 9–12 con un contexto de [AppLocale.wrap]).
 *
 * Regla: todo `@string` nuevo en `widget_*.xml` (salvo
 * `activity_widget_note_edit.xml`, que infla la propia app) se repite acá.
 */
internal object WidgetTexts {

    /** Lista de notas (`widget_notes.xml`). Llamar antes de los textos de estado. */
    fun notes(context: Context, views: RemoteViews) {
        views.setTextViewText(R.id.widget_notes_title, context.getString(R.string.widget_notes_title))
        views.setTextViewText(R.id.widget_notes_empty, context.getString(R.string.widget_notes_empty))
        val add = context.getString(R.string.widget_add_note)
        views.setContentDescription(R.id.widget_notes_add, add)
        views.setContentDescription(R.id.widget_notes_add_right, add)
        val dictate = context.getString(R.string.widget_dictate_note)
        views.setContentDescription(R.id.widget_notes_mic, dictate)
        views.setContentDescription(R.id.widget_notes_mic_left, dictate)
        views.setContentDescription(R.id.widget_voice_box, context.getString(R.string.widget_recording))
        views.setContentDescription(R.id.widget_cancel, context.getString(R.string.widget_cancel_recording))
    }

    /** Nota o pendiente abierto dentro del widget (`widget_note_detail.xml`). */
    fun detail(context: Context, views: RemoteViews) {
        views.setContentDescription(R.id.widget_detail_back, context.getString(R.string.widget_detail_back))
        views.setTextViewText(R.id.widget_detail_title, context.getString(R.string.widget_untitled))
        views.setContentDescription(R.id.widget_detail_edit, context.getString(R.string.widget_edit_note))
        views.setTextViewText(R.id.widget_detail_empty, context.getString(R.string.widget_note_empty))
        views.setContentDescription(R.id.widget_detail_copy, context.getString(R.string.widget_copy_content))
        views.setContentDescription(R.id.widget_detail_ai_title, context.getString(R.string.widget_ai_title))
        views.setContentDescription(R.id.widget_detail_ai_summary, context.getString(R.string.widget_ai_summary))
        views.setTextViewText(R.id.widget_detail_summary_discard, context.getString(R.string.widget_discard))
        views.setTextViewText(R.id.widget_detail_summary_apply, context.getString(R.string.widget_replace))
        views.setTextViewText(R.id.widget_detail_open_pending, context.getString(R.string.widget_listen_transcribe))
    }

    /** Fila de nota (`widget_note_item.xml`). */
    fun noteItem(context: Context, views: RemoteViews) {
        views.setTextViewText(R.id.widget_item_title, context.getString(R.string.widget_untitled))
        views.setContentDescription(R.id.widget_item_audio, context.getString(R.string.widget_with_original_audio))
    }

    /** Fila de audio pendiente (`widget_pending_item.xml`). */
    fun pendingItem(context: Context, views: RemoteViews) {
        views.setTextViewText(R.id.widget_pending_title, context.getString(R.string.widget_pending_untranscribed))
        views.setTextViewText(R.id.widget_pending_time, context.getString(R.string.widget_pending_tap_transcribe))
    }
}
