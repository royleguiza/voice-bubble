package com.royleguiza.voicebubble.puntero

/**
 * Lo último que el host contó del dictado (estado, nivel de voz, mensaje) y
 * desde cuándo. Lógica pura (sin android.*) para testearla en la JVM.
 *
 * Seguro contra un host que muere a medio dictado: mientras graba o
 * transcribe, el host manda noticias seguido ([PointerProtocol.MIC_LEVEL_EVERY_MS]
 * grabando y un latido cada ~1,5 s transcribiendo). Si pasan
 * [PointerProtocol.MIC_STALE_MS] sin noticias, [isStale] avisa y la barra
 * vuelve a reposo en vez de quedarse «grabando» para siempre.
 *
 * Solo guarda estados y un nivel: ni audio ni texto pasan por acá.
 */
internal class MicStateTracker {

    var state: String = PointerProtocol.MIC_IDLE
        private set
    var level: Float = 0f
        private set
    var message: String? = null
        private set

    /** Reloj (ms) en que empezó la grabación actual; 0 si no hay. */
    private var recordingSinceMs = 0L
    private var lastNewsMs = 0L

    val isBusy: Boolean get() = PointerProtocol.isBusy(state)

    /** Aplica una noticia del host. Devuelve true si cambió el ESTADO (no solo el nivel). */
    fun update(next: PointerProtocol.MicState, nowMs: Long): Boolean {
        val changed = next.state != state
        if (changed && next.state == PointerProtocol.MIC_RECORDING) recordingSinceMs = nowMs
        if (changed && next.state != PointerProtocol.MIC_TRANSCRIBING && next.state != PointerProtocol.MIC_RECORDING) {
            recordingSinceMs = 0L
        }
        state = next.state
        level = next.level
        message = next.message
        lastNewsMs = nowMs
        return changed
    }

    /** ¿Hace demasiado que no hay noticias de un dictado en curso? */
    fun isStale(nowMs: Long): Boolean = isBusy && nowMs - lastNewsMs > PointerProtocol.MIC_STALE_MS

    /**
     * «Listo» y «error» se muestran una sola vez: después de mostrarlos queda
     * reposo, para que un cambio de configuración (p. ej. mover la isla desde
     * Ajustes) no los vuelva a mostrar.
     */
    fun consumeResult() {
        if (state == PointerProtocol.MIC_DONE || state == PointerProtocol.MIC_ERROR) {
            state = PointerProtocol.MIC_IDLE
            message = null
            level = 0f
        }
    }

    /** Vuelve a reposo (sin noticias, o el servicio se desvinculó). */
    fun reset() {
        state = PointerProtocol.MIC_IDLE
        level = 0f
        message = null
        recordingSinceMs = 0L
        lastNewsMs = 0L
    }

    /** Segundos grabados hasta ahora (el cronómetro de la isla); 0 si no graba. */
    fun elapsedSeconds(nowMs: Long): Int =
        if (recordingSinceMs == 0L) 0 else ((nowMs - recordingSinceMs).coerceAtLeast(0L) / 1000L).toInt()

    companion object {
        /** «m:ss» para el cronómetro. */
        fun clock(seconds: Int): String {
            val s = seconds.coerceAtLeast(0)
            return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
        }
    }
}
