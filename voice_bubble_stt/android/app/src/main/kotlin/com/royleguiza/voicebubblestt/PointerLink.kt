package com.royleguiza.voicebubblestt

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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

    // --- Confirmación de clics (ver PointerProtocol.ACTION_RESULT) ---
    private var seq = 0
    private var pendingSeq = 0
    private var onProblem: ((String) -> Unit)? = null
    private var receiver: BroadcastReceiver? = null
    private val ackTimeout = Runnable {
        if (pendingSeq != 0) {
            pendingSeq = 0
            report(PointerProtocol.resultMessage(null))
        }
    }

    /**
     * Escucha las respuestas del complemento mientras el trackpad está abierto.
     * [problem] recibe un texto listo para mostrar cuando un clic no se hizo.
     */
    fun listen(context: Context, problem: (String) -> Unit) {
        onProblem = problem
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action != PointerProtocol.ACTION_RESULT) return
                val got = intent.getIntExtra(PointerProtocol.EXTRA_SEQ, 0)
                if (got == 0 || got != pendingSeq) return
                pendingSeq = 0
                main.removeCallbacks(ackTimeout)
                report(PointerProtocol.resultMessage(intent.getStringExtra(PointerProtocol.EXTRA_RESULT)))
            }
        }
        val filter = IntentFilter(PointerProtocol.ACTION_RESULT)
        try {
            val app = context.applicationContext
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                app.registerReceiver(r, filter, PointerProtocol.PERMISSION_POINTER, null, Context.RECEIVER_EXPORTED)
            } else {
                app.registerReceiver(r, filter, PointerProtocol.PERMISSION_POINTER, null)
            }
            receiver = r
        } catch (_: Exception) {}
    }

    fun stopListening(context: Context) {
        onProblem = null
        pendingSeq = 0
        main.removeCallbacks(ackTimeout)
        val r = receiver ?: return
        receiver = null
        try {
            context.applicationContext.unregisterReceiver(r)
        } catch (_: Exception) {}
    }

    private fun report(message: String?) {
        if (message == null) return
        try {
            onProblem?.invoke(message)
        } catch (_: Exception) {}
    }

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
        // Solo se espera respuesta si alguien la escucha (el trackpad flotante).
        val ackSeq = if (receiver != null && PointerProtocol.wantsAck(cmd.op)) {
            seq = if (seq >= 1_000_000) 1 else seq + 1
            seq
        } else {
            0
        }
        val intent = Intent(PointerProtocol.ACTION_POINTER).apply {
            setPackage(PointerProtocol.COMPANION_PACKAGE)
            putExtra(PointerProtocol.EXTRA_OP, cmd.op)
            putExtra(PointerProtocol.EXTRA_X, cmd.x)
            putExtra(PointerProtocol.EXTRA_Y, cmd.y)
            putExtra(PointerProtocol.EXTRA_DY, cmd.dy)
            putExtra(PointerProtocol.EXTRA_SEQ, ackSeq)
        }
        val lead = if (OverlayPassThrough.clear(cmd, CLEAR_LEAD_MS)) CLEAR_LEAD_MS else 0L
        if (ackSeq != 0) {
            pendingSeq = ackSeq
            main.removeCallbacks(ackTimeout)
            main.postDelayed(ackTimeout, lead + cmd.durationMs() + PointerProtocol.ACK_TIMEOUT_MS)
        }
        val send = Runnable {
            try {
                app.sendBroadcast(intent)
            } catch (_: Exception) {}
        }
        if (lead > 0) main.postDelayed(send, lead) else send.run()
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
