package com.royleguiza.voicebubble.puntero

import android.content.Context
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowInsets
import android.view.WindowManager
import kotlin.math.roundToInt

/**
 * Mide la pantalla real (barra de estado, de navegación y recorte de cámara
 * incluidos) para las ventanas de Accesibilidad. Se vuelve a leer al girar el
 * teléfono: nada se cachea.
 */
internal class ScreenProbe(private val context: Context, private val windowManager: WindowManager) {

    /** (ancho, alto) en px del display completo, en la orientación actual. */
    fun size(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val b = windowManager.maximumWindowMetrics.bounds
                if (b.width() > 0 && b.height() > 0) return Pair(b.width(), b.height())
            } catch (_: Exception) {}
        }
        val dm = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(dm)
        return Pair(dm.widthPixels, dm.heightPixels)
    }

    /** Alto de la barra de estado / recorte de cámara arriba (zona segura de la burbuja). */
    fun topInset(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val i = windowManager.currentWindowMetrics.windowInsets
                    .getInsetsIgnoringVisibility(WindowInsets.Type.statusBars() or WindowInsets.Type.displayCutout())
                if (i.top > 0) return i.top
            } catch (_: Exception) {}
        }
        return (28 * context.resources.displayMetrics.density).roundToInt()
    }

    /** Alto de la barra de navegación (o de la zona de gestos) abajo. */
    fun bottomInset(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val i = windowManager.currentWindowMetrics.windowInsets
                    .getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars())
                if (i.bottom > 0) return i.bottom
            } catch (_: Exception) {}
        }
        val res = context.resources
        val id = res.getIdentifier("navigation_bar_height", "dimen", "android")
        if (id > 0) {
            try {
                return res.getDimensionPixelSize(id)
            } catch (_: Exception) {}
        }
        return (24 * res.displayMetrics.density).roundToInt()
    }
}
