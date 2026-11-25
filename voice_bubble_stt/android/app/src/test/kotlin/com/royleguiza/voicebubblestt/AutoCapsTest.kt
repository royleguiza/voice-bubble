package com.royleguiza.voicebubblestt

import android.text.InputType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T6 (K2) · Mayúscula automática: qué campos y qué transiciones. */
class AutoCapsTest {
    private val text = InputType.TYPE_CLASS_TEXT
    private val sentences = InputType.TYPE_TEXT_FLAG_CAP_SENTENCES

    @Test
    fun fieldsThatNeverCapitalize() {
        assertTrue(AutoCaps.fieldAllows(text or sentences))
        assertTrue(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_SHORT_MESSAGE or sentences))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_PASSWORD))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS))
        assertFalse(AutoCaps.fieldAllows(text or InputType.TYPE_TEXT_VARIATION_URI))
        assertFalse(AutoCaps.fieldAllows(InputType.TYPE_CLASS_NUMBER))
        assertFalse(AutoCaps.fieldAllows(InputType.TYPE_CLASS_PHONE))
        assertFalse(AutoCaps.fieldAllows(InputType.TYPE_NULL))
    }

    @Test
    fun turnsOnWhenTheFieldAsksAndOffAfterwards() {
        val on = AutoCaps.next(ShiftState.OFF, false, sentences, true)
        assertEquals(AutoCaps.Step(ShiftState.MOMENTARY, true), on)
        val off = AutoCaps.next(on.state, on.auto, 0, true)
        assertEquals(AutoCaps.Step(ShiftState.OFF, false), off)
    }

    @Test
    fun neverWhenNotAllowed() {
        assertEquals(AutoCaps.Step(ShiftState.OFF, false), AutoCaps.next(ShiftState.OFF, false, sentences, false))
        // Si deja de estar permitido (p. ej. cambio a ?123), apaga el suyo.
        assertEquals(AutoCaps.Step(ShiftState.OFF, false), AutoCaps.next(ShiftState.MOMENTARY, true, sentences, false))
    }

    @Test
    fun respectsManualShiftAndCapsLock() {
        assertEquals(AutoCaps.Step(ShiftState.MOMENTARY, false), AutoCaps.next(ShiftState.MOMENTARY, false, 0, true))
        assertEquals(AutoCaps.Step(ShiftState.CAPS_LOCK, false), AutoCaps.next(ShiftState.CAPS_LOCK, false, 0, true))
        assertEquals(AutoCaps.Step(ShiftState.CAPS_LOCK, false), AutoCaps.next(ShiftState.CAPS_LOCK, true, sentences, true))
    }

    @Test
    fun staysOnWhileStillAsked() {
        assertEquals(AutoCaps.Step(ShiftState.MOMENTARY, true), AutoCaps.next(ShiftState.MOMENTARY, true, sentences, true))
    }
}
