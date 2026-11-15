package com.royleguiza.voicebubble.puntero

import android.content.Context
import android.graphics.Typeface

/**
 * Tokens Horizonte (design.md) del complemento, día/noche. Las vistas leen
 * estos campos al dibujar: [reload] los vuelve a resolver cuando el sistema
 * cambia de tema y alcanza con repintar.
 */
internal class Palette(private val context: Context) {
    var surf = 0
        private set
    var surf2 = 0
        private set
    var line = 0
        private set
    var fg = 0
        private set
    var fg2 = 0
        private set
    var ember = 0
        private set
    var emberT = 0
        private set
    var emberSoft = 0
        private set
    var hole = 0
        private set
    var hot = 0
        private set
    var onHole = 0
        private set

    // Isla: siempre negra, de día y de noche (mismos valores en los dos temas).
    var islandBg = 0
        private set
    var islandLine = 0
        private set
    var islandTool = 0
        private set
    var islandToolLine = 0
        private set
    var islandFg = 0
        private set

    init {
        reload()
    }

    fun reload() {
        surf = context.getColor(R.color.hz_surf)
        surf2 = context.getColor(R.color.hz_surf2)
        line = context.getColor(R.color.hz_line)
        fg = context.getColor(R.color.hz_fg)
        fg2 = context.getColor(R.color.hz_fg2)
        ember = context.getColor(R.color.hz_ember)
        emberT = context.getColor(R.color.hz_ember_t)
        emberSoft = context.getColor(R.color.hz_ember_soft)
        hole = context.getColor(R.color.hz_hole)
        hot = context.getColor(R.color.hz_hot)
        onHole = context.getColor(R.color.hz_on_hole)
        islandBg = context.getColor(R.color.island_bg)
        islandLine = context.getColor(R.color.island_line)
        islandTool = context.getColor(R.color.island_tool)
        islandToolLine = context.getColor(R.color.island_tool_line)
        islandFg = context.getColor(R.color.island_fg)
    }
}

/** Fuentes Horizonte: Sora para títulos, Inter para texto. Sin ellas, la del sistema. */
internal object Fonts {
    private fun load(context: Context, id: Int, fallback: Typeface): Typeface = try {
        context.resources.getFont(id)
    } catch (_: Exception) {
        fallback
    }

    fun sora(context: Context): Typeface = load(context, R.font.sora_semibold, Typeface.DEFAULT_BOLD)
    fun inter(context: Context): Typeface = load(context, R.font.inter_regular, Typeface.DEFAULT)
    fun interMedium(context: Context): Typeface = load(context, R.font.inter_medium, Typeface.DEFAULT_BOLD)
    fun mono(context: Context): Typeface = load(context, R.font.jetbrains_mono_medium, Typeface.MONOSPACE)
}
