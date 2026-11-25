package com.royleguiza.voicebubblestt

import android.content.Context
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** T1 · Ida y vuelta de la copia de seguridad y reglas de su formato. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class BackupManagerTest {

    private lateinit var context: Context
    private val prefs get() = context.getSharedPreferences(NoteStore.PREFS_NAME, Context.MODE_PRIVATE)

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        wipe()
    }

    @After
    fun tearDown() = wipe()

    private fun wipe() {
        prefs.edit().clear().commit()
        context.filesDir.listFiles()?.forEach { it.deleteRecursively() }
        ClipboardStore.markDiskChanged()
    }

    private fun seed(): File {
        val audioDir = File(context.filesDir, "notes_audio").apply { mkdirs() }
        val wav = File(audioDir, "rec_1.wav").apply { writeBytes(ByteArray(2048) { it.toByte() }) }
        val store = NoteStore(context)
        assertEquals(NoteSaveResult.SAVED, store.addUntitledNote("Nota con audio", wav.absolutePath))
        assertEquals(NoteSaveResult.SAVED, store.saveNote(null, "Título", "Nota sin audio"))
        val history = TranscriptionHistoryRepository(context)
        assertTrue(history.addTranscription("dictado uno", "2026-11-20T10:00:00Z"))
        assertTrue(history.addTranscription("dictado dos", "2026-11-21T10:00:00Z"))
        SnippetStore(context).writeAll(
            listOf(VbSnippet("s1", "Saludo", "Hola, ¿cómo estás?", 0, "naranja")),
        )
        val clipExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
        ClipboardStore(context, clipExecutor).writeImported(
            listOf(ClipboardItem(id = "c1", type = ClipType.TEXT, text = "recorte", timestamp = 1000L)),
        )
        clipExecutor.shutdown()
        prefs.edit()
            .putBoolean("flutter.kb_haptics_enabled", false)
            .putString("flutter.kb_height_profile", "alta")
            .putLong("flutter.kb_bottom_elevation_dp", 12L)
            .putString("flutter.kb_stt_api_key", "gsk_SECRETO_NO_VIAJA")
            .putString("flutter.vb_credentials_v1", "[{\"user\":\"yo\"}]")
            .putString("flutter.vb_cred_pass_v1", "pass-secreta")
            .putString("flutter.some_auth_token", "tok-secreto")
            .commit()
        return wav
    }

    private fun exportBytes(): ByteArray {
        val out = ByteArrayOutputStream()
        BackupManager(context).export(out, "1.0.0")
        return out.toByteArray()
    }

    private fun entries(zip: ByteArray): Map<String, ByteArray> {
        val map = LinkedHashMap<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(zip)).use { input ->
            while (true) {
                val entry = input.nextEntry ?: break
                map[entry.name] = input.readBytes()
            }
        }
        return map
    }

    @Test
    fun exportHasEverythingButNoSecrets() {
        seed()
        val zip = exportBytes()
        val files = entries(zip)
        assertTrue(files.keys.containsAll(listOf("manifest.json", "notes.json", "history.json", "snippets.json", "clips.json", "settings.json", "audio/rec_1.wav")))
        val all = files.values.joinToString("\n") { String(it, Charsets.UTF_8) }
        assertFalse(all.contains("gsk_SECRETO_NO_VIAJA"))
        assertFalse(all.contains("pass-secreta"))
        assertFalse(all.contains("tok-secreto"))
        assertFalse(all.contains("vb_credentials_v1"))
        val manifest = JSONObject(String(files.getValue("manifest.json"), Charsets.UTF_8))
        assertEquals(BackupFormat.FORMAT, manifest.getString("format"))
        assertEquals(2, manifest.getInt("notes"))
        assertEquals(1, manifest.getInt("audio"))
    }

    @Test
    fun roundTripIntoCleanInstallRestoresDataWithoutKeys() {
        seed()
        val zip = exportBytes()
        wipe()

        val summary = BackupManager(context).import(ByteArrayInputStream(zip))
        assertEquals(2, summary.notes)
        assertEquals(1, summary.audio)
        assertEquals(2, summary.history)
        assertEquals(1, summary.snippets)
        assertEquals(1, summary.clips)

        val notes = NoteStore(context).load()
        assertEquals(2, notes.size)
        val withAudio = notes.single { it.cuerpo == "Nota con audio" }
        val audio = File(withAudio.audioPath)
        assertTrue(audio.isFile)
        assertEquals(2048L, audio.length())
        assertEquals(File(context.filesDir, "notes_audio").canonicalPath, audio.parentFile!!.canonicalPath)
        assertEquals("Título", notes.single { it.cuerpo == "Nota sin audio" }.titulo)

        val history = TranscriptionHistoryRepository(context).loadHistory().map { it.getString("text") }
        assertEquals(listOf("dictado dos", "dictado uno"), history)
        val snippet = SnippetStore(context).load().single()
        assertEquals("Hola, ¿cómo estás?", snippet.contenido)
        assertEquals("naranja", snippet.color)
        val clipExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
        assertEquals("recorte", ClipboardStore(context, clipExecutor).loadItems().single().text)
        clipExecutor.shutdown()

        assertFalse(prefs.getBoolean("flutter.kb_haptics_enabled", true))
        assertEquals("alta", prefs.getString("flutter.kb_height_profile", null))
        assertEquals(12L, prefs.getLong("flutter.kb_bottom_elevation_dp", 0L))
        assertNull(prefs.getString("flutter.kb_stt_api_key", null))
        assertNull(prefs.getString("flutter.vb_credentials_v1", null))
        assertNull(prefs.getString("flutter.vb_cred_pass_v1", null))
    }

    @Test
    fun reimportingDoesNotDuplicate() {
        seed()
        val zip = exportBytes()
        val again = BackupManager(context).import(ByteArrayInputStream(zip))
        assertEquals(0, again.notes)
        assertEquals(0, again.snippets)
        assertEquals(0, again.clips)
        assertEquals(0, again.history)
        assertEquals(2, NoteStore(context).load().size)
        assertEquals(1, File(context.filesDir, "notes_audio").listFiles()!!.size)
    }

    @Test
    fun importKeepsLocalNotesAndAddsNewOnes() {
        seed()
        val zip = exportBytes()
        wipe()
        assertEquals(NoteSaveResult.SAVED, NoteStore(context).saveNote(null, "", "Nota local"))
        BackupManager(context).import(ByteArrayInputStream(zip))
        val bodies = NoteStore(context).load().map { it.cuerpo }.toSet()
        assertEquals(setOf("Nota local", "Nota con audio", "Nota sin audio"), bodies)
    }

    @Test
    fun foreignZipIsRejectedAndNothingChanges() {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            zip.putNextEntry(ZipEntry("../evil.txt"))
            zip.write("x".toByteArray())
            zip.closeEntry()
            zip.putNextEntry(ZipEntry("manifest.json"))
            zip.write("{\"format\":\"otra-cosa\",\"version\":1}".toByteArray())
            zip.closeEntry()
        }
        try {
            BackupManager(context).import(ByteArrayInputStream(out.toByteArray()))
            fail("debía rechazar el zip")
        } catch (error: BackupManager.BackupException) {
            assertEquals(BackupManager.REASON_FORMAT, error.reason)
        }
        assertFalse(File(context.cacheDir.parentFile, "evil.txt").exists())
        assertTrue(NoteStore(context).load().isEmpty())
    }

    @Test
    fun newerFormatIsRejected() {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            zip.putNextEntry(ZipEntry("manifest.json"))
            zip.write("{\"format\":\"orison-backup\",\"version\":99}".toByteArray())
            zip.closeEntry()
        }
        try {
            BackupManager(context).import(ByteArrayInputStream(out.toByteArray()))
            fail("debía rechazar la versión")
        } catch (error: BackupManager.BackupException) {
            assertEquals(BackupManager.REASON_VERSION, error.reason)
        }
    }

    @Test
    fun notAZipIsRejected() {
        try {
            BackupManager(context).import(ByteArrayInputStream("hola".toByteArray()))
            fail("debía rechazar")
        } catch (error: BackupManager.BackupException) {
            assertEquals(BackupManager.REASON_FORMAT, error.reason)
        }
    }

    // ----------------------------------------------------------- formato puro

    @Test
    fun entryNamesAreValidated() {
        assertEquals(BackupFormat.EntryKind.JSON, BackupFormat.classifyEntry("notes.json"))
        assertEquals(BackupFormat.EntryKind.AUDIO, BackupFormat.classifyEntry("audio/rec_1.wav"))
        assertEquals(BackupFormat.EntryKind.CLIP_MEDIA, BackupFormat.classifyEntry("clips/clip_a.png"))
        assertNull(BackupFormat.classifyEntry("../notes.json"))
        assertNull(BackupFormat.classifyEntry("audio/../x.wav"))
        assertNull(BackupFormat.classifyEntry("audio/sub/x.wav"))
        assertNull(BackupFormat.classifyEntry("audio/.hidden"))
        assertNull(BackupFormat.classifyEntry("/etc/passwd"))
        assertNull(BackupFormat.classifyEntry("otro.json"))
    }

    @Test
    fun secretsNeverExportable() {
        listOf(
            "flutter.kb_stt_api_key", "flutter.groq_api_key", "flutter.vb_cred_pass_v1",
            "flutter.vb_credentials_v1", "flutter.kb_stt_key_configured", "flutter.x_token",
            "flutter.voice_notes_v1", "flutter.transcriptions", "otra.clave",
        ).forEach { assertFalse(it, BackupFormat.isExportablePrefKey(it)) }
        listOf("flutter.kb_height_profile", "flutter.theme_mode", "flutter.kb_app_locale")
            .forEach { assertTrue(it, BackupFormat.isExportablePrefKey(it)) }
    }

    @Test
    fun prefsKeepTheirTypes() {
        val encoded = BackupFormat.encodePrefs(
            mapOf(
                "flutter.a" to true, "flutter.b" to 7L, "flutter.c" to 1.5f,
                "flutter.d" to "x", "flutter.e" to setOf("p", "q"), "flutter.kb_stt_api_key" to "no",
            ),
        )
        val decoded = BackupFormat.decodePrefs(JSONObject(encoded.toString()))
        assertEquals(true, decoded["flutter.a"])
        assertEquals(7L, decoded["flutter.b"])
        assertEquals(1.5f, decoded["flutter.c"])
        assertEquals("x", decoded["flutter.d"])
        assertEquals(setOf("p", "q"), decoded["flutter.e"])
        assertFalse(decoded.containsKey("flutter.kb_stt_api_key"))
    }

    @Test
    fun mergeNotesNeverDropsLocalAndRespectsCap() {
        fun note(id: String, t: String) = VbNote(id, "", id, t, t)
        val epoch = { iso: String -> java.time.Instant.parse(iso).toEpochMilli() }
        val local = listOf(note("a", "2026-01-01T00:00:00Z"), note("b", "2026-01-02T00:00:00Z"))
        val incoming = listOf(
            note("a", "2026-03-01T00:00:00Z").copy(cuerpo = "a nueva"),
            note("b", "2025-01-01T00:00:00Z").copy(cuerpo = "b vieja"),
            note("c", "2026-02-01T00:00:00Z"),
            note("d", "2026-02-02T00:00:00Z"),
        )
        val merge = BackupFormat.mergeNotes(local, incoming, 3, epoch)
        assertEquals(1, merge.updated)
        assertEquals(1, merge.added)
        assertEquals(1, merge.skipped)
        assertEquals(listOf("a", "d", "b"), merge.notes.map { it.id })
        assertEquals("a nueva", merge.notes.first().cuerpo)
        assertEquals("b", merge.notes.last().cuerpo)
    }

    @Test
    fun mergeSnippetsSkipsSameBody() {
        val local = listOf(VbSnippet("seed-1", "Saludo", "Hola", 0))
        val incoming = listOf(
            VbSnippet("otro-id", "Saludo", "Hola", 0),
            VbSnippet("n", "Precio", "$100", 1),
        )
        val merge = BackupFormat.mergeSnippets(local, incoming, 50)
        assertEquals(1, merge.added)
        assertEquals(listOf("seed-1", "n"), merge.snippets.map { it.id })
        assertNotNull(merge.snippets.last().orden)
    }
}
