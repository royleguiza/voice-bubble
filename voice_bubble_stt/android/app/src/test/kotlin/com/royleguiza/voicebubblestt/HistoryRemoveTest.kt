package com.royleguiza.voicebubblestt

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** T9 (K6) · Borrar un dictado del historial sin que la fusión lo resucite. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class HistoryRemoveTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences(TranscriptionHistoryRepository.PREFS_NAME, Context.MODE_PRIVATE)
            .edit().clear().commit()
        context.filesDir.listFiles()?.forEach { it.deleteRecursively() }
    }

    @Test
    fun removesFromFileAndFromFlutterPrefs() {
        // La app Flutter también guardó el dictado en sus preferencias.
        val dartCopy = JSONArray()
            .put(JSONObject().put("text", "uno").put("timestamp", "2026-11-20T10:00:00.000Z").toString())
        context.getSharedPreferences(TranscriptionHistoryRepository.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(
                TranscriptionHistoryRepository.SHARED_HISTORY_KEY,
                TranscriptionHistoryLogic.JSON_LIST_PREFIX + dartCopy,
            ).commit()
        val repo = TranscriptionHistoryRepository(context)
        assertTrue(repo.addTranscription("uno", "2026-11-20T10:00:00Z"))
        assertTrue(repo.addTranscription("dos", "2026-11-21T10:00:00Z"))
        assertEquals(listOf("dos", "uno"), repo.loadHistory().map { it.getString("text") })

        assertTrue(repo.removeTranscription("uno", "2026-11-20T10:00:00Z"))
        assertEquals(listOf("dos"), TranscriptionHistoryRepository(context).loadHistory().map { it.getString("text") })
    }

    @Test
    fun removingSomethingMissingIsHarmless() {
        val repo = TranscriptionHistoryRepository(context)
        assertTrue(repo.addTranscription("dos", "2026-11-21T10:00:00Z"))
        assertTrue(repo.removeTranscription("otro", "2026-11-21T10:00:00Z"))
        assertEquals(1, repo.loadHistory().size)
    }
}
