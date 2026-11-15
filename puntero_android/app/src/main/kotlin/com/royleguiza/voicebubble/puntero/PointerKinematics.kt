package com.royleguiza.voicebubble.puntero

import kotlin.math.sqrt

/**
 * Cinemática del puntero: convierte lo que recorre el dedo en el pad en lo
 * que se mueve el puntero (sensibilidad + curva de aceleración). Lógica pura
 * (sin android.*) para testearla en la JVM.
 */
object PointerKinematics {

    /** [density]: densidad de pantalla; el umbral de la curva dinámica se mide en dp. */
    fun apply(dx: Float, dy: Float, sensitivity: Float, curve: String, density: Float): Pair<Float, Float> =
        when (curve) {
            PointerProtocol.ACCEL_LINEAR -> Pair(dx * sensitivity, dy * sensitivity)
            PointerProtocol.ACCEL_PRECISION -> {
                val factor = sensitivity * 0.55f
                Pair(dx * factor, dy * factor)
            }
            else -> {
                // Dinámica: lento y fino de cerca, más rápido cuanto más largo el barrido.
                val distance = sqrt(dx * dx + dy * dy)
                val baseThreshold = 10f * density
                val factor = if (distance > baseThreshold) {
                    1.0f + ((distance - baseThreshold) / (18f * density)) * 0.6f
                } else {
                    1.0f
                }.coerceIn(1.0f, 3.2f)
                Pair(dx * sensitivity * factor, dy * sensitivity * factor)
            }
        }
}
