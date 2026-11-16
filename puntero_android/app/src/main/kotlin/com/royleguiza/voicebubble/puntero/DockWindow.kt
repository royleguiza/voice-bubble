package com.royleguiza.voicebubble.puntero

import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.WindowManager

/**
 * Ventana flotante de la barra, la burbuja, el abanico y la isla: port de
 * `GlassWindow` de VoiceBubble. Ya no es un cuadro de diálogo de la app (una
 * ventana de aplicación queda debajo de la barra de estado y Android 12+ le
 * bloquea toques) sino una ventana TYPE_ACCESSIBILITY_OVERLAY del servicio:
 * queda por encima de todo y es de confianza, así que ya no hace falta
 * apartarla del camino de un clic como en el host.
 *
 * Superficie sólida Horizonte, sin desenfoque: la ventana es transparente y la
 * vista dibuja su propia superficie. Sin foco y sin bloquear los toques que
 * caen fuera de su rectángulo.
 *
 * [noLimits]: solo la isla (puede quedar sobre la barra de estado y la cámara,
 * en pantalla completa sin insets). La barra y la burbuja nunca salen de la
 * pantalla: además las posiciona el controlador dentro de la zona segura.
 */
internal class DockWindow(
    private val windowManager: WindowManager,
    private val content: View,
    private val noLimits: Boolean = false,
) {
    private var params: WindowManager.LayoutParams? = null
    private var attached = false
    private var touchable = true
    private var veiled = false
    private var userAlpha = 1f

    var x = 0
        private set
    var y = 0
        private set
    var width = 0
        private set
    var height = 0
        private set

    private fun baseFlags(): Int {
        var f = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        if (noLimits) f = f or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        return f
    }

    /** Agrega la ventana. Devuelve false si Android no la dejó crear. */
    fun show(x: Int, y: Int, w: Int, h: Int): Boolean {
        this.x = x
        this.y = y
        width = w
        height = h
        if (attached) {
            applyBounds()
            return true
        }
        val lp = WindowManager.LayoutParams(
            w,
            h,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            baseFlags(),
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            this.y = y
            windowAnimations = 0
            alpha = if (veiled) 0f else userAlpha
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                fitInsetsTypes = 0
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        return try {
            windowManager.addView(content, lp)
            params = lp
            attached = true
            updateFlags()
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isShown(): Boolean = attached

    fun setBounds(x: Int, y: Int, w: Int, h: Int) {
        this.x = x
        this.y = y
        width = w
        height = h
        applyBounds()
    }

    fun moveTo(x: Int, y: Int) = setBounds(x, y, width, height)

    private fun applyBounds() {
        val lp = params ?: return
        lp.x = x
        lp.y = y
        lp.width = width
        lp.height = height
        try {
            windowManager.updateViewLayout(content, lp)
        } catch (_: Exception) {}
    }

    /** Ventana visible pero que deja pasar los toques (p. ej. mientras se anima). */
    fun setTouchable(enabled: Boolean) {
        touchable = enabled
        updateFlags()
    }

    /** Recibir ACTION_OUTSIDE cuando tocan fuera (cerrar el abanico). */
    fun setWatchOutside(enabled: Boolean) {
        val lp = params ?: return
        lp.flags = if (enabled) {
            lp.flags or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
        } else {
            lp.flags and WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH.inv()
        }
        pushParams()
    }

    /** Zona protegida del gesto Atrás (Android 10+, tope 200 dp por borde). */
    fun setGestureExclusion(rect: Rect?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            content.systemGestureExclusionRects = if (rect == null) emptyList() else listOf(rect)
        }
    }

    /** Muestra u oculta la vista; oculta no recibe toques. */
    fun setVisible(visible: Boolean) {
        content.visibility = if (visible) View.VISIBLE else View.INVISIBLE
        updateFlags()
    }

    /**
     * Opacidad de la ventana sin tocar si recibe toques: la barra se vuelve
     * invisible mientras el dedo, que empezó sobre ella, arrastra la burbuja.
     */
    fun setWindowAlpha(alpha: Float) {
        userAlpha = alpha
        val lp = params ?: return
        lp.alpha = if (veiled) 0f else alpha
        pushParams()
    }

    /**
     * Velo (fase 4, historial): la ventana sigue puesta —la barra cuenta como
     * dibujada y VoiceBubble no saca la suya— pero no se ve y deja pasar los
     * toques al panel de historial que queda debajo.
     */
    fun setVeiled(on: Boolean) {
        if (veiled == on) return
        veiled = on
        val lp = params ?: return
        lp.alpha = if (on) 0f else userAlpha
        updateFlags()
    }

    private fun updateFlags() {
        val lp = params ?: return
        val off = veiled || !touchable || content.visibility != View.VISIBLE
        lp.flags = if (off) {
            lp.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        } else {
            lp.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        }
        pushParams()
    }

    private fun pushParams() {
        val lp = params ?: return
        try {
            windowManager.updateViewLayout(content, lp)
        } catch (_: Exception) {}
    }

    /** Saca la ventana ya, sin animar. */
    fun dismiss() {
        content.animate().cancel()
        if (attached) {
            attached = false
            try {
                windowManager.removeViewImmediate(content)
            } catch (_: Exception) {}
        }
        params = null
    }
}
