package com.royleguiza.voicebubblestt

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T15 · 30 días con todo, después 10 dictados por día; Pro ilimitado. */
class ProGateTest {
    private val day = 86_400_000L
    private val t0 = 1_800_000_000_000L

    private fun state(unlocked: Boolean = false, start: Long = t0, d: String? = null, n: Int = 0) =
        ProGate.State(unlocked, start, d, n)

    @Test
    fun firstUseStartsTheTrial() {
        val decision = ProGate.decide(state(start = 0L), t0, "2027-01-01")
        assertTrue(decision.allowed)
        assertEquals(t0, decision.next.trialStartMs)
    }

    @Test
    fun trialIsUnlimited() {
        var s = state()
        repeat(50) {
            val decision = ProGate.decide(s, t0 + 29 * day, "2027-01-30")
            assertTrue(decision.allowed)
            s = decision.next
        }
    }

    @Test
    fun afterTrialTenPerDay() {
        var s = state()
        val now = t0 + 31 * day
        repeat(ProGate.FREE_DAILY_DICTATIONS) {
            val decision = ProGate.decide(s, now, "2027-02-01")
            assertTrue(decision.allowed)
            s = decision.next
        }
        assertFalse(ProGate.decide(s, now, "2027-02-01").allowed)
        // Al día siguiente vuelve a haber 10.
        assertTrue(ProGate.decide(s, now + day, "2027-02-02").allowed)
    }

    @Test
    fun proIsUnlimitedForever() {
        var s = state(unlocked = true, d = "2027-02-01", n = 99)
        repeat(30) {
            val decision = ProGate.decide(s, t0 + 400 * day, "2028-02-01")
            assertTrue(decision.allowed)
            s = decision.next
        }
    }
}
