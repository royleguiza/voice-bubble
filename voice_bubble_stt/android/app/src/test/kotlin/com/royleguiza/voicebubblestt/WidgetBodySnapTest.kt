package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Test

/** T11 · El cuerpo de la hoja del widget mide renglones enteros. */
class WidgetBodySnapTest {
    @Test
    fun roundsDownToWholeLines() {
        // 140 dp × 2,0 = 280 px; relleno 2 × 22 px; renglón de 48 px → 4 renglones.
        assertEquals(44 + 4 * 48, snapToWholeLines(280, 44, 48))
    }

    @Test
    fun exactFitIsKept() = assertEquals(44 + 5 * 48, snapToWholeLines(44 + 5 * 48, 44, 48))

    @Test
    fun atLeastOneLine() = assertEquals(44 + 48, snapToWholeLines(10, 44, 48))

    @Test
    fun invalidLineHeightKeepsHeight() = assertEquals(280, snapToWholeLines(280, 44, 0))
}
