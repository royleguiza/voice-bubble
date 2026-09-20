package com.royleguiza.voicebubblestt

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import org.json.JSONArray
import org.json.JSONObject

class WidgetNoteEditActivity : Activity() {

    private var noteId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_note_edit)

        noteId = intent.getStringExtra("note_id")

        val titleEt = findViewById<EditText>(R.id.edit_title)
        val bodyEt = findViewById<EditText>(R.id.edit_body)

        val notes = NoteStore(this).load()
        val note = notes.firstOrNull { it.id == noteId }
        titleEt.setText(note?.titulo.orEmpty())
        bodyEt.setText(note?.cuerpo.orEmpty())
        titleEt.hint = "Sin título"

        findViewById<Button>(R.id.btn_cancel).setOnClickListener { finish() }
        findViewById<Button>(R.id.btn_save).setOnClickListener {
            saveNote(titleEt.text.toString(), bodyEt.text.toString())
            finish()
        }
    }

    private fun saveNote(titulo: String, cuerpo: String) {
        if (cuerpo.trim().isEmpty()) return
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.voice_notes_v1", null)
            val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            val now = java.time.Instant.now().toString()
            val out = JSONArray()
            var found = false
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optString("id") == noteId) {
                    o.put("titulo", titulo.trim())
                    o.put("cuerpo", cuerpo.trim())
                    o.put("updatedAt", now)
                    found = true
                }
                out.put(o)
            }
            if (!found) {
                val obj = JSONObject()
                    .put("id", noteId ?: "${System.currentTimeMillis()}")
                    .put("titulo", titulo.trim())
                    .put("cuerpo", cuerpo.trim())
                    .put("createdAt", now)
                    .put("updatedAt", now)
                val wrapped = JSONArray()
                wrapped.put(obj)
                for (i in 0 until out.length()) wrapped.put(out.getJSONObject(i))
                prefs.edit().putString("flutter.voice_notes_v1", wrapped.toString()).apply()
            } else {
                prefs.edit().putString("flutter.voice_notes_v1", out.toString()).apply()
            }
            // Actualiza widgets sin abrir la app: todo queda en home screen.
            // Futura accion "Ver en app" lanzaria MainActivity con open_notes.
            val awm = AppWidgetManager.getInstance(this)
            val ids = awm.getAppWidgetIds(ComponentName(this, WidgetNotesProvider::class.java))
            for (id in ids) WidgetNotesProvider.updateOne(this, awm, id)
        } catch (_: Exception) {}
    }
}
