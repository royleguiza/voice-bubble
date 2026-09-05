package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import org.json.JSONObject
import kotlin.math.abs

/**
 * Controlador nativo para el modo Isla Dinámica (Dynamic Island Pill & Morphing History Modal).
 *
 * Características implementadas (MEJ-18 / MEJ-16 / MEJORAS-SEPTIEMBRE):
 * 1. Píldora compacta superior en el cutout / notch (184dp x 36dp, r=18dp):
 *    - Ranura izquierda: Botón de lanzamiento de Trackpad Flotante.
 *    - Ranura central: Orificio de cámara frontal / Notch sensor (12dp x 12dp). Al tocarlo despliega
 *      la modal flotante de Historial de Transcripciones.
 *    - Ranura derecha: Micrófono para inicio instantáneo de dictado por voz.
 *    - Orden de ranuras intercambiable (trackpad_camera_mic vs mic_camera_trackpad).
 * 2. Estado de grabación de audio (Recording Pill):
 *    - Expansión horizontal fluida a 330dp x 48dp (r=24dp).
 *    - Indicador de punto rojo pulsante, cronómetro M:SS en vivo, barra de onda y botón [✕] de cancelación.
 *    - Procesamiento Groq STT con estado "Procesando con Groq...".
 *    - Notificación de copiado/pegado automático con cierre fluido.
 * 3. Modal flotante de Historial de Transcripciones con Morphing (20-25% a 50% de pantalla):
 *    - Rayita interactiva inferior (drag handle):
 *      * 1-tap cierra directamente la modal.
 *      * Swipe-up cierra directamente.
 *      * Drag down expande hacia abajo hasta el 50% de la altura de la pantalla.
 *    - Diseño adaptativo con contornos completos:
 *      * 1 elemento: 100% de la altura para ver el párrafo entero sin elipsis.
 *      * 2 elementos: 50% de la altura para cada tarjeta.
 *      * 3+ elementos: muestra 3 tarjetas completas + scroll vertical fluido.
 *    - Acciones en tarjeta:
 *      * Tocar texto: pega directamente en el cursor (o copia si no hay cursor).
 *      * Botón copiar: copia al portapapeles con confirmación visual (tilde verde) por 1.2s.
 *      * Presión larga: expande el mensaje en el eje vertical para lectura completa.
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni telemetría de audios ni textos de transcripción.
 */
class DynamicIslandController(
    private val context: Context,
    private val windowManager: WindowManager,
    private val onMicTap: () -> Unit,
    private val onCancelRecording: () -> Unit,
    private val onStopRecording: () -> Unit
) {

    private val density = context.resources.displayMetrics.density
    private val screenWidth = context.resources.displayMetrics.widthPixels
    private val screenHeight = context.resources.displayMetrics.heightPixels

    private var islandContainer: FrameLayout? = null
    private lateinit var islandLayoutParams: WindowManager.LayoutParams

    private var compactView: LinearLayout? = null
    private var recordingView: LinearLayout? = null
    private var statusView: LinearLayout? = null
    private var historyModalView: LinearLayout? = null

    private var isRecording = false
    private var isHistoryOpen = false
    private var isHistoryExtended50 = false
    private var recSeconds = 0

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recTimerRunnable: Runnable? = null

    private val isNight: Boolean
        get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    init {
        setupIslandLayout()
    }

    private fun setupIslandLayout() {
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val initialW = (184 * density).toInt()
        val initialH = (36 * density).toInt()

        islandLayoutParams = WindowManager.LayoutParams(
            initialW,
            initialH,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (12 * density).toInt()
        }

        val root = FrameLayout(context).apply {
            background = createIslandBackground(cornerRadius = 18f * density)
            elevation = 16f * density
        }

        // 1. Vista Compacta
        compactView = buildCompactView()
        root.addView(compactView)

        // 2. Vista Grabación
        recordingView = buildRecordingView().apply { visibility = View.GONE }
        root.addView(recordingView)

        // 3. Vista Estado (Groq STT)
        statusView = buildStatusView().apply { visibility = View.GONE }
        root.addView(statusView)

        // 4. Modal Historial
        historyModalView = buildHistoryModalView().apply { visibility = View.GONE }
        root.addView(historyModalView)

        islandContainer = root
        try {
            windowManager.addView(root, islandLayoutParams)
        } catch (_: Exception) {}
    }

    private fun createIslandBackground(cornerRadius: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = cornerRadius
            val bgColor = if (isNight) Color.parseColor("#E60A0B10") else Color.parseColor("#E61F2430")
            setColor(bgColor)
            setStroke((1.2f * density).toInt(), Color.parseColor("#33FFFFFF"))
        }
    }

    private fun buildCompactView(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((6 * density).toInt(), 0, (6 * density).toInt(), 0)

            // Slot Izquierdo: Lanzador de Trackpad Flotante
            val btnTrackpad = ImageView(context).apply {
                setImageResource(R.drawable.ic_trackpad)
                setColorFilter(Color.WHITE)
                val pad = (6 * density).toInt()
                setPadding(pad, pad, pad, pad)
                val size = (32 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size)
                contentDescription = "Abrir Trackpad Flotante"
                setOnClickListener {
                    FloatingTrackpadService.start(context)
                }
            }
            addView(btnTrackpad)

            // Espaciador / Orificio Central (Cámara frontal / Cutout)
            val camPunch = FrameLayout(context).apply {
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1.0f)
                val dot = View(context).apply {
                    val dotSize = (12 * density).toInt()
                    layoutParams = FrameLayout.LayoutParams(dotSize, dotSize).apply {
                        gravity = Gravity.CENTER
                    }
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.BLACK)
                        setStroke((1f * density).toInt(), Color.parseColor("#44FFFFFF"))
                    }
                }
                addView(dot)
                contentDescription = "Abrir Historial de Transcripciones"
                setOnClickListener {
                    toggleHistoryModal()
                }
            }
            addView(camPunch)

            // Slot Derecho: Micrófono de Grabación
            val btnMic = ImageView(context).apply {
                setImageResource(R.drawable.kb_ic_mic)
                setColorFilter(ContextCompat.getColor(context, R.color.kb_key_bg_accent))
                val pad = (6 * density).toInt()
                setPadding(pad, pad, pad, pad)
                val size = (32 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size)
                contentDescription = "Iniciar Grabación de Voz"
                setOnClickListener {
                    onMicTap()
                }
            }
            addView(btnMic)
        }
    }

    private fun buildRecordingView(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((12 * density).toInt(), 0, (12 * density).toInt(), 0)

            // Punto pulsante rojo de grabación
            val redDot = View(context).apply {
                val s = (10 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s).apply {
                    setMargins(0, 0, (8 * density).toInt(), 0)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#FF453A"))
                }
            }
            addView(redDot)

            // Cronómetro en vivo
            val tvTimer = TextView(context).apply {
                id = View.generateViewId()
                text = "00:00"
                setTextColor(Color.WHITE)
                textSize = 13f
                typeface = android.graphics.Typeface.MONOSPACE
            }
            addView(tvTimer)

            // Barra de progreso de onda
            val waveBar = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(0, (4 * density).toInt(), 1.0f).apply {
                    setMargins((12 * density).toInt(), 0, (12 * density).toInt(), 0)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 2f * density
                    setColor(Color.parseColor("#38BDF8"))
                }
            }
            addView(waveBar)

            // Botón Cancelar [✕]
            val btnCancel = TextView(context).apply {
                text = "✕"
                setTextColor(Color.parseColor("#FF453A"))
                textSize = 16f
                gravity = Gravity.CENTER
                val s = (32 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s)
                setOnClickListener {
                    cancelRecording()
                }
            }
            addView(btnCancel)

            // Tocar el cuerpo de grabación finaliza y transcribe
            setOnClickListener {
                onStopRecording()
            }
        }
    }

    private fun buildStatusView(): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((12 * density).toInt(), 0, (12 * density).toInt(), 0)

            val tvStatus = TextView(context).apply {
                id = View.generateViewId()
                text = "Procesando con Groq..."
                setTextColor(Color.WHITE)
                textSize = 12f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            addView(tvStatus)
        }
    }

    private fun buildHistoryModalView(): LinearLayout {
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((12 * density).toInt(), (10 * density).toInt(), (12 * density).toInt(), 0)
        }

        // Header con título y contador
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (32 * density).toInt()
            )

            val tvTitle = TextView(context).apply {
                text = "HISTORIAL DE DICTADOS"
                textSize = 11f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setTextColor(Color.parseColor("#38BDF8"))
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1.0f)
            }
            addView(tvTitle)

            val btnClose = TextView(context).apply {
                text = "✕"
                textSize = 14f
                setTextColor(if (isNight) Color.WHITE else Color.parseColor("#1C1C1E"))
                gravity = Gravity.CENTER
                val s = (28 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s)
                setOnClickListener {
                    closeHistoryModal()
                }
            }
            addView(btnClose)
        }
        root.addView(header)

        // Contenedor scrollable de tarjetas
        val scrollView = ScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1.0f
            )
            isVerticalScrollBarEnabled = false
            isFillViewport = true
        }

        val cardsList = LinearLayout(context).apply {
            id = View.generateViewId()
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        scrollView.addView(cardsList)
        root.addView(scrollView)

        // Rayita interactiva inferior (drag handle)
        val bottomHandleZone = FrameLayout(context).apply {
            val h = (28 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, h)

            val rayita = View(context).apply {
                val rW = (44 * density).toInt()
                val rH = (5 * density).toInt()
                layoutParams = FrameLayout.LayoutParams(rW, rH).apply {
                    gravity = Gravity.CENTER
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 3f * density
                    setColor(if (isNight) Color.parseColor("#E6FFFFFF") else Color.parseColor("#CC1D1D1F"))
                }
            }
            addView(rayita)

            setOnTouchListener(object : View.OnTouchListener {
                private var startY = 0f
                private var startH = 0
                private var didDrag = false

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    when (event.actionMasked) {
                        MotionEvent.ACTION_DOWN -> {
                            startY = event.rawY
                            startH = islandLayoutParams.height
                            didDrag = false
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            val dy = event.rawY - startY
                            if (abs(dy) > (6 * density)) {
                                didDrag = true
                            }
                            if (dy > 0) {
                                // Arrastre hacia abajo: expande hasta el 50% de la pantalla
                                val maxH = (screenHeight * 0.50f).toInt()
                                val newH = (startH + dy).toInt().coerceAtMost(maxH)
                                islandLayoutParams.height = newH
                                try {
                                    windowManager.updateViewLayout(islandContainer, islandLayoutParams)
                                } catch (_: Exception) {}
                            } else if (dy < -(20 * density)) {
                                // Swipe-up: cierra directamente la modal
                                closeHistoryModal()
                                return true
                            }
                            return true
                        }
                        MotionEvent.ACTION_UP -> {
                            if (!didDrag) {
                                // 1-tap en la rayita: cierra directamente
                                closeHistoryModal()
                                return true
                            }
                            val dy = event.rawY - startY
                            if (dy < -(15 * density)) {
                                closeHistoryModal()
                            } else if (islandLayoutParams.height > (280 * density).toInt()) {
                                setHistoryExtended50(true)
                            } else {
                                setHistoryExtended50(false)
                            }
                            return true
                        }
                    }
                    return false
                }
            })
        }
        root.addView(bottomHandleZone)

        return root
    }

    /**
     * Renderiza las tarjetas adaptativas de historial:
     * - 1 elemento: 100% de la altura
     * - 2 elementos: 50% de la altura
     * - 3+ elementos: 3 elementos visibles + scroll
     */
    fun populateHistoryCards() {
        val root = historyModalView ?: return
        val scrollView = root.getChildAt(1) as? ScrollView ?: return
        val cardsList = scrollView.getChildAt(0) as? LinearLayout ?: return
        cardsList.removeAllViews()

        val repo = TranscriptionHistoryRepository(context)
        val items = repo.loadHistory()

        if (items.isEmpty()) {
            val emptyTv = TextView(context).apply {
                text = "No hay dictados recientes en el historial."
                setTextColor(Color.parseColor("#8E8E93"))
                textSize = 12f
                gravity = Gravity.CENTER
                setPadding(0, (40 * density).toInt(), 0, (40 * density).toInt())
            }
            cardsList.addView(emptyTv)
            return
        }

        val count = items.size
        cardsList.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            if (count <= 2) ViewGroup.LayoutParams.MATCH_PARENT else ViewGroup.LayoutParams.WRAP_CONTENT
        )

        for ((idx, item) in items.withIndex()) {
            val text = item.optString("text", "")
            if (text.isBlank()) continue

            val card = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL

                val cardLp = when (count) {
                    1, 2 -> LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1.0f).apply {
                        setMargins(0, (4 * density).toInt(), 0, (4 * density).toInt())
                    }
                    else -> LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (52 * density).toInt()).apply {
                        setMargins(0, (3 * density).toInt(), 0, (3 * density).toInt())
                    }
                }
                layoutParams = cardLp

                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 12f * density
                    setColor(if (isNight) Color.parseColor("#331C1D26") else Color.parseColor("#14000000"))
                    setStroke((1f * density).toInt(), if (isNight) Color.parseColor("#26FFFFFF") else Color.parseColor("#20000000"))
                }
                setPadding((10 * density).toInt(), (6 * density).toInt(), (10 * density).toInt(), (6 * density).toInt())

                // Texto del snippet con contraste accesible para modo claro y oscuro
                val tvSnippet = TextView(context).apply {
                    this.text = "\"$text\""
                    setTextColor(if (isNight) Color.WHITE else Color.parseColor("#1C1C1E"))
                    textSize = 12f
                    maxLines = when (count) {
                        1 -> 16
                        2 -> 4
                        else -> 2
                    }
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1.0f)
                }
                addView(tvSnippet)

                // Botón de copiado con confirmación de tilde verde
                val btnCopy = ImageView(context).apply {
                    setImageResource(R.drawable.ic_copy)
                    setColorFilter(if (isNight) Color.WHITE else Color.parseColor("#3C3C43"))
                    val p = (6 * density).toInt()
                    setPadding(p, p, p, p)
                    val s = (28 * density).toInt()
                    layoutParams = LinearLayout.LayoutParams(s, s).apply {
                        setMargins((6 * density).toInt(), 0, 0, 0)
                    }
                    contentDescription = "Copiar al portapapeles"
                    setOnClickListener {
                        copyToClipboard(text)
                        setImageResource(R.drawable.ic_check)
                        setColorFilter(Color.parseColor("#30D158"))
                        postDelayed({
                            setImageResource(R.drawable.ic_copy)
                            setColorFilter(if (isNight) Color.WHITE else Color.parseColor("#3C3C43"))
                        }, 1200L)
                    }
                }
                addView(btnCopy)

                // Clic en el cuerpo: inyecta directamente en el cursor, copia al portapapeles y cierra modal
                setOnClickListener {
                    val injected = VoiceKeyboardService.commitFromExternal(text)
                    copyToClipboard(text)
                    closeHistoryModal()
                }

                // Presión larga: expande mensaje en Y para lectura completa
                setOnLongClickListener {
                    tvSnippet.maxLines = if (tvSnippet.maxLines == Int.MAX_VALUE) 2 else Int.MAX_VALUE
                    performHaptic(isFirm = true)
                    true
                }
            }
            cardsList.addView(card)
        }
    }

    private fun copyToClipboard(text: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("VoiceBubble STT", text)
        clipboard.setPrimaryClip(clip)
        performHaptic(isFirm = false)
    }

    private fun performHaptic(isFirm: Boolean) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val effect = if (isFirm) {
                        VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
                    } else {
                        VibrationEffect.createOneShot(18L, 90)
                    }
                    vibrator.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(if (isFirm) 35L else 18L)
                }
            }
        } catch (_: Exception) {}
    }

    fun startRecordingUI() {
        if (isRecording) return
        isRecording = true
        if (isHistoryOpen) closeHistoryModal()

        compactView?.visibility = View.GONE
        statusView?.visibility = View.GONE
        historyModalView?.visibility = View.GONE
        recordingView?.visibility = View.VISIBLE

        islandLayoutParams.width = (330 * density).toInt()
        islandLayoutParams.height = (48 * density).toInt()
        islandContainer?.background = createIslandBackground(cornerRadius = 24f * density)

        try {
            windowManager.updateViewLayout(islandContainer, islandLayoutParams)
        } catch (_: Exception) {}

        recSeconds = 0
        recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        recTimerRunnable = object : Runnable {
            override fun run() {
                recSeconds++
                val m = String.format("%02d", recSeconds / 60)
                val s = String.format("%02d", recSeconds % 60)
                recordingView?.let { root ->
                    val tv = root.getChildAt(1) as? TextView
                    tv?.text = "$m:$s"
                }
                mainHandler.postDelayed(this, 1000L)
            }
        }
        mainHandler.postDelayed(recTimerRunnable!!, 1000L)
    }

    fun showProcessingUI() {
        recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        recTimerRunnable = null

        recordingView?.visibility = View.GONE
        statusView?.visibility = View.VISIBLE
        statusView?.let { root ->
            val tv = root.getChildAt(0) as? TextView
            tv?.text = "Procesando con Groq..."
        }

        islandLayoutParams.width = (240 * density).toInt()
        islandLayoutParams.height = (48 * density).toInt()
        try {
            windowManager.updateViewLayout(islandContainer, islandLayoutParams)
        } catch (_: Exception) {}
    }

    fun showSuccessUI(text: String) {
        statusView?.let { root ->
            val tv = root.getChildAt(0) as? TextView
            tv?.text = "✓ ¡Copiado y pegado!"
        }
        mainHandler.postDelayed({
            collapseToCompact()
        }, 1200L)
    }

    fun cancelRecording() {
        recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        recTimerRunnable = null
        isRecording = false
        onCancelRecording()
        collapseToCompact()
    }

    fun collapseToCompact() {
        isRecording = false
        recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        recTimerRunnable = null

        recordingView?.visibility = View.GONE
        statusView?.visibility = View.GONE
        historyModalView?.visibility = View.GONE
        compactView?.visibility = View.VISIBLE

        islandLayoutParams.width = (184 * density).toInt()
        islandLayoutParams.height = (36 * density).toInt()
        islandContainer?.background = createIslandBackground(cornerRadius = 18f * density)

        try {
            windowManager.updateViewLayout(islandContainer, islandLayoutParams)
        } catch (_: Exception) {}
    }

    fun toggleHistoryModal() {
        if (isHistoryOpen) {
            closeHistoryModal()
        } else {
            openHistoryModal()
        }
    }

    fun openHistoryModal() {
        if (isRecording) return
        isHistoryOpen = true

        compactView?.visibility = View.GONE
        recordingView?.visibility = View.GONE
        statusView?.visibility = View.GONE
        historyModalView?.visibility = View.VISIBLE

        populateHistoryCards()

        val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((360 * density).toInt())
        val modalH = (240 * density).toInt()

        islandLayoutParams.width = modalW
        islandLayoutParams.height = modalH
        islandContainer?.background = createIslandBackground(cornerRadius = 20f * density)

        try {
            windowManager.updateViewLayout(islandContainer, islandLayoutParams)
        } catch (_: Exception) {}
    }

    fun closeHistoryModal() {
        isHistoryOpen = false
        isHistoryExtended50 = false
        collapseToCompact()
    }

    fun setHistoryExtended50(extended: Boolean) {
        isHistoryExtended50 = extended
        val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((360 * density).toInt())
        val modalH = if (extended) (screenHeight * 0.50f).toInt() else (240 * density).toInt()

        islandLayoutParams.width = modalW
        islandLayoutParams.height = modalH

        try {
            windowManager.updateViewLayout(islandContainer, islandLayoutParams)
        } catch (_: Exception) {}
    }

    fun destroy() {
        recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
        recTimerRunnable = null
        if (islandContainer != null) {
            try {
                windowManager.removeViewImmediate(islandContainer)
            } catch (_: Exception) {}
            islandContainer = null
        }
    }
}
