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

    // Etapa 4: Android 9–12 toma el idioma elegido en la app (13+ lo pone el sistema).
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    companion object {
        private const val GEMINI_TITULO = "titulo"
        private const val GEMINI_RESUMIR = "resumir"

        // = NotesService.maxTituloLength en Dart.
        private const val MAX_TITLE_CHARS = 80

        /** Espera para el segundo aviso al widget, con el launcher ya al frente. */
        private const val LIST_REFRESH_AFTER_EXIT_MS = 700L

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
    private val geminiInProgress = AtomicBoolean(false)

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
                            Toast.makeText(this, getString(R.string.widget_audio_not_pending), Toast.LENGTH_SHORT).show()
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
                Toast.makeText(this, getString(R.string.widget_nothing_to_copy), Toast.LENGTH_SHORT).show()
            } else {
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("nota", text))
                    Toast.makeText(this, getString(R.string.widget_content_copied), Toast.LENGTH_SHORT).show()
                } catch (_: Exception) {
                    Toast.makeText(this, getString(R.string.widget_copy_failed), Toast.LENGTH_SHORT).show()
                }
            }
        }
        findViewById<View>(R.id.btn_save).setOnClickListener {
            requestSave(titleEt.text.toString(), bodyEt.text.toString())
        }
        findViewById<View>(R.id.btn_gemini_titulo).setOnClickListener { runGemini(GEMINI_TITULO) }
        findViewById<View>(R.id.btn_gemini_resumir).setOnClickListener { runGemini(GEMINI_RESUMIR) }
        findViewById<View>(R.id.btn_delete).setOnClickListener { confirmDelete() }
        findViewById<View>(R.id.btn_delete_cancel).setOnClickListener { showDeleteConfirm(false) }
        findViewById<View>(R.id.btn_delete_confirm).setOnClickListener {
            showDeleteConfirm(false)
            requestDelete()
        }

        val editingId = noteId
        if (editingId == null) {
            setEditorState(writable = true, ready = true, deletable = false)
            focusEditor()
            return
        }

        findViewById<TextView>(R.id.overlay_title).text = getString(R.string.widget_edit_note)
        // Desde la vista de lectura del widget la nota ya está en memoria:
        // se muestra al instante y el teclado sube en el mismo gesto (sin
        // tarjeta vacía ni salto). Igual se verifica contra el disco.
        val cached = WidgetReader.cachedNote(editingId)
        if (cached != null) {
            titleEt.setText(cached.titulo)
            bodyEt.setText(cached.cuerpo)
            setEditorState(writable = true, ready = true, deletable = true)
            focusEditor()
        } else {
            setEditorState(writable = false, ready = false, deletable = false)
        }
        BackgroundWork.executeWithResult(
            { loadExistingNote(editingId) },
            { result ->
                if (isFinishing || isDestroyed) return@executeWithResult
                if (result == null) {
                    if (cached == null) showExistingUnavailable()
                    return@executeWithResult
                }
                when (WidgetNoteEditActivity.resolveExistingNoteState(result.snapshot, editingId)) {
                    ExistingNoteUiState.UNAVAILABLE -> if (cached == null) showExistingUnavailable()
                    ExistingNoteUiState.NOT_FOUND -> {
                        Toast.makeText(this, getString(R.string.widget_note_gone), Toast.LENGTH_SHORT).show()
                        finish()
                    }
                    ExistingNoteUiState.READY -> {
                        val loaded = result.note
                        if (loaded == null) {
                            if (cached == null) showExistingUnavailable()
                            return@executeWithResult
                        }
                        val untouched = cached == null || (
                            titleEt.text.toString() == cached.titulo &&
                                bodyEt.text.toString() == cached.cuerpo
                            )
                        // Solo se pisa si el usuario todavía no tocó nada.
                        if (untouched && (cached == null || loaded != cached)) {
                            titleEt.setText(loaded.titulo)
                            bodyEt.setText(loaded.cuerpo)
                        }
                        if (cached == null) {
                            setEditorState(writable = true, ready = true, deletable = true)
                            focusEditor()
                        }
                    }
                }
            },
        )
    }

    private fun setupEditorWindow() {
        // C-46: la fila con el player es exclusiva del pendiente; la nota
        // normal usa la botonera clásica de siempre.
        findViewById<View>(R.id.pending_row)?.visibility = View.GONE
        findViewById<View>(R.id.classic_row)?.visibility = View.VISIBLE
        try {
            window.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or
                    WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
            )
        } catch (_: Exception) {}
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            setupKeyboardFollow()
            setupExpandableBody()
            return
        }
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

    /**
     * Android 11+: la tarjeta sube pegada al teclado cuadro a cuadro en vez
     * de saltar cuando la ventana se redimensiona. La ventana dibuja detrás
     * de las barras y el relleno se calcula con los insets reales; durante
     * la animación del teclado la tarjeta se traslada con su progreso.
     */
    @android.annotation.TargetApi(android.os.Build.VERSION_CODES.R)
    private fun setupKeyboardFollow() {
        try {
            window.setDecorFitsSystemWindows(false)
            val root = findViewById<View>(R.id.overlay_root)
            val card = findViewById<View>(R.id.note_card)
            val side = root.paddingLeft
            val types = android.view.WindowInsets.Type.systemBars() or
                android.view.WindowInsets.Type.displayCutout()
            root.setOnApplyWindowInsetsListener { view, insets ->
                val bars = insets.getInsets(types)
                val ime = insets.getInsets(android.view.WindowInsets.Type.ime())
                view.setPadding(side, bars.top, side, maxOf(bars.bottom, ime.bottom))
                recomputeBodyMax()
                insets
            }
            root.setWindowInsetsAnimationCallback(
                object : android.view.WindowInsetsAnimation.Callback(
                    android.view.WindowInsetsAnimation.Callback.DISPATCH_MODE_STOP,
                ) {
                    private var startBottom = 0
                    private var delta = 0f

                    private fun cardBottom(): Int {
                        val loc = IntArray(2)
                        card.getLocationInWindow(loc)
                        return loc[1] + card.height
                    }

                    override fun onPrepare(animation: android.view.WindowInsetsAnimation) {
                        startBottom = cardBottom()
                    }

                    override fun onStart(
                        animation: android.view.WindowInsetsAnimation,
                        bounds: android.view.WindowInsetsAnimation.Bounds,
                    ): android.view.WindowInsetsAnimation.Bounds {
                        // Ya está maquetada en su posición final: arranca
                        // desde donde estaba y acompaña al teclado.
                        delta = (startBottom - cardBottom()).toFloat()
                        card.translationY = delta
                        return bounds
                    }

                    override fun onProgress(
                        insets: android.view.WindowInsets,
                        running: MutableList<android.view.WindowInsetsAnimation>,
                    ): android.view.WindowInsets {
                        val ime = running.firstOrNull {
                            it.typeMask and android.view.WindowInsets.Type.ime() != 0
                        } ?: return insets
                        card.translationY = delta * (1f - ime.interpolatedFraction)
                        return insets
                    }

                    override fun onEnd(animation: android.view.WindowInsetsAnimation) {
                        card.translationY = 0f
                        delta = 0f
                    }
                },
            )
        } catch (_: Exception) {}
    }

    /** Máximo del cuerpo: lo visible menos el cromo de la tarjeta. */
    private fun bodyMinPx(): Int {
        if (cachedBodyMinPx > 0) return cachedBodyMinPx
        val density = resources.displayMetrics.density
        if (density <= 0) return 0
        cachedBodyMinPx = (140 * density).toInt()
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
        // Cursor al final: se sigue escribiendo donde terminó la nota.
        try {
            bodyEt.setSelection(bodyEt.text.length)
        } catch (_: Exception) {}
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Pide el teclado ya, aunque la ventana todavía esté entrando:
            // sube junto con la tarjeta en una sola animación.
            try {
                window.insetsController?.show(android.view.WindowInsets.Type.ime())
                return
            } catch (_: Exception) {}
        }
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
        Toast.makeText(this, getString(R.string.widget_note_read_failed), Toast.LENGTH_SHORT).show()
    }

    private fun showPendingUnavailable() {
        setEditorState(writable = false, ready = false, deletable = false)
        Toast.makeText(this, getString(R.string.widget_audio_read_failed), Toast.LENGTH_SHORT).show()
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
        findViewById<TextView>(R.id.overlay_title).text = getString(R.string.widget_pending_untranscribed)
        findViewById<View>(R.id.edit_title_wrap).visibility = View.GONE
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        bodyEt.setText(pendingInfoText(pending))
        // C-46: la fila del pendiente (con el player integrado) reemplaza por
        // completo a la botonera clásica, que queda oculta.
        findViewById<View>(R.id.pending_row).visibility = View.VISIBLE
        findViewById<View>(R.id.classic_row).visibility = View.GONE
        findViewById<View>(R.id.pending_transcribe).visibility = View.VISIBLE
        findViewById<View>(R.id.pending_cancel).visibility = View.VISIBLE
        findViewById<View>(R.id.pending_delete).visibility = View.VISIBLE
        findViewById<View>(R.id.pending_cancel).setOnClickListener { finish() }
        setupExpandingPlayer(pending)
        // C-39: transcribir directo desde el widget con la red vigente
        // (datos o Wi-Fi), sin pasar por Notas de la app.
        findViewById<View>(R.id.pending_transcribe)
            .setOnClickListener { requestPendingTranscription() }
        // C-45: un pendiente dañado (ceros) quedaba atrapado sin salida:
        // la modal solo ofrecía play/transcribir. Se habilita eliminar.
        findViewById<View>(R.id.pending_delete)
            .setOnClickListener { requestDiscardPending() }
        setEditorState(writable = false, ready = false, deletable = false)
    }

    /**
     * C-45: descarta el pendiente desde la propia modal (el audio no se
     * pudo reproducir/transcribir o el usuario ya no lo quiere). Quita el
     * índice compartido, borra el WAV y refresca widgets.
     */
    private fun requestDiscardPending() {
        val id = pendingId ?: return
        val path = pendingAudioPath
        if (!transcribeInProgress.compareAndSet(false, true)) return
        BackgroundWork.execute {
            try {
                NoteStore(this).removePending(id)
            } catch (_: Exception) {}
            try {
                if (!path.isNullOrBlank()) File(path).delete()
            } catch (_: Exception) {}
            BackgroundWork.execute { refreshNoteWidgets() }
            transcribeInProgress.set(false)
            BackgroundWork.postMain {
                Toast.makeText(this, getString(R.string.widget_audio_discarded), Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    /**
     * C-46: reproductor expandible del pendiente con tiempos reales.
     *
     * El player vive dentro de la fila de botones, entre dos espaciadores de
     * peso. Colapsado solo se ve el play (48dp) y queda centrado porque los
     * dos espaciadores se reparten el sobrante por igual. Al abrirse crecen el
     * reloj y la X, el grupo se ensancha y los espaciadores ceden terreno: la
     * X de cerrar la modal se va a la izquierda y Transcribir a la derecha,
     * sin salirse de la tarjeta. Cerrar es la animación inversa.
     *
     * Nunca se superponen: el ancho de la X y del reloj es 0 colapsado, así
     * que no hay translación ni IgnorePointer que puedan interceptar el play.
     *
     * El total colapsado se estima por tamaño (PCM16 mono 16kHz); al
     * preparar MediaPlayer se corrige con la duración real y el transcurrido
     * se publica cada 500 ms.
     */
    private var playerOpen = false
    private var playerTotalMs = 0
    private var playerClockWidthPx = 0
    private var playerSpreadAnimator: android.animation.ValueAnimator? = null
    private val elapsedHandler by lazy {
        android.os.Handler(android.os.Looper.getMainLooper())
    }
    private var elapsedRunnable: Runnable? = null

    private fun estimateTotalMs(path: String?): Long {
        if (path.isNullOrBlank()) return 0L
        return try {
            estimatePlayerTotalMs(File(path).length())
        } catch (_: Exception) {
            0L
        }
    }

    private fun renderClock(positionMs: Long) {
        try {
            findViewById<TextView>(R.id.player_clock)?.text =
                formatPlayerClock(positionMs, playerTotalMs.toLong())
        } catch (_: Exception) {}
    }

    /** Ancho del reloj ya con aire a los lados; se mide una sola vez. */
    private fun measureClockWidth(): Int {
        return try {
            val clock = findViewById<TextView>(R.id.player_clock) ?: return 0
            val gap = (12 * resources.displayMetrics.density).toInt()
            val spec = android.view.View.MeasureSpec.makeMeasureSpec(
                0,
                android.view.View.MeasureSpec.UNSPECIFIED,
            )
            clock.measure(spec, spec)
            (clock.measuredWidth + gap * 2).coerceAtLeast(gap)
        } catch (_: Exception) {
            0
        }
    }

    /**
     * progress 0 = solo play centrado. progress 1 = pausa | reloj | X.
     * Mueve anchos, no posiciones: los espaciadores hacen el resto.
     */
    private fun applyPlayerSpread(progress: Float) {
        try {
            val close = findViewById<android.view.View>(R.id.btn_player_close) ?: return
            val clock = findViewById<android.view.View>(R.id.player_clock) ?: return
            val main = findViewById<android.view.View>(R.id.btn_player_main) ?: return
            val density = resources.displayMetrics.density
            val button = (48 * density).toInt()
            val gap = (12 * density).toInt()

            val closeParams = close.layoutParams as android.widget.LinearLayout.LayoutParams
            closeParams.width = (button * progress).toInt().coerceAtLeast(0)
            close.layoutParams = closeParams

            val clockParams = clock.layoutParams as android.widget.LinearLayout.LayoutParams
            clockParams.width = (playerClockWidthPx * progress).toInt().coerceAtLeast(0)
            clock.layoutParams = clockParams

            val mainParams = main.layoutParams as android.widget.LinearLayout.LayoutParams
            mainParams.rightMargin = gap
            main.layoutParams = mainParams
        } catch (_: Exception) {}
    }

    private fun animatePlayerSpread(open: Boolean) {
        try {
            playerSpreadAnimator?.cancel()
            val from = if (open) 0f else 1f
            val to = if (open) 1f else 0f
            val animator = android.animation.ValueAnimator.ofFloat(from, to)
            animator.duration = 280L
            animator.addUpdateListener { value ->
                applyPlayerSpread(value.animatedValue as Float)
            }
            playerSpreadAnimator = animator
            animator.start()
        } catch (_: Exception) {
            applyPlayerSpread(if (open) 1f else 0f)
        }
    }

    private fun setupExpandingPlayer(pending: VbPending) {
        playerTotalMs = estimateTotalMs(pending.audioPath).toInt()
        val bar = findViewById<android.view.View>(R.id.player_bar) ?: return
        val main = findViewById<android.view.View>(R.id.btn_player_main) ?: return
        val close = findViewById<android.view.View>(R.id.btn_player_close) ?: return
        val clock = findViewById<TextView>(R.id.player_clock) ?: return
        playerOpen = false
        renderClock(0L)
        playerClockWidthPx = measureClockWidth()
        bar.visibility = android.view.View.VISIBLE
        applyPlayerSpread(0f)
        setPlayerMainIcon(playing = false)
        main.setOnClickListener { toggleExpandingPlayback() }
        close.setOnClickListener { closeExpandingPlayback() }
    }

    private fun openExpandingPlayer() {
        if (playerClockWidthPx <= 0) playerClockWidthPx = measureClockWidth()
        playerOpen = true
        animatePlayerSpread(open = true)
    }

    private fun collapseExpandingPlayer() {
        playerOpen = false
        stopElapsedUpdates()
        animatePlayerSpread(open = false)
        setPlayerMainIcon(playing = false)
    }

    private fun setPlayerMainIcon(playing: Boolean) {
        try {
            val icon = findViewById<android.widget.ImageView>(R.id.player_main_icon)
            if (playing) {
                icon?.setImageResource(R.drawable.widget_ic_pause)
                findViewById<android.view.View>(R.id.btn_player_main)
                    ?.contentDescription = getString(R.string.widget_pause_audio)
            } else {
                icon?.setImageResource(R.drawable.widget_ic_play)
                findViewById<android.view.View>(R.id.btn_player_main)
                    ?.contentDescription = getString(R.string.widget_play_audio)
            }
        } catch (_: Exception) {}
    }

    private fun startElapsedUpdates() {
        stopElapsedUpdates()
        val runnable = object : Runnable {
            override fun run() {
                try {
                    val pos = try {
                        player?.currentPosition ?: 0
                    } catch (_: Exception) {
                        0
                    }
                    renderClock(pos.toLong())
                } catch (_: Exception) {}
                elapsedHandler.postDelayed(this, 500L)
            }
        }
        elapsedRunnable = runnable
        elapsedHandler.post(runnable)
    }

    private fun stopElapsedUpdates() {
        elapsedRunnable?.let { elapsedHandler.removeCallbacks(it) }
        elapsedRunnable = null
    }

    private fun toggleExpandingPlayback() {
        val current = player
        if (current != null && playerPrepared) {
            try {
                if (current.isPlaying) {
                    current.pause()
                    setPlayerMainIcon(playing = false)
                    stopElapsedUpdates()
                    try {
                        renderClock(current.currentPosition.toLong())
                    } catch (_: Exception) {}
                } else {
                    current.start()
                    setPlayerMainIcon(playing = true)
                    startElapsedUpdates()
                }
            } catch (_: Exception) {
                releasePlayer()
                collapseExpandingPlayer()
            }
            return
        }
        val path = pendingAudioPath
        if (path.isNullOrBlank()) {
            Toast.makeText(this, getString(R.string.widget_audio_unavailable), Toast.LENGTH_SHORT).show()
            return
        }
        if (!playerLoading.compareAndSet(false, true)) return
        openExpandingPlayer()
        BackgroundWork.execute {
            val mediaPlayer = try {
                val created = android.media.MediaPlayer()
                created.setDataSource(path)
                created
            } catch (_: Exception) {
                playerLoading.set(false)
                BackgroundWork.postMain {
                    collapseExpandingPlayer()
                    Toast.makeText(this, getString(R.string.widget_audio_unavailable), Toast.LENGTH_SHORT).show()
                }
                return@execute
            }
            mediaPlayer.setOnPreparedListener {
                BackgroundWork.postMain {
                    if (player !== mediaPlayer) return@postMain
                    playerPrepared = true
                    playerLoading.set(false)
                    try {
                        playerTotalMs = mediaPlayer.duration
                    } catch (_: Exception) {}
                    try {
                        mediaPlayer.start()
                        setPlayerMainIcon(playing = true)
                        startElapsedUpdates()
                        renderClock(0L)
                    } catch (_: Exception) {
                        releasePlayer()
                        collapseExpandingPlayer()
                    }
                }
            }
            mediaPlayer.setOnCompletionListener {
                BackgroundWork.postMain {
                    if (player !== mediaPlayer) return@postMain
                    try {
                        mediaPlayer.seekTo(0)
                    } catch (_: Exception) {}
                    renderClock(0L)
                    collapseExpandingPlayer()
                }
            }
            mediaPlayer.setOnErrorListener { _, _, _ ->
                BackgroundWork.postMain {
                    if (player === mediaPlayer) releasePlayer()
                    playerLoading.set(false)
                    collapseExpandingPlayer()
                    Toast.makeText(this, getString(R.string.widget_audio_damaged), Toast.LENGTH_SHORT).show()
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
                    collapseExpandingPlayer()
                    Toast.makeText(this, getString(R.string.widget_play_failed), Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun closeExpandingPlayback() {
        releasePlayer()
        renderClock(0L)
        collapseExpandingPlayer()
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
                val raw = try {
                    File(path).readBytes()
                } catch (_: Exception) {
                    null
                }
                if (raw == null || raw.isEmpty()) {
                    failPendingTranscription(getString(R.string.widget_audio_unavailable))
                    return@execute
                }
                // C-45: si el pendiente trae hueco sin tapa (stop anormal
                // en la app) se repara y se persiste sano para el play.
                val repaired = SpeechToTextClient.tryRepairHolePcmBytes(raw)
                val wav = repaired ?: raw
                if (repaired != null) {
                    try {
                        File(path).writeBytes(wav)
                    } catch (_: Exception) {}
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
                    failPendingTranscription(getString(R.string.widget_configure_key))
                    return@execute
                }
                client.transcribe(
                    wav,
                    config,
                    onDone = { text ->
                        if (text.isNullOrBlank()) {
                            failPendingTranscription(getString(R.string.widget_transcribe_failed_kept))
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
                            failPendingTranscription(getString(R.string.widget_note_not_saved_kept))
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
                            Toast.makeText(this, getString(R.string.widget_note_saved), Toast.LENGTH_SHORT).show()
                            finish()
                        }
                    },
                    onError = { _, message ->
                        failPendingTranscription(message)
                    },
                )
            } catch (_: Exception) {
                failPendingTranscription(getString(R.string.widget_transcribe_failed_kept))
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
            // C-46: el pendiente transcribe desde su propia fila.
            findViewById<View>(R.id.pending_transcribe).isEnabled = !busy
        } catch (_: Exception) {
        }
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
            getString(R.string.widget_recorded_here)
        } else {
            getString(R.string.widget_recorded_on_here, whenText)
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
                    findViewById<View>(R.id.btn_play).contentDescription = getString(R.string.widget_play_audio)
                } else {
                    current.start()
                    icon.setImageResource(R.drawable.widget_ic_pause)
                    findViewById<View>(R.id.btn_play).contentDescription = getString(R.string.widget_pause_audio)
                }
            } catch (_: Exception) {
                releasePlayer()
            }
            return
        }
        val path = pendingAudioPath
        if (path.isNullOrBlank()) {
            Toast.makeText(this, getString(R.string.widget_audio_unavailable), Toast.LENGTH_SHORT).show()
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
                    Toast.makeText(this, getString(R.string.widget_audio_unavailable), Toast.LENGTH_SHORT).show()
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
                        findViewById<View>(R.id.btn_play).contentDescription = getString(R.string.widget_pause_audio)
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
                    findViewById<View>(R.id.btn_play).contentDescription = getString(R.string.widget_play_audio)
                }
            }
            mediaPlayer.setOnErrorListener { _, _, _ ->
                BackgroundWork.postMain {
                    if (player === mediaPlayer) releasePlayer()
                    playerLoading.set(false)
                    icon.setImageResource(R.drawable.widget_ic_play)
                    Toast.makeText(this, getString(R.string.widget_audio_damaged), Toast.LENGTH_SHORT).show()
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
                    Toast.makeText(this, getString(R.string.widget_play_failed), Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun releasePlayer() {
        playerPrepared = false
        playerLoading.set(false)
        stopElapsedUpdates()
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

    /**
     * Confirmar eliminar dentro de la propia hoja: la botonera se cambia por
     * «Se borra la nota y su audio…» + Cancelar / Eliminar. Antes era un
     * Dialog aparte: al tomar el foco escondía el teclado, la hoja bajaba de
     * golpe y Eliminar (esquinas de tecla) no hacía juego con Cancelar
     * (píldora). Ahora nada salta y las dos son píldoras iguales.
     */
    private fun confirmDelete() {
        if (!deleteAvailable || mutationInProgress.get()) return
        showDeleteConfirm(true)
    }

    private fun showDeleteConfirm(show: Boolean) {
        findViewById<View>(R.id.classic_row)?.visibility = if (show) View.GONE else View.VISIBLE
        findViewById<View>(R.id.delete_confirm_row)?.visibility = if (show) View.VISIBLE else View.GONE
        if (show) {
            findViewById<android.widget.TextView>(R.id.delete_confirm_text)?.text =
                getString(R.string.widget_delete_title) + " " + getString(R.string.widget_delete_body)
            findViewById<View>(R.id.btn_delete_confirm)
                ?.sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_FOCUSED)
        }
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
                    Toast.makeText(this, getString(R.string.widget_note_deleted), Toast.LENGTH_SHORT).show()
                    BackgroundWork.execute { refreshNoteWidgets() }
                    finish()
                } else {
                    Toast.makeText(this, getString(R.string.widget_delete_failed_kept), Toast.LENGTH_SHORT).show()
                }
            },
        )
    }

    private fun requestSave(titulo: String, cuerpo: String) {
        if (cuerpo.trim().isEmpty()) {
            Toast.makeText(this, getString(R.string.widget_nothing_to_save), Toast.LENGTH_SHORT).show()
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
                        getString(R.string.widget_notes_limit, NoteStore.MAX_NOTES)
                    } else {
                        getString(R.string.widget_save_failed_kept)
                    }
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                }
            },
        )
    }

    private sealed class GeminiOutcome {
        object MissingKey : GeminiOutcome()
        data class Ok(val text: String) : GeminiOutcome()
        data class Failed(val message: String) : GeminiOutcome()
    }

    /**
     * Título o resumen con Gemini desde el propio widget, sin abrir la app.
     * Título: se escribe en el campo y, si la nota ya existe, se guarda.
     * Resumen: vista previa con Descartar / Reemplazar (igual que la app).
     */
    private fun runGemini(action: String) {
        if (!editorWritable || pendingMode) return
        val bodyEt = findViewById<EditText>(R.id.edit_body)
        val texto = bodyEt.text.toString().trim()
        if (texto.isEmpty()) {
            Toast.makeText(this, getString(R.string.widget_write_first), Toast.LENGTH_SHORT).show()
            return
        }
        if (!geminiInProgress.compareAndSet(false, true)) return
        setGeminiBusy(action, true)
        BackgroundWork.executeWithResult(
            {
                val client = NoteAiClients.create(this)
                if (client == null) {
                    GeminiOutcome.MissingKey
                } else {
                    try {
                        val text = if (action == GEMINI_TITULO) client.sugerirTitulo(texto) else client.resumir(texto)
                        if (text.isBlank()) GeminiOutcome.Failed(getString(R.string.widget_ai_empty_response)) else GeminiOutcome.Ok(text)
                    } catch (e: GeminiNoteClient.GeminiError) {
                        GeminiOutcome.Failed(e.localized(this@WidgetNoteEditActivity))
                    } catch (_: Exception) {
                        GeminiOutcome.Failed(getString(R.string.widget_unexpected_error))
                    }
                }
            },
            { outcome ->
                geminiInProgress.set(false)
                if (isFinishing || isDestroyed) return@executeWithResult
                setGeminiBusy(action, false)
                when (outcome) {
                    null, is GeminiOutcome.MissingKey -> Toast.makeText(
                        this,
                        getString(R.string.widget_missing_ai_key),
                        Toast.LENGTH_LONG,
                    ).show()
                    is GeminiOutcome.Failed -> showGlassDialog(getString(R.string.widget_ai_error), outcome.message, getString(R.string.widget_close))
                    is GeminiOutcome.Ok -> if (action == GEMINI_TITULO) {
                        applyGeminiTitle(outcome.text)
                    } else {
                        showGlassDialog(getString(R.string.widget_summary_title), outcome.text, getString(R.string.widget_discard), getString(R.string.widget_replace)) {
                            bodyEt.setText(outcome.text)
                            bodyEt.setSelection(bodyEt.text.length)
                            persistQuietly()
                        }
                    }
                }
            },
        )
    }

    private fun applyGeminiTitle(title: String) {
        val titleEt = findViewById<EditText>(R.id.edit_title)
        val max = MAX_TITLE_CHARS
        titleEt.setText(if (title.length > max) title.substring(0, max) else title)
        titleEt.setSelection(titleEt.text.length)
        persistQuietly()
        Toast.makeText(this, getString(R.string.widget_title_generated), Toast.LENGTH_SHORT).show()
    }

    /** Guarda sin cerrar el editor (solo notas existentes, como la app). */
    private fun persistQuietly() {
        val id = noteId ?: return
        val titulo = findViewById<EditText>(R.id.edit_title).text.toString()
        val cuerpo = findViewById<EditText>(R.id.edit_body).text.toString()
        if (cuerpo.isBlank()) return
        BackgroundWork.execute {
            if (NoteStore(this).saveNote(id, titulo, cuerpo) == NoteSaveResult.SAVED) {
                refreshNoteWidgets()
            }
        }
    }

    /**
     * Hubo un guardado silencioso (título o resumen de IA) con el editor
     * abierto: el listado se vuelve a pedir al salir. Muchos launchers
     * (Motorola, entre otros) ignoran el aviso de datos nuevos mientras el
     * widget está tapado, y al volver mostraban la lista vieja.
     */
    @Volatile
    private var listDirty = false

    override fun onStop() {
        super.onStop()
        if (!listDirty) return
        listDirty = false
        val app = applicationContext
        BackgroundWork.execute { refreshNoteWidgets(app) }
        // Segundo aviso cuando el launcher ya volvió al frente.
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(
            { BackgroundWork.execute { refreshNoteWidgets(app) } },
            LIST_REFRESH_AFTER_EXIT_MS,
        )
    }

    private fun setGeminiBusy(action: String, busy: Boolean) {
        val (icon, progress) = if (action == GEMINI_TITULO) {
            R.id.icon_gemini_titulo to R.id.progress_gemini_titulo
        } else {
            R.id.icon_gemini_resumir to R.id.progress_gemini_resumir
        }
        findViewById<View>(icon)?.visibility = if (busy) View.INVISIBLE else View.VISIBLE
        findViewById<View>(progress)?.visibility = if (busy) View.VISIBLE else View.GONE
        findViewById<View>(R.id.btn_gemini_titulo)?.isEnabled = !busy
        findViewById<View>(R.id.btn_gemini_resumir)?.isEnabled = !busy
    }

    /** Diálogo sólido (hoja bg + line) con el mismo estilo que el de eliminar. */
    private fun showGlassDialog(
        title: String,
        message: String,
        dismissLabel: String,
        actionLabel: String? = null,
        onAction: (() -> Unit)? = null,
    ) {
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
                setBackgroundResource(R.drawable.widget_sheet_bg)
                setPadding(pad, pad, pad, pad)
            }
            box.addView(
                android.widget.TextView(this).apply {
                    text = title
                    setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
                    typeface = KbFonts.display(context)
                },
            )
            val scroll = android.widget.ScrollView(this)
            scroll.addView(
                android.widget.TextView(this).apply {
                    text = message
                    setTextIsSelectable(true)
                    setTextColor(ContextCompat.getColor(context, R.color.kb_label_secondary))
                    typeface = KbFonts.body(context)
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
                    setPadding(0, (8 * density).toInt(), 0, pad)
                },
            )
            val maxScroll = (resources.displayMetrics.heightPixels * 0.5f).toInt()
            box.addView(
                scroll,
                android.widget.LinearLayout.LayoutParams(
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                    android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
            scroll.post {
                if (scroll.height > maxScroll) {
                    scroll.layoutParams = scroll.layoutParams.apply { height = maxScroll }
                }
            }
            val row = android.widget.LinearLayout(this).apply {
                orientation = android.widget.LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.END
            }
            val dismiss = android.widget.TextView(this).apply {
                text = dismissLabel
                gravity = android.view.Gravity.CENTER
                setPadding(pad, pad, pad, pad)
                setBackgroundResource(R.drawable.widget_secondary_bg)
                setTextColor(ContextCompat.getColor(context, R.color.kb_label))
                setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                setOnClickListener { dialog.dismiss() }
            }
            val dismissParams = android.widget.LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
            )
            if (actionLabel != null) dismissParams.rightMargin = pad / 2
            row.addView(dismiss, dismissParams)
            if (actionLabel != null) {
                val action = android.widget.TextView(this).apply {
                    text = actionLabel
                    gravity = android.view.Gravity.CENTER
                    setPadding(pad, pad, pad, pad)
                    setBackgroundResource(R.drawable.widget_primary_bg)
                    setTextColor(ContextCompat.getColor(context, R.color.kb_label_on_accent))
                    setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                    typeface = KbFonts.body(context, strong = true)
                    setOnClickListener {
                        dialog.dismiss()
                        onAction?.invoke()
                    }
                }
                row.addView(
                    action,
                    android.widget.LinearLayout.LayoutParams(
                        0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
                    ),
                )
            }
            box.addView(row)
            dialog.setContentView(box)
            dialog.window?.setLayout(
                resources.displayMetrics.widthPixels - (48 * density).toInt(),
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            dialog.show()
        } catch (_: Exception) {}
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

    private fun refreshNoteWidgets(context: Context = this) {
        // Con el editor abierto, el aviso puede perderse: se repite al salir (onStop).
        if (context === this) listDirty = true
        val appWidgetManager = AppWidgetManager.getInstance(context)
        WidgetNotesProvider.requestListRefresh(context, appWidgetManager)
        val ids = appWidgetManager.getAppWidgetIds(
            ComponentName(context, WidgetNotesProvider::class.java),
        )
        for (id in ids) WidgetNotesProvider.updateOne(context, appWidgetManager, id)
    }
}
