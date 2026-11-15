package com.royleguiza.voicebubblestt

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Respaldo del dictado de la barra del complemento (fase 2A): si Android no deja
 * que [DockDictationService] arranque el micrófono desde segundo plano, el
 * complemento abre esta actividad (translúcida, sin animación, fuera de
 * recientes). Estando en primer plano, arranca el servicio con
 * `EXTRA_FROM_TRAMPOLINE` y se cierra sola: la persona casi no la ve.
 *
 * Exportada SOLO para apps con el permiso de firma del puntero (manifiesto).
 * No muestra nada ni guarda nada.
 */
class DockTrampolineActivity : Activity() {

    private var started = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
    }

    override fun onResume() {
        super.onResume()
        // Ya en primer plano: ahora sí el servicio puede pasar a primer plano con el micrófono.
        if (!started) {
            started = true
            try {
                val intent = Intent(this, DockDictationService::class.java)
                    .setAction(PointerProtocol.ACTION_DICTATION_TOGGLE)
                    .putExtra(PointerProtocol.EXTRA_FROM_TRAMPOLINE, true)
                startForegroundService(intent)
            } catch (_: Exception) {
                DockLink.sendMicState(
                    this,
                    PointerProtocol.MIC_ERROR,
                    message = DockDictationLogic.MSG_MIC_FAILED,
                )
            }
        }
        finish()
        overridePendingTransition(0, 0)
    }
}
