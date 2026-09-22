package com.royleguiza.voicebubblestt

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

class WidgetNoteEditActivity : Activity() {

    private var noteId: String? = null

    // singleTop: si llega otro tap con la modal abierta, se reutiliza en
    // vez de apilar instancias (evita las "5 ventanas" encadenadas).
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_note_edit)
        // Tocar fuera cierra sin guardar (igual que la X).
        try {
            setFinishOnTouchOutside(true)
        } catch (_: Exception) {}

        noteId = intent.getStringExtra("note_id")

        val titleEt = findViewById<EditText>(R.id.edit_title)
        val bodyEt = findViewById<EditText>(R.id.edit_body)

        val notes = NoteStore(this).load()
        val note = notes.firstOrNull { it.id == noteId }
        titleEt.setText(note?.titulo.orEmpty())
        bodyEt.setText(note?.cuerpo.orEmpty())

        // La modal pertenece al teclado: se ancla sobre él con el mismo
        // margen lateral a ambos lados y 12dp por encima del teclado.
        // adjustResize puede no aplicarse en temas translúcidos, se fuerza.
        try {
            window.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or
                    WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
            )
        } catch (_: Exception) {}
        try {
            val root = findViewById<View>(R.id.overlay_root)
            val side = root.paddingLeft
            root.setOnApplyWindowInsetsListener { v, insets ->
                @Suppress("DEPRECATION")
                val imeBottom = insets.systemWindowInsetBottom
                v.setPadding(side, v.paddingTop, side, imeBottom)
                insets
            }
        } catch (_: Exception) {}

        // Foco directo en el contenido + teclado automático, sin clics extra.
        bodyEt.requestFocus()
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(bodyEt, InputMethodManager.SHOW_IMPLICIT)
        } catch (_: Exception) {}

        findViewById<View>(R.id.btn_cancel).setOnClickListener { finish() }
        findViewById<View>(R.id.btn_copy).setOnClickListener {
            // Copia el contenido (cuerpo) en edición, nunca el título.
            val text = bodyEt.text.toString()
            if (text.isBlank()) {
                Toast.makeText(this, "Sin contenido para copiar", Toast.LENGTH_SHORT).show()
            } else {
                try {
                    val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    cm.setPrimaryClip(ClipData.newPlainText("nota", text))
                    Toast.makeText(this, "Contenido copiado", Toast.LENGTH_SHORT).show()
                } catch (_: Exception) {
                    Toast.makeText(this, "No se pudo copiar", Toast.LENGTH_SHORT).show()
                }
            }
        }
        findViewById<View>(R.id.btn_save).setOnClickListener {
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
