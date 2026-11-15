package com.royleguiza.voicebubble.puntero

/**
 * Lo que la barra le pide al resto del complemento (la implementa [DockManager]).
 * El audio y el texto nunca pasan por acá: solo órdenes («dictá», «cancelá»,
 * «abrí el puntero») y avisos de forma.
 */
internal interface DockCallbacks {
    /** Tocaron el micrófono: empezar o terminar el dictado (lo hace VoiceBubble). */
    fun onMicTap()

    /** Tocaron la ✕: cortar y tirar la grabación. */
    fun onMicCancel()

    /** Tocaron el puntero: abrir el trackpad junto a (anchorX, anchorY). */
    fun onPointerTap(anchorX: Int, anchorY: Int)

    /** La persona convirtió la barra en burbuja (o al revés) con el dedo: VoiceBubble debe enterarse (Ajustes). */
    fun onFormChanged(form: String)
}

/**
 * Una forma de la barra (borde/burbuja en [DockController], isla en
 * [IslandController]). [DockManager] crea la que pide la configuración y la
 * cambia en vivo; cada una limpia sus ventanas, animadores y temporizadores en
 * [destroy].
 */
internal interface DockSurface {
    /** ¿Hay una ventana visible dibujando la barra? Si Android no dejó crearla, VoiceBubble debe mostrar la suya. */
    fun isDrawing(): Boolean

    /** Aplica la configuración (herramientas, isla) sin recrear la superficie. */
    fun applyConfig(cfg: PointerProtocol.DockConfig)

    /** Estado del dictado que cuenta VoiceBubble. */
    fun setMic(tracker: MicStateTracker, nowMs: Long)

    /** El trackpad del complemento se abrió o se cerró. */
    fun setTrackpadOpen(open: Boolean)

    /** Giró el teléfono, cambió el tamaño de pantalla o el tema. */
    fun onConfigurationChanged()

    /** Saca ventanas, animadores y temporizadores. */
    fun destroy()
}
