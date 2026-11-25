package com.royleguiza.voicebubblestt

import android.content.Context
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * T15 · Orison Pro: 30 días con todo desde el primer uso; después, teclado
 * completo y [FREE_DAILY_DICTATIONS] dictados por día; Pro (pago único)
 * los hace ilimitados. El estado vive en las preferencias de Flutter para
 * que la app (Dart), el teclado, el widget y la barra cuenten lo mismo:
 * `flutter.pro_unlocked`, `flutter.pro_trial_start_ms`, `flutter.pro_day`
 * y `flutter.pro_day_count` (espejo en Dart: `ProGate` de pro_service.dart).
 * Sin red: si la compra no se pudo verificar, nunca se bloquea por error
 * al que ya pagó, porque `pro_unlocked` queda guardado.
 */
object ProGate {
    const val TRIAL_DAYS = 30L
    const val FREE_DAILY_DICTATIONS = 10

    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_UNLOCKED = "flutter.pro_unlocked"
    private const val KEY_TRIAL_START = "flutter.pro_trial_start_ms"
    private const val KEY_DAY = "flutter.pro_day"
    private const val KEY_DAY_COUNT = "flutter.pro_day_count"
    private const val DAY_MS = 86_400_000L

    /** Estado puro para probar sin Android. */
    data class State(
        val unlocked: Boolean,
        val trialStartMs: Long,
        val day: String?,
        val dayCount: Int,
    )

    data class Decision(val allowed: Boolean, val next: State)

    fun inTrial(state: State, nowMs: Long): Boolean =
        state.trialStartMs <= 0L || nowMs - state.trialStartMs < TRIAL_DAYS * DAY_MS

    /** ¿Se puede empezar un dictado ahora? Si sí, ya lo cuenta. */
    fun decide(state: State, nowMs: Long, today: String): Decision {
        val start = if (state.trialStartMs <= 0L) nowMs else state.trialStartMs
        val base = state.copy(trialStartMs = start)
        if (base.unlocked || inTrial(base, nowMs)) return Decision(true, base)
        val count = if (base.day == today) base.dayCount else 0
        if (count >= FREE_DAILY_DICTATIONS) return Decision(false, base.copy(day = today, dayCount = count))
        return Decision(true, base.copy(day = today, dayCount = count + 1))
    }

    private val lock = Any()

    /**
     * Pide permiso para un dictado. Ante cualquier error de lectura deja
     * dictar (un fallo nuestro nunca bloquea).
     */
    fun tryStartDictation(context: Context, nowMs: Long = System.currentTimeMillis()): Boolean {
        return try {
            synchronized(lock) {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val state = State(
                    unlocked = prefs.getBoolean(KEY_UNLOCKED, false),
                    trialStartMs = readLong(prefs, KEY_TRIAL_START),
                    day = prefs.getString(KEY_DAY, null),
                    dayCount = readLong(prefs, KEY_DAY_COUNT).toInt(),
                )
                val today = LocalDate.ofInstant(Instant.ofEpochMilli(nowMs), ZoneId.systemDefault()).toString()
                val decision = decide(state, nowMs, today)
                if (decision.next != state) {
                    val edit = prefs.edit()
                    edit.putLong(KEY_TRIAL_START, decision.next.trialStartMs)
                    decision.next.day?.let { edit.putString(KEY_DAY, it) }
                    edit.putLong(KEY_DAY_COUNT, decision.next.dayCount.toLong())
                    edit.commit()
                }
                decision.allowed
            }
        } catch (_: Exception) {
            true
        }
    }

    /** Flutter guarda los int como Long; tolera Int por si acaso. */
    private fun readLong(prefs: android.content.SharedPreferences, key: String): Long = try {
        prefs.getLong(key, 0L)
    } catch (_: ClassCastException) {
        try {
            prefs.getInt(key, 0).toLong()
        } catch (_: Exception) {
            0L
        }
    }
}
