package com.royleguiza.voicebubblestt

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent
import kotlin.math.abs

/**
 * DORMIDO (perfil anti-Play-Protect, sin declarar en manifest).
 * Puntero local sí; dispatch en otra app no. Ver docs/contrato-trackpad.md.
 */
class VoiceBubbleAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: VoiceBubbleAccessibilityService? = null
            private set

        @Volatile
        private var isScrollActive = false
        private var pendingScrollDelta = 0f
        private var lastScrollX = 0f
        private var lastScrollY = 0f

        fun isConnected(): Boolean = instance != null

        /**
         * Despacha un tap rápido (clic primario / izquierdo) en la posición (x, y).
         */
        fun dispatchTap(x: Float, y: Float, onComplete: ((Boolean) -> Unit)? = null): Boolean {
            val service = instance ?: return false
            if (x.isNaN() || y.isNaN() || x < 0f || y < 0f) return false

            // Cancelamos cualquier acumulación de scroll previa para no mezclar gestos
            pendingScrollDelta = 0f

            val path = Path().apply {
                moveTo(x, y)
                lineTo(x, y)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, 40L)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            return service.dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        onComplete?.invoke(true)
                    }
                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        onComplete?.invoke(false)
                    }
                },
                null
            )
        }

        /**
         * Despacha una pulsación larga (clic secundario / menú contextual) en la posición (x, y).
         */
        fun dispatchLongPress(x: Float, y: Float, durationMs: Long = 400L, onComplete: ((Boolean) -> Unit)? = null): Boolean {
            val service = instance ?: return false
            if (x.isNaN() || y.isNaN() || x < 0f || y < 0f) return false

            pendingScrollDelta = 0f

            val path = Path().apply {
                moveTo(x, y)
                lineTo(x, y)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, durationMs)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            return service.dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        onComplete?.invoke(true)
                    }
                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        onComplete?.invoke(false)
                    }
                },
                null
            )
        }

        /**
         * Despacha un desplazamiento vertical continuo (scroll) desde (x, y) con recorrido deltaY.
         * Incorpora acumulación y despacho en serie defensivo para que eventos de alta frecuencia
         * (60 Hz) no se cancelen mutuamente en el framework de accesibilidad de Android.
         */
        fun dispatchScroll(x: Float, y: Float, deltaY: Float, durationMs: Long = 80L, onComplete: ((Boolean) -> Unit)? = null): Boolean {
            val service = instance ?: return false
            if (x.isNaN() || y.isNaN() || deltaY.isNaN() || x < 0f || y < 0f) return false

            lastScrollX = x
            lastScrollY = y
            pendingScrollDelta += deltaY

            if (isScrollActive) {
                // Hay un trazo ejecutándose activamente; se despachará en cuanto termine
                return true
            }

            return flushPendingScroll(service, durationMs, onComplete)
        }

        private fun flushPendingScroll(
            service: VoiceBubbleAccessibilityService,
            durationMs: Long,
            onComplete: ((Boolean) -> Unit)?
        ): Boolean {
            val delta = pendingScrollDelta
            if (abs(delta) < 2f) {
                isScrollActive = false
                onComplete?.invoke(true)
                return true
            }

            pendingScrollDelta = 0f
            isScrollActive = true

            val clampedDelta = delta.coerceIn(-600f, 600f)
            val targetY = (lastScrollY + clampedDelta).coerceAtLeast(0f)

            val path = Path().apply {
                moveTo(lastScrollX, lastScrollY)
                lineTo(lastScrollX, targetY)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, durationMs)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()

            val dispatched = service.dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        isScrollActive = false
                        onComplete?.invoke(true)
                        if (abs(pendingScrollDelta) >= 2f && instance != null) {
                            flushPendingScroll(service, durationMs, null)
                        }
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        isScrollActive = false
                        onComplete?.invoke(false)
                        if (abs(pendingScrollDelta) >= 2f && instance != null) {
                            flushPendingScroll(service, durationMs, null)
                        }
                    }
                },
                null
            )

            if (!dispatched) {
                isScrollActive = false
            }
            return dispatched
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        isScrollActive = false
        pendingScrollDelta = 0f
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        isScrollActive = false
        pendingScrollDelta = 0f
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // CERO telemetría: estrictamente vacío para garantizar privacidad total
    }

    override fun onInterrupt() {
        // No-op
    }
}
