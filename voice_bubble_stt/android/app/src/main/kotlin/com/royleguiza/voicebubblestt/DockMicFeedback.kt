package com.royleguiza.voicebubblestt

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * Sonidos y hápticos del micrófono de la barra flotante, con los mismos
 * ajustes que el teclado y el widget (Ajustes › Teclado › Micrófono):
 * `kb_mic_haptics_enabled` y los de inicio / fin / cancelar por separado,
 * `kb_mic_sounds_enabled` con sus estilos. Un [SoundPool] chico que se suelta
 * en [release].
 */
internal class DockMicFeedback(private val context: Context) {

    enum class Event { START, STOP, PASTE, CANCEL }

    private var pool: SoundPool? = null
    private var soundStart = 0
    private var soundStop = 0
    private var soundCancel = 0

    private val prefs get() = context.getSharedPreferences(FlutterPrefs.PREFS_NAME, Context.MODE_PRIVATE)

    private fun flag(key: String, fallback: Boolean): Boolean = try {
        prefs.getBoolean(key, fallback)
    } catch (_: Exception) {
        fallback
    }

    fun play(event: Event) {
        haptic(event)
        sound(event)
    }

    private fun haptic(event: Event) {
        try {
            if (!flag("flutter.kb_haptics_enabled", true) || !flag("flutter.kb_mic_haptics_enabled", true)) return
            val (enabled, ms, amp) = when (event) {
                Event.START -> Triple(flag("flutter.kb_mic_haptic_start", true), 12L, 255)
                Event.STOP -> Triple(flag("flutter.kb_mic_haptic_start", true), 20L, 200)
                Event.PASTE -> Triple(flag("flutter.kb_mic_haptic_paste", true), 15L, 180)
                Event.CANCEL -> Triple(flag("flutter.kb_mic_haptic_cancel", true), 30L, 160)
            }
            if (!enabled) return
            @Suppress("DEPRECATION")
            val vib = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (!vib.hasVibrator()) return
            vib.vibrate(VibrationEffect.createOneShot(ms, amp))
        } catch (_: Exception) {}
    }

    private fun sound(event: Event) {
        try {
            if (!flag("flutter.kb_mic_sounds_enabled", false)) return
            ensurePool()
            val id = when (event) {
                Event.START -> soundStart
                Event.STOP, Event.PASTE -> soundStop
                Event.CANCEL -> soundCancel
            }
            if (id != 0) pool?.play(id, 1f, 1f, 1, 0, 1f)
        } catch (_: Exception) {}
    }

    private fun style(key: String): String {
        val v = try {
            prefs.getString(key, "3")
        } catch (_: Exception) {
            "3"
        }
        return if (v == "1" || v == "2" || v == "3" || v == "4") v else "3"
    }

    private fun ensurePool() {
        if (pool != null) return
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val p = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(attrs).build()
            val pkg = context.packageName
            soundStart = p.load(context, context.resources.getIdentifier("mic_start_${style("flutter.kb_mic_start_style")}", "raw", pkg), 1)
            soundStop = p.load(context, context.resources.getIdentifier("mic_stop_${style("flutter.kb_mic_stop_style")}", "raw", pkg), 1)
            soundCancel = p.load(context, R.raw.mic_cancel, 1)
            pool = p
        } catch (_: Exception) {
            pool = null
        }
    }

    fun release() {
        try {
            pool?.release()
        } catch (_: Exception) {}
        pool = null
        soundStart = 0
        soundStop = 0
        soundCancel = 0
    }
}
