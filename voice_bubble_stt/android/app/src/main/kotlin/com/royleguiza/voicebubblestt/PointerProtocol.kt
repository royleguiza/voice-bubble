package com.royleguiza.voicebubblestt

import kotlin.math.abs

/**
 * Protocolo con el complemento "VoiceBubble Puntero" (docs/contrato-trackpad.md).
 *
 * VoiceBubble NO declara AccessibilityService (perfil anti-Play-Protect): los
 * clics en otras apps los ejecuta el complemento, que solo recibe órdenes
 * "tocá en (x, y)" por broadcast explícito protegido con un permiso de firma
 * declarado en las dos apps. Sin lectura de pantalla, sin registro.
 *
 * ESPEJO EXACTO: puntero_android/app/src/main/kotlin/.../PointerProtocol.kt.
 * La suite test_floating_dock_suite.py verifica que las constantes coincidan.
 * Lógica pura (sin android.*) para testearla en la JVM.
 */
object PointerProtocol {
    const val COMPANION_PACKAGE = "com.royleguiza.voicebubble.puntero"
    const val COMPANION_SERVICE_CLASS = "com.royleguiza.voicebubble.puntero.PunteroService"
    const val ACTION_POINTER = "com.royleguiza.voicebubble.puntero.ACTION_POINTER"
    const val PERMISSION_POINTER = "com.royleguiza.voicebubble.puntero.permission.POINTER"

    const val EXTRA_OP = "op"
    const val EXTRA_X = "x"
    const val EXTRA_Y = "y"
    const val EXTRA_DY = "dy"

    const val OP_TAP = "tap"
    const val OP_LONG_PRESS = "long_press"
    const val OP_SCROLL = "scroll"

    /** Recorrido máximo de un trazo de scroll (px). */
    const val MAX_SCROLL_PX = 600f

    /** Duraciones de los gestos que despacha el complemento (ms). */
    const val TAP_MS = 40L
    const val LONG_PRESS_MS = 450L
    const val SCROLL_MS = 80L

    const val STATUS_MISSING = "missing"
    const val STATUS_DISABLED = "disabled"
    const val STATUS_READY = "ready"

    /** Respuesta del complemento a un clic: confirma que Android lo hizo. */
    const val HOST_PACKAGE = "com.royleguiza.voicebubblestt"
    const val ACTION_RESULT = "com.royleguiza.voicebubble.puntero.ACTION_RESULT"
    const val EXTRA_SEQ = "seq"
    const val EXTRA_RESULT = "result"
    const val RESULT_DONE = "done"
    const val RESULT_CANCELLED = "cancelled"
    const val RESULT_REJECTED = "rejected"

    /** Si no llega respuesta en este tiempo (tras el gesto), el complemento no está escuchando. */
    const val ACK_TIMEOUT_MS = 1200L

    data class Command(val op: String, val x: Float, val y: Float, val dy: Float = 0f) {
        /** Cuánto dura el gesto en pantalla: las ventanas propias se apartan ese tiempo. */
        fun durationMs(): Long = when (op) {
            OP_LONG_PRESS -> LONG_PRESS_MS
            OP_SCROLL -> SCROLL_MS
            else -> TAP_MS
        }
    }

    /**
     * Valida y normaliza una orden. Devuelve null si es inválida: operación
     * desconocida, coordenadas no finitas o negativas, o scroll sin recorrido.
     */
    fun validate(op: String?, x: Float, y: Float, dy: Float = 0f): Command? {
        if (op != OP_TAP && op != OP_LONG_PRESS && op != OP_SCROLL) return null
        if (!x.isFinite() || !y.isFinite() || x < 0f || y < 0f) return null
        if (op == OP_SCROLL) {
            if (!dy.isFinite() || abs(dy) < 1f) return null
            return Command(op, x, y, dy.coerceIn(-MAX_SCROLL_PX, MAX_SCROLL_PX))
        }
        return Command(op, x, y, 0f)
    }

    /**
     * ¿Está el servicio del complemento en Settings.Secure
     * ENABLED_ACCESSIBILITY_SERVICES? Formato: "pkg/cls:pkg/.cls".
     */
    fun isServiceEnabled(
        setting: String?,
        pkg: String = COMPANION_PACKAGE,
        cls: String = COMPANION_SERVICE_CLASS,
    ): Boolean {
        if (setting.isNullOrBlank()) return false
        return setting.split(':').any { entry ->
            val slash = entry.indexOf('/')
            if (slash <= 0 || slash == entry.length - 1) return@any false
            val p = entry.substring(0, slash).trim()
            var c = entry.substring(slash + 1).trim()
            if (c.startsWith(".")) c = p + c
            p == pkg && c == cls
        }
    }

    /**
     * ¿El trazo de [cmd] pasa por el rectángulo (l, t, r, b)? Con [slopPx]
     * de margen. Sirve para apartar nuestras ventanas flotantes que taparían
     * el clic (Android 12+ bloquea toques bajo overlays opacos de otra app).
     */
    fun pathHits(cmd: Command, l: Int, t: Int, r: Int, b: Int, slopPx: Float = 0f): Boolean {
        if (r <= l || b <= t) return false
        val top = minOf(cmd.y, cmd.y + cmd.dy) - slopPx
        val bottom = maxOf(cmd.y, cmd.y + cmd.dy) + slopPx
        return cmd.x + slopPx >= l && cmd.x - slopPx <= r && bottom >= t && top <= b
    }

    fun status(installed: Boolean, enabled: Boolean): String = when {
        !installed -> STATUS_MISSING
        !enabled -> STATUS_DISABLED
        else -> STATUS_READY
    }

    /** ¿Esta orden pide confirmación? Solo los clics (el scroll llega a 60 Hz). */
    fun wantsAck(op: String): Boolean = op == OP_TAP || op == OP_LONG_PRESS

    /**
     * Qué decirle a la persona según la respuesta del complemento.
     * null = salió bien (no hay nada que avisar). [result] null = no respondió.
     */
    fun resultMessage(result: String?): String? = when (result) {
        RESULT_DONE -> null
        RESULT_CANCELLED -> "Android interrumpió el clic. Probá de nuevo."
        RESULT_REJECTED -> "VoiceBubble Puntero no pudo hacer el clic. Apagalo y volvé a prenderlo en Accesibilidad."
        else -> "VoiceBubble Puntero no responde. Apagalo y volvé a prenderlo en Accesibilidad."
    }
}
