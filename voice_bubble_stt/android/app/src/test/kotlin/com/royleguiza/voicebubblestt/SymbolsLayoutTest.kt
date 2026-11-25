package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** T7 (K3) · Símbolos completos: ¿ ¡ € ° … « » - se pueden escribir. */
class SymbolsLayoutTest {

    private fun page(spanish: Boolean, page2: Boolean): String {
        val top = if (page2) {
            LayoutLayer.SYMBOLS2_ROW1 + LayoutLayer.SYMBOLS2_ROW2
        } else {
            "1234567890" + "@#$%&-+()/"
        }
        return top + LayoutLayer.symbolsRow3(spanish, page2)
    }

    @Test
    fun spanishPage1ShowsInvertedMarks() {
        val p1 = page(spanish = true, page2 = false)
        assertTrue("¿" in p1 && "¡" in p1 && "?" in p1 && "!" in p1)
    }

    @Test
    fun everyNeededSymbolIsReachableInBothLanguages() {
        for (es in listOf(true, false)) {
            val all = page(es, false) + page(es, true)
            for (s in listOf("¿", "¡", "€", "£", "°", "…", "«", "»", "-", "'", "=", "^", "\\", "<", ">", "{", "}", "[", "]", "~", "`", "|", "•", "_")) {
                assertTrue("falta $s (es=$es)", s in all)
            }
        }
    }

    @Test
    fun noDuplicatesWithinAPage() {
        for (es in listOf(true, false)) {
            for (p2 in listOf(true, false)) {
                val chars = page(es, p2).toList()
                assertEquals("repetidos en es=$es p2=$p2", chars.size, chars.toSet().size)
            }
        }
    }

    @Test
    fun rowsFitTheGrid() {
        assertEquals(10, LayoutLayer.SYMBOLS2_ROW1.length)
        assertEquals(10, LayoutLayer.SYMBOLS2_ROW2.length)
        for (es in listOf(true, false)) for (p2 in listOf(true, false)) {
            assertTrue(LayoutLayer.symbolsRow3(es, p2).length in 7..8)
        }
    }

    @Test
    fun longPressAlternatives() {
        assertEquals(listOf("¿"), symbolsFor('?'))
        assertEquals(listOf("¡"), symbolsFor('!'))
        assertEquals("€", symbolsFor('$').first())
        assertEquals(listOf("°"), symbolsFor('0'))
        assertTrue("—" in symbolsFor('-'))
        assertTrue("«" in symbolsFor('"') && "»" in symbolsFor('"'))
        assertTrue("•" in symbolsFor('*'))
        assertEquals(listOf("‰"), symbolsFor('%'))
        assertTrue(symbolsFor('a').isEmpty())
    }
}
