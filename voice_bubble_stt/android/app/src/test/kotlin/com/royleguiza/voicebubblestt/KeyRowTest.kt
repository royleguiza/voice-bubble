package com.royleguiza.voicebubblestt

import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** T5 (K1) · Los toques en los huecos llegan enteros a la tecla más cercana. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class KeyRowTest {

    private lateinit var row: KeyRow
    private lateinit var a: View
    private lateinit var b: View
    private val events = mutableListOf<Triple<String, Int, Pair<Float, Float>>>()

    /** Fila de 200×60: tecla a en x 4..96, tecla b en x 104..196, y 8..52. */
    @Before
    fun setUp() {
        val ctx = RuntimeEnvironment.getApplication()
        row = KeyRow(ctx)
        a = View(ctx)
        b = View(ctx)
        for ((name, v) in listOf("a" to a, "b" to b)) {
            v.setOnTouchListener { _, ev ->
                events.add(Triple(name, ev.actionMasked, ev.x to ev.y))
                true
            }
            row.addView(v)
        }
        row.layout(0, 0, 200, 60)
        a.layout(4, 8, 96, 52)
        b.layout(104, 8, 196, 52)
    }

    private fun ev(action: Int, x: Float, y: Float): MotionEvent {
        val t = SystemClock.uptimeMillis()
        return MotionEvent.obtain(t, t, action, x, y, 0)
    }

    @Test
    fun touchOnKeyGoesToThatKey() {
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 50f, 30f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_UP, 50f, 30f))
        assertEquals(listOf("a", "a"), events.map { it.first })
    }

    @Test
    fun gapBetweenKeysGoesToNearestAndKeepsTheWholeGesture() {
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 98f, 30f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_MOVE, 99f, 31f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_UP, 99f, 31f))
        assertEquals(listOf("a", "a", "a"), events.map { it.first })
        assertEquals(
            listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP),
            events.map { it.second },
        )
        // DOWN corrido al borde derecho de a (x local 91 = 95 - 4), y local 22.
        assertEquals(91f, events[0].third.first, 0.01f)
        assertEquals(22f, events[0].third.second, 0.01f)
    }

    @Test
    fun rowPaddingAndEdgesAreNotDead() {
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 1f, 2f)) // borde izquierdo + relleno superior
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_UP, 1f, 2f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 199f, 58f)) // esquina inferior derecha
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_UP, 199f, 58f))
        assertEquals(listOf("a", "a", "b", "b"), events.map { it.first })
        assertEquals(0f, events[0].third.first, 0.01f)
        assertEquals(0f, events[0].third.second, 0.01f)
    }

    @Test
    fun hiddenKeysAreSkipped() {
        a.visibility = View.GONE
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 98f, 30f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_UP, 98f, 30f))
        assertTrue(events.all { it.first == "b" })
    }

    @Test
    fun cancelIsForwarded() {
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_DOWN, 100f, 30f))
        row.dispatchTouchEvent(ev(MotionEvent.ACTION_CANCEL, 100f, 30f))
        assertEquals(MotionEvent.ACTION_CANCEL, events.last().second)
    }
}
