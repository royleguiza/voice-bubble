package com.royleguiza.voicebubblestt

import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Nivel de voz 0..1 (Horizonte fase 1, design.md §8 "Voz") a partir de PCM
 * 16-bit little-endian. Funciones puras, sin Android y sin asignaciones:
 * RMS → dBFS → normalizado entre un piso de ruido y un techo, más un
 * suavizado de ataque rápido y caída lenta para que la animación no tiemble.
 */
object VoiceLevel {
    /** Por debajo de este nivel (ruido de fondo típico) el nivel es 0. */
    const val FLOOR_DB = -55f

    /** Por encima, el nivel es 1 (un seno a plena escala da -3 dBFS). */
    const val CEIL_DB = -6f

    /** Fracción del salto que se aplica por buffer al subir (ataque rápido). */
    const val ATTACK = 0.6f

    /** Fracción del salto que se aplica por buffer al bajar (caída lenta). */
    const val RELEASE = 0.15f

    private const val SILENCE_DB = -120f

    /** RMS de [len] bytes de [pcm] relativo a plena escala (0..~1). */
    fun rms(pcm: ByteArray, len: Int): Float {
        val samples = minOf(len, pcm.size) / 2
        if (samples <= 0) return 0f
        var sum = 0.0
        var i = 0
        while (i < samples) {
            val lo = pcm[2 * i].toInt() and 0xFF
            val hi = pcm[2 * i + 1].toInt() // con signo: arma la muestra de 16 bits
            val s = (hi shl 8) or lo
            sum += (s * s).toDouble()
            i++
        }
        return (sqrt(sum / samples) / 32768.0).toFloat()
    }

    /** dBFS de un RMS relativo; silencio digital = -120. */
    fun dbfs(rms: Float): Float =
        if (rms <= 1e-6f) SILENCE_DB else (20.0 * log10(rms.toDouble())).toFloat()

    /** Mapea dBFS a 0..1 entre [FLOOR_DB] y [CEIL_DB]. */
    fun normalize(db: Float): Float =
        ((db - FLOOR_DB) / (CEIL_DB - FLOOR_DB)).coerceIn(0f, 1f)

    /** Nivel instantáneo (sin suavizar) de un buffer PCM16. */
    fun level(pcm: ByteArray, len: Int): Float = normalize(dbfs(rms(pcm, len)))

    /** Un paso de suavizado: sube con [ATTACK], baja con [RELEASE]. */
    fun smooth(previous: Float, target: Float): Float {
        val k = if (target > previous) ATTACK else RELEASE
        return (previous + (target - previous) * k).coerceIn(0f, 1f)
    }
}

/**
 * Medidor vivo: lo alimenta SOLO el hilo de captura (un escritor) y la UI
 * lo lee por cuadro como un campo volátil (lectura sin trabajo ni bloqueo).
 */
class VoiceLevelMeter {
    @Volatile
    var level: Float = 0f
        private set

    fun feed(pcm: ByteArray, len: Int) {
        level = VoiceLevel.smooth(level, VoiceLevel.level(pcm, len))
    }

    fun reset() {
        level = 0f
    }
}
