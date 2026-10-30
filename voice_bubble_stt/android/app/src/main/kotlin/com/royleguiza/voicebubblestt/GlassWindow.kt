package com.royleguiza.voicebubblestt

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.ContextThemeWrapper
import android.view.MotionEvent
import android.view.View
import android.view.Window
import android.view.WindowManager
import androidx.core.content.ContextCompat
import java.util.function.Consumer

/**
 * Ventana flotante de vidrio (barra, burbuja, abanico y trackpad).
 *
 * Por qué un Dialog y no WindowManager.addView: el desenfoque real de lo que
 * hay detrás (Window.setBackgroundBlurRadius, Android 12+) solo existe para
 * ventanas con objeto Window. El Dialog se muestra como TYPE_APPLICATION_OVERLAY,
 * sin foco y sin bloquear toques fuera de su rectángulo. Sin
 * FLAG_LAYOUT_NO_LIMITS (C-29): la barra/burbuja nunca sale de la pantalla;
 * además DockController limita cada posición a la zona segura.
 *
 * - [cornerRadiusPx] != null: el sistema desenfoca el fondo dentro de un
 *   rectángulo redondeado (Android solo desenfoca formas así). La vista
 *   dibuja el contenido; el tinte del vidrio lo pone el fondo de la ventana.
 * - [cornerRadiusPx] == null o sin soporte (Android 9–11, ahorro de batería,
 *   equipos que lo apagan): la vista dibuja vidrio lechoso por su cuenta.
 *   [onBlurChanged] le avisa cuál de los dos casos aplica.
 */
class GlassWindow(
    context: Context,
    private val content: View,
    private val cornerRadiusPx: Float?,
    private val onBlurChanged: (Boolean) -> Unit = {},
) : OverlayPassThrough.Handle {

    private val appContext = context.applicationContext
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    /** Toque fuera de la ventana (requiere [setWatchOutside]). */
    var onOutsideTouch: (() -> Unit)? = null

    private val host = object : Dialog(ContextThemeWrapper(context, android.R.style.Theme_Translucent_NoTitleBar)) {
        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (event.actionMasked == MotionEvent.ACTION_OUTSIDE) {
                onOutsideTouch?.invoke()
                return true
            }
            return super.onTouchEvent(event)
        }
    }
    private val window: Window
    private var shown = false
    private var passThrough = false
    private var touchable = true
    private var blurListener: Consumer<Boolean>? = null

    var x = 0
        private set
    var y = 0
        private set
    var width = 0
        private set
    var height = 0
        private set

    /** Desenfoque real activo ahora mismo. */
    var blurActive = false
        private set

    init {
        host.requestWindowFeature(Window.FEATURE_NO_TITLE)
        host.setCancelable(false)
        host.setCanceledOnTouchOutside(false)
        host.setContentView(content)
        window = host.window ?: throw IllegalStateException("Dialog sin Window")
        window.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        window.decorView.setPadding(0, 0, 0, 0)
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            // Android 9–10: sin esto, una ventana pegada a la barra de estado
            // recibe relleno del sistema y su contenido se corre.
            @Suppress("DEPRECATION")
            window.decorView.setOnApplyWindowInsetsListener { _, insets -> insets.consumeSystemWindowInsets() }
        }
        window.attributes = window.attributes.apply {
            gravity = android.view.Gravity.TOP or android.view.Gravity.START
            windowAnimations = 0
            dimAmount = 0f
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    /** Tinte del vidrio sobre el desenfoque (token claro/noche). */
    private fun glassTint(): Int = ContextCompat.getColor(content.context, R.color.dock_glass_tint)

    private fun applyBlur() {
        val radius = cornerRadiusPx
        val supported = radius != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            try {
                wm.isCrossWindowBlurEnabled
            } catch (_: Exception) {
                false
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (supported && radius != null) {
                window.setBackgroundDrawable(
                    GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = radius
                        setColor(glassTint())
                    },
                )
                window.setBackgroundBlurRadius((24 * appContext.resources.displayMetrics.density).toInt())
            } else {
                window.setBackgroundBlurRadius(0)
                window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            }
        }
        if (blurActive != supported) {
            blurActive = supported
            onBlurChanged(supported)
        } else if (!shown) {
            onBlurChanged(supported)
        }
    }

    fun show(x: Int, y: Int, w: Int, h: Int) {
        setBounds(x, y, w, h)
        if (shown) return
        applyBlur()
        try {
            host.show()
            shown = true
        } catch (_: Exception) {
            shown = false
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && cornerRadiusPx != null) {
            val l = Consumer<Boolean> { applyBlur() }
            try {
                wm.addCrossWindowBlurEnabledListener(l)
                blurListener = l
            } catch (_: Exception) {}
        }
        OverlayPassThrough.register(this)
    }

    fun isShown(): Boolean = shown

    fun setBounds(x: Int, y: Int, w: Int, h: Int) {
        this.x = x
        this.y = y
        width = w
        height = h
        val attrs = window.attributes
        attrs.x = x
        attrs.y = y
        attrs.width = w
        attrs.height = h
        try {
            window.attributes = attrs
        } catch (_: Exception) {}
    }

    fun moveTo(x: Int, y: Int) = setBounds(x, y, width, height)

    /** Ventana visible pero que deja pasar los toques (p. ej. mientras se anima). */
    fun setTouchable(enabled: Boolean) {
        touchable = enabled
        updateFlags()
    }

    /** Recibir ACTION_OUTSIDE cuando tocan fuera (cerrar el abanico). */
    fun setWatchOutside(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH)
        }
    }

    /** Zona protegida del gesto Atrás (Android 10+, tope 200 dp por borde). */
    fun setGestureExclusion(rect: Rect?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            content.systemGestureExclusionRects = if (rect == null) emptyList() else listOf(rect)
        }
    }

    fun setVisible(visible: Boolean) {
        content.visibility = if (visible) View.VISIBLE else View.INVISIBLE
        val attrs = window.attributes
        attrs.alpha = if (visible && !passThrough) 1f else 0f
        try {
            window.attributes = attrs
        } catch (_: Exception) {}
        updateFlags()
    }

    /**
     * Opacidad de la ventana sin tocar si recibe toques: la barra se vuelve
     * invisible mientras el dedo, que empezó sobre ella, arrastra la burbuja.
     */
    fun setWindowAlpha(alpha: Float) {
        val attrs = window.attributes
        attrs.alpha = if (passThrough) 0f else alpha
        try {
            window.attributes = attrs
        } catch (_: Exception) {}
    }

    private fun updateFlags() {
        val off = passThrough || !touchable || content.visibility != View.VISIBLE
        if (off) {
            window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        }
    }

    override fun screenBounds(): IntArray? {
        if (!shown || content.visibility != View.VISIBLE) return null
        return intArrayOf(x, y, x + width, y + height)
    }

    override fun setPassThrough(enabled: Boolean) {
        if (passThrough == enabled) return
        passThrough = enabled
        val attrs = window.attributes
        attrs.alpha = if (enabled || content.visibility != View.VISIBLE) 0f else 1f
        try {
            window.attributes = attrs
        } catch (_: Exception) {}
        updateFlags()
    }

    /** Releer tema claro/oscuro (cambia el tinte del vidrio). */
    fun refreshTheme() {
        if (shown) applyBlur()
        content.invalidate()
    }

    fun dismiss() {
        OverlayPassThrough.unregister(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            blurListener?.let {
                try {
                    wm.removeCrossWindowBlurEnabledListener(it)
                } catch (_: Exception) {}
            }
        }
        blurListener = null
        if (shown) {
            try {
                host.dismiss()
            } catch (_: Exception) {}
        }
        shown = false
    }
}
