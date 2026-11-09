package com.royleguiza.voicebubblestt

import android.content.Context
import android.os.Build
import android.view.WindowInsets
import android.widget.LinearLayout

/**
 * Raíz vertical del teclado que se mide SIEMPRE con el relleno inferior
 * vigente (barra del sistema + elevación elegida en Ajustes).
 *
 * Antes el relleno se fijaba solo desde el listener de insets. Si los
 * insets llegaban después de que la ventana del IME (WRAP_CONTENT) ya
 * había tomado su alto, el relleno crecía sin que la ventana creciera y
 * la fila inferior (?123, coma, punto, espacio, Enter) quedaba cortada
 * justo lo que medía la barra (~24 dp). No pasaba siempre: dependía del
 * orden en que llegaban los insets al abrir el teclado.
 *
 * Ahora [onMeasure] recalcula el relleno con los insets actuales antes de
 * medir, y si el listener trae un valor distinto fuerza una medición nueva
 * en el siguiente cuadro. La altura de la ventana y el relleno no pueden
 * desincronizarse. La elevación se lee en vivo: cambiarla en Ajustes se
 * refleja en la próxima medición, sin recrear la vista.
 */
class KeyboardRootLayout(context: Context) : LinearLayout(context) {

    /** Relleno inferior total en px para unos insets dados. */
    var bottomPaddingFor: (WindowInsets?) -> Int = { 0 }
    var padH = 0
    var padV = 0

    private var lastInsets: WindowInsets? = null

    init {
        orientation = VERTICAL
    }

    override fun onApplyWindowInsets(insets: WindowInsets): WindowInsets {
        lastInsets = insets
        if (syncPadding(insets)) post { requestLayout() }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowInsets.CONSUMED
        } else {
            @Suppress("DEPRECATION")
            insets.consumeSystemWindowInsets()
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        syncPadding(rootWindowInsets ?: lastInsets)
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    /** Aplica el relleno si cambió. Devuelve true si hubo cambio. */
    private fun syncPadding(insets: WindowInsets?): Boolean {
        val bottom = padV + bottomPaddingFor(insets)
        if (paddingLeft == padH && paddingTop == padV &&
            paddingRight == padH && paddingBottom == bottom
        ) {
            return false
        }
        setPadding(padH, padV, padH, bottom)
        return true
    }
}
