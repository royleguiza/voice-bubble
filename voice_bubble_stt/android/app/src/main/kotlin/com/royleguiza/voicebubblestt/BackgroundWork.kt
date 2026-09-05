package com.royleguiza.voicebubblestt

import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

/**
 * Puerta única de ejecución en segundo plano para el código nativo.
 *
 * Causa raíz que corrige: lecturas de disco (historial, portapapeles) y el
 * arranque de AudioRecord corrían en el hilo principal (MethodChannel,
 * onCreateInputView/rebuild, populate de modales), con riesgo de ANR.
 * En vez de un thread suelto por sitio, todos los llamadores pasan por acá:
 * un pool compartido para el trabajo y post al main solo para tocar UI.
 *
 * REGLAS:
 * - [block] jamás corre en el main; no debe tocar vistas.
 * - [onResult]/[postMain] siempre corren en el main; el llamador debe
 *   revalidar que su vista siga vigente (rebuild/destroy en el medio).
 * - Cero logs, cero red, cero claves nuevas: no toca el contrato Flutter.
 */
object BackgroundWork {

    private val executor = Executors.newCachedThreadPool { runnable ->
        Thread(runnable, "VbBackground").apply { isDaemon = true }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Ejecuta [block] en un hilo de trabajo, sin resultado. */
    fun execute(block: () -> Unit) {
        try {
            executor.execute {
                try {
                    block()
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    /**
     * Ejecuta [block] en un hilo de trabajo y entrega su valor en el main.
     * Si el trabajo falla, entrega null en vez de dejar la respuesta colgada.
     */
    fun <T : Any> executeWithResult(block: () -> T?, onResult: (T?) -> Unit) {
        try {
            executor.execute {
                val value = try {
                    block()
                } catch (_: Exception) {
                    null
                }
                postMain {
                    onResult(value)
                }
            }
        } catch (_: Exception) {
            postMain {
                onResult(null)
            }
        }
    }

    /** Publica [block] al hilo principal (toques de UI). */
    fun postMain(block: () -> Unit) {
        try {
            mainHandler.post {
                try {
                    block()
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }
}
