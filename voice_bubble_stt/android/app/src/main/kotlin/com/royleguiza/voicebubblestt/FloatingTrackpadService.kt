package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.LinearLayout
import android.widget.Toast
import kotlin.math.hypot
import kotlin.math.roundToInt

/**
 * Trackpad flotante que abre la barra (herramienta "Puntero").
 *
 * - Sin burbuja propia: lo abre la barra y, al cerrarse, el servicio termina.
 * - "Se abre como" (flutter.pointer_open_mode): panel abajo o ventana flotante.
 * - La línea de arriba: un toque lo cierra; arrastrarla mueve la ventana o
 *   baja el panel; se acorta mostrando cuánto falta para el cierre automático
 *   (flutter.kb_trackpad_auto_return, 0 = queda abierto).
 * - Clics, clic largo y scroll en otras apps: vía el complemento
 *   VoiceBubble Puntero ([PointerLink]). Sin él, el puntero solo se mueve.
 *   Ver docs/contrato-trackpad.md.
 */
class FloatingTrackpadService : Service() {

    companion object {
        const val ACTION_OPEN = "com.royleguiza.voicebubblestt.ACTION_OPEN_TRACKPAD"
        const val ACTION_STOP = "com.royleguiza.voicebubblestt.ACTION_STOP_TRACKPAD"
        const val EXTRA_ANCHOR_X = "anchor_x"
        const val EXTRA_ANCHOR_Y = "anchor_y"
        const val PREF_OPEN_MODE = "flutter.pointer_open_mode"
        const val MODE_PANEL = "panel"
        const val MODE_WINDOW = "window"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun open(context: Context, anchorX: Int, anchorY: Int) {
            val intent = Intent(context, FloatingTrackpadService::class.java).apply {
                action = ACTION_OPEN
                putExtra(EXTRA_ANCHOR_X, anchorX)
                putExtra(EXTRA_ANCHOR_Y, anchorY)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FloatingTrackpadService::class.java))
        }
    }

    private var windowManager: WindowManager? = null
    private var pointerManager: PointerOverlayManager? = null
    private var panelWindow: GlassWindow? = null
    private var container: LinearLayout? = null
    private var handleView: HandleView? = null
    private var mode = MODE_PANEL
    private var extended = false
    private val handler = Handler(Looper.getMainLooper())
    private var lastNoCompanionHint = 0L
    private var lastProblemHint = 0L
    private var padView: FloatingPadView? = null
    private var autoReturnSeconds = 0
    private val idleClose = Runnable { closePanel() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        pointerManager = PointerOverlayManager(this)
        PointerLink.listen(this) { showProblem(it) }
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_OPEN -> {
                val ax = intent.getIntExtra(EXTRA_ANCHOR_X, -1)
                val ay = intent.getIntExtra(EXTRA_ANCHOR_Y, -1)
                try {
                    openPanel(ax, ay)
                } catch (_: Exception) {
                    stopSelf()
                }
            }
            else -> if (panelWindow == null) stopSelf()
        }
        // Servicio de UI bajo demanda: si el proceso muere no se resucita solo.
        return START_NOT_STICKY
    }

    // ------------------------------------------------------------- medidas

    private val d get() = resources.displayMetrics.density

    private fun screenSize(): Pair<Int, Int> {
        val wm = windowManager
        if (wm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val b = wm.currentWindowMetrics.bounds
                if (b.width() > 0) return Pair(b.width(), b.height())
            } catch (_: Exception) {}
        }
        return Pair(resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels)
    }

    private fun bottomInset(): Int {
        val wm = windowManager
        if (wm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val i = wm.currentWindowMetrics.windowInsets.getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars())
                return i.bottom
            } catch (_: Exception) {}
        }
        return (24 * d).roundToInt()
    }

    private fun panelHeight(): Int = ((if (extended) 380 else 240) * d).roundToInt()

    // --------------------------------------------------------------- panel

    private fun readMode(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val v = try {
            prefs.getString(PREF_OPEN_MODE, MODE_PANEL)
        } catch (_: Exception) {
            MODE_PANEL
        }
        return if (v == MODE_WINDOW) MODE_WINDOW else MODE_PANEL
    }

    private fun openPanel(anchorX: Int, anchorY: Int) {
        mode = readMode()
        if (panelWindow == null) buildPanel()
        val win = panelWindow ?: return
        val (sw, sh) = screenSize()
        val h = panelHeight()
        val (x, y, w) = if (mode == MODE_PANEL) {
            val margin = (10 * d).roundToInt()
            Triple(margin, sh - bottomInset() - h - (12 * d).roundToInt(), sw - 2 * margin)
        } else {
            val w = (280 * d).roundToInt().coerceAtMost(sw - (16 * d).roundToInt())
            val ax = if (anchorX >= 0) anchorX else sw / 2
            val ay = if (anchorY >= 0) anchorY else sh / 2
            val x = if (ax < sw / 2) ax + (16 * d).roundToInt() else ax - w - (16 * d).roundToInt()
            Triple(x.coerceIn(0, sw - w), (ay - h / 2).coerceIn((40 * d).roundToInt(), sh - h - bottomInset()), w)
        }
        if (win.isShown()) win.setBounds(x, y, w, h) else win.show(x, y, w, h)
        container?.let {
            it.alpha = 0f
            it.scaleX = 0.92f
            it.scaleY = 0.92f
            it.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(220L).start()
        }
        pointerManager?.resetBottomLimit()
        pointerManager?.show()
        startIdle()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun buildPanel() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val scrollDir = prefs.getString("flutter.kb_trackpad_scroll_direction", "natural") ?: "natural"
        autoReturnSeconds = try {
            when (val raw = prefs.all["flutter.kb_trackpad_auto_return"]) {
                is Number -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
        val sens = try {
            when (val raw = prefs.all["flutter.kb_trackpad_sensitivity"]) {
                is Number -> raw.toFloat()
                is String -> raw.toFloatOrNull() ?: 1.2f
                else -> 1.2f
            }
        } catch (_: Exception) {
            1.2f
        }
        val accel = prefs.getString("flutter.kb_trackpad_accel_curve", "dynamic") ?: "dynamic"
        val style = prefs.getString("flutter.kb_trackpad_pointer_style", "arrow") ?: "arrow"
        // Contrato kb_trackpad_haptic: String ("subtle"/"none"/"firm"), nunca bool.
        val hapticMode = try {
            (prefs.getString("flutter.kb_trackpad_haptic", "subtle") ?: "subtle").takeIf {
                it == "subtle" || it == "none" || it == "firm"
            } ?: "subtle"
        } catch (_: Exception) {
            "subtle"
        }

        pointerManager?.apply {
            sensitivity = sens
            accelCurve = accel
            pointerStyle = style
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = (10 * d).roundToInt()
            setPadding(pad, (2 * d).roundToInt(), pad, pad)
        }
        val handle = HandleView(this)
        handle.contentDescription = "Cerrar trackpad"
        handle.setOnTouchListener(HandleTouch())
        root.addView(handle, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (34 * d).roundToInt()))

        // Superficie única como el prototipo HTML (sin botones ni grilla).
        val pad = FloatingPadView(
            context = this,
            naturalScroll = scrollDir != "traditional",
            listener = object : FloatingPadView.Listener {
                override fun onMove(dx: Float, dy: Float) {
                    pointerManager?.moveBy(dx, dy)
                    updateGhost()
                }

                override fun onTap() {
                    pointerManager?.triggerClickFeedback()
                    val pos = pointerManager?.getPosition() ?: return
                    if (!PointerLink.tap(this@FloatingTrackpadService, pos.first, pos.second)) hintNoCompanion()
                }

                override fun onLongPress() {
                    pointerManager?.triggerClickFeedback(long = true)
                    val pos = pointerManager?.getPosition() ?: return
                    if (!PointerLink.longPress(this@FloatingTrackpadService, pos.first, pos.second)) hintNoCompanion()
                }

                override fun onScroll(gestureDy: Float) {
                    val pos = pointerManager?.getPosition() ?: return
                    if (!PointerLink.scroll(this@FloatingTrackpadService, pos.first, pos.second, gestureDy)) hintNoCompanion()
                }

                override fun onTouchStart() {
                    cancelIdle()
                }

                override fun onTouchEnd() {
                    startIdle()
                }

                override fun performHaptic(isFirm: Boolean) {
                    vibrate(isFirm, hapticMode)
                }
            },
        )
        root.addView(pad, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        padView = pad

        container = root
        handleView = handle
        panelWindow = GlassWindow(this, root, cornerRadiusPx = 30 * d) { blur ->
            root.background = if (blur) null else android.graphics.drawable.GradientDrawable().apply {
                cornerRadius = 30 * d
                setColor(androidx.core.content.ContextCompat.getColor(this@FloatingTrackpadService, R.color.dock_glass_frosted))
                setStroke((1 * d).roundToInt(), androidx.core.content.ContextCompat.getColor(this@FloatingTrackpadService, R.color.dock_glass_line))
            }
        }
    }

    /** Puntero encima del panel: el panel se vuelve casi transparente (y el clic pasa). */
    private fun updateGhost() {
        val win = panelWindow ?: return
        val root = container ?: return
        val (px, py) = pointerManager?.getPosition() ?: return
        val inside = px >= win.x && px <= win.x + win.width && py >= win.y && py <= win.y + win.height
        val target = if (inside) 0.28f else 1f
        if (root.alpha != target) root.animate().alpha(target).setDuration(120L).start()
    }

    private fun hintNoCompanion() {
        val now = SystemClock.uptimeMillis()
        if (now - lastNoCompanionHint < 8000L) return
        lastNoCompanionHint = now
        val status = PointerLink.status(this)
        val msg = if (status == PointerProtocol.STATUS_MISSING) {
            "Para hacer clic en otras apps, instalá VoiceBubble Puntero"
        } else {
            "Activá VoiceBubble Puntero en Accesibilidad para hacer clic"
        }
        try {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        } catch (_: Exception) {}
    }

    /** Cierre automático al soltar (kb_trackpad_auto_return; 0 = queda abierto). */
    private fun startIdle() {
        handler.removeCallbacks(idleClose)
        val ms = autoReturnSeconds * 1000L
        if (ms <= 0) return
        handleView?.startCountdown(ms)
        handler.postDelayed(idleClose, ms)
    }

    private fun cancelIdle() {
        handler.removeCallbacks(idleClose)
        handleView?.cancelCountdown()
    }

    /** El complemento avisó que un clic no se hizo (o no respondió). */
    private fun showProblem(message: String) {
        val now = SystemClock.uptimeMillis()
        if (now - lastProblemHint < 6000L) return
        lastProblemHint = now
        try {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        } catch (_: Exception) {}
    }

    private fun vibrate(isFirm: Boolean, hapticMode: String) {
        if (hapticMode == "none") return
        val useFirm = isFirm || hapticMode == "firm"
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (vibrator?.hasVibrator() == true) {
                val effect = if (useFirm) {
                    VibrationEffect.createOneShot(35L, VibrationEffect.DEFAULT_AMPLITUDE)
                } else {
                    VibrationEffect.createOneShot(18L, 90)
                }
                vibrator.vibrate(effect)
            }
        } catch (_: Exception) {}
    }

    private fun setExtended(value: Boolean) {
        val win = panelWindow ?: return
        extended = value
        val h = panelHeight()
        val (_, sh) = screenSize()
        val y = if (mode == MODE_PANEL) sh - bottomInset() - h - (12 * d).roundToInt() else win.y
        win.setBounds(win.x, y, win.width, h)
    }

    private fun closePanel() {
        pointerManager?.hide()
        val root = container
        if (root == null) {
            stopSelf()
            return
        }
        root.animate().alpha(0f).scaleX(0.94f).scaleY(0.94f).setDuration(160L).withEndAction { stopSelf() }.start()
    }

    /** La línea: toque = cerrar; arrastre = mover (ventana) o bajar/extender (panel). */
    private inner class HandleTouch : View.OnTouchListener {
        private var x0 = 0f
        private var y0 = 0f
        private var wx0 = 0
        private var wy0 = 0
        private var dragged = false

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            val win = panelWindow ?: return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    x0 = e.rawX
                    y0 = e.rawY
                    wx0 = win.x
                    wy0 = win.y
                    dragged = false
                    cancelIdle()
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - x0
                    val dy = e.rawY - y0
                    if (!dragged && hypot(dx, dy) > 6 * d) dragged = true
                    if (!dragged) return true
                    if (mode == MODE_WINDOW) {
                        val (sw, sh) = screenSize()
                        win.moveTo((wx0 + dx).roundToInt().coerceIn(0, sw - win.width), (wy0 + dy).roundToInt().coerceIn(0, sh - win.height))
                    } else {
                        container?.translationY = dy.coerceAtLeast(0f)
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val dy = e.rawY - y0
                    container?.animate()?.translationY(0f)?.setDuration(160L)?.start()
                    if (!dragged) {
                        if (e.actionMasked == MotionEvent.ACTION_UP) closePanel()
                        return true
                    }
                    if (mode == MODE_PANEL) {
                        when {
                            dy > 55 * d -> closePanel()
                            dy < -25 * d && !extended -> setExtended(true)
                            dy > 20 * d && extended -> setExtended(false)
                        }
                    }
                }
            }
            return true
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        panelWindow?.refreshTheme()
        handleView?.refreshPalette()
        padView?.refreshPalette()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        PointerLink.stopListening(this)
        handleView?.cancelCountdown()
        pointerManager?.destroy()
        pointerManager = null
        panelWindow?.dismiss()
        panelWindow = null
        container = null
        handleView = null
        padView = null
        isRunning = false
        super.onDestroy()
    }
}

/**
 * La línea de arriba del trackpad: botón de cerrar y, a la vez, reloj del
 * cierre automático (se acorta desde los extremos hacia el centro).
 */
@SuppressLint("ViewConstructor")
internal class HandleView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density
    private var palette = DockPalette(context)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private var remaining = 1f
    private var counting = false
    private var animator: ValueAnimator? = null

    fun refreshPalette() {
        palette = DockPalette(context)
        invalidate()
    }

    fun startCountdown(totalMs: Long) {
        animator?.cancel()
        if (totalMs <= 0) return
        counting = true
        animator = ValueAnimator.ofFloat(1f, 0f).apply {
            duration = totalMs
            interpolator = LinearInterpolator()
            addUpdateListener {
                remaining = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    fun cancelCountdown() {
        animator?.cancel()
        animator = null
        counting = false
        remaining = 1f
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = 40 * d
        val h = 5 * d
        val cx = width / 2f
        val cy = height / 2f
        val track = RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        paint.color = palette.track
        canvas.drawRoundRect(track, h / 2, h / 2, paint)
        val fw = w * (if (counting) remaining else 1f)
        if (fw > 0.5f) {
            paint.color = if (counting) palette.accent else palette.handle
            canvas.drawRoundRect(RectF(cx - fw / 2, track.top, cx + fw / 2, track.bottom), h / 2, h / 2, paint)
        }
    }
}
