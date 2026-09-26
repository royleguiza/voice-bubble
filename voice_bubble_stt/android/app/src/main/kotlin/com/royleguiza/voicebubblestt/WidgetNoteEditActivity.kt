package com.royleguiza.voicebubblestt

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONArray

class WidgetNoteEditActivity : Activity() {

    companion object {
        private val UUID_REGEX =
            Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

        internal fun isValidUuid(raw: String?): Boolean {
            return raw != null && UUID_REGEX.matches(raw)
        }

        internal fun resolveExistingNoteState(
            snapshot: NoteStoreLoad,
            id: String,
        ): ExistingNoteUiState {
            if (!isAuthoritativeNoteSnapshot(snapshot)) {
                return ExistingNoteUiState.UNAVAILABLE
            }
            return if (snapshot.notes.any { it.id == id }) {
                ExistingNoteUiState.READY
            } else {
                ExistingNoteUiState.NOT_FOUND
            }
        }
    }

    private data class ExistingNoteResult(
        val snapshot: NoteStoreLoad,
        val note: VbNote?,
    )

    private var noteId: String? = null
    private var pendingId: String? = null
    private var pendingAudioPath: String? = null
    private var player: android.media.MediaPlayer? = null
    private var playerPrepared = false
    private val mutationInProgress = AtomicBoolean(false)
    private val playerLoading = AtomicBoolean(false)
    private var editorWritable = false
    private var noteReadyForSave = false
    private var deleteAvailable = false
    private var pendingMode = false
    private val transcribeInProgress = AtomicBoolean(false)

    // C-40: expansión del cuerpo por arrastre del tirador.
    private var cachedBodyMinPx = 0
    private var bodyMaxPx = 0
    private var dragPointer = -1
    private var dragStartY = 0f
    private var dragStartH = 0
    private var lastTapUp = 0L
    private var lastTapY = 0f

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
        // La ventana es translúcida a pantalla completa: el toque "fuera"
        // cae dentro de la ventana sobre overlay_root, así que se cierra
        // a mano (la tarjeta interior lo consume con clickable=true).
        try {
            findViewById<View>(R.id.overlay_root).setOnClickListener { finish() }
        } catch (_: Exception) {}

        val rawNoteId = intent.getStringExtra("note_id")
        val rawPendingId = intent.getStringExtra("pending_id")
        if (rawNoteId != null && !isValidUuid(rawNoteId)) {
            finish()
            return
        }
        if (rawPendingId != null && !isValidUuid(rawPendingId)) {
            finish()
            return
        }
        noteId = rawNoteId
        pendingId = rawPendingId

        findViewById<View>(R.id.btn_cancel).setOnClickListener { finish() }

        val pending = pendingId
        if (pending != null) {
            setEditorState(writable = false, ready = false, deletable = false)
            BackgroundWork.executeWithResult(
                { loadPending(pending) },
                { result ->
                    val loaded = result?.pending
                    when {
                        result == null || result.unavailable -> showPendingUnavailable()
                        loaded != null -> setupPendingMode(loaded)
                        else -> {
                            Toast.makeText(this, "El audio ya no está pendiente", Toast.LENGTH_SHORT).show()
                            finish()
                        }
                    }
                },
            )
            return
        }

        setupEditorWindow()
        val titleEt = findViewById<EditText>(R.id.edit_title)
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        // Un solo atrás cierra igual que la X aunque el teclado esté
        // visible (onKeyPreIme corre antes de que el IME consuma el gesto).
        (titleEt as? DismissEditText)?.onBackWhileEditing = { hideKeyboardAndFinish() }
        (bodyEt as? DismissEditText)?.onBackWhileEditing = { hideKeyboardAndFinish() }
        findViewById<View>(R.id.btn_copy).setOnClickListener {
            val text = bodyEt.text.toString()
            if (text.isBlank()) {
                Toast.makeText(this, "Sin contenido para copiar", Toast.LENGTH_SHORT).show()
            } else {
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("nota", text))
                    Toast.makeText(this, "Contenido copiado", Toast.LENGTH_SHORT).show()
                } catch (_: Exception) {
                    Toast.makeText(this, "No se pudo copiar", Toast.LENGTH_SHORT).show()
                }
            }
        }
        findViewById<View>(R.id.btn_save).setOnClickListener {
            requestSave(titleEt.text.toString(), bodyEt.text.toString())
        }
        findViewById<View>(R.id.btn_delete).setOnClickListener { confirmDelete() }

        val editingId = noteId
        if (editingId == null) {
            setEditorState(writable = true, ready = true, deletable = false)
            focusEditor()
            return
        }

        setEditorState(writable = false, ready = false, deletable = false)
        BackgroundWork.executeWithResult(
            { loadExistingNote(editingId) },
            { result ->
                if (result == null) {
                    showExistingUnavailable()
                    return@executeWithResult
                }
                when (WidgetNoteEditActivity.resolveExistingNoteState(result.snapshot, editingId)) {
                    ExistingNoteUiState.UNAVAILABLE -> showExistingUnavailable()
                    ExistingNoteUiState.NOT_FOUND -> {
                        Toast.makeText(this, "La nota ya no existe", Toast.LENGTH_SHORT).show()
                        finish()
                    }
                    ExistingNoteUiState.READY -> {
                        val loaded = result.note
                        if (loaded == null) {
                            showExistingUnavailable()
                            return@executeWithResult
                        }
                        titleEt.setText(loaded.titulo)
                        bodyEt.setText(loaded.cuerpo)
                        setEditorState(writable = true, ready = true, deletable = true)
                        focusEditor()
                    }
                }
            },
        )
    }

    private fun setupEditorWindow() {
        try {
            window.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or
                    WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
            )
        } catch (_: Exception) {}
        try {
            val root = findViewById<View>(R.id.overlay_root)
            val side = root.paddingLeft
            root.setOnApplyWindowInsetsListener { view, insets ->
                @Suppress("DEPRECATION")
                val imeBottom = insets.systemWindowInsetBottom
                view.setPadding(side, view.paddingTop, side, imeBottom)
                // El área visible cambió (teclado/rotación): re-clampear.
                recomputeBodyMax()
                insets
            }
        } catch (_: Exception) {}
        setupExpandableBody()
    }

    /** Máximo del cuerpo: lo visible menos el cromo de la tarjeta. */
    private fun bodyMinPx(): Int {
        if (cachedBodyMinPx > 0) return cachedBodyMinPx
        val density = resources.displayMetrics.density
        if (density <= 0) return 0
        cachedBodyMinPx = (120 * density).toInt()
        return cachedBodyMinPx
    }

    private fun recomputeBodyMax() {
        try {
            val density = resources.displayMetrics.density
            if (density <= 0) return
            val min = bodyMinPx()
            if (min <= 0) return
            val root = findViewById<View>(R.id.overlay_root) ?: return
            val card = findViewById<View>(R.id.note_card) ?: return
            val body = findViewById<View>(R.id.edit_body) ?: return
            if (root.height <= 0 || card.height <= 0 || body.height <= 0) return
            val margin = (12 * density).toInt()
            bodyMaxPx = computeBodyMaxPx(
                root.height, root.paddingBottom,
                card.height - body.height, margin, margin, min,
            )
            val lp = body.layoutParams ?: return
            if (lp.height > 0 && (lp.height < min || lp.height > bodyMaxPx)) {
                lp.height = clampBodyHeight(lp.height, min, bodyMaxPx)
                body.requestLayout()
            }
        } catch (_: Exception) {
        }
    }

    /**
     * C-40: el tirador amplía SOLO el cuerpo (título y botonera fijos).
     * Arrastrar sigue al dedo 1:1 con clamp; doble-tap alterna min/max.
     * Multi-touch: se sigue únicamente el primer puntero.
     */
    private fun setupExpandableBody() {
        val handle = try {
            findViewById<View>(R.id.btn_expand_handle)
        } catch (_: Exception) {
            null
        } ?: return
        recomputeBodyMax()
        handle.setOnTouchListener { _, event ->
            try {
                val body = findViewById<View>(R.id.edit_body) ?: return@setOnTouchListener false
                val density = resources.displayMetrics.density
                if (density <= 0) return@setOnTouchListener false
                val min = bodyMinPx()
                if (min <= 0) return@setOnTouchListener false
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        recomputeBodyMax()
                        dragPointer = event.getPointerId(event.actionIndex)
                        dragStartY = yOf(event, dragPointer)
                        dragStartH = body.height
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        if (dragPointer < 0) return@setOnTouchListener false
                        val y = yOf(event, dragPointer)
                        if (y.isNaN()) return@setOnTouchListener true
                        val lp = body.layoutParams ?: return@setOnTouchListener false
                        lp.height = clampBodyHeight(
                            dragStartH + (dragStartY - y).toInt(), min, bodyMaxPx,
                        )
                        body.requestLayout()
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        val now = SystemClock.uptimeMillis()
                        val tapH = 10 * density
                        if (dragPointer >= 0 && now - lastTapUp < 300 &&
                            kotlin.math.abs(event.rawY - lastTapY) < tapH
                        ) {
                            toggleBodyHeight()
                            lastTapUp = 0L
                        } else {
                            lastTapUp = now
                            lastTapY = event.rawY
                        }
                        dragPointer = -1
                        true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        dragPointer = -1
                        true
                    }
                    MotionEvent.ACTION_POINTER_UP -> {
                        if (event.getPointerId(event.actionIndex) == dragPointer) {
                            dragPointer = -1
                        }
                        true
                    }
                    else -> false
                }
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun yOf(event: MotionEvent, pointerId: Int): Float {
        val idx = event.findPointerIndex(pointerId)
        if (idx < 0) return Float.NaN
        return event.getY(idx)
    }

    private fun toggleBodyHeight() {
        try {
            val body = findViewById<View>(R.id.edit_body) ?: return
            val min = bodyMinPx()
            if (min <= 0) return
            recomputeBodyMax()
            val lp = body.layoutParams ?: return
            lp.height = if (body.height >= bodyMaxPx - 2) min else bodyMaxPx
            body.requestLayout()
        } catch (_: Exception) {
        }
    }

    private fun focusEditor() {
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        bodyEt.requestFocus()
        try {
            val input = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            input.showSoftInput(bodyEt, InputMethodManager.SHOW_IMPLICIT)
        } catch (_: Exception) {}
    }

    /** Cierra sin guardar igual que la X (toque fuera o atrás único). */
    private fun hideKeyboardAndFinish() {
        try {
            val input = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            val view = currentFocus ?: findViewById(R.id.edit_body)
            input.hideSoftInputFromWindow(view?.windowToken, 0)
        } catch (_: Exception) {}
        finish()
    }

    private fun loadExistingNote(id: String): ExistingNoteResult {
        val snapshot = NoteStore(this).loadSnapshot()
        val authoritative = isAuthoritativeNoteSnapshot(snapshot)
        return ExistingNoteResult(
            snapshot = snapshot,
            note = if (authoritative) snapshot.notes.firstOrNull { it.id == id } else null,
        )
    }

    private fun showExistingUnavailable() {
        setEditorState(writable = false, ready = false, deletable = false)
        Toast.makeText(this, "No se pudo leer la nota; no se perdió nada", Toast.LENGTH_SHORT).show()
    }

    private fun showPendingUnavailable() {
        setEditorState(writable = false, ready = false, deletable = false)
        Toast.makeText(this, "No se pudo leer el audio; no se perdió nada", Toast.LENGTH_SHORT).show()
    }

    private fun loadPending(id: String): PendingLoadResult {
        return try {
            val prefs = getSharedPreferences(NoteStore.PREFS_NAME, Context.MODE_PRIVATE)
            parseWidgetPending(prefs.getString(NoteStore.PENDING_KEY, null), id) { path ->
                val audio = File(path)
                audio.exists() && audio.isFile
            }
        } catch (_: Exception) {
            PendingLoadResult(null, true)
        }
    }

    private fun setupPendingMode(pending: VbPending) {
        pendingMode = true
        pendingAudioPath = pending.audioPath
        findViewById<TextView>(R.id.overlay_title).text = "Audio sin transcribir"
        findViewById<View>(R.id.edit_title_wrap).visibility = View.GONE
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        bodyEt.setText(pendingInfoText(pending))
        findViewById<View>(R.id.slot_save).visibility = View.GONE
        findViewById<View>(R.id.slot_copy).visibility = View.GONE
        findViewById<View>(R.id.slot_play).visibility = View.VISIBLE
        findViewById<View>(R.id.btn_play).setOnClickListener { togglePlayback() }
        // C-39: transcribir directo desde el widget con la red vigente
        // (datos o Wi-Fi), sin pasar por Notas de la app.
        findViewById<View>(R.id.slot_transcribe).visibility = View.VISIBLE
        findViewById<View>(R.id.btn_transcribe).setOnClickListener { requestPendingTranscription() }
        setEditorState(writable = false, ready = false, deletable = false)
    }

    /**
     * C-39: reintento de transcripción del pendiente desde la propia
     * modal. En éxito guarda la nota (texto + audio promovido), retira
     * el pendiente, refresca widgets y cierra; en fallo avisa y conserva
     * el audio para reintentar. Corre fuera del main; la UI solo por post.
     */
    private fun requestPendingTranscription() {
        val id = pendingId ?: return
        val path = pendingAudioPath ?: return
        if (!transcribeInProgress.compareAndSet(false, true)) return
        setTranscribeBusy(true)
        BackgroundWork.execute {
            try {
                val wav = try {
                    File(path).readBytes()
                } catch (_: Exception) {
                    null
                }
                if (wav == null || wav.isEmpty()) {
                    failPendingTranscription("Audio no disponible")
                    return@execute
                }
                val client = try {
                    SpeechToTextClient(this)
                } catch (_: Exception) {
                    null
                }
                val config = try {
                    client?.loadConfig()
                } catch (_: Exception) {
                    null
                }
                if (client == null || config == null || config.apiKey.isBlank()) {
                    failPendingTranscription("Configurá tu clave en la app")
                    return@execute
                }
                client.transcribe(
                    wav,
                    config,
                    onDone = { text ->
                        if (text.isNullOrBlank()) {
                            failPendingTranscription("No se pudo transcribir; el audio se conserva")
                            return@transcribe
                        }
                        val keptPath = promotePendingWav(id, wav)
                        val saved = keptPath != null &&
                            NoteStore(this).addUntitledNote(text.trim(), keptPath) == NoteSaveResult.SAVED
                        if (!saved) {
                            if (keptPath != null) {
                                try {
                                    File(keptPath).delete()
                                } catch (_: Exception) {
                                }
                            }
                            failPendingTranscription("Nota no guardada; el audio se conserva")
                            return@transcribe
                        }
                        NoteStore(this).removePending(id)
                        try {
                            File(path).delete()
                        } catch (_: Exception) {
                        }
                        BackgroundWork.execute { refreshNoteWidgets() }
                        transcribeInProgress.set(false)
                        BackgroundWork.postMain {
                            Toast.makeText(this, "Nota guardada", Toast.LENGTH_SHORT).show()
                            finish()
                        }
                    },
                    onError = { _, message ->
                        failPendingTranscription(message)
                    },
                )
            } catch (_: Exception) {
                failPendingTranscription("No se pudo transcribir; el audio se conserva")
            }
        }
    }

    private fun failPendingTranscription(message: String) {
        transcribeInProgress.set(false)
        BackgroundWork.postMain {
            setTranscribeBusy(false)
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun setTranscribeBusy(busy: Boolean) {
        try {
            findViewById<View>(R.id.btn_transcribe).isEnabled = !busy
        } catch (_: Exception) {
        }
    }

    /** Copia el WAV pendiente a notes_audio como audio conservado de nota. */
    private fun promotePendingWav(id: String, wav: ByteArray): String? {
        return try {
            if (!isValidUuid(id)) return null
            val dir = File(filesDir, "notes_audio")
            if (!dir.isDirectory && !dir.mkdirs() && !dir.isDirectory) return null
            val tmp = File.createTempFile("pending_", ".tmp", dir)
            try {
                java.io.FileOutputStream(tmp).use { it.write(wav) }
                val dest = File(dir, "${java.util.UUID.randomUUID()}.wav")
                if (!tmp.renameTo(dest)) return null
                dest.path
            } finally {
                try {
                    if (tmp.exists()) tmp.delete()
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun pendingInfoText(pending: VbPending): String {
        val whenText = try {
            val time = java.time.Instant.ofEpochMilli(pending.createdAtMs)
                .atZone(java.time.ZoneId.systemDefault())
            java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm").format(time)
        } catch (_: Exception) {
            ""
        }
        return if (whenText.isBlank()) {
            "Grabado en este teléfono. Transcribilo acá con tus datos o Wi-Fi."
        } else {
            "Grabado el $whenText en este teléfono. Transcribilo acá con tus datos o Wi-Fi."
        }
    }

    private fun togglePlayback() {
        val current = player
        val icon = findViewById<ImageView>(R.id.widget_play_icon)
        if (current != null && playerPrepared) {
            try {
                if (current.isPlaying) {
                    current.pause()
                    icon.setImageResource(R.drawable.widget_ic_play)
                    findViewById<View>(R.id.btn_play).contentDescription = "Reproducir audio"
                } else {
                    current.start()
                    icon.setImageResource(R.drawable.widget_ic_pause)
                    findViewById<View>(R.id.btn_play).contentDescription = "Pausar audio"
                }
            } catch (_: Exception) {
                releasePlayer()
            }
            return
        }
        val path = pendingAudioPath
        if (path.isNullOrBlank()) {
            Toast.makeText(this, "Audio no disponible", Toast.LENGTH_SHORT).show()
            return
        }
        if (!playerLoading.compareAndSet(false, true)) return
        BackgroundWork.execute {
            val mediaPlayer = try {
                val created = android.media.MediaPlayer()
                created.setDataSource(path)
                created
            } catch (_: Exception) {
                playerLoading.set(false)
                BackgroundWork.postMain {
                    Toast.makeText(this, "Audio no disponible", Toast.LENGTH_SHORT).show()
                }
                return@execute
            }
            mediaPlayer.setOnPreparedListener {
                BackgroundWork.postMain {
                    if (player !== mediaPlayer) return@postMain
                    playerPrepared = true
                    playerLoading.set(false)
                    try {
                        mediaPlayer.start()
                        icon.setImageResource(R.drawable.widget_ic_pause)
                        findViewById<View>(R.id.btn_play).contentDescription = "Pausar audio"
                    } catch (_: Exception) {
                        releasePlayer()
                    }
                }
            }
            mediaPlayer.setOnCompletionListener {
                BackgroundWork.postMain {
                    if (player !== mediaPlayer) return@postMain
                    try {
                        mediaPlayer.seekTo(0)
                    } catch (_: Exception) {}
                    icon.setImageResource(R.drawable.widget_ic_play)
                    findViewById<View>(R.id.btn_play).contentDescription = "Reproducir audio"
                }
            }
            mediaPlayer.setOnErrorListener { _, _, _ ->
                BackgroundWork.postMain {
                    if (player === mediaPlayer) releasePlayer()
                    playerLoading.set(false)
                    icon.setImageResource(R.drawable.widget_ic_play)
                }
                true
            }
            synchronized(this) {
                if (player != null) {
                    try {
                        mediaPlayer.release()
                    } catch (_: Exception) {}
                    playerLoading.set(false)
                    return@execute
                }
                player = mediaPlayer
            }
            try {
                mediaPlayer.prepareAsync()
            } catch (_: Exception) {
                synchronized(this) {
                    if (player === mediaPlayer) player = null
                }
                try {
                    mediaPlayer.release()
                } catch (_: Exception) {}
                playerLoading.set(false)
                BackgroundWork.postMain {
                    Toast.makeText(this, "No se pudo reproducir", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun releasePlayer() {
        playerPrepared = false
        playerLoading.set(false)
        val current = player
        player = null
        try {
            current?.stop()
        } catch (_: Exception) {}
        try {
            current?.release()
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }

    private fun confirmDelete() {
        try {
            val density = resources.displayMetrics.density
            val pad = (14 * density).toInt()
            val dialog = android.app.Dialog(this)
            dialog.requestWindowFeature(android.view.Window.FEATURE_NO_TITLE)
            dialog.window?.setBackgroundDrawable(
                android.graphics.drawable.ColorDrawable(android.graphics.Color.TRANSPARENT),
            )
            val box = android.widget.LinearLayout(this).apply {
                orientation = android.widget.LinearLayout.VERTICAL
                setBackgroundResource(R.drawable.widget_glass_inner)
                setPadding(pad, pad, pad, pad)
            }
            val title = android.widget.TextView(this).apply {
                text = "¿Eliminar nota?"
                setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            box.addView(title)
            val description = android.widget.TextView(this).apply {
                text = "Se borra la nota y su audio. No se puede deshacer."
                setTextColor(ContextCompat.getColor(context, R.color.kb_label_secondary))
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                setPadding(0, (8 * density).toInt(), 0, pad)
            }
            box.addView(description)
            val row = android.widget.LinearLayout(this).apply {
                orientation = android.widget.LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.END
            }
            val buttonParams = android.widget.LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
            )
            val cancel = android.widget.TextView(this).apply {
                text = "Cancelar"
                gravity = android.view.Gravity.CENTER
                setPadding(pad, pad, pad, pad)
                setBackgroundResource(R.drawable.widget_note_card_bg)
                setTextColor(ContextCompat.getColor(context, R.color.kb_label_secondary))
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                setOnClickListener { dialog.dismiss() }
            }
            val cancelParams = android.widget.LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
            )
            cancelParams.rightMargin = pad / 2
            row.addView(cancel, cancelParams)
            val remove = android.widget.TextView(this).apply {
                text = "Eliminar"
                gravity = android.view.Gravity.CENTER
                setPadding(pad, pad, pad, pad)
                setBackgroundResource(R.drawable.kb_key_danger)
                setTextColor(ContextCompat.getColor(context, R.color.kb_label_on_accent))
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setOnClickListener {
                    dialog.dismiss()
                    requestDelete()
                }
            }
            row.addView(remove, buttonParams)
            box.addView(row)
            dialog.setContentView(box)
            dialog.window?.setLayout(
                resources.displayMetrics.widthPixels - (48 * density).toInt(),
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            dialog.show()
        } catch (_: Exception) {}
    }

    private fun requestDelete() {
        val id = noteId ?: return
        if (!mutationInProgress.compareAndSet(false, true)) return
        setMutationBusy(true)
        BackgroundWork.executeWithResult(
            {
                when (val result = NoteStore(this).deleteNote(id)) {
                    is NoteDeleteResult.Deleted -> {
                        for (path in result.audioPaths) {
                            try {
                                val audio = File(path)
                                if (audio.exists()) audio.delete()
                            } catch (_: Exception) {}
                        }
                        result
                    }
                    else -> result
                }
            },
            { result ->
                mutationInProgress.set(false)
                setMutationBusy(false)
                if (result is NoteDeleteResult.Deleted) {
                    Toast.makeText(this, "Nota eliminada", Toast.LENGTH_SHORT).show()
                    BackgroundWork.execute { refreshNoteWidgets() }
                    finish()
                } else {
                    Toast.makeText(this, "No se pudo eliminar; se conservó el audio", Toast.LENGTH_SHORT).show()
                }
            },
        )
    }

    private fun requestSave(titulo: String, cuerpo: String) {
        if (cuerpo.trim().isEmpty()) {
            Toast.makeText(this, "Sin contenido para guardar", Toast.LENGTH_SHORT).show()
            return
        }
        if (!mutationInProgress.compareAndSet(false, true)) return
        val editingId = noteId
        setMutationBusy(true)
        BackgroundWork.executeWithResult(
            { NoteStore(this).saveNote(editingId, titulo, cuerpo) },
            { result ->
                mutationInProgress.set(false)
                if (result == NoteSaveResult.SAVED) {
                    BackgroundWork.execute { refreshNoteWidgets() }
                    finish()
                } else {
                    setMutationBusy(false)
                    val message = if (result == NoteSaveResult.LIMIT_REACHED) {
                        "Límite de ${NoteStore.MAX_NOTES} notas"
                    } else {
                        "No se pudo guardar; tus cambios siguen aquí"
                    }
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                }
            },
        )
    }

    private fun setMutationBusy(busy: Boolean) {
        val title = findViewById<EditText>(R.id.edit_title)
        val body = findViewById<EditText>(R.id.edit_body)
        val editable = editorWritable && !busy && !pendingMode
        title.isEnabled = editable
        body.isEnabled = editable
        findViewById<View>(R.id.btn_save).isEnabled = noteReadyForSave && editable
        findViewById<View>(R.id.btn_copy).isEnabled = editable
        findViewById<View>(R.id.btn_delete).isEnabled = deleteAvailable && !busy && !pendingMode
    }

    private fun setEditorState(writable: Boolean, ready: Boolean, deletable: Boolean) {
        editorWritable = writable
        noteReadyForSave = ready
        deleteAvailable = deletable
        findViewById<View>(R.id.slot_delete).visibility = if (deletable) View.VISIBLE else View.GONE
        setMutationBusy(mutationInProgress.get())
    }

    private fun refreshNoteWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        WidgetNotesProvider.requestListRefresh(this, appWidgetManager)
        val ids = appWidgetManager.getAppWidgetIds(
            ComponentName(this, WidgetNotesProvider::class.java),
        )
        for (id in ids) WidgetNotesProvider.updateOne(this, appWidgetManager, id)
    }
}
