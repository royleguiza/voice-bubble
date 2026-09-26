package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.Intent
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout
import java.io.File
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowToast

/**
 * C-38: la modal del widget cierra en un gesto, igual que la X y sin
 * guardar. Usa el manifest real (recursos y tema de la app) sobre la
 * rama de nota nueva (sin extras: sin E/S en segundo plano).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class WidgetNoteDismissTest {

    private fun buildNewNote(): WidgetNoteEditActivity {
        val controller = Robolectric.buildActivity(
            WidgetNoteEditActivity::class.java, Intent(),
        )
        return controller.setup().get()
    }

    @Test
    fun tapOutsideCardFinishesLikeX() {
        val activity = buildNewNote()
        activity.findViewById<View>(R.id.overlay_root).performClick()
        assertTrue(activity.isFinishing)
    }

    @Test
    fun cardConsumesItsOwnTouches() {
        val activity = buildNewNote()
        val card = activity.findViewById<LinearLayout>(R.id.overlay_root)
            .getChildAt(0)
        assertTrue((card as View).isClickable)
    }

    @Test
    fun backWhileEditingFinishesLikeX() {
        val activity = buildNewNote()
        val body = activity.findViewById<DismissEditText>(R.id.edit_body)
        val consumed = body.dispatchKeyEventPreIme(
            KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK),
        )
        assertTrue(consumed)
        assertTrue(activity.isFinishing)
    }

    @Test
    fun otherKeysStillDelegateToSuper() {
        val activity = buildNewNote()
        val body = activity.findViewById<DismissEditText>(R.id.edit_body)
        val consumed = body.dispatchKeyEventPreIme(
            KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_A),
        )
        assertFalse(consumed)
        assertFalse(activity.isFinishing)
    }

    /**
     * C-39: la modal de un pendiente ofrece transcribir acá. Siembra el
     * índice compartido + WAV real en el contexto de la app de prueba.
     */
    private fun buildPending(): Pair<WidgetNoteEditActivity, String> {
        val app = RuntimeEnvironment.getApplication()
        val id = UUID.randomUUID().toString()
        val dir = File(app.filesDir, "pending_notes").apply { mkdirs() }
        val wav = File(dir, "$id.wav").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
        val entry = JSONArray().put(
            JSONObject()
                .put("id", id)
                .put("audioPath", wav.path)
                .put("createdAtMs", System.currentTimeMillis()),
        ).toString()
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putString("flutter.voice_notes_pending_v1", entry).commit()
        val intent = Intent().putExtra("pending_id", id)
        val activity = Robolectric.buildActivity(
            WidgetNoteEditActivity::class.java, intent,
        ).setup().get()
        return activity to id
    }

    private fun idleMain() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun pendingModalShowsTranscribeSlot() {
        val (activity, _) = buildPending()
        var visible = false
        repeat(100) {
            idleMain()
            if (activity.findViewById<View>(R.id.slot_transcribe).visibility == View.VISIBLE) {
                visible = true
                return@repeat
            }
            Thread.sleep(50)
        }
        assertTrue(visible)
        assertEquals(
            "Transcribir ahora",
            activity.findViewById<View>(R.id.btn_transcribe).contentDescription,
        )
    }

    @Test
    fun transcribeWithoutKeyToastsAndKeepsAudio() {
        val (activity, id) = buildPending()
        repeat(100) {
            idleMain()
            if (activity.findViewById<View>(R.id.slot_transcribe).visibility == View.VISIBLE) return@repeat
            Thread.sleep(50)
        }
        activity.findViewById<View>(R.id.btn_transcribe).performClick()
        var toasted = false
        repeat(100) {
            idleMain()
            if (ShadowToast.getTextOfLatestToast() != null) {
                toasted = true
                return@repeat
            }
            Thread.sleep(50)
        }
        assertTrue(toasted)
        assertFalse(activity.isFinishing)
        val raw = activity.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.voice_notes_pending_v1", null)
        assertNotNull(raw)
        assertTrue(raw!!.contains(id))
    }

    // C-40: cuerpo expandible con tirador.

    @Test
    fun clampBodyHeightKeepsInsideRange() {
        val activity = buildNewNote()
        assertEquals(100, activity.clampBodyHeight(50, 100, 500))
        assertEquals(500, activity.clampBodyHeight(900, 100, 500))
        assertEquals(300, activity.clampBodyHeight(300, 100, 500))
        assertEquals(100, activity.clampBodyHeight(900, 100, 40))
    }

    @Test
    fun computeBodyMaxPxFallsBackToMin() {
        val activity = buildNewNote()
        assertEquals(376, activity.computeBodyMaxPx(800, 100, 300, 12, 12, 180))
        assertEquals(180, activity.computeBodyMaxPx(300, 50, 200, 12, 12, 180))
        assertEquals(180, activity.computeBodyMaxPx(0, 0, 0, 12, 12, 180))
    }

    @Test
    fun dragDownClampsBodyToMin() {
        val activity = buildNewNote()
        idleMain()
        val density = activity.resources.displayMetrics.density
        assertTrue(density > 0)
        val min = (120 * density).toInt()
        val body = activity.findViewById<View>(R.id.edit_body)
        body.layoutParams.height = min + 500
        body.requestLayout()
        val handle = activity.findViewById<View>(R.id.btn_expand_handle)
        val now = SystemClock.uptimeMillis()
        handle.dispatchTouchEvent(
            MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, 100f, 500f, 0),
        )
        handle.dispatchTouchEvent(
            MotionEvent.obtain(now, now + 10, MotionEvent.ACTION_MOVE, 100f, 5000f, 0),
        )
        assertEquals(min, body.layoutParams.height)
    }
}
