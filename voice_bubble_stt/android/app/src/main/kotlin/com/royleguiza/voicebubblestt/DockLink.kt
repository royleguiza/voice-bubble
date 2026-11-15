package com.royleguiza.voicebubblestt

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Lado VoiceBubble de la barra flotante que dibuja el complemento (protocolo
 * v3, ver [PointerProtocol]): le manda la configuración ([sendConfig]) y el
 * estado del dictado ([sendMicState]) y recuerda si el complemento está
 * dibujando la barra ([complementDrawing]), para que la barra de respaldo de
 * [FloatingBubbleService] se esconda: nunca se ven dos.
 *
 * Todo es best-effort y firmado (permiso de firma + paquete explícito). Solo
 * viajan ajustes de la barra y estados: ni audio ni texto.
 *
 * Las claves nuevas de Ajustes de la isla (`dock_island_*`) y `floating_bubble_enabled`
 * se leen componiendo el prefijo ([FlutterPrefs.key]): la fase 2B las suma al
 * contrato Kotlin↔Dart (docs/contract-keys.txt) junto con los controles de Ajustes.
 */
object DockLink {

    private const val K_ENABLED = "floating_bubble_enabled"
    private const val K_ISLAND_X = "dock_island_x"
    private const val K_ISLAND_Y = "dock_island_y"
    private const val K_ISLAND_W = "dock_island_w"
    private const val K_ISLAND_H = "dock_island_h"
    private const val K_ISLAND_SIDE = "dock_island_side"

    /** Última noticia del complemento: ¿está dibujando la barra? (en memoria; se pierde con el proceso). */
    @Volatile
    var complementDrawing = false
        private set

    /** Quien escucha los cambios de [complementDrawing] (la barra de respaldo mientras vive). Hilo principal. */
    @Volatile
    var onDrawingChanged: ((Boolean) -> Unit)? = null

    // ------------------------------------------------------------ host → complemento

    /**
     * Lee los Ajustes de la barra y se los manda al complemento (aplican EN VIVO).
     * [enabledOverride]: al encender o apagar la barra, Dart guarda la preferencia
     * DESPUÉS de llamar al servicio, así que quien enciende o apaga lo dice acá.
     * [ack]: pide que el complemento conteste con DOCK_STATE aunque nada cambie.
     * Devuelve false si el complemento no está instalado.
     */
    fun sendConfig(context: Context, enabledOverride: Boolean? = null, ack: Boolean = true): Boolean {
        val app = context.applicationContext
        if (!PointerLink.isInstalled(app)) return false
        return try {
            val prefs = app.getSharedPreferences(FlutterPrefs.PREFS_NAME, Context.MODE_PRIVATE)
            val cfg = readConfig(app, prefs, enabledOverride)
            val tp = cfg.trackpad
            val intent = Intent(PointerProtocol.ACTION_DOCK_CONFIG)
                .setPackage(PointerProtocol.COMPANION_PACKAGE)
                .putExtra(PointerProtocol.EXTRA_DOCK_ENABLED, cfg.enabled)
                .putExtra(PointerProtocol.EXTRA_DOCK_FORM, cfg.form)
                .putExtra(PointerProtocol.EXTRA_TOOL_MIC, cfg.toolMic)
                .putExtra(PointerProtocol.EXTRA_TOOL_POINTER, cfg.toolPointer)
                .putExtra(PointerProtocol.EXTRA_ISLAND_X, cfg.islandX)
                .putExtra(PointerProtocol.EXTRA_ISLAND_Y, cfg.islandY)
                .putExtra(PointerProtocol.EXTRA_ISLAND_W, cfg.islandW)
                .putExtra(PointerProtocol.EXTRA_ISLAND_H, cfg.islandH)
                .putExtra(PointerProtocol.EXTRA_ISLAND_SIDE, cfg.islandSide)
                .putExtra(PointerProtocol.EXTRA_MODE, tp.mode)
                .putExtra(PointerProtocol.EXTRA_SENSITIVITY, tp.sensitivity)
                .putExtra(PointerProtocol.EXTRA_ACCEL, tp.accel)
                .putExtra(PointerProtocol.EXTRA_STYLE, tp.style)
                .putExtra(PointerProtocol.EXTRA_HAPTIC, tp.haptic)
                .putExtra(PointerProtocol.EXTRA_SCROLL_DIR, tp.scrollDir)
                .putExtra(PointerProtocol.EXTRA_AUTO_RETURN, tp.autoReturnS)
                .putExtra(PointerProtocol.EXTRA_ACK, ack)
            app.sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Ajustes de la barra ya validados (los mismos con los que el complemento dibuja). */
    internal fun readConfig(
        context: Context,
        prefs: android.content.SharedPreferences,
        enabledOverride: Boolean? = null,
    ): PointerProtocol.DockConfig {
        val all = try {
            prefs.all
        } catch (_: Exception) {
            emptyMap<String, Any?>()
        }
        fun intPref(name: String): Int = when (val raw = all[FlutterPrefs.key(name)]) {
            is Number -> raw.toInt()
            is String -> raw.toIntOrNull() ?: PointerProtocol.ISLAND_DEFAULT
            else -> PointerProtocol.ISLAND_DEFAULT
        }
        fun boolPref(name: String, fallback: Boolean): Boolean = (all[name] as? Boolean) ?: fallback
        return PointerProtocol.normalizeDockConfig(
            enabled = enabledOverride ?: boolPref(FlutterPrefs.key(K_ENABLED), false),
            form = all[DockController.PREF_FORM] as? String,
            toolMic = boolPref(DockController.PREF_TOOL_MIC, true),
            toolPointer = boolPref(DockController.PREF_TOOL_POINTER, false),
            islandX = intPref(K_ISLAND_X),
            islandY = intPref(K_ISLAND_Y),
            islandW = intPref(K_ISLAND_W),
            islandH = intPref(K_ISLAND_H),
            islandSide = all[FlutterPrefs.key(K_ISLAND_SIDE)] as? String,
            trackpad = PointerLink.readTrackpadConfig(context, -1, -1),
        )
    }

    /** Estado del dictado hacia la barra del complemento. [message]: frase fija corta, nunca texto dictado. */
    fun sendMicState(
        context: Context,
        state: String,
        level: Float = 0f,
        message: String? = null,
        needsUi: Boolean = false,
    ) {
        try {
            val intent = Intent(PointerProtocol.ACTION_MIC_STATE)
                .setPackage(PointerProtocol.COMPANION_PACKAGE)
                .putExtra(PointerProtocol.EXTRA_MIC_STATE, state)
                .putExtra(PointerProtocol.EXTRA_MIC_LEVEL, level)
                .putExtra(PointerProtocol.EXTRA_NEEDS_UI, needsUi)
            if (message != null) intent.putExtra(PointerProtocol.EXTRA_MIC_MESSAGE, message)
            context.applicationContext.sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)
        } catch (_: Exception) {}
    }

    // ------------------------------------------------------------ complemento → host

    /** DOCK_HELLO: el servicio del complemento arrancó; se le contesta con la configuración al día. */
    internal fun onHello(context: Context) {
        sendConfig(context, ack = true)
    }

    /** DOCK_STATE: el complemento dice si dibuja la barra y, si la persona la convirtió con el dedo, qué forma quedó. */
    internal fun onDockState(context: Context, intent: Intent) {
        val form = intent.getStringExtra(PointerProtocol.EXTRA_DOCK_FORM)
        if (form == PointerProtocol.FORM_EDGE || form == PointerProtocol.FORM_BUBBLE) {
            // Ajustes muestra la forma elegida con el dedo (el complemento no puede escribir en nuestras prefs).
            try {
                context.applicationContext.getSharedPreferences(FlutterPrefs.PREFS_NAME, Context.MODE_PRIVATE)
                    .edit().putString(DockController.PREF_FORM, form).apply()
            } catch (_: Exception) {}
        }
        if (intent.hasExtra(PointerProtocol.EXTRA_ACTIVE)) {
            val active = intent.getBooleanExtra(PointerProtocol.EXTRA_ACTIVE, false)
            complementDrawing = active
            try {
                onDrawingChanged?.invoke(active)
            } catch (_: Exception) {}
        }
    }
}

/**
 * Receptor del MANIFIESTO (funciona con la app cerrada: Android la despierta):
 * contesta DOCK_HELLO con la configuración y recibe DOCK_STATE. Solo apps con
 * el permiso de firma pueden mandarle algo (`android:permission` en el manifiesto).
 */
class DockLinkReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        when (intent?.action) {
            PointerProtocol.ACTION_DOCK_HELLO -> DockLink.onHello(ctx)
            PointerProtocol.ACTION_DOCK_STATE -> DockLink.onDockState(ctx, intent)
        }
    }
}
