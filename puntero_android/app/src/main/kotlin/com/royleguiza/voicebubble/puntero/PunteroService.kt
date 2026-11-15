package com.royleguiza.voicebubble.puntero

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.Path
import android.os.Build
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/**
 * Hace los gestos del puntero de VoiceBubble y dibuja su trackpad: tap, toque
 * largo, scroll y arrastre en la posición que indica el puntero, y las
 * acciones de sistema (Atrás, Inicio, Recientes, Notificaciones).
 *
 * - El puntero y el panel del trackpad son ventanas de Accesibilidad
 *   ([TrackpadController]): quedan por encima de la barra de estado y la
 *   cortina, y los gestos salen directo, sin un broadcast por clic.
 * - Los gestos sueltos por broadcast (tap, toque largo, scroll) se conservan
 *   para el trackpad integrado al teclado de VoiceBubble.
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

        /** Servicio en marcha (para la prueba de clic de la pantalla del complemento). */
        @Volatile
        private var instance: PunteroService? = null

        // Diagnóstico en memoria desde que arrancó el servicio: solo cuentas,
        // nunca coordenadas ni a qué app fue el clic (se pierden al cerrarse).
        @Volatile var received = 0
            private set
        @Volatile var done = 0
            private set
        @Volatile var cancelled = 0
            private set
        @Volatile var rejected = 0
            private set

        /**
         * Toque de prueba en (x, y) de pantalla: lo usa la pantalla del
         * complemento para comprobar que Android ejecuta los gestos.
         * [result]: true = Android lo completó, false = lo canceló o rechazó.
         * Devuelve false si el servicio no está en marcha.
         */
        fun testTap(x: Float, y: Float, result: (Boolean) -> Unit): Boolean {
            val s = instance ?: return false
            val path = Path().apply {
                moveTo(x, y)
                lineTo(x, y)
            }
            return s.dispatch(path, PointerProtocol.TAP_MS, null) { result(it) }
        }
    }

    private val scroll = ScrollQueue()
    private var registered = false
    private var trackpad: TrackpadController? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                PointerProtocol.ACTION_OPEN_TRACKPAD -> {
                    openTrackpad(intent)
                    return
                }
                PointerProtocol.ACTION_CLOSE_TRACKPAD -> {
                    trackpad?.close()
                    return
                }
            }
            if (intent?.action != PointerProtocol.ACTION_POINTER) return
            val cmd = PointerProtocol.validate(
                intent.getStringExtra(PointerProtocol.EXTRA_OP),
                intent.getFloatExtra(PointerProtocol.EXTRA_X, Float.NaN),
                intent.getFloatExtra(PointerProtocol.EXTRA_Y, Float.NaN),
                intent.getFloatExtra(PointerProtocol.EXTRA_DY, 0f),
            ) ?: return
            val seq = intent.getIntExtra(PointerProtocol.EXTRA_SEQ, 0)
            when (cmd.op) {
                PointerProtocol.OP_TAP -> press(cmd.x, cmd.y, PointerProtocol.TAP_MS, seq)
                PointerProtocol.OP_LONG_PRESS -> press(cmd.x, cmd.y, PointerProtocol.LONG_PRESS_MS, seq)
                PointerProtocol.OP_SCROLL -> scroll.add(cmd.x, cmd.y, cmd.dy)?.let { dispatchScroll(it) }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isConnected = true
        instance = this
        // El WindowManager del servicio solo sirve para ventanas de Accesibilidad
        // una vez conectado: el controlador se crea acá, no antes.
        if (trackpad == null) trackpad = TrackpadController(this)
        if (!registered) {
            val filter = IntentFilter(PointerProtocol.ACTION_POINTER).apply {
                addAction(PointerProtocol.ACTION_OPEN_TRACKPAD)
                addAction(PointerProtocol.ACTION_CLOSE_TRACKPAD)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER, null, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER, null)
            }
            registered = true
        }
    }

    /** Valida la configuración que llega con OPEN_TRACKPAD y abre el trackpad. */
    private fun openTrackpad(intent: Intent) {
        val cfg = PointerProtocol.normalizeTrackpadConfig(
            anchorX = intent.getIntExtra(PointerProtocol.EXTRA_ANCHOR_X, -1),
            anchorY = intent.getIntExtra(PointerProtocol.EXTRA_ANCHOR_Y, -1),
            mode = intent.getStringExtra(PointerProtocol.EXTRA_MODE),
            sensitivity = intent.getFloatExtra(PointerProtocol.EXTRA_SENSITIVITY, Float.NaN),
            accel = intent.getStringExtra(PointerProtocol.EXTRA_ACCEL),
            style = intent.getStringExtra(PointerProtocol.EXTRA_STYLE),
            haptic = intent.getStringExtra(PointerProtocol.EXTRA_HAPTIC),
            scrollDir = intent.getStringExtra(PointerProtocol.EXTRA_SCROLL_DIR),
            autoReturnS = intent.getIntExtra(PointerProtocol.EXTRA_AUTO_RETURN, 0),
        )
        try {
            trackpad?.open(cfg)
        } catch (_: Exception) {
            // Sin ventanas no hay trackpad: que VoiceBubble no lo dé por abierto.
            trackpad?.destroy()
            sendTrackpadState(false)
        }
    }

    /** Le avisa a VoiceBubble si el trackpad está abierto (solo apps con la misma firma lo reciben). */
    internal fun sendTrackpadState(open: Boolean) {
        try {
            val intent = Intent(PointerProtocol.ACTION_TRACKPAD_STATE)
                .setPackage(PointerProtocol.HOST_PACKAGE)
                .putExtra(PointerProtocol.EXTRA_OPEN, open)
            sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)
        } catch (_: Exception) {}
    }

    /** Botones de sistema del panel (Atrás, Inicio, Recientes, Notificaciones). */
    internal fun globalAction(action: Int): Boolean = try {
        performGlobalAction(action)
    } catch (_: Exception) {
        false
    }

    /** Scroll por trazos encadenados (la cola evita que Android cancele uno con el siguiente). */
    internal fun scrollBy(x: Float, y: Float, dy: Float) {
        scroll.add(x, y, dy)?.let { dispatchScroll(it) }
    }

    /**
     * Arrastre: UN gesto de dos trazos continuos (espera en el origen + recorrido
     * al destino, ver [DragPlan]). Devuelve false si Android lo rechazó;
     * [onEnd] se llama al terminar o cancelarse.
     */
    internal fun drag(plan: DragPlan, onEnd: () -> Unit): Boolean {
        scroll.reset()
        val hold = Path().apply {
            moveTo(plan.startX, plan.startY)
            lineTo(plan.startX, plan.startY)
        }
        val move = Path().apply {
            moveTo(plan.startX, plan.startY)
            lineTo(plan.endX, plan.endY)
        }
        // Un trazo continuado (`willContinue`) deja el dedo virtual apoyado al
        // terminar su gesto, y la continuación va en el gesto SIGUIENTE: por
        // eso son dos despachos encadenados, no dos trazos en el mismo gesto.
        return try {
            val grab = GestureDescription.StrokeDescription(hold, 0L, DragPlan.HOLD_MS, true)
            val first = GestureDescription.Builder().addStroke(grab).build()
            send(first, null) { held ->
                if (!held) {
                    onEnd()
                    return@send
                }
                val sent = try {
                    val carry = grab.continueStroke(move, 0L, DragPlan.MOVE_MS, false)
                    send(GestureDescription.Builder().addStroke(carry).build(), onEnd, null)
                } catch (_: Exception) {
                    false
                }
                if (!sent) onEnd()
            }
        } catch (_: Exception) {
            false
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

    /** Tap o toque largo en (x, y). [seq] > 0 = hay que confirmarle a VoiceBubble cómo terminó. */
    internal fun press(x: Float, y: Float, durationMs: Long, seq: Int = 0) {
        received++
        scroll.reset()
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val ok = dispatch(path, durationMs, null) { completed ->
            if (completed) done++ else cancelled++
            reply(seq, if (completed) PointerProtocol.RESULT_DONE else PointerProtocol.RESULT_CANCELLED)
        }
        if (!ok) {
            rejected++
            reply(seq, PointerProtocol.RESULT_REJECTED)
        }
    }

    /** Le confirma a VoiceBubble cómo terminó el clic (solo apps con la misma firma lo reciben). */
    private fun reply(seq: Int, result: String) {
        if (seq <= 0) return
        try {
            val intent = Intent(PointerProtocol.ACTION_RESULT)
                .setPackage(PointerProtocol.HOST_PACKAGE)
                .putExtra(PointerProtocol.EXTRA_SEQ, seq)
                .putExtra(PointerProtocol.EXTRA_RESULT, result)
            sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)
        } catch (_: Exception) {}
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

    private fun dispatch(
        path: Path,
        durationMs: Long,
        onEnd: (() -> Unit)?,
        onResult: ((Boolean) -> Unit)? = null,
    ): Boolean {
        return try {
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0L, durationMs))
                .build()
            send(gesture, onEnd, onResult)
        } catch (_: Exception) {
            false
        }
    }

    private fun send(gesture: GestureDescription, onEnd: (() -> Unit)?, onResult: ((Boolean) -> Unit)?): Boolean {
        return try {
            dispatchGesture(
                gesture,
                object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        onResult?.invoke(true)
                        onEnd?.invoke()
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        onResult?.invoke(false)
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
        // Puntero y panel afuera, con sus temporizadores: nada queda dibujado
        // ni corriendo sin el servicio.
        trackpad?.destroy()
        trackpad = null
        scroll.reset()
        isConnected = false
        if (instance === this) instance = null
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Giro o cambio de tamaño de pantalla o de tema: las ventanas se reacomodan.
        trackpad?.onConfigurationChanged()
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
