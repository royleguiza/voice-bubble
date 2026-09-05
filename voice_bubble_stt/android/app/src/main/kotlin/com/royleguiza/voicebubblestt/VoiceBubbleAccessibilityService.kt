package com.royleguiza.voicebubblestt

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import kotlin.math.abs

/**
 * Servicio de accesibilidad para la inyección de gestos del Trackpad Virtual (MEJ-09).
 *
 * REGLA INMUTABLE DE PRIVACIDAD:
 * CERO monitoreo de texto o contenido de ventanas (canRetrieveWindowContent="false").
 * CERO registro, buffers o telemetría de eventos (onAccessibilityEvent vacío y sin logs).
 * Se utiliza de forma exclusiva para despachar toques (tap), pulsaciones largas y scroll
 * sobre la pantalla mediante dispatchGesture.
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

        /** El FGS la llama al arrancar: crea la isla si la burbuja está activa. */
        fun ensureIsland() {
            try {
                instance?.setupIslandOverlayIfNeeded()
            } catch (_: Throwable) {}
        }

        /** El FGS la llama al detenerse: la isla pertenece a la burbuja activa. */
        fun removeIsland() {
            try {
                instance?.teardownIslandOverlay()
            } catch (_: Throwable) {}
        }

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
        setupIslandOverlayIfNeeded()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        teardownIslandOverlay()
        instance = null
        isScrollActive = false
        pendingScrollDelta = 0f
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        teardownIslandOverlay()
        instance = null
        isScrollActive = false
        pendingScrollDelta = 0f
        super.onDestroy()
    }

    // ——— Isla exacta sobre cámara (TYPE_ACCESSIBILITY_OVERLAY) ———
    private var islandController: DynamicIslandController? = null

    /**
     * Crea la isla con TYPE_ACCESSIBILITY_OVERLAY: capa por encima de la
     * status-bar, recibe touch en Y=0..12 donde TYPE_APPLICATION_OVERLAY es
     * consumido por el sistema. Solo en modo dynamic_island (default).
     * Requiere API 26+ (minSdk 28 OK). Sin duplicados: registra el controlador
     * en FloatingBubbleService y le pide soltar su fallback local.
     */
    private fun setupIslandOverlayIfNeeded() {
        try {
            if (islandController != null) return
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // La isla pertenece a la burbuja: sin burbuja activa no aparecer sola.
            val bubbleOn = prefs.getBoolean("flutter.floating_bubble_enabled", false) ||
                prefs.getBoolean("floating_bubble_enabled", false)
            if (!bubbleOn) return
            val dockingMode = prefs.getString("flutter.bubble_docking_mode", null)
                ?: prefs.getString("bubble_docking_mode", "dynamic_island") ?: "dynamic_island"
            if (dockingMode == "classic_bubble") return
            val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
            val controller = DynamicIslandController(
                context = this,
                windowManager = wm,
                onMicTap = {
                    try {
                        FloatingBubbleService.onBubbleActionListener?.onBubbleTap()
                    } catch (_: Throwable) {}
                },
                onCancelRecording = {
                    try {
                        FloatingBubbleService.updateState("idle")
                    } catch (_: Throwable) {}
                    try {
                        FloatingBubbleService.onBubbleActionListener?.onBubbleCancel()
                    } catch (_: Throwable) {}
                },
                onStopRecording = {
                    try {
                        FloatingBubbleService.onBubbleActionListener?.onBubbleTap()
                    } catch (_: Throwable) {}
                },
                overlayType = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            )
            islandController = controller
            FloatingBubbleService.accessibilityIsland = controller
            FloatingBubbleService.dropLocalIsland()
        } catch (_: Throwable) {}
    }

    private fun teardownIslandOverlay() {
        try {
            islandController?.destroy()
        } catch (_: Throwable) {}
        islandController = null
        try {
            if (FloatingBubbleService.accessibilityIsland != null) {
                FloatingBubbleService.accessibilityIsland = null
            }
        } catch (_: Throwable) {}
        try {
            FloatingBubbleService.restoreLocalIsland()
        } catch (_: Throwable) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // CERO telemetría: estrictamente vacío para garantizar privacidad total
    }

    override fun onInterrupt() {
        // No-op
    }
}
