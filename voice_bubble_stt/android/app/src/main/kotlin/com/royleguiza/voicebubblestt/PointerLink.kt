package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Lado VoiceBubble del puntero: manda "tocá acá" al complemento
 * VoiceBubble Puntero (ver [PointerProtocol]). Si el complemento no está
 * instalado o su Accesibilidad está apagada, no hace nada y devuelve false:
 * el trackpad sigue moviendo el puntero, pero sin clics en otras apps.
 */
object PointerLink {

    private val main = Handler(Looper.getMainLooper())

    /** Leer Settings.Secure en cada tick de scroll (60 Hz) es caro: cache de 1 s. */
    private const val ENABLED_CACHE_MS = 1000L
    private var enabledCache = false
    private var enabledCacheAt = 0L

    /** Margen para dar tiempo a que el sistema aplique el "apartar ventanas". */
    private const val CLEAR_LEAD_MS = 48L

    fun isInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(PointerProtocol.COMPANION_PACKAGE, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    } catch (_: Exception) {
        false
    }

    fun isEnabled(context: Context, fresh: Boolean = false): Boolean {
        val now = SystemClock.uptimeMillis()
        if (!fresh && now - enabledCacheAt < ENABLED_CACHE_MS) return enabledCache
        val setting = try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        } catch (_: Exception) {
            null
        }
        enabledCache = PointerProtocol.isServiceEnabled(setting)
        enabledCacheAt = now
        return enabledCache
    }

    fun isReady(context: Context): Boolean = isEnabled(context) && isInstalled(context)

    /** "missing" | "disabled" | "ready" (lo muestra Ajustes › Trackpad). */
    fun status(context: Context): String =
        PointerProtocol.status(isInstalled(context), isEnabled(context, fresh = true))

    fun tap(context: Context, x: Float, y: Float): Boolean =
        dispatch(context, PointerProtocol.validate(PointerProtocol.OP_TAP, x, y))

    fun longPress(context: Context, x: Float, y: Float): Boolean =
        dispatch(context, PointerProtocol.validate(PointerProtocol.OP_LONG_PRESS, x, y))

    fun scroll(context: Context, x: Float, y: Float, deltaY: Float): Boolean =
        dispatch(context, PointerProtocol.validate(PointerProtocol.OP_SCROLL, x, y, deltaY))

    private fun dispatch(context: Context, cmd: PointerProtocol.Command?): Boolean {
        if (cmd == null || !isEnabled(context)) return false
        val app = context.applicationContext
        val intent = Intent(PointerProtocol.ACTION_POINTER).apply {
            setPackage(PointerProtocol.COMPANION_PACKAGE)
            putExtra(PointerProtocol.EXTRA_OP, cmd.op)
            putExtra(PointerProtocol.EXTRA_X, cmd.x)
            putExtra(PointerProtocol.EXTRA_Y, cmd.y)
            putExtra(PointerProtocol.EXTRA_DY, cmd.dy)
        }
        val send = Runnable {
            try {
                app.sendBroadcast(intent)
            } catch (_: Exception) {}
        }
        if (OverlayPassThrough.clear(cmd, CLEAR_LEAD_MS)) {
            main.postDelayed(send, CLEAR_LEAD_MS)
        } else {
            send.run()
        }
        return true
    }

    fun openAccessibilitySettings(context: Context): Boolean = start(
        context,
        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
    )

    /** Información de la app del complemento: ahí está "Permitir ajustes restringidos". */
    fun openCompanionDetails(context: Context): Boolean = start(
        context,
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:${PointerProtocol.COMPANION_PACKAGE}")),
    )

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: Exception) {
        false
    }
}

/**
 * Registro de nuestras ventanas flotantes (barra, burbuja, trackpad, puntero).
 *
 * Android 12+ bloquea un toque si sobre ese punto hay una ventana flotante de
 * otra app con más de 80 % de opacidad. Antes de cada clic, las ventanas que
 * tapan el trazo se vuelven transparentes e intocables durante el gesto y
 * vuelven solas al terminar.
 */
object OverlayPassThrough {

    interface Handle {
        /** Rectángulo en pantalla [l, t, r, b], o null si no está visible. */
        fun screenBounds(): IntArray?
        fun setPassThrough(enabled: Boolean)
    }

    private val handles = CopyOnWriteArraySet<Handle>()
    private val main = Handler(Looper.getMainLooper())
    private val cleared = mutableSetOf<Handle>()
    private val restore = Runnable {
        cleared.forEach { h ->
            try {
                h.setPassThrough(false)
            } catch (_: Exception) {}
        }
        cleared.clear()
    }

    fun register(handle: Handle) {
        handles.add(handle)
    }

    fun unregister(handle: Handle) {
        handles.remove(handle)
        cleared.remove(handle)
    }

    /** Aparta las ventanas que cubren el trazo. Devuelve true si apartó alguna. */
    fun clear(cmd: PointerProtocol.Command, leadMs: Long): Boolean {
        var any = false
        for (h in handles) {
            val b = try {
                h.screenBounds()
            } catch (_: Exception) {
                null
            } ?: continue
            if (!PointerProtocol.pathHits(cmd, b[0], b[1], b[2], b[3], slopPx = 4f)) continue
            try {
                h.setPassThrough(true)
                cleared.add(h)
                any = true
            } catch (_: Exception) {}
        }
        if (any) {
            main.removeCallbacks(restore)
            main.postDelayed(restore, leadMs + cmd.durationMs() + 140L)
        }
        return any
    }
}
