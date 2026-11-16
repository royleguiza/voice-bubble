package com.royleguiza.voicebubble.puntero

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * Lado complemento del enlace con VoiceBubble (protocolo v3): avisos firmados
 * hacia el host y el pedido de dictado. Todo es best-effort: si VoiceBubble no
 * está, no hace nada. Nada de lo que viaja es audio ni texto.
 */
internal object HostLink {

    /** El complemento arrancó (o quiere configuración): VoiceBubble contesta con DOCK_CONFIG. */
    fun hello(context: Context) {
        send(context, Intent(PointerProtocol.ACTION_DOCK_HELLO))
    }

    /**
     * Cuenta si el complemento está dibujando la barra ([active]) y, si la
     * persona la convirtió con el dedo, la forma nueva ([form]) para que Ajustes
     * la muestre. VoiceBubble esconde su barra de respaldo mientras [active].
     */
    fun state(context: Context, active: Boolean, form: String? = null) {
        val intent = Intent(PointerProtocol.ACTION_DOCK_STATE).putExtra(PointerProtocol.EXTRA_ACTIVE, active)
        if (form != null) intent.putExtra(PointerProtocol.EXTRA_DOCK_FORM, form)
        send(context, intent)
    }

    /** Toque largo: VoiceBubble muestra su historial (el texto se queda allá). */
    fun showHistory(context: Context, x: Int, y: Int, size: Int) {
        send(
            context,
            Intent(PointerProtocol.ACTION_DOCK_HISTORY)
                .putExtra(PointerProtocol.EXTRA_HISTORY_X, x)
                .putExtra(PointerProtocol.EXTRA_HISTORY_Y, y)
                .putExtra(PointerProtocol.EXTRA_HISTORY_SIZE, size),
        )
    }

    private fun send(context: Context, intent: Intent) {
        try {
            intent.setPackage(PointerProtocol.HOST_PACKAGE)
            context.sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)
        } catch (_: Exception) {}
    }

    /** ¿Está VoiceBubble instalada? (visible por `<queries>` del manifiesto). */
    fun isHostInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(PointerProtocol.HOST_PACKAGE, 0)
        true
    } catch (_: Exception) {
        false
    }

    /** ¿VoiceBubble tiene el permiso de micrófono? Sin él no vale la pena pedirle que grabe. */
    fun hostHasMicPermission(context: Context): Boolean = try {
        context.packageManager.checkPermission("android.permission.RECORD_AUDIO", PointerProtocol.HOST_PACKAGE) ==
            PackageManager.PERMISSION_GRANTED
    } catch (_: Exception) {
        // Sin poder ver al host, que intente él y conteste con su propio error.
        true
    }

    /**
     * Empezar o terminar el dictado: arranca en primer plano el servicio nativo
     * de VoiceBubble (el complemento tiene una ventana visible, lo que habilita
     * el micrófono «mientras se usa»). Devuelve false si Android no lo dejó
     * arrancar: el que llama abre entonces la actividad trampolín.
     */
    fun toggleDictation(context: Context): Boolean = try {
        val intent = Intent(PointerProtocol.ACTION_DICTATION_TOGGLE)
            .setClassName(PointerProtocol.HOST_PACKAGE, PointerProtocol.HOST_DICTATION_SERVICE_CLASS)
        context.startForegroundService(intent) != null
    } catch (_: Exception) {
        false
    }

    /** Cortar y tirar la grabación en curso (el servicio ya está corriendo: no hace falta primer plano). */
    fun cancelDictation(context: Context): Boolean = try {
        val intent = Intent(PointerProtocol.ACTION_DICTATION_CANCEL)
            .setClassName(PointerProtocol.HOST_PACKAGE, PointerProtocol.HOST_DICTATION_SERVICE_CLASS)
        context.startService(intent) != null
    } catch (_: Exception) {
        false
    }

    /**
     * Respaldo: la actividad trampolín de VoiceBubble (translúcida, sin
     * animación, fuera de recientes) arranca el servicio estando en primer
     * plano y se cierra sola. Un servicio de Accesibilidad puede abrir
     * actividades desde el fondo.
     */
    fun openTrampoline(context: Context): Boolean = try {
        val intent = Intent(PointerProtocol.ACTION_DICTATION_TOGGLE)
            .setClassName(PointerProtocol.HOST_PACKAGE, PointerProtocol.HOST_TRAMPOLINE_CLASS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
        context.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
