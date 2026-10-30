package com.royleguiza.voicebubble.puntero

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.os.Build
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/**
 * Hace los clics del puntero de VoiceBubble: tap, toque largo y scroll en
 * la posición que manda VoiceBubble. Nada más.
 *
 * - Solo escucha órdenes mientras el servicio está activo, y solo de apps
 *   con el permiso de firma [PointerProtocol.PERMISSION_POINTER].
 * - No lee ventanas (canRetrieveWindowContent=false), no registra eventos,
 *   no guarda nada.
 */
class PunteroService : AccessibilityService() {

    companion object {
        @Volatile
        var isConnected = false
            private set
    }

    private val scroll = ScrollQueue()
    private var registered = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != PointerProtocol.ACTION_POINTER) return
            val cmd = PointerProtocol.validate(
                intent.getStringExtra(PointerProtocol.EXTRA_OP),
                intent.getFloatExtra(PointerProtocol.EXTRA_X, Float.NaN),
                intent.getFloatExtra(PointerProtocol.EXTRA_Y, Float.NaN),
                intent.getFloatExtra(PointerProtocol.EXTRA_DY, 0f),
            ) ?: return
            when (cmd.op) {
                PointerProtocol.OP_TAP -> press(cmd.x, cmd.y, PointerProtocol.TAP_MS)
                PointerProtocol.OP_LONG_PRESS -> press(cmd.x, cmd.y, PointerProtocol.LONG_PRESS_MS)
                PointerProtocol.OP_SCROLL -> scroll.add(cmd.x, cmd.y, cmd.dy)?.let { dispatchScroll(it) }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isConnected = true
        if (!registered) {
            val filter = IntentFilter(PointerProtocol.ACTION_POINTER)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER, null, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER, null)
            }
            registered = true
        }
    }

    private fun screenHeight(): Float {
        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        if (wm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                return wm.currentWindowMetrics.bounds.height().toFloat()
            } catch (_: Exception) {}
        }
        return resources.displayMetrics.heightPixels.toFloat()
    }

    private fun press(x: Float, y: Float, durationMs: Long) {
        scroll.reset()
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        dispatch(path, durationMs, null)
    }

    private fun dispatchScroll(dy: Float) {
        val maxY = (screenHeight() - 1f).coerceAtLeast(1f)
        val startY = scroll.y.coerceIn(0f, maxY)
        val endY = (startY + dy).coerceIn(0f, maxY)
        val path = Path().apply {
            moveTo(scroll.x, startY)
            lineTo(scroll.x, endY)
        }
        val done: () -> Unit = {
            val next = scroll.finished()
            if (next != null) dispatchScroll(next)
        }
        if (!dispatch(path, PointerProtocol.SCROLL_MS, done)) scroll.reset()
    }

    private fun dispatch(path: Path, durationMs: Long, onEnd: (() -> Unit)?): Boolean {
        return try {
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0L, durationMs))
                .build()
            dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        onEnd?.invoke()
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        onEnd?.invoke()
                    }
                },
                null,
            )
        } catch (_: Exception) {
            false
        }
    }

    private fun unregister() {
        if (registered) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {}
            registered = false
        }
        scroll.reset()
        isConnected = false
    }

    override fun onUnbind(intent: Intent?): Boolean {
        unregister()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        unregister()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Cero telemetría: no se lee ni se guarda ningún evento.
    }

    override fun onInterrupt() {}
}
