package com.royleguiza.voicebubblestt

import android.content.Context
import android.view.ViewConfiguration

/**
 * GestureTuning - Centralización de afinaciones, distancias y tiempos para gestos táctiles.
 * Proporciona constantes canónicas y helpers para touch slop, swipe y pulsaciones largas
 * en el teclado, burbuja y trackpad.
 */
object GestureTuning {
    /** Tiempo en milisegundos para disparar una pulsación larga canónica. */
    const val LONG_PRESS_MS: Long = 400L

    /** Distancia en dp para armar el deslizamiento de selección en la tarjeta de burbuja. */
    const val BUBBLE_SWIPE_ARM_DP: Float = 48f

    /** Límite máximo en dp para el desplazamiento lateral en swipe de tarjetas. */
    const val BUBBLE_SWIPE_MAX_DP: Float = 72f

    /** Umbral de desplazamiento en dp para la barra espaciadora. */
    const val SPACEBAR_THRESHOLD_DP: Float = 14f

    /** Timeout máximo en milisegundos para considerar un tap-to-click en trackpad. */
    const val TRACKPAD_TAP_TIMEOUT_MS: Long = 250L

    /** Ratio mínimo entre dx y dy para confirmar un gesto horizontal sobre vertical. */
    const val SWIPE_SLOP_RATIO: Float = 1.4f

    /**
     * Retorna el touch slop del sistema escalado para la densidad del contexto.
     */
    fun getTouchSlopPx(context: Context): Int {
        return ViewConfiguration.get(context).scaledTouchSlop
    }

    /**
     * Retorna un touch slop derivado directamente de la densidad.
     */
    fun getTouchSlopPx(density: Float): Float {
        return 8f * density
    }
}
