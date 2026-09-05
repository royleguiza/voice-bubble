package com.royleguiza.voicebubblestt

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
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
 * 5. En modo Procesamiento/Éxito: solo animación (spinner, luego check),
 *    sin textos; colapso automático.
 *
 * REGLA SAGRADA DE PRIVACIDAD: CERO logs ni telemetría de audios ni textos de transcripción.
 *
 * Overlay exacto sobre cámara (Y=0..12 dentro de la status-bar):
 * créese desde VoiceBubbleAccessibilityService con
 * overlayType = TYPE_ACCESSIBILITY_OVERLAY (capa por encima de la status-bar,
 * recibe touch donde TYPE_APPLICATION_OVERLAY es consumido por el sistema).
 * Sin accesibilidad, FloatingBubbleService usa TYPE_APPLICATION_OVERLAY como fallback.
 */
class DynamicIslandController(
    private val context: Context,
    private val windowManager: WindowManager,
    private val onMicTap: () -> Unit,
    private val onCancelRecording: () -> Unit,
    private val onStopRecording: () -> Unit,
    private val overlayType: Int? = null
) {

    companion object {
        private const val MORPH_DURATION_MS = 420L
        private val FLUID_INTERPOLATOR = PathInterpolator(0.16f, 1f, 0.3f, 1f)
        // Anti-rebote del centro: un tap = DOWN+UP+click; sin esto el toggle
        // abrir/cerrar se dispara dos veces y se percibe como "se cierra solo".
        private const val CENTER_DEBOUNCE_MS = 300L
    }

    // Métricas SIEMPRE frescas (getters, no vals de init): tras una rotación
    // los valores cacheados dejaban la isla fuera de pantalla o con el
    // tamaño del modo anterior.
    private val density: Float
        get() = context.resources.displayMetrics.density
    private val screenWidth: Int
        get() = context.resources.displayMetrics.widthPixels
    private val screenHeight: Int
        get() = context.resources.displayMetrics.heightPixels

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
    private var statusCheckView: ImageView? = null

    private val waveBars = ArrayList<View>()
    private val waveAnimators = ArrayList<ValueAnimator>()
    private val waveDelays = longArrayOf(50L, 200L, 350L, 100L, 450L, 250L, 400L, 150L, 300L)
    // Onda reactiva: multiplicadores fijos por barra (sin azar, testeable).
    private val waveMults = floatArrayOf(1.0f, 0.7f, 0.85f, 0.6f, 0.95f, 0.75f, 0.9f, 0.65f, 0.8f)
    private var waveReactive = false

    private var morphAnimator: ValueAnimator? = null
    private var currentRadiusDp = 18f

    private var isRecording = false
    private var isHistoryOpen = false
    private var isHistoryExtended50 = false
    private var isHistoryTall = false

    // Anti-rebote del centro: un tap = DOWN+UP+click; sin esto el toggle
    // abrir/cerrar se dispara dos veces y se percibe como "se cierra solo".
    // (Los contadores de diagnóstico se retiraron: sin lector.)
    private var lastCenterActionUptime = 0L

    /** Un solo camino de disparo para tap y swipe del centro (evita doble toggle). */
    private fun allowCenterAction(): Boolean {
        val now = SystemClock.uptimeMillis()
        if (now - lastCenterActionUptime < CENTER_DEBOUNCE_MS) {
            return false
        }
        lastCenterActionUptime = now
        return true
    }
    private var recSeconds = 0

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recTimerRunnable: Runnable? = null
    private var collapseRunnable: Runnable? = null

    private val isNight: Boolean
        get() = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private val isDarkUi: Boolean
        get() = when (islandTheme) {
            "light" -> false
            "dark" -> true
            else -> isNight
        }

    private var posX: Int = 0
    private var posY: Int = 12
    private var widthDp: Int = 184
    private var heightDp: Int = 36
    private var slotOrder: String = "trackpad_camera_mic"
    private var islandTheme: String = "dark"
    private var waveformEnabled: Boolean = true

    private val prefChangeListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key != null && key.contains("island")) {
            mainHandler.post {
                reloadConfiguration()
            }
        }
    }

    /** Borde superior táctil = barras de estado reales (con notch) + 8dp.
     * En API 30+ se lee el inset aplicado por el sistema (incluye el cutout
     * de la cámara); antes se usa el recurso + margen. Sin esto la píldora
     * bajo la cámara queda en zona muda (este equipo: cámara 0..40dp). */
    private fun statusBarFloorDp(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val insets = windowManager.currentWindowMetrics.windowInsets
                    .getInsets(android.view.WindowInsets.Type.statusBars())
                (insets.top / density).toInt() + 8
            } else {
                val resId = context.resources.getIdentifier("status_bar_height", "dimen", "android")
                val statusDp = if (resId > 0) {
                    (context.resources.getDimensionPixelSize(resId) / density).toInt()
                } else {
                    24
                }
                statusDp + 8
            }
        } catch (_: Exception) {
            48
        }
    }

    init {
        loadPreferences()
        setupIslandLayout()
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.registerOnSharedPreferenceChangeListener(prefChangeListener)
        } catch (_: Exception) {}
    }

    private fun loadPreferences() {
        val prefs = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        } catch (_: Exception) {
            return
        }
        // Try FINO por clave: un mismatch de tipos en una sola (p.ej. String
        // donde se espera Boolean lanza ClassCastException) no debe tumbar
        // ni ocultar la lectura del resto. Sin catch Throwable genérico.
        // (Claves literales a propósito: el CI valida la paridad
        // Flutter↔Kotlin con grep sobre `flutter.*`, sin interpolación.)
        posX = intPref(prefs, "flutter.island_pos_x", "island_pos_x", 0)
        posY = intPref(prefs, "flutter.island_pos_y", "island_pos_y", 12)
        // Piso táctil solo sin overlay de accesibilidad: el
        // APPLICATION_OVERLAY no recibe touch dentro de la status-bar.
        // Con accesibilidad (trial B) la isla vive sobre la cámara (Y≈0).
        posY = if (overlayType == WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY) {
            max(posY, -100)
        } else {
            max(posY, statusBarFloorDp())
        }
        widthDp = intPref(prefs, "flutter.island_width", "island_width", 184)
        heightDp = intPref(prefs, "flutter.island_height", "island_height", 36)
        slotOrder = stringPref(prefs, "flutter.island_slot_order", "island_slot_order", "trackpad_camera_mic")
        islandTheme = stringPref(prefs, "flutter.island_theme", "island_theme", "dark")
        waveformEnabled = booleanPref(prefs, "flutter.island_waveform_enabled", "island_waveform_enabled", true)
    }

    /** Entero tolerante con espejo flutter. primero (paridad Flutter↔Kotlin). */
    private fun intPref(prefs: SharedPreferences, flutterKey: String, plainKey: String, default: Int): Int = try {
        (prefs.all[flutterKey] as? Number)?.toInt()
            ?: (prefs.all[plainKey] as? Number)?.toInt() ?: default
    } catch (_: Exception) {
        default
    }

    /** Texto tolerante con espejo flutter. primero (paridad Flutter↔Kotlin). */
    private fun stringPref(prefs: SharedPreferences, flutterKey: String, plainKey: String, default: String): String = try {
        prefs.getString(flutterKey, null) ?: prefs.getString(plainKey, default) ?: default
    } catch (_: Exception) {
        default
    }

    /** Booleano tolerante que respeta el espejo escrito por Ajustes. */
    private fun booleanPref(prefs: SharedPreferences, flutterKey: String, plainKey: String, default: Boolean): Boolean = try {
        if (prefs.contains(flutterKey)) {
            prefs.getBoolean(flutterKey, default)
        } else {
            prefs.getBoolean(plainKey, default)
        }
    } catch (_: Exception) {
        default
    }

    private fun setupIslandLayout() {
        try {
            val layoutFlag = overlayType ?: if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
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
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
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

                    // Reconstruir todas las capas con el nuevo tema y orden de ranuras
                    historyModalView?.let { old -> root.removeView(old) }
                    recordingView?.let { old -> root.removeView(old) }
                    statusView?.let { old -> root.removeView(old) }
                    compactView?.let { old -> root.removeView(old) }

                    val newHistory = buildHistoryModalView().apply { visibility = View.GONE; alpha = 0f }
                    val newRecording = buildRecordingView().apply { visibility = View.GONE; alpha = 0f }
                    val newStatus = buildStatusView().apply { visibility = View.GONE; alpha = 0f }
                    val newCompact = buildCompactView()

                    historyModalView = newHistory
                    recordingView = newRecording
                    statusView = newStatus
                    compactView = newCompact

                    root.addView(newHistory)
                    root.addView(newRecording)
                    root.addView(newStatus)
                    root.addView(newCompact)
                }
            }
        } catch (_: Throwable) {}
    }

    /**
     * Colores de la píldora para el tema vigente, resueltos UNA vez por
     * llamada (parseColor es caro y no debe correr por frame de animación).
     */
    private fun islandBackgroundColors(): Pair<Int, Int> {
        return try {
            when (islandTheme) {
                "light" -> Pair(Color.parseColor("#FFFFFFFF"), Color.parseColor("#26000000"))
                "dark" -> Pair(Color.parseColor("#000000"), Color.parseColor("#33FFFFFF"))
                else -> {
                    val bgColor = if (isNight) Color.parseColor("#26FFFFFF") else Color.parseColor("#33FFFFFF")
                    Pair(bgColor, Color.parseColor("#4DFFFFFF"))
                }
            }
        } catch (_: Exception) {
            Pair(Color.BLACK, Color.WHITE)
        }
    }

    private fun createIslandBackground(cornerRadius: Float): GradientDrawable {
        val (bgColor, strokeColor) = islandBackgroundColors()
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            this.cornerRadius = cornerRadius
            setColor(bgColor)
            setStroke((1.2f * density).toInt(), strokeColor)
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

        // Punch Central: Tap (abre), Swipe Down (abre), Swipe Up (cierra).
        // Paridad lab (cutout sin punto, pointer-events:none al expandir):
        // NUNCA focusable (como los slots: robar foco cierra el teclado),
        // GONE al expandir (los taps llegan al historial, no a la app de atrás),
        // un solo camino con anti-rebote (sin doble toggle DOWN+UP+click).
        val camPunch = FrameLayout(context).apply {
            val punchW = (48 * density).toInt()
            val punchH = (heightDp * density).toInt()
            layoutParams = FrameLayout.LayoutParams(punchW, punchH).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.TOP
            }

            contentDescription = "Abrir Historial de Transcripciones"
            isClickable = true
            isFocusable = false
            isFocusableInTouchMode = false

            setOnClickListener {
                try {
                    // Fallback de accesibilidad (TalkBack): misma vía única.
                    if (!isRecording && !isHistoryOpen && allowCenterAction()) {
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
                        if (isRecording || isHistoryOpen) return false
                        if (event.pointerCount > 1) {
                            isDragging = false
                            return true
                        }
                        when (event.actionMasked) {
                            MotionEvent.ACTION_DOWN -> {
                                startX = event.rawX
                                startY = event.rawY
                                isDragging = false
                                return true
                            }
                            MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_POINTER_UP -> {
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
                                    if (!allowCenterAction()) return true
                                    if (dy > slop) {
                                        // Swipe Down -> Abrir Historial
                                        openHistoryModal()
                                        performHaptic(isFirm = false)
                                    } else if (dy < -slop) {
                                        // Swipe Up con historial cerrado: nada que cerrar.
                                    }
                                } else if (abs(dx) < slop && abs(dy) < slop) {
                                    // Tap -> vía única con anti-rebote (no performClick:
                                    // el onClick es solo fallback de accesibilidad).
                                    if (!allowCenterAction()) return true
                                    toggleHistoryModal()
                                    performHaptic(isFirm = false)
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
        val isLight = islandTheme == "light"
        val tvTimer = TextView(context).apply {
            id = View.generateViewId()
            text = "00:00"
            setTextColor(if (isLight) Color.parseColor("#1F2430") else Color.WHITE)
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
        // Tap en ondas o fondo = confirmar (evita errarle entre ✓ y ✕ juntas).
        waveContainer.isClickable = true
        waveContainer.setOnClickListener {
            try {
                onStopRecording()
            } catch (_: Throwable) {}
        }
        root.addView(waveContainer)
        root.isClickable = true
        root.setOnClickListener {
            try {
                onStopRecording()
            } catch (_: Throwable) {}
        }

        // Acciones: círculos grandes separados (✓ verde = OK, ✕ roja = descartar).
        val actionsGroup = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val actionSize = (32 * density).toInt()
        val btnFinish = TextView(context).apply {
            text = "✓"
            setTextColor(Color.WHITE)
            textSize = 17f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF30D158"))
            }
            layoutParams = LinearLayout.LayoutParams(actionSize, actionSize).apply {
                setMargins(0, 0, (10 * density).toInt(), 0)
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
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FFFF453A"))
            }
            layoutParams = LinearLayout.LayoutParams(actionSize, actionSize)
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
        waveReactive = false
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
        waveReactive = false
        for (anim in waveAnimators) {
            try { anim.cancel() } catch (_: Throwable) {}
        }
        waveAnimators.clear()
        for (bar in waveBars) {
            try { bar.scaleY = 0.2f } catch (_: Throwable) {}
        }
    }

    /**
     * Nivel real del micrófono (0..1, pico del WAV en Dart). Al primer nivel
     * apaga la animación decorativa y la onda refleja la voz: en silencio
     * (<0.05) las barras colapsan a ticks mínimos (línea punteada).
     */
    fun setWaveformLevel(level: Float) {
        try {
            if (!isRecording) return
            if (!waveReactive) {
                waveReactive = true
                for (anim in waveAnimators) {
                    try { anim.cancel() } catch (_: Throwable) {}
                }
                waveAnimators.clear()
            }
            if (waveBars.isEmpty()) return
            val lv = level.coerceIn(0f, 1f)
            for (i in waveBars.indices) {
                val m = waveMults[i % waveMults.size]
                val target = if (lv < 0.05f) {
                    0.12f
                } else {
                    0.2f + 0.8f * (lv * m).coerceIn(0f, 1f)
                }
                try {
                    waveBars[i].scaleY = target
                } catch (_: Throwable) {}
            }
        } catch (_: Throwable) {}
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

            // Indicador giratorio de progreso (sin textos: solo animación suave)
            val spinner = ProgressBar(context, null, android.R.attr.progressBarStyleSmall).apply {
                val s = (18 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s)
                isIndeterminate = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    indeterminateTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#58A6FF"))
                }
            }
            spinnerView = spinner
            addView(spinner)

            // Check de éxito (se muestra 1.2 s y colapsa, sin textos)
            val check = ImageView(context).apply {
                try {
                    setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_check))
                } catch (_: Throwable) {
                    try { setImageResource(R.drawable.ic_check) } catch (_: Throwable) {}
                }
                setColorFilter(Color.parseColor("#30D158"))
                val s = (22 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(s, s)
                contentDescription = "Listo"
                visibility = View.GONE
            }
            statusCheckView = check
            addView(check)
        }
    }

    private fun buildHistoryModalView(): LinearLayout {
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Paridad lab trackpad_lab.html .expanded-history { padding: 14px 16px }.
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), 0)
        }

        // Sin header superior ni título ni X (diseño lab trackpad_lab.html):
        // el historial se gestiona solo con slots laterales (puntero/mic),
        // tap en cards y rayita inferior (tap/swipe-up cierra, drag-down expande).

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
                    setColor(if (isDarkUi) Color.parseColor("#E6FFFFFF") else Color.parseColor("#CC1D1D1F"))
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

    fun populateHistoryCards() {
        // I/O fuera del main (disco + XML + prefs del repositorio): el render
        // vuelve al main y re-resuelve la lista vigente (un reload en el
        // medio puede haber reconstruido las vistas).
        BackgroundWork.executeWithResult(
            block = {
                try {
                    TranscriptionHistoryRepository(context).loadHistory()
                        .filter { it.optString("text", "").isNotBlank() }
                } catch (_: Exception) {
                    emptyList()
                }
            },
            onResult = { items -> renderHistoryCards(items ?: emptyList()) }
        )
    }

    /**
     * Renderiza las tarjetas adaptativas de historial:
     * - 1 elemento: 100% de la altura
     * - 2 elementos: 50% de la altura
     * - 3+ elementos: 3 elementos visibles + scroll
     */
    private fun renderHistoryCards(items: List<JSONObject>) {
        try {
            val cardsList = historyCardsList ?: run {
                val root = historyModalView ?: return
                // Sin header: child 0 = ScrollView, child 1 = rayita inferior.
                // Búsqueda por tipo para no depender del índice.
                var found: LinearLayout? = null
                for (i in 0 until root.childCount) {
                    val sv = root.getChildAt(i) as? ScrollView ?: continue
                    found = sv.getChildAt(0) as? LinearLayout
                    if (found != null) break
                }
                found ?: return
            }
            cardsList.removeAllViews()

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

                // Paridad lab: count-1 padding 12x14 align-top, count-2 padding 10x12
                // align-top, 3+ padding 10x7 min-height 46dp radius 10dp gap 6dp.
                val cardPaddingH = when (count) {
                    1 -> (14 * density).toInt()
                    2 -> (12 * density).toInt()
                    else -> (10 * density).toInt()
                }
                val cardPaddingV = when (count) {
                    1 -> (12 * density).toInt()
                    2 -> (10 * density).toInt()
                    else -> (7 * density).toInt()
                }
                val cardGravity = if (count <= 2) Gravity.TOP else Gravity.CENTER_VERTICAL

                fun cardBackground(expanded: Boolean): GradientDrawable {
                    return GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 10f * density
                        if (expanded) {
                            // Lab .snippet-expanded: rgba(88,166,255,0.14) + borde 0.45.
                            setColor(Color.parseColor("#2458A6FF"))
                            setStroke((1f * density).toInt(), Color.parseColor("#7358A6FF"))
                        } else {
                            val cardBg = when {
                                islandTheme == "dark" -> Color.parseColor("#1A1A1A")
                                islandTheme == "light" -> Color.parseColor("#F2F2F7")
                                // Lab glass: rgba(255,255,255,0.13) + borde 0.22.
                                else -> Color.parseColor("#21FFFFFF")
                            }
                            val cardStroke = when {
                                islandTheme == "dark" -> Color.parseColor("#26FFFFFF")
                                islandTheme == "light" -> Color.parseColor("#1F000000")
                                else -> Color.parseColor("#38FFFFFF")
                            }
                            setColor(cardBg)
                            setStroke((1f * density).toInt(), cardStroke)
                        }
                    }
                }

                fun copyBackground(copied: Boolean): GradientDrawable {
                    return GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 8f * density
                        if (copied) {
                            // Lab .copied: bg #238636 + borde #3fb950.
                            setColor(Color.parseColor("#FF238636"))
                            setStroke((1f * density).toInt(), Color.parseColor("#FF3FB950"))
                        } else if (islandTheme == "light" || (!isDarkUi && islandTheme == "glass")) {
                            setColor(Color.parseColor("#0F000000"))
                            setStroke((1f * density).toInt(), Color.parseColor("#1F000000"))
                        } else {
                            // Lab default: rgba(255,255,255,0.12).
                            setColor(Color.parseColor("#1FFFFFFF"))
                            setStroke((1f * density).toInt(), Color.parseColor("#26FFFFFF"))
                        }
                    }
                }

                val card = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = cardGravity

                    val cardLp = when (count) {
                        1, 2 -> LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1.0f).apply {
                            setMargins(0, (4 * density).toInt(), 0, (4 * density).toInt())
                        }
                        else -> LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (46 * density).toInt()).apply {
                            setMargins(0, (3 * density).toInt(), 0, (3 * density).toInt())
                        }
                    }
                    layoutParams = cardLp

                    background = cardBackground(expanded = false)
                    setPadding(cardPaddingH, cardPaddingV, cardPaddingH, cardPaddingV)

                    // Texto del snippet con contraste accesible para temas claro y oscuro
                    val tvSnippet = TextView(context).apply {
                        this.text = "\"$text\""
                        setTextColor(if (isDarkUi) Color.WHITE else Color.parseColor("#1C1C1E"))
                        textSize = 12f
                        maxLines = when (count) {
                            1 -> 16
                            2 -> 4
                            else -> 2
                        }
                        layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1.0f)
                    }
                    addView(tvSnippet)

                    // Botón de copiado 32dp radius 8dp (paridad lab .history-card-copy-btn).
                    val btnCopy = ImageView(context).apply {
                        try {
                            setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                        } catch (_: Throwable) {
                            try { setImageResource(R.drawable.ic_copy) } catch (_: Throwable) {}
                        }
                        setColorFilter(if (isDarkUi) Color.WHITE else Color.parseColor("#3C3C43"))
                        background = copyBackground(copied = false)
                        // Glifo 17-18px dentro de 32dp: padding 7dp.
                        val p = (7 * density).toInt()
                        setPadding(p, p, p, p)
                        val s = (32 * density).toInt()
                        layoutParams = LinearLayout.LayoutParams(s, s).apply {
                            setMargins((10 * density).toInt(), 0, 0, 0)
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
                                setColorFilter(Color.WHITE)
                                background = copyBackground(copied = true)
                                postDelayed({
                                    try {
                                        try {
                                            setImageDrawable(ContextCompat.getDrawable(context, R.drawable.ic_copy))
                                        } catch (_: Throwable) {
                                            try { setImageResource(R.drawable.ic_copy) } catch (_: Throwable) {}
                                        }
                                        setColorFilter(if (isDarkUi) Color.WHITE else Color.parseColor("#3C3C43"))
                                        background = copyBackground(copied = false)
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

                    // Presión larga: paridad lab toggleSnippetExpansion —
                    // expande texto + pinta card azul + crece isla a history-tall 350dp.
                    setOnLongClickListener {
                        try {
                            val defaultLines = when (count) {
                                1 -> 16
                                2 -> 4
                                else -> 2
                            }
                            val expanding = tvSnippet.maxLines != Int.MAX_VALUE
                            // Colapsar las demás como en el lab (lectura enfocada).
                            try {
                                val parent = parent as? LinearLayout
                                for (i in 0 until (parent?.childCount ?: 0)) {
                                    val other = parent?.getChildAt(i) as? LinearLayout
                                    if (other != null && other != this@apply) {
                                        other.background = cardBackground(expanded = false)
                                    }
                                }
                            } catch (_: Throwable) {}
                            if (expanding) {
                                tvSnippet.maxLines = Int.MAX_VALUE
                                background = cardBackground(expanded = true)
                                setHistoryTall(true)
                            } else {
                                tvSnippet.maxLines = defaultLines
                                background = cardBackground(expanded = false)
                                setHistoryTall(false)
                            }
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

            // Fondo precalculado UNA vez para el morph completo (colores del
            // tema vigente): por frame solo muta el radio del MISMO drawable.
            // Antes se alojaba un GradientDrawable + 2 parseColor por frame.
            val frameBg = createIslandBackground(cornerRadius = startR * density)
            islandContainer?.background = frameBg
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
                        try {
                            frameBg.cornerRadius = curR * density
                        } catch (_: Exception) {}

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
                            try {
                                frameBg.cornerRadius = targetRadiusDp * density
                            } catch (_: Exception) {}
                            islandContainer?.background = frameBg
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
            statusCheckView?.visibility = View.GONE

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
            statusCheckView?.visibility = View.VISIBLE

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
            isHistoryTall = false
            recTimerRunnable?.let { mainHandler.removeCallbacks(it) }
            recTimerRunnable = null
            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null
            stopWaveformAnimation()

            recordingView?.visibility = View.GONE
            statusView?.visibility = View.GONE
            compactView?.visibility = View.VISIBLE
            compactView?.alpha = 1f
            // Reingresa a hit-testing (pudo quedar GONE al colapsar desde abierto).
            camPunch?.visibility = View.VISIBLE

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
                        camPunch?.visibility = View.VISIBLE
                        camPunch?.alpha = 1f
                        camPunch?.translationY = 0f
                        camPunch?.isClickable = true
                        camPunch?.isEnabled = true
                        camPunch?.contentDescription = "Abrir Historial de Transcripciones"
                        spinnerView?.visibility = View.VISIBLE
                        statusCheckView?.visibility = View.GONE
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
            isHistoryTall = false

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

            // Paridad lab (cutout oculto al expandir): el centro se desvanece
            // y sale de hit-testing (GONE al final); los taps llegan al
            // historial dentro de la ventana, jamás a la app de atrás.
            // Siempre clicable al estar visible: no roba foco (ver construcción).
            camPunch?.visibility = View.VISIBLE
            camPunch?.isClickable = true
            camPunch?.isEnabled = true
            camPunch?.contentDescription = "Cerrar Historial de Transcripciones"

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
                        camPunch?.visibility = View.GONE
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
            isHistoryTall = false

            collapseRunnable?.let { mainHandler.removeCallbacks(it) }
            collapseRunnable = null

            // Reingresa a hit-testing antes de animar el fundido de entrada.
            camPunch?.visibility = View.VISIBLE

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
                        camPunch?.visibility = View.VISIBLE
                        camPunch?.alpha = 1f
                        camPunch?.translationY = 0f
                        camPunch?.isClickable = true
                        camPunch?.isEnabled = true
                        camPunch?.contentDescription = "Abrir Historial de Transcripciones"
                    } catch (_: Throwable) {}
                }
            )
        } catch (_: Throwable) {}
    }

    fun setHistoryExtended50(extended: Boolean) {
        try {
            isHistoryExtended50 = extended
            if (extended) isHistoryTall = false
            val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((340 * density).toInt())
            val modalH = when {
                extended -> (screenHeight * 0.50f).toInt()
                isHistoryTall -> (350 * density).toInt()
                else -> (230 * density).toInt()
            }

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

    /**
     * Paridad lab .history-tall (350px): long-press en una card expande la isla
     * en Y para lectura completa. Si el modo 50% está activo no hace nada
     * (ya es más alto). Misma curva 420ms e interpolador fluido.
     */
    fun setHistoryTall(expanded: Boolean) {
        try {
            if (!isHistoryOpen) return
            if (isHistoryExtended50) {
                isHistoryTall = false
                return
            }
            if (isHistoryTall == expanded) return
            isHistoryTall = expanded
            val modalW = (screenWidth - (24 * density).toInt()).coerceAtMost((340 * density).toInt())
            val modalH = if (expanded) (350 * density).toInt() else (230 * density).toInt()

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
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.unregisterOnSharedPreferenceChangeListener(prefChangeListener)
            } catch (_: Exception) {}
            if (islandContainer != null) {
                try {
                    windowManager.removeViewImmediate(islandContainer)
                } catch (_: Throwable) {}
                islandContainer = null
            }
        } catch (_: Throwable) {}
    }
}
