package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** T10 (K8) · Mantener q…p escribe 1…0; las tildes siguen en el menú. */
class TopRowNumbersTest {
    @Test
    fun digitsOfTheTopRow() {
        assertEquals("1", topRowDigitFor('q'))
        assertEquals("2", topRowDigitFor('w'))
        assertEquals("0", topRowDigitFor('p'))
        assertNull(topRowDigitFor('a'))
        assertNull(topRowDigitFor('ñ'))
    }

    @Test
    fun letterWithoutAccentsGetsOnlyItsNumber() {
        assertEquals(listOf("2"), letterLongPressOptions('w', true))
        assertEquals(listOf("1"), letterLongPressOptions('q', true))
    }

    @Test
    fun vowelsKeepAccentsAfterTheNumber() {
        val e = letterLongPressOptions('e', true)
        assertEquals("3", e.first())
        assertTrue("é" in e && "è" in e)
        assertEquals("8", letterLongPressOptions('i', true).first())
    }

    @Test
    fun switchOffRestoresAccentsOnly() {
        assertEquals(accentsFor('e'), letterLongPressOptions('e', false))
        assertTrue(letterLongPressOptions('w', false).isEmpty())
        assertEquals(accentsFor('a'), letterLongPressOptions('a', true))
    }
}
