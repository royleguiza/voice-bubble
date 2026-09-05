package com.royleguiza.voicebubblestt

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
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
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.PathInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Controlador nativo para el modo Isla Dinámica (Dynamic Island Pill & Morphing History Modal).
 *
 * Características implementadas (MEJ-18 / MEJ-16 / MEJORAS-SEPTIEMBRE):
 * 1. Píldora compacta superior en el cutout / notch (184dp x 36dp, r=18dp):
 *    - Ranura izquierda: Botón de lanzamiento de Trackpad Flotante.
 *    - Ranura central: Orificio de cámara frontal / Notch sensor (12dp x 12dp).
 *      Gestos del centro: Tap alterna historial, Swipe Down abre, Swipe Up cierra.
 *    - Ranura derecha: Micrófono para inicio instantáneo de dictado por voz.
 *    - Orden de ranuras intercambiable (trackpad_camera_mic vs mic_camera_trackpad).
 * 2. Transiciones Morphing Fluidas de 420ms (cubic-bezier 0.16, 1, 0.3, 1 / PathInterpolator):
 *    - Expansión y colapso de dimensiones y radios mediante ValueAnimator e interpolador cúbico.
 * 3. En modo Historial Expandido:
 *    - Las ranuras NO se ocultan; los botones de Trackpad y Mic se deslizan suavemente hacia las esquinas
 *      inferiores (top = height - 46dp, left/right = 14dp).
 *    - El orificio central de cámara se desvanece (alpha = 0, translationY = -80dp).
 *    - Rayita drag handle inferior visible para control gestual (1-tap/swipe up cierra, drag down expande a 50%).
 *    - Adaptabilidad de tarjetas: 1 elemento (100% alto), 2 elementos (50% alto), 3+ elementos (scrollable).
 *    - Inyección directa en cursor vía VoiceKeyboardService.commitFromExternal y copia con feedback de checkmark.
 * 4. En modo Grabación:
 *    - Expansión horizontal fluida a 330dp x 48dp (r=24dp) con adaptación inteligente a los bordes de pantalla.
 *    - Punto rojo pulsante, cronómetro M:SS en vivo, visualizador de onda con 9 barras reactivas desfasadas,
 *      botón de confirmación [✓] y botón de cancelación [✕].
 * 5. En modo Procesamiento:
 *    - Indicador giratorio (spinner) de progreso y texto de estado "Procesando con Groq...".
 *    - Transición fluida de éxito y colapso automático.
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

    companion object {
        private const val MORPH_DURATION_MS = 420L
        private val FLUID_INTERPOLATOR = PathInterpolator(0.16f, 1f, 0.3f, 1f)
    }

    private val density = context.resources.displayMetrics.density
    private val screenWidth = context.resources.displayMetrics.widthPixels
    private val screenHeight = context.resources.displayMetrics.heightPixels

    private var islandContainer: FrameLayout? = null
    private lateinit var islandLayoutParams: WindowManager.LayoutParams

    private var compactView: FrameLayout? = null
    private var slotLeft: FrameLayout? = null
    private var slotRight: FrameLayout? = null
    private var camPunch: FrameLayout? = null

    private var recordingView: LinearLayout? = null
    private var statusView: LinearLayout? = null
    private var historyModalView: LinearLayout? = null
    private var historyScrollView: ScrollView? = null
    private var historyCardsList: LinearLayout? = null
    private var spinnerView: ProgressBar? = null

    private val waveBars = ArrayList<View>()
    private val waveAnimators = ArrayList<ValueAnimator>()
    private val waveDelays = longArrayOf(50L, 200L, 350L, 100L, 450L, 250L, 400L, 150L, 300L)

    private var morphAnimator: ValueAnimator? = null
    private var currentRadiusDp = 18f

    private var isRecording = false
    private var isHistoryOpen = false
    private var isHistoryExtended50 = false
    private var recSeconds = 0

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recTimerRunnable: Runnable? = null
    private var collapseRunnable: Runnable? = null

    private val isNight: Boolean
        get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private var posX: Int = 0
    private var posY: Int = 12
    private var widthDp: Int = 184
    private var heightDp: Int = 36
    private var slotOrder: String = "trackpad_camera_mic"
    private var islandTheme: String = "glass"
    private var waveformEnabled: Boolean = true

    init {
        loadPreferences()
        setupIslandLayout()
    }

    private fun loadPreferences() {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            posX = (prefs.all["flutter.island_pos_x"] as? Number)?.toInt() ?: 0
            posY = (prefs.all["flutter.island_pos_y"] as? Number)?.toInt() ?: 12
            widthDp = (prefs.all["flutter.island_width"] as? Number)?.toInt() ?: 184
            heightDp = (prefs.all["flutter.island_height"] as? Number)?.toInt() ?: 36
            slotOrder = prefs.getString("flutter.island_slot_order", "trackpad_camera_mic") ?: "trackpad_camera_mic"
            islandTheme = prefs.getString("flutter.island_theme", "glass") ?: "glass"
            waveformEnabled = prefs.getBoolean("flutter.island_waveform_enabled", true)
        } catch (_: Throwable) {}
    }

    private fun setupIslandLayout() {
        try {
            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val initialW = (widthDp * density).toInt()
            val initialH = (heightDp * density).toInt()
            currentRadiusDp = heightDp / 2f

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
                x = (posX * density).toInt()
                y = (posY * density).toInt()
            }

            val root = FrameLayout(context).apply {
                background = createIslandBackground(cornerRadius = currentRadiusDp * density)
                elevation = 16f * density
                clipToOutline = true
            }

            // 1. Modal Historial (capa base para morphing dentro de la píldora)
            historyModalView = buildHistoryModalView().apply { visibility = View.GONE; alpha = 0f }
            root.addView(historyModalView)

            // 2. Vista Grabación (9 barras reactivas de onda)
            recordingView = buildRecordingView().apply { visibility = View.GONE; alpha = 0f }
            root.addView(recordingView)

            // 3. Vista Estado (Groq STT con spinner)
            statusView = buildStatusView().apply { visibility = View.GONE; alpha = 0f }
            root.addView(statusView)

            // 4. Vista Compacta con ranuras deslizantes y punch central
            compactView = buildCompactView()
            root.addView(compactView)

            islandContainer = root
            windowManager.addView(root, islandLayoutParams)
        } catch (_: Throwable) {}
    }

    fun reloadConfiguration() {
        try {
            loadPreferences()
            if (!isRecording && !isHistoryOpen) {
                islandLayoutParams.x = (posX * density).toInt()
                islandLayoutParams.y = (posY * density).toInt()
                islandLayoutParams.width = (widthDp * density).toInt()
                islandLayoutParams.height = (heightDp * density).toInt()
                currentRadiusDp = heightDp / 2f
                islandContainer?.background = createIslandBackground(cornerRadius = currentRadiusDp * density)
                islandContainer?.let { root ->
                    try {
                        windowManager.updateViewLayout(root, islandLayoutParams)
                    } catch (_: Throwable) {}
                }
                compactView?.let { old ->
                    islandContainer?.removeView(old)
                    val newView = buildCompactView()
                    compactView = newView
                    islandContainer?.addView(newView)
                }
            }
        } catch (_: Throwable) {}
    }

    private fun createIslandBackground(cornerRadius: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = cornerRadius
            when (islandTheme) {
                "light" -> {
                    setColor(Color.parseColor("#F5FFFFFF"))
                    setStroke((1.2f * density).toInt(), Color.parseColor("#33000000"))
                }
                "dark" -> {
                    setColor(Color.parseColor("#F00A0B10"))
                    setStroke((1.2f * density).toInt(), Color.parseColor("#33FFFFFF"))
                }
                else -> {
                    val bgColor = if (isNight) Color.parseColor("#E60A0B10") else Color.parseColor("#E61F2430")
                    setColor(bgColor)
                    setStroke((1.2f * density).toInt(), Color.parseColor("#40FFFFFF"))
                }
            }
        }
    }

    private fun buildCompactView(): FrameLayout {
        val root = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val isLight = islandTheme == "light"
        val iconColor = if (isLight) Color.parseColor("#1F2430") else Color.WHITE
        val slotBtnSize = (34 * density).toInt()
        val initialSlotTop = ((heightDp * density - slotBtnSize) / 2f).coerceAtLeast(0f).toInt()

        // Botón Trackpad
        val btnTrackpad = ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_trackpad))
            } catch (_: Throwable) {
                try { setImageResource(R.drawable.ic_trackpad) } catch (_: Throwable) {}
            }
            setColorFilter(Color.parseColor("#58A6FF"))
            val pad = (6 * density).toInt()
            setPadding(pad, pad, pad, pad)
            layoutParams = FrameLayout.LayoutParams(slotBtnSize, slotBtnSize)
            contentDescription = "Abrir Trackpad Flotante"
            setOnClickListener {
                try {
                    FloatingTrackpadService.start(context)
                } catch (_: Throwable) {}
            }
        }

        // Botón Micrófono
        val btnMic = ImageView(context).apply {
            try {
                setImageDrawable(ContextCompat.getDrawable(context, R.drawable.kb_ic_mic))
            } catch (_: Throwable) {
                try { setImageResource(R.drawable.kb_ic_mic) } catch (_: Throwable) {}
            }
            setColorFilter(Color.parseColor("#FF453A"))
            val pad = (6 * density).toInt()
            setPadding(pad, pad, pad, pad)
            layoutParams = FrameLayout.LayoutParams(slotBtnSize, slotBtnSize)
            contentDescription = "Iniciar Grabación de Voz"
            setOnClickListener {
                try {
                    onMicTap()
                } catch (_: Throwable) {}
            }
        }

        // Slot Izquierdo
        val slotL = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(slotBtnSize, slotBtnSize).apply {
                gravity = Gravity.START or Gravity.TOP
                leftMargin = (8 * density).toInt()
                topMargin = initialSlotTop
            }
            addView(if (slotOrder == "mic_camera_trackpad") btnMic else btnTrackpad)
        }

        // Slot Derecho
        val slotR = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(slotBtnSize, slotBtnSize).apply {
                gravity = Gravity.END or Gravity.TOP
                rightMargin = (8 * density).toInt()
                topMargin = initialSlotTop
            }
            addView(if (slotOrder == "mic_camera_trackpad") btnTrackpad else btnMic)
        }

        // Punch Central con soporte para gestos: Tap (toggle), Swipe Down (open), Swipe Up (close)
        val camPunch = FrameLayout(context).apply {
            val punchW = (48 * density).toInt()
            val punchH = (heightDp * density).toInt()
            layoutParams = FrameLayout.LayoutParams(punchW, punchH).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.TOP
            }

            val dot = View(context).apply {
                val dotSize = (12 * density).toInt()
                layoutParams = FrameLayout.LayoutParams(dotSize, dotSize).apply {
                    gravity = Gravity.CENTER
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.BLACK)
                    val strokeColor = if (isLight) Color.parseColor("#33000000") else Color.parseColor("#44FFFFFF")
                    setStroke((1f * density).toInt(), strokeColor)
                }
            }
            addView(dot)
            contentDescription = "Abrir Historial de Transcripciones"
            isClickable = true
            isFocusable = true

            setOnClickListener {
                try {
                    if (!isRecording) {
                        toggleHistoryModal()
                        performHaptic(isFirm = false)
                    }
                } catch (_: Throwable) {}
            }

            setOnTouchListener(object : View.OnTouchListener {
                private var startX = 0f
                private var startY = 0f
                private var isDragging = false

                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    try {
                        if (isRecording) return false
                        when (event.actionMasked) {
                            MotionEvent.ACTION_DOWN -> {
                                startX = event.rawX
                                startY = event.rawY
                                isDragging = false
                                return true
                            }
                            MotionEvent.ACTION_MOVE -> {
                                val dy = event.rawY - startY
                                val dx = event.rawX - startX
                                if (abs(dy) > (10 * density) && abs(dy) > abs(dx)) {
                                    isDragging = true
                                }
                                return true
                            }
                            MotionEvent.ACTION_UP -> {
                                val dy = event.rawY - startY
                                val dx = event.rawX - startX
                                val slop = 12 * density
                                if (isDragging || abs(dy) > slop) {
                                    if (dy > slop) {
                                        // Swipe Down -> Abrir Historial
                                        openHistoryModal()
                                        performHaptic(isFirm = false)
                                    } else if (dy < -slop) {
                                        // Swipe Up -> Cerrar Historial
                                        closeHistoryModal()
                                        performHaptic(isFirm = false)
                                    }
                                } else if (abs(dx) < slop && abs(dy) < slop) {
                                    // Tap -> Toggle Historial vía click accesible
                                    v.performClick()
                                }
                                return true
                            }
                            MotionEvent.ACTION_CANCEL -> {
                                isDragging = false
                                return true
                            }
                        }
                    } catch (_: Throwable) {}
                    return false
                }
            })
        }

        root.addView(slotL)
        root.addView(camPunch)
        root.addView(slotR)

        this.slotLeft = slotL
        this.slotRight = slotR
        this.camPunch = camPunch

        return root
    }

    private fun buildRecordingView(): LinearLayout {
        waveBars.clear()
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding((12 * density).toInt(), 0, (12 * density).toInt(), 0)
        }

        // Contenedor indicador y timer
        val timerGroup = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

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
        timerGroup.addView(redDot)

        // Cronómetro en vivo
        val tvTimer = TextView(context).apply {
            id = View.generateViewId()
            text = "00:00"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = android.graphics.Typeface.MONOSPACE
        }
        timerGroup.addView(tvTimer)
        root.addView(timerGroup)

        // Visualizador de 9 barras reactivas de onda con animación escalonada (matching UI lab)
        val waveContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(0, (22 * density).toInt(), 1.0f).apply {
                setMargins((8 * density).toInt(), 0, (8 * density).toInt(), 0)
            }
        }

        val barW = (3 * density).toInt()
        val barH = (20 * density).toInt()
        val barMarginH = (1.5f * density).toInt()

        for (i in 0 until 9) {
            val waveBar = View(context).apply {
                layoutParams = LinearLayout.LayoutParams(barW, barH).apply {
                    setMargins(barMarginH, 0, barMarginH, 0)
                }
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 2f * density
                    setColor(Color.parseColor("#30D158"))
                }
                pivotY = barH.toFloat() // transform-origin: bottom
                scaleY = 0.2f
            }
            waveBars.add(waveBar)
            waveContainer.addView(waveBar)
        }
        root.addView(waveContainer)

        // Acciones: Botón de Finalización [✓] y Botón de Cancelación [✕]
        val actionsGroup = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val btnFinish = TextView(context).apply {
            text = "✓"
            setTextColor(Color.parseColor("#30D158"))
            textSize = 16f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            val s = (30 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(s, s).apply {
                setMargins(0, 0, (4 * density).toInt(), 0)
            }
            contentDescription = "Detener y Transcribir"
            setOnClickListener {
                try {
                    onStopRecording()
                } catch (_: Throwable) {}
            }
        }
        actionsGroup.addView(btnFinish)

        val btnCancel = TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#FF453A"))
            textSize = 16f
            gravity = Gravity.CENTER
            val s = (30 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(s, s)
            contentDescription = "Cancelar Grabación"
            setOnClickListener {
                try {
                    cancelRecording()
                } catch (_: Throwable) {}
            }
        }
        actionsGroup.addView(btnCancel)
        root.addView(actionsGroup)

        return root
    }

    private fun startWaveformAnimation() {
        stopWaveformAnimation()
        if (!waveformEnabled) return
        for (i in 0 until waveBars.size.coerceAtMost(waveDelays.size)) {
            val bar = waveBars[i]
            val delay = waveDelays[i]
            val anim = ValueAnimator.ofFloat(0.2f, 1.0f).apply {
                duration = 700L
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                interpolator = AccelerateDecelerateInterpolator()
                startDelay = delay
                addUpdateListener { a ->
                    try {
                        bar.scaleY = a.animatedValue as Float
                    } catch (_: Throwable) {}
                }
            }
            waveAnimators.add(anim)
            anim.start()
        }
    }

    private fun stopWaveformAnimation() {
        for (anim in waveAnimators) {
            try { anim.cancel() } catch (_: Throwable) {}
        }
        waveAnimators.clear()
        for (bar in waveBars) {
            try { bar.scaleY = 0.2f } catch (_: Throwable) {}
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
            setPadding((14 * density).toInt(), 0, (14 * density).toInt(), 0)

            // Indicador giratorio (spinner) de progreso
            val spinner = ProgressBar(context, null, android.R.attr.progressBarStyleSmall).apply {
                val s = (18 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s).apply {
                    setMargins(0, 0, (10 * density).toInt(), 0)
                }
                isIndeterminate = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#58A6FF"))
                }
            }
            spinnerView = spinner
            addView(spinner)

            val tvStatus = TextView(context).apply {
                id = View.generateViewId()
                text = "Procesando con Groq..."
                setTextColor(Color.WHITE)
                textSize = 13f
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

        // Header con título y botón de cierre
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
                    try {
                        closeHistoryModal()
                    } catch (_: Throwable) {}
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
            ).apply {
                setMargins(0, 0, 0, (6 * density).toInt())
            }
            isVerticalScrollBarEnabled = false
            isFillViewport = true
        }
        historyScrollView = scrollView

        val cardsList = LinearLayout(context).apply {
            id = View.generateViewId()
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }
        historyCardsList = cardsList
        scrollView.addView(cardsList)
        root.addView(scrollView)

        // Rayita interactiva inferior (drag handle)
        val bottomHandleZone = FrameLayout(context).apply {
            val h = (46 * density).toInt()
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
                    try {
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
                                    // Arrastre hacia abajo: expande hacia 50% de pantalla
                                    val maxH = (screenHeight * 0.50f).toInt()
                                    val newH = (startH + dy).toInt().coerceAtMost(maxH)
                                    islandLayoutParams.height = newH
                                    try {
                                        windowManager.updateViewLayout(islandContainer, islandLayoutParams)
                                    } catch (_: Throwable) {}

                                    // Mantener los botones deslizantes alineados a las esquinas inferiores
                                    val slotBtnSize = (34 * density).toInt()
                                    val initialSlotTop = ((heightDp * density - slotBtnSize) / 2f).coerceAtLeast(0f)
                                    val curSlotDeltaY = (newH - 46 * density) - initialSlotTop
                                    slotLeft?.translationY = curSlotDeltaY
                                    slotRight?.translationY = curSlotDeltaY
                                } else if (dy < -(20 * density)) {
                                    // Swipe-up: cierra directamente la modal
                                    closeHistoryModal()
                                    return true
                                }
                                return true
                            }
                            MotionEvent.ACTION_UP -> {
                                if (!didDrag) {
                                    // 1-tap en rayita: cierra directamente
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
                    } catch (_: Throwable) {}
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
        try {
            val cardsList = historyCardsList ?: run {
                val root = historyModalView ?: return
                val scrollView = root.getChildAt(1) as? ScrollView ?: return
                scrollView.getChildAt(0) as? LinearLayout ?: return
            }
            cardsList.removeAllViews()

            val repo = TranscriptionHistoryRepository(context)
            val rawItems = try {
                repo.loadHistory()
            } catch (e: Throwable) {
                emptyList<JSONObject>()
            }

            val items = rawItems.filter { it.optString("text", "").isNotBlank() }

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

                    // Texto del snippet con contraste accesible para temas claro y oscuro
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

                    // Botón de copiado con confirmación de tilde verde usando ContextCompat.getDrawable
                    val btnCopy = ImageView(context).apply {
                        try {
                            setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                        } catch (_: Throwable) {
                            try { setImageResource(R.drawable.ic_copy) } catch (_: Throwable) {}
                        }
                        setColorFilter(if (isNight) Color.WHITE else Color.parseColor("#3C3C43"))
                        val p = (6 * density).toInt()
                        setPadding(p, p, p, p)
                        val s = (28 * density).toInt()
                        layoutParams = LinearLayout.LayoutParams(s, s).apply {
                            setMargins((6 * density).toInt(), 0, 0, 0)
                        }
                        contentDescription = "Copiar al portapapeles"
                        setOnClickListener {
                            try {
                                copyToClipboard(text)
                                try {
                                    setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
                                } catch (_: Throwable) {
                                    try { setImageResource(R.drawable.ic_check) } catch (_: Throwable) {}
                                }
                                setColorFilter(Color.parseColor("#30D158"))
                                postDelayed({
                                    try {
                                        try {
                                            setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                                        } catch (_: Throwable) {
                                            try { setImageResource(R.drawable.ic_copy) } catch (_: Throwable) {}
                                        }
                                        setColorFilter(if (isNight) Color.WHITE else Color.parseColor("#3C3C43"))
                                    } catch (_: Throwable) {}
                                }, 1200L)
                            } catch (_: Throwable) {}
                        }
                    }
                    addView(btnCopy)

                    // Clic en el cuerpo: inyecta directamente en el cursor, copia al portapapeles y cierra modal
                    setOnClickListener {
                        try {
                            val injected = VoiceKeyboardService.commitFromExternal(text)
                            copyToClipboard(text)
                            closeHistoryModal()
                        } catch (_: Throwable) {}
                    }

                    // Presión larga: expande mensaje en Y para lectura completa
                    setOnLongClickListener {
                        try {
                            tvSnippet.maxLines = if (tvSnippet.maxLines == Int.MAX_VALUE) 2 else Int.MAX_VALUE
                            performHaptic(isFirm = true)
                        } catch (_: Throwable) {}
                        true
                    }
                }
                cardsList.addView(card)
            }
        } catch (e: Throwable) {
            // Comprehensive guard against any crash on touch
        }
    }

    /**
     * Calcula límites adaptativos para evitar que la pastilla sobresalga de la pantalla.
     * Réplica exacta de applyAdaptiveRecordingBounds del laboratorio UI.
     */
    private fun calculateAdaptiveBounds(targetWDp: Int, targetHDp: Int): IntArray {
        val margin = (10 * density).toInt()
        val targetW = (targetWDp * density).toInt()
        val targetH = (targetHDp * density).toInt()
        val clampedW = min(targetW, screenWidth - (margin * 2))

        val compactCenterX = (screenWidth / 2) + (posX * density).toInt()
        val halfW = clampedW / 2

        val targetX: Int = when {
            compactCenterX + halfW > screenWidth - margin -> {
                // Sobresale borde derecho: anclar al margen derecho
                val targetCenterX = screenWidth - margin - halfW
                targetCenterX - (screenWidth / 2)
            }
            compactCenterX - halfW < margin -> {
                // Sobresale borde izquierdo: anclar al margen izquierdo
                val targetCenterX = margin + halfW
                targetCenterX - (screenWidth / 2)
            }
            else -> {
                (posX * density).toInt()
            }
        }

        val minTop = min(0, (posY * density).toInt())
        val safeTop = (posY * density).toInt().coerceIn(minTop, max(minTop, screenHeight - targetH - margin))
        return intArrayOf(clampedW, targetH, targetX, safeTop)
    }

    private fun animateBoundsAndMorph(
        targetW: Int,
        targetH: Int,
        targetX: Int,
        targetY: Int,
        targetRadiusDp: Float,
        onStart: (() -> Unit)? = null,
        onProgress: ((fraction: Float) -> Unit)? = null,
        onEnd: (() -> Unit)? = null
    ) {
        try {
            morphAnimator?.let {
                it.removeAllListeners()
                it.cancel()
            }
            morphAnimator = null
            val startW = islandLayoutParams.width
            val startH = islandLayoutParams.height
            val startX = islandLayoutParams.x
            val startY = islandLayoutParams.y
            val startR = currentRadiusDp

            onStart?.invoke()

            if (startW == targetW && startH == targetH && startX == targetX && startY == targetY && startR == targetRadiusDp) {
                onProgress?.invoke(1f)
                onEnd?.invoke()
                return
            }

            morphAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = MORPH_DURATION_MS
                interpolator = FLUID_INTERPOLATOR
                addUpdateListener { anim ->
                    try {
                        val f = anim.animatedValue as Float
                        islandLayoutParams.width = (startW + (targetW - startW) * f).toInt()
                        islandLayoutParams.height = (startH + (targetH - startH) * f).toInt()
                        islandLayoutParams.x = (startX + (targetX - startX) * f).toInt()
                        islandLayoutParams.y = (startY + (targetY - startY) * f).toInt()

                        val curR = startR + (targetRadiusDp - startR) * f
                        currentRadiusDp = curR
                        islandContainer?.background = createIslandBackground(cornerRadius = curR * density)

                        onProgress?.invoke(f)

                        islandContainer?.let { root ->
                            windowManager.updateViewLayout(root, islandLayoutParams)
                        }
                    } catch (_: Throwable) {}
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            islandLayoutParams.width = targetW
                            islandLayoutParams.height = targetH
                            islandLayoutParams.x = targetX
                            islandLayoutParams.y = targetY
                            currentRadiusDp = targetRadiusDp
                            islandContainer?.background = createIslandBackground(cornerRadius = targetRadiusDp * density)
                            islandContainer?.let { root ->
                                windowManager.updateViewLayout(root, islandLayoutParams)
                            }
                            onEnd?.invoke()
                        } catch (_: Throwable) {}
                    }
                })
                start()
            }
        } catch (_: Throwable) {
            onEnd?.invoke()
        }
    }

    private fun copyToClipboard(text: String) {
        try {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            val clip = ClipData.newPlainText("VoiceBubble STT", text)
            clipboard?.setPrimaryClip(clip)
            performHaptic(isFirm = false)
        } catch (_: Throwable) {}
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
        } catch (_: Throwable) {}
    }

    fun startRecordingUI() {
        try {
            if (isRecording) return
            isRecording = true
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null

            if (isHistoryOpen) {
                closeHistoryModal()
            }

            compactView?.visibility = View.GONE
            statusView?.visibility = View.GONE
            historyModalView?.visibility = View.GONE
            recordingView?.visibility = View.VISIBLE
            recordingView?.alpha = 1f

            val bounds = calculateAdaptiveBounds(330, 48)
            animateBoundsAndMorph(
                targetW = bounds[0],
                targetH = bounds[1],
                targetX = bounds[2],
                targetY = bounds[3],
                targetRadiusDp = 24f,
                onStart = {
                    startWaveformAnimation()
                }
            )

            recSeconds = 0
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = object : Runnable {
                override fun run() {
                    recSeconds++
                    val m = String.format("%02d", recSeconds / 60)
                    val s = String.format("%02d", recSeconds % 60)
                    recordingView?.let { root ->
                        val group = root.getChildAt(0) as? LinearLayout
                        val tv = group?.getChildAt(1) as? TextView
                        tv?.text = "$m:$s"
                    }
                    mainHandler.postDelayed(this, 1000L)
                }
            }
            mainHandler.postDelayed(recTimerRunnable!!, 1000L)
        } catch (_: Throwable) {}
    }

    fun showProcessingUI() {
        try {
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = null
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null
            stopWaveformAnimation()

            recordingView?.visibility = View.GONE
            historyModalView?.visibility = View.GONE
            compactView?.visibility = View.GONE
            statusView?.visibility = View.VISIBLE
            statusView?.alpha = 1f
            spinnerView?.visibility = View.VISIBLE

            statusView?.let { root ->
                val tv = root.getChildAt(1) as? TextView
                tv?.text = "Procesando con Groq..."
            }

            val bounds = calculateAdaptiveBounds(240, 48)
            animateBoundsAndMorph(
                targetW = bounds[0],
                targetH = bounds[1],
                targetX = bounds[2],
                targetY = bounds[3],
                targetRadiusDp = 24f
            )
        } catch (_: Throwable) {}
    }

    fun showSuccessUI(text: String) {
        try {
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null

            recordingView?.visibility = View.GONE
            historyModalView?.visibility = View.GONE
            compactView?.visibility = View.GONE
            statusView?.visibility = View.VISIBLE
            statusView?.alpha = 1f

            spinnerView?.visibility = View.GONE
            statusView?.let { root ->
                val tv = root.getChildAt(1) as? TextView
                tv?.text = "✓ ¡Copiado y pegado!"
            }

            val runnable = Runnable {
                try {
                    collapseToCompact()
                } catch (_: Throwable) {}
            }
            collapseRunnable = runnable
            mainHandler.postDelayed(runnable, 1200L)
        } catch (_: Throwable) {}
    }

    fun cancelRecording() {
        try {
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = null
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null
            stopWaveformAnimation()
            isRecording = false
            onCancelRecording()
            collapseToCompact()
        } catch (_: Throwable) {}
    }

    fun collapseToCompact() {
        try {
            val wasHistoryOpen = isHistoryOpen || historyModalView?.visibility == View.VISIBLE
            isRecording = false
            isHistoryOpen = false
            isHistoryExtended50 = false
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = null
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null
            stopWaveformAnimation()

            recordingView?.visibility = View.GONE
            statusView?.visibility = View.GONE
            compactView?.visibility = View.VISIBLE
            compactView?.alpha = 1f

            val compactW = (widthDp * density).toInt()
            val compactH = (heightDp * density).toInt()
            val compactX = (posX * density).toInt()
            val compactY = (posY * density).toInt()
            val targetR = heightDp / 2f

            val startSlotX = slotLeft?.translationX ?: 0f
            val startSlotY = slotLeft?.translationY ?: 0f
            val startCamAlpha = camPunch?.alpha ?: 1f
            val startCamTransY = camPunch?.translationY ?: 0f

            animateBoundsAndMorph(
                targetW = compactW,
                targetH = compactH,
                targetX = compactX,
                targetY = compactY,
                targetRadiusDp = targetR,
                onProgress = { fraction ->
                    try {
                        val inv = 1f - fraction
                        if (wasHistoryOpen) {
                            historyModalView?.alpha = inv
                        }
                        slotLeft?.translationX = startSlotX * inv
                        slotLeft?.translationY = startSlotY * inv
                        slotRight?.translationX = -startSlotX * inv
                        slotRight?.translationY = startSlotY * inv
                        camPunch?.alpha = startCamAlpha + (1f - startCamAlpha) * fraction
                        camPunch?.translationY = startCamTransY * inv
                    } catch (_: Throwable) {}
                },
                onEnd = {
                    try {
                        historyModalView?.visibility = View.GONE
                        historyModalView?.alpha = 0f
                        slotLeft?.translationX = 0f
                        slotLeft?.translationY = 0f
                        slotRight?.translationX = 0f
                        slotRight?.translationY = 0f
                        camPunch?.alpha = 1f
                        camPunch?.translationY = 0f
                        camPunch?.isClickable = true
                        camPunch?.isEnabled = true
                        spinnerView?.visibility = View.VISIBLE
                    } catch (_: Throwable) {}
                }
            )
        } catch (_: Throwable) {}
    }

    fun toggleHistoryModal() {
        try {
            if (isHistoryOpen) {
                closeHistoryModal()
            } else {
                openHistoryModal()
            }
        } catch (_: Throwable) {}
    }

    fun openHistoryModal() {
        try {
            if (isRecording || isHistoryOpen) return
            isHistoryOpen = true

            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null

            recordingView?.visibility = View.GONE
            statusView?.visibility = View.GONE

            populateHistoryCards()

            val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((340 * density).toInt())
            val modalH = if (isHistoryExtended50) (screenHeight * 0.50f).toInt() else (230 * density).toInt()

            val margin = (10 * density).toInt()
            val halfModalW = modalW / 2
            val targetCenterX = (screenWidth / 2) + (posX * density).toInt()
            val clampedCenterX = targetCenterX.coerceIn(margin + halfModalW, screenWidth - margin - halfModalW)
            val targetX = clampedCenterX - (screenWidth / 2)
            val minTop = min(0, (posY * density).toInt())
            val targetY = (posY * density).toInt().coerceIn(minTop, max(minTop, screenHeight - modalH - margin))

            val slotBtnSize = (34 * density).toInt()
            val initialSlotTop = ((heightDp * density - slotBtnSize) / 2f).coerceAtLeast(0f)
            val targetSlotTop = modalH - (46 * density)
            val targetDeltaY = targetSlotTop - initialSlotTop
            val targetDeltaX = (14 - 8) * density

            val startSlotX = slotLeft?.translationX ?: 0f
            val startSlotY = slotLeft?.translationY ?: 0f

            historyModalView?.visibility = View.VISIBLE
            historyModalView?.alpha = 0f
            compactView?.visibility = View.VISIBLE

            camPunch?.isClickable = false
            camPunch?.isEnabled = false

            animateBoundsAndMorph(
                targetW = modalW,
                targetH = modalH,
                targetX = targetX,
                targetY = targetY,
                targetRadiusDp = 28f,
                onProgress = { fraction ->
                    try {
                        historyModalView?.alpha = fraction
                        val curDeltaX = startSlotX + (targetDeltaX - startSlotX) * fraction
                        val curDeltaY = startSlotY + (targetDeltaY - startSlotY) * fraction
                        slotLeft?.translationX = curDeltaX
                        slotLeft?.translationY = curDeltaY
                        slotRight?.translationX = -curDeltaX
                        slotRight?.translationY = curDeltaY
                        camPunch?.alpha = (1f - fraction).coerceIn(0f, 1f)
                        camPunch?.translationY = (-80f * density) * fraction
                    } catch (_: Throwable) {}
                },
                onEnd = {
                    try {
                        historyModalView?.alpha = 1f
                        slotLeft?.translationX = targetDeltaX
                        slotLeft?.translationY = targetDeltaY
                        slotRight?.translationX = -targetDeltaX
                        slotRight?.translationY = targetDeltaY
                        camPunch?.alpha = 0f
                        camPunch?.translationY = -80f * density
                    } catch (_: Throwable) {}
                }
            )
        } catch (_: Throwable) {}
    }

    fun closeHistoryModal() {
        try {
            if (!isHistoryOpen) return
            isHistoryOpen = false
            isHistoryExtended50 = false

            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null

            val compactW = (widthDp * density).toInt()
            val compactH = (heightDp * density).toInt()
            val compactX = (posX * density).toInt()
            val compactY = (posY * density).toInt()
            val targetR = heightDp / 2f

            val slotBtnSize = (34 * density).toInt()
            val initialSlotTop = ((heightDp * density - slotBtnSize) / 2f).coerceAtLeast(0f)
            val startH = islandLayoutParams.height
            val defaultDeltaY = (startH - 46 * density) - initialSlotTop
            val defaultDeltaX = (14 - 8) * density

            val startSlotX = slotLeft?.translationX ?: defaultDeltaX
            val startSlotY = slotLeft?.translationY ?: defaultDeltaY

            animateBoundsAndMorph(
                targetW = compactW,
                targetH = compactH,
                targetX = compactX,
                targetY = compactY,
                targetRadiusDp = targetR,
                onProgress = { fraction ->
                    try {
                        val inv = 1f - fraction
                        historyModalView?.alpha = inv
                        slotLeft?.translationX = startSlotX * inv
                        slotLeft?.translationY = startSlotY * inv
                        slotRight?.translationX = -startSlotX * inv
                        slotRight?.translationY = startSlotY * inv
                        camPunch?.alpha = fraction
                        camPunch?.translationY = (-80f * density) * inv
                    } catch (_: Throwable) {}
                },
                onEnd = {
                    try {
                        historyModalView?.visibility = View.GONE
                        historyModalView?.alpha = 0f
                        slotLeft?.translationX = 0f
                        slotLeft?.translationY = 0f
                        slotRight?.translationX = 0f
                        slotRight?.translationY = 0f
                        camPunch?.alpha = 1f
                        camPunch?.translationY = 0f
                        camPunch?.isClickable = true
                        camPunch?.isEnabled = true
                    } catch (_: Throwable) {}
                }
            )
        } catch (_: Throwable) {}
    }

    fun setHistoryExtended50(extended: Boolean) {
        try {
            isHistoryExtended50 = extended
            val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((340 * density).toInt())
            val modalH = if (extended) (screenHeight * 0.50f).toInt() else (230 * density).toInt()

            val margin = (10 * density).toInt()
            val halfModalW = modalW / 2
            val targetCenterX = (screenWidth / 2) + (posX * density).toInt()
            val clampedCenterX = targetCenterX.coerceIn(margin + halfModalW, screenWidth - margin - halfModalW)
            val targetX = clampedCenterX - (screenWidth / 2)
            val minTop = min(0, (posY * density).toInt())
            val targetY = (posY * density).toInt().coerceIn(minTop, max(minTop, screenHeight - modalH - margin))

            val slotBtnSize = (34 * density).toInt()
            val initialSlotTop = ((heightDp * density - slotBtnSize) / 2f).coerceAtLeast(0f)
            val deltaX = (14 - 8) * density

            val startSlotDeltaY = slotLeft?.translationY ?: 0f
            val targetSlotDeltaY = (modalH - 46 * density) - initialSlotTop

            animateBoundsAndMorph(
                targetW = modalW,
                targetH = modalH,
                targetX = targetX,
                targetY = targetY,
                targetRadiusDp = 28f,
                onProgress = { fraction ->
                    try {
                        val curDeltaY = startSlotDeltaY + (targetSlotDeltaY - startSlotDeltaY) * fraction
                        slotLeft?.translationY = curDeltaY
                        slotRight?.translationY = curDeltaY
                        slotLeft?.translationX = deltaX
                        slotRight?.translationX = -deltaX
                    } catch (_: Throwable) {}
                },
                onEnd = {
                    try {
                        slotLeft?.translationY = targetSlotDeltaY
                        slotRight?.translationY = targetSlotDeltaY
                        slotLeft?.translationX = deltaX
                        slotRight?.translationX = -deltaX
                    } catch (_: Throwable) {}
                }
            )
        } catch (_: Throwable) {}
    }

    fun destroy() {
        try {
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = null
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null
            morphAnimator?.let {
                it.removeAllListeners()
                it.cancel()
            }
            morphAnimator = null
            stopWaveformAnimation()
            if (islandContainer != null) {
                try {
                    windowManager.removeViewImmediate(islandContainer)
                } catch (_: Throwable) {}
                islandContainer = null
            }
        } catch (_: Throwable) {}
    }
}
