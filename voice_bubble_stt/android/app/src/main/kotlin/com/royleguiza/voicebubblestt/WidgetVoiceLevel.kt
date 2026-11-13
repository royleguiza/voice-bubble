package com.royleguiza.voicebubblestt

/**
 * Voz del widget por NIVELES (Horizonte fase 4, design.md §14).
 *
 * RemoteViews no admite dibujo por cuadro: el widget tiene tres variantes
 * animadas solas (AnimatedVectorDrawable en un ProgressBar) y el servicio
 * solo cambia cuál se ve. Esta lógica pura (sin android.*, testeable en la
 * JVM) decide la variante con histéresis a partir del nivel 0..1 del
 * [VoiceLevelMeter] de la captura y limita los cambios a [MIN_SWITCH_MS]
 * (≈ 3 por segundo como máximo).
 */
internal enum class WidgetVoiceTier { LOW, MID, HIGH }

internal object WidgetVoiceLevel {
    /** Cada cuánto el servicio lee el nivel (lectura volátil, sin trabajo). */
    const val POLL_MS = 120L

    /** Separación mínima entre dos cambios de variante: ≤ ~3 por segundo. */
    const val MIN_SWITCH_MS = 340L

    // Umbrales con histéresis: se sube con el valor alto y se baja con el bajo.
    const val MID_UP = 0.22f
    const val MID_DOWN = 0.14f
    const val HIGH_UP = 0.58f
    const val HIGH_DOWN = 0.46f

    /**
     * Variante vigente mientras graba (la escribe el servicio, la lee el
     * provider en una actualización completa para no volver a goteo).
     */
    @Volatile
    var liveTier: WidgetVoiceTier = WidgetVoiceTier.LOW

    /** Variante que corresponde a [level] partiendo de [current] (histéresis). */
    fun nextTier(current: WidgetVoiceTier, level: Float): WidgetVoiceTier {
        val l = level.coerceIn(0f, 1f)
        return when (current) {
            WidgetVoiceTier.LOW -> when {
                l >= HIGH_UP -> WidgetVoiceTier.HIGH
                l >= MID_UP -> WidgetVoiceTier.MID
                else -> WidgetVoiceTier.LOW
            }
            WidgetVoiceTier.MID -> when {
                l >= HIGH_UP -> WidgetVoiceTier.HIGH
                l < MID_DOWN -> WidgetVoiceTier.LOW
                else -> WidgetVoiceTier.MID
            }
            WidgetVoiceTier.HIGH -> when {
                l < MID_DOWN -> WidgetVoiceTier.LOW
                l < HIGH_DOWN -> WidgetVoiceTier.MID
                else -> WidgetVoiceTier.HIGH
            }
        }
    }
}

/**
 * Compuerta de cambios: devuelve la variante nueva SOLO si cambió y pasó
 * [WidgetVoiceLevel.MIN_SWITCH_MS] desde el último cambio; si no, null
 * (no hay que tocar el widget).
 */
internal class WidgetVoiceTierGate(startMs: Long = Long.MIN_VALUE / 2) {
    var tier: WidgetVoiceTier = WidgetVoiceTier.LOW
        private set
    private var lastSwitchMs = startMs

    fun offer(level: Float, nowMs: Long): WidgetVoiceTier? {
        val next = WidgetVoiceLevel.nextTier(tier, level)
        if (next == tier) return null
        if (nowMs - lastSwitchMs < WidgetVoiceLevel.MIN_SWITCH_MS) return null
        tier = next
        lastSwitchMs = nowMs
        return next
    }

    fun reset(nowMs: Long) {
        tier = WidgetVoiceTier.LOW
        lastSwitchMs = nowMs
    }
}
