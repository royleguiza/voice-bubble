package com.royleguiza.voicebubblestt

import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import kotlin.math.abs

/**
 * Capa Spacebar (SPK-05, módulo 17 de N): gestos de la barra espaciadora
 * MEJ-25 (deslizamiento Gboard, trackpad 2D iOS con blank-out y selección
 * multitáctil), extraída de VoiceKeyboardService sin cambiar conducta.
 * Todo lo que necesita del teclado entra por [service]
 * (contexto/sistema) y [host]; el estado del gesto (handler, runnable)
 * es suyo. PRIVACIDAD: nada se registra en Log.
 */
class SpacebarLayer(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {
    /** Constructor secundario para compatibilidad con llamadas sin handler explícito. */
    constructor(service: InputMethodService, host: UiHost) : this(service, Handler(Looper.getMainLooper()), host)

    /** Lo mínimo que la espaciadora exige al teclado. */
    interface UiHost {
        fun haptic(view: View)
        fun isShiftActive(): Boolean
        fun sendCode(code: Int)
        fun sendCodeWithMeta(code: Int, meta: Int)
        fun pressSpace()
        fun spacebarTrackpadMode(): String
        fun currentInputView(): View?
        fun longPressDelayMs(): Long
    }

    private var longPressRunnable: Runnable? = null

    fun attachSpacebarGestures(space: View) {
        // C-16: El listener anterior muere con su vista en rebuild: cancelar su
        // long-press pendiente en el handler compartido antes de asociar el nuevo.
        try {
            longPressRunnable?.let { handler.removeCallbacks(it) }
        } catch (_: Exception) {}
        longPressRunnable = null
        space.setOnTouchListener(object : View.OnTouchListener {
            private var startX = 0f
            private var startY = 0f
            private var lastX = 0f
            private var lastY = 0f
            private var isLongPressTriggered = false
            private var isDragNavTriggered = false
            private var isSelecting = false
            private val longPressTask = Runnable {
                if (host.spacebarTrackpadMode() == "ios_2d") {
                    isLongPressTriggered = true
                    setTrackpadBlankOutMode(true, space)
                    host.haptic(space)
                }
            }

            init {
                // Publicar el runnable vigente para cancelarlo en
                // rebuild/onDestroy aunque su vista ya no exista.
                longPressRunnable = longPressTask
            }

            private fun dispatchNavKey(keyCode: Int) {
                if (isSelecting || host.isShiftActive()) {
                    host.sendCodeWithMeta(keyCode, KeyEvent.META_SHIFT_ON)
                } else {
                    host.sendCode(keyCode)
                }
                host.haptic(space)
            }

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val density = service.resources.displayMetrics.density
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        v.parent?.requestDisallowInterceptTouchEvent(true)
                        startX = event.rawX
                        startY = event.rawY
                        lastX = event.rawX
                        lastY = event.rawY
                        isLongPressTriggered = false
                        isDragNavTriggered = false
                        isSelecting = false
                        v.isPressed = true
                        handler.removeCallbacks(longPressTask)
                        handler.postDelayed(longPressTask, host.longPressDelayMs())
                        return true
                    }
                    MotionEvent.ACTION_POINTER_DOWN -> {
                        // Toque con un segundo dedo mientras se navega activa selección de texto estilo iOS
                        if (isLongPressTriggered || isDragNavTriggered) {
                            isSelecting = true
                            host.haptic(space)
                        }
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val threshold = 14f * density
                        if (isLongPressTriggered) {
                            val deltaX = event.rawX - lastX
                            val stepsX = (abs(deltaX) / threshold).toInt()
                            if (stepsX > 0) {
                                val key = if (deltaX > 0) KeyEvent.KEYCODE_DPAD_RIGHT else KeyEvent.KEYCODE_DPAD_LEFT
                                for (i in 0 until stepsX) {
                                    dispatchNavKey(key)
                                }
                                lastX += stepsX * threshold * (if (deltaX > 0) 1 else -1)
                            }

                            val deltaY = event.rawY - lastY
                            val stepsY = (abs(deltaY) / threshold).toInt()
                            if (stepsY > 0) {
                                val key = if (deltaY > 0) KeyEvent.KEYCODE_DPAD_DOWN else KeyEvent.KEYCODE_DPAD_UP
                                for (i in 0 until stepsY) {
                                    dispatchNavKey(key)
                                }
                                lastY += stepsY * threshold * (if (deltaY > 0) 1 else -1)
                            }
                        } else {
                            if (abs(event.rawX - startX) > (16f * density)) {
                                handler.removeCallbacks(longPressTask)
                                isDragNavTriggered = true
                            }
                            if (isDragNavTriggered) {
                                val deltaX = event.rawX - lastX
                                val stepsX = (abs(deltaX) / threshold).toInt()
                                if (stepsX > 0) {
                                    val key = if (deltaX > 0) KeyEvent.KEYCODE_DPAD_RIGHT else KeyEvent.KEYCODE_DPAD_LEFT
                                    for (i in 0 until stepsX) {
                                        dispatchNavKey(key)
                                    }
                                    lastX += stepsX * threshold * (if (deltaX > 0) 1 else -1)
                                }
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        handler.removeCallbacks(longPressTask)
                        v.isPressed = false
                        if (isLongPressTriggered) {
                            setTrackpadBlankOutMode(false, space)
                            host.haptic(space)
                        } else if (!isDragNavTriggered) {
                            host.pressSpace()
                        }
                        isSelecting = false
                        return true
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        handler.removeCallbacks(longPressTask)
                        v.isPressed = false
                        if (isLongPressTriggered) {
                            setTrackpadBlankOutMode(false, space)
                        }
                        isSelecting = false
                        return true
                    }
                }
                return false
            }
        })
    }

    fun cancelPending() {
        try {
            longPressRunnable?.let { handler.removeCallbacks(it) }
        } catch (_: Exception) {}
        longPressRunnable = null
        // C-16: Restaurar alpha=1 inmediatamente sobre las vistas del teclado
        // para que un rebuild rápido no deje el teclado invisible ni con glifos apagados.
        setTrackpadBlankOutMode(false, space = null, immediate = true)
    }

    private fun setTrackpadBlankOutMode(enabled: Boolean, space: View? = null, immediate: Boolean = false) {
        val targetAlpha = if (enabled) 0.0f else 1.0f
        fun fadeGlyphs(view: View) {
            if (space != null && view === space) return
            if (view is TextView || (view is ImageView && (space == null || view !== space))) {
                view.animate().cancel()
                if (immediate) {
                    view.alpha = targetAlpha
                } else {
                    view.animate().alpha(targetAlpha).setDuration(120L).start()
                }
            } else if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    fadeGlyphs(view.getChildAt(i))
                }
            }
        }
        host.currentInputView()?.let { fadeGlyphs(it) }
    }
}
