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
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

class WidgetNoteEditActivity : Activity() {

    private var noteId: String? = null
    private var pendingId: String? = null
    private var pendingAudioPath: String? = null
    private var player: android.media.MediaPlayer? = null
    private var playerPrepared = false

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
        pendingId = intent.getStringExtra("pending_id")

        val titleEt = findViewById<EditText>(R.id.edit_title)
        val bodyEt = findViewById<EditText>(R.id.edit_body)

        // La X cierra en ambos modos (notas y pendientes).
        findViewById<View>(R.id.btn_cancel).setOnClickListener { finish() }

        // Modo pendiente: ver + reproducir, sin editar ni transcribir.
        // La transcripción vive solo en Notas de la app (toque explícito).
        val pending = pendingId?.let { loadPending(it) }
        if (pending != null) {
            setupPendingMode(pending)
            return
        } else if (pendingId != null) {
            Toast.makeText(this, "El audio ya no está pendiente", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

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

    /**
     * Modo pendiente: el audio grabado sin red se VE y se REPRODUCE en la
     * modal del widget (play/pausa local), pero jamás se transcribe desde
     * acá: sin botón de envío, sin auto-upload. Solo lectura + audio.
     */
    private fun loadPending(id: String): VbPending? {
        return try {
            WidgetPendingStore.load(this).firstOrNull { it.id == id }
        } catch (_: Exception) {
            null
        }
    }

    private fun setupPendingMode(pending: VbPending) {
        pendingAudioPath = pending.audioPath
        findViewById<TextView>(R.id.overlay_title).text = "Audio sin transcribir"
        findViewById<View>(R.id.edit_title_wrap).visibility = View.GONE
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        bodyEt.setText(pendingInfoText(pending))
        bodyEt.isEnabled = false
        bodyEt.isFocusable = false
        // Sin teclado en este modo: no hay nada que escribir.
        findViewById<View>(R.id.btn_save).visibility = View.GONE
        findViewById<View>(R.id.btn_copy).visibility = View.GONE
        findViewById<View>(R.id.btn_play).visibility = View.VISIBLE
        findViewById<View>(R.id.btn_play_gap).visibility = View.VISIBLE
        findViewById<View>(R.id.btn_play).setOnClickListener { togglePlayback() }
    }

    private fun pendingInfoText(pending: VbPending): String {
        val whenText = try {
            val t = java.time.Instant.ofEpochMilli(pending.createdAtMs)
                .atZone(java.time.ZoneId.systemDefault())
            java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm").format(t)
        } catch (_: Exception) {
            ""
        }
        return if (whenText.isBlank()) {
            "Grabado en este teléfono. Se transcribe solo desde Notas de la app."
        } else {
            "Grabado el $whenText en este teléfono. Se transcribe solo desde Notas de la app."
        }
    }

    private fun togglePlayback() {
        val path = pendingAudioPath
        val icon = findViewById<ImageView>(R.id.widget_play_icon)
        if (path.isNullOrBlank()) {
            Toast.makeText(this, "Audio no disponible", Toast.LENGTH_SHORT).show()
            return
        }
        try {
            if (!java.io.File(path).exists()) {
                Toast.makeText(this, "Audio no disponible", Toast.LENGTH_SHORT).show()
                return
            }
        } catch (_: Exception) {
            Toast.makeText(this, "Audio no disponible", Toast.LENGTH_SHORT).show()
            return
        }
        try {
            val current = player
            if (current != null && playerPrepared && current.isPlaying) {
                current.pause()
                icon.setImageResource(R.drawable.widget_ic_play)
                findViewById<View>(R.id.btn_play).contentDescription = "Reproducir audio"
                return
            }
            if (current != null && playerPrepared) {
                current.start()
                icon.setImageResource(R.drawable.widget_ic_pause)
                findViewById<View>(R.id.btn_play).contentDescription = "Pausar audio"
                return
            }
            releasePlayer()
            val mp = android.media.MediaPlayer()
            mp.setDataSource(path)
            mp.setOnPreparedListener {
                playerPrepared = true
                try {
                    it.start()
                    icon.setImageResource(R.drawable.widget_ic_pause)
                    findViewById<View>(R.id.btn_play).contentDescription = "Pausar audio"
                } catch (_: Exception) {}
            }
            mp.setOnCompletionListener {
                try {
                    it.seekTo(0)
                } catch (_: Exception) {}
                icon.setImageResource(R.drawable.widget_ic_play)
                findViewById<View>(R.id.btn_play).contentDescription = "Reproducir audio"
            }
            mp.setOnErrorListener { _, _, _ ->
                icon.setImageResource(R.drawable.widget_ic_play)
                playerPrepared = false
                true
            }
            player = mp
            mp.prepareAsync()
        } catch (_: Exception) {
            Toast.makeText(this, "No se pudo reproducir", Toast.LENGTH_SHORT).show()
        }
    }

    private fun releasePlayer() {
        playerPrepared = false
        try {
            player?.stop()
        } catch (_: Exception) {}
        try {
            player?.release()
        } catch (_: Exception) {}
        player = null
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }

    private fun saveNote(titulo: String, cuerpo: String) {
        if (cuerpo.trim().isEmpty()) return
        try {
            // Tope como Dart `addNote`: con 50 notas no se crea una mas.
            if (noteId == null && NoteStore(this).load().size >= NoteStore.MAX_NOTES) {
                Toast.makeText(this, "Límite de 50 notas", Toast.LENGTH_SHORT).show()
                return
            }
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
            // UUID (no millis): dos notas creadas en el mismo milisegundo
            // colisionaban de id y el widget podia abrir la equivocada.
            val finalJson: String
            if (!found) {
                val obj = JSONObject()
                    .put("id", noteId ?: UUID.randomUUID().toString())
                    .put("titulo", titulo.trim())
                    .put("cuerpo", cuerpo.trim())
                    .put("createdAt", now)
                    .put("updatedAt", now)
                val wrapped = JSONArray()
                wrapped.put(obj)
                for (i in 0 until out.length()) wrapped.put(out.getJSONObject(i))
                finalJson = wrapped.toString()
            } else {
                finalJson = out.toString()
            }
            prefs.edit().putString("flutter.voice_notes_v1", finalJson).apply()
            // Write-through al archivo para que Dart y widget lean lo mismo
            // aun si la app no vuelve a abrirse antes de mirar el widget.
            NoteStore.writeFileMirror(this, finalJson)
            // Actualiza widgets sin abrir la app: todo queda en home screen.
            // Futura accion "Ver en app" lanzaria MainActivity con open_notes.
            val awm = AppWidgetManager.getInstance(this)
            WidgetNotesProvider.requestListRefresh(this, awm)
            val ids = awm.getAppWidgetIds(ComponentName(this, WidgetNotesProvider::class.java))
            for (id in ids) WidgetNotesProvider.updateOne(this, awm, id)
        } catch (_: Exception) {}
    }
}
