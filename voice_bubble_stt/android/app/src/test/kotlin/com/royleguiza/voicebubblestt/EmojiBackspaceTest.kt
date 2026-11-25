package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** T14 (K7) · ⌫ borra el emoji entero, aunque sea compuesto. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE)
class EmojiBackspaceTest {
    @Test
    fun plainLetter() = assertEquals(1, graphemeUnitsBefore("hola", 1))

    @Test
    fun simpleEmoji() = assertEquals(2, graphemeUnitsBefore("ok 😀", 1))

    @Test
    fun skinTone() = assertEquals("👍🏽".length, graphemeUnitsBefore("dale 👍🏽", 1))

    @Test
    fun zwjFamily() {
        val family = "👨‍👩‍👧‍👦"
        assertEquals(family.length, graphemeUnitsBefore("hola $family", 1))
    }

    @Test
    fun flag() = assertEquals("🇦🇷".length, graphemeUnitsBefore("vamos 🇦🇷", 1))

    @Test
    fun severalGraphemes() = assertEquals(1 + "😀".length, graphemeUnitsBefore("a😀b", 2) )

    @Test
    fun emptyIsZero() {
        assertEquals(0, graphemeUnitsBefore("", 1))
        assertEquals(0, graphemeUnitsBefore(null, 1))
    }
}
