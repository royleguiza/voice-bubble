package com.royleguiza.voicebubblestt

import android.content.Context
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import org.json.JSONArray
import org.json.JSONObject

/**
 * T1 · Copia de seguridad: exporta e importa un `.zip` (formato en
 * [BackupFormat]) usando los mismos almacenes que la app, el teclado y el
 * widget, con sus candados. Corre fuera del hilo principal. Sin logs de
 * contenido: solo cuenta elementos.
 */
class BackupManager(private val context: Context) {

    class BackupException(val reason: String) : IOException(reason)

    data class Summary(
        val notes: Int = 0,
        val notesUpdated: Int = 0,
        val notesSkipped: Int = 0,
        val audio: Int = 0,
        val history: Int = 0,
        val snippets: Int = 0,
        val snippetsSkipped: Int = 0,
        val clips: Int = 0,
        val settings: Int = 0,
    ) {
        fun toMap(): Map<String, Int> = mapOf(
            "notes" to notes,
            "notesUpdated" to notesUpdated,
            "notesSkipped" to notesSkipped,
            "audio" to audio,
            "history" to history,
            "snippets" to snippets,
            "snippetsSkipped" to snippetsSkipped,
            "clips" to clips,
            "settings" to settings,
        )
    }

    private val prefs by lazy {
        context.getSharedPreferences(NoteStore.PREFS_NAME, Context.MODE_PRIVATE)
    }
    private val notesAudioDir: File get() = File(context.filesDir, NOTES_AUDIO_DIR)

    // ---------------------------------------------------------------- exportar

    fun export(out: OutputStream, appVersion: String): Summary {
        val snapshot = NoteStore(context).loadSnapshot()
        if (!isAuthoritativeNoteSnapshot(snapshot) &&
            !(snapshot.fileState == NoteIndexState.MISSING && snapshot.prefsState == NoteIndexState.MISSING)
        ) {
            throw BackupException(REASON_UNAVAILABLE)
        }
        val history = TranscriptionHistoryRepository(context).loadHistory()
        val snippets = SnippetStore(context).load()
        val clipExecutor = Executors.newSingleThreadExecutor()
        val clipStore = ClipboardStore(context, clipExecutor)
        val clips = try {
            clipStore.readForBackup()
        } finally {
            clipExecutor.shutdown()
        }
        val settings = BackupFormat.encodePrefs(prefs.all)

        var audioCount = 0
        var clipCount = 0
        ZipOutputStream(BufferedOutputStream(out)).use { zip ->
            val usedAudio = HashSet<String>()
            val notesJson = JSONArray()
            for (note in snapshot.notes) {
                val audio = exportableAudio(note.audioPath)
                var entryName: String? = null
                if (audio != null) {
                    var name = audio.name
                    if (!usedAudio.add(name)) {
                        name = "${UUID.randomUUID().toString().take(8)}_${audio.name}"
                        usedAudio.add(name)
                    }
                    entryName = BackupFormat.AUDIO_DIR + name
                    zip.putNextEntry(ZipEntry(entryName))
                    audio.inputStream().use { it.copyTo(zip) }
                    zip.closeEntry()
                    audioCount++
                }
                notesJson.put(BackupFormat.noteToJson(note, entryName))
            }
            putJson(zip, BackupFormat.NOTES, notesJson.toString())

            val historyJson = JSONArray()
            history.forEach { historyJson.put(it) }
            putJson(zip, BackupFormat.HISTORY, historyJson.toString())

            val snippetsJson = JSONArray()
            snippets.forEach { snippetsJson.put(BackupFormat.snippetToJson(it)) }
            putJson(zip, BackupFormat.SNIPPETS, snippetsJson.toString())

            val clipsJson = JSONArray()
            val mediaDir = clipStore.mediaDirectory()
            for (item in clips) {
                if (item.type == ClipType.IMAGE) {
                    val name = item.mediaFileName ?: continue
                    if (!BackupFormat.isSafeFileName(name)) continue
                    val media = File(mediaDir, name)
                    if (!media.isFile) continue
                    zip.putNextEntry(ZipEntry(BackupFormat.CLIP_MEDIA_DIR + name))
                    media.inputStream().use { it.copyTo(zip) }
                    zip.closeEntry()
                }
                clipsJson.put(item.toJson())
                clipCount++
            }
            putJson(zip, BackupFormat.CLIPS, clipsJson.toString())
            putJson(zip, BackupFormat.SETTINGS, settings.toString())

            val manifest = JSONObject()
                .put("format", BackupFormat.FORMAT)
                .put("version", BackupFormat.VERSION)
                .put("createdAt", Instant.now().toString())
                .put("app", context.packageName)
                .put("appVersion", appVersion)
                .put("notes", snapshot.notes.size)
                .put("audio", audioCount)
                .put("history", history.size)
                .put("snippets", snippets.size)
                .put("clips", clipCount)
                .put("settings", settings.length())
            putJson(zip, BackupFormat.MANIFEST, manifest.toString())
        }
        return Summary(
            notes = snapshot.notes.size,
            audio = audioCount,
            history = history.size,
            snippets = snippets.size,
            clips = clipCount,
            settings = settings.length(),
        )
    }

    /** Solo WAV propios de `filesDir/notes_audio/`: jamás rutas ajenas. */
    private fun exportableAudio(path: String): File? {
        if (path.isBlank()) return null
        return try {
            val file = File(path).canonicalFile
            val root = notesAudioDir.canonicalFile
            if (file.isFile && file.parentFile == root && BackupFormat.isSafeFileName(file.name)) {
                file
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun putJson(zip: ZipOutputStream, name: String, json: String) {
        zip.putNextEntry(ZipEntry(name))
        zip.write(json.toByteArray(StandardCharsets.UTF_8))
        zip.closeEntry()
    }

    // ---------------------------------------------------------------- importar

    fun import(input: InputStream): Summary {
        val work = File(context.cacheDir, "backup_import_${UUID.randomUUID()}")
        if (!work.mkdirs()) throw BackupException(REASON_IO)
        try {
            unzip(input, work)
            val manifestFile = File(work, BackupFormat.MANIFEST)
            if (!manifestFile.isFile) throw BackupException(REASON_FORMAT)
            val manifest = try {
                JSONObject(manifestFile.readText(StandardCharsets.UTF_8))
            } catch (_: Exception) {
                throw BackupException(REASON_FORMAT)
            }
            if (manifest.optString("format") != BackupFormat.FORMAT) {
                throw BackupException(REASON_FORMAT)
            }
            val version = manifest.optInt("version", 0)
            if (version < 1) throw BackupException(REASON_FORMAT)
            if (version > BackupFormat.VERSION) throw BackupException(REASON_VERSION)

            val notes = importNotes(work)
            val history = importHistory(work)
            val snippets = importSnippets(work)
            val clips = importClips(work)
            val settings = importSettings(work)
            return Summary(
                notes = notes.added,
                notesUpdated = notes.updated,
                notesSkipped = notes.skipped,
                audio = notes.audio,
                history = history,
                snippets = snippets.added,
                snippetsSkipped = snippets.skipped,
                clips = clips,
                settings = settings,
            )
        } finally {
            work.deleteRecursively()
        }
    }

    /** Extrae solo entradas conocidas, con nombres seguros y topes de tamaño. */
    private fun unzip(input: InputStream, work: File) {
        var total = 0L
        var count = 0
        try {
            ZipInputStream(BufferedInputStream(input)).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (++count > BackupFormat.MAX_ENTRIES) throw BackupException(REASON_TOO_BIG)
                    if (entry.isDirectory) continue
                    val kind = BackupFormat.classifyEntry(entry.name) ?: continue
                    val limit = if (kind == BackupFormat.EntryKind.JSON) {
                        BackupFormat.MAX_JSON_BYTES
                    } else {
                        BackupFormat.MAX_MEDIA_BYTES
                    }
                    val dest = File(work, entry.name)
                    dest.parentFile?.mkdirs()
                    var written = 0L
                    dest.outputStream().use { out ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val read = zip.read(buffer)
                            if (read < 0) break
                            written += read
                            total += read
                            if (written > limit || total > BackupFormat.MAX_TOTAL_BYTES) {
                                throw BackupException(REASON_TOO_BIG)
                            }
                            out.write(buffer, 0, read)
                        }
                    }
                }
            }
        } catch (error: BackupException) {
            throw error
        } catch (_: Exception) {
            throw BackupException(REASON_FORMAT)
        }
        if (count == 0) throw BackupException(REASON_FORMAT)
    }

    private fun readArray(work: File, name: String): JSONArray? {
        val file = File(work, name)
        if (!file.isFile) return null
        return try {
            JSONArray(file.readText(StandardCharsets.UTF_8))
        } catch (_: Exception) {
            throw BackupException(REASON_FORMAT)
        }
    }

    private data class NotesOutcome(val added: Int, val updated: Int, val skipped: Int, val audio: Int)

    private fun importNotes(work: File): NotesOutcome {
        val array = readArray(work, BackupFormat.NOTES) ?: return NotesOutcome(0, 0, 0, 0)
        val created = ArrayList<File>()
        val incoming = ArrayList<VbNote>()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val note = BackupFormat.noteFromJson(obj) ?: continue
            val local = if (note.audioPath.isNotBlank()) {
                placeAudio(File(work, note.audioPath), created)
            } else {
                null
            }
            incoming.add(note.copy(audioPath = local?.absolutePath ?: ""))
        }
        val merge = try {
            NoteStore(context).importNotes(incoming)
        } catch (_: Exception) {
            null
        }
        if (merge == null) {
            created.forEach { it.delete() }
            throw BackupException(REASON_UNAVAILABLE)
        }
        val referenced = merge.notes.map { it.audioPath }.toHashSet()
        var audio = 0
        for (file in created) {
            if (file.absolutePath in referenced) audio++ else file.delete()
        }
        return NotesOutcome(merge.added, merge.updated, merge.skipped, audio)
    }

    /**
     * Copia un WAV del zip a `notes_audio/`. Si ya existe uno igual (mismo
     * nombre y tamaño, p. ej. al reimportar en el mismo teléfono) lo reutiliza.
     */
    private fun placeAudio(source: File, created: MutableList<File>): File? {
        if (!source.isFile) return null
        val dir = notesAudioDir
        if (!dir.isDirectory && !dir.mkdirs()) return null
        var dest = File(dir, source.name)
        if (dest.exists()) {
            if (dest.length() == source.length()) return dest
            dest = File(dir, "imp_${UUID.randomUUID().toString().take(8)}_${source.name}")
        }
        return try {
            source.copyTo(dest)
            created.add(dest)
            dest
        } catch (_: Exception) {
            dest.delete()
            null
        }
    }

    private fun importHistory(work: File): Int {
        val array = readArray(work, BackupFormat.HISTORY) ?: return 0
        val entries = (0 until array.length()).mapNotNull { array.optJSONObject(it) }
        if (entries.isEmpty()) return 0
        val repo = TranscriptionHistoryRepository(context)
        val before = repo.loadHistory().size
        if (!repo.importTranscriptions(entries)) throw BackupException(REASON_UNAVAILABLE)
        return (repo.loadHistory().size - before).coerceAtLeast(0)
    }

    private fun importSnippets(work: File): BackupFormat.SnippetMerge {
        val array = readArray(work, BackupFormat.SNIPPETS)
            ?: return BackupFormat.SnippetMerge(emptyList(), 0, 0)
        val incoming = (0 until array.length()).mapNotNull { index ->
            array.optJSONObject(index)?.let {
                BackupFormat.snippetFromJson(it, SnippetStore.MAX_CONTENIDO)
            }
        }
        val store = SnippetStore(context)
        val merge = BackupFormat.mergeSnippets(store.load(), incoming, SnippetStore.MAX_SNIPPETS)
        if (merge.added > 0) {
            store.writeAll(merge.snippets)
            prefs.edit().putBoolean(SnippetStore.KEY_SEEDED, true).commit()
        }
        return merge
    }

    private fun importClips(work: File): Int {
        val array = readArray(work, BackupFormat.CLIPS) ?: return 0
        val executor = Executors.newSingleThreadExecutor()
        val store = ClipboardStore(context, executor)
        try {
            val mediaDir = store.mediaDirectory()
            val created = ArrayList<File>()
            val incoming = ArrayList<ClipboardItem>()
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i) ?: continue
                val item = try {
                    ClipboardItem.fromJson(obj)
                } catch (_: Exception) {
                    continue
                }
                if (item.type == ClipType.IMAGE) {
                    val name = item.mediaFileName ?: continue
                    if (!BackupFormat.isSafeFileName(name)) continue
                    val source = File(work, BackupFormat.CLIP_MEDIA_DIR + name)
                    if (!source.isFile) continue
                    val dest = File(mediaDir, name)
                    if (!dest.exists()) {
                        try {
                            source.copyTo(dest)
                            created.add(dest)
                        } catch (_: Exception) {
                            dest.delete()
                            continue
                        }
                    }
                }
                incoming.add(item)
            }
            val merge = BackupFormat.mergeClips(
                store.readForBackup(),
                incoming,
                ClipboardStore.MAX_UNPINNED_ITEMS,
            )
            if (merge.added > 0) store.writeImported(merge.items)
            val kept = merge.items.mapNotNull { it.mediaFileName }.toHashSet()
            created.filter { it.name !in kept }.forEach { it.delete() }
            return merge.added
        } finally {
            executor.shutdown()
        }
    }

    private fun importSettings(work: File): Int {
        val file = File(work, BackupFormat.SETTINGS)
        if (!file.isFile) return 0
        val values = try {
            BackupFormat.decodePrefs(JSONObject(file.readText(StandardCharsets.UTF_8)))
        } catch (_: Exception) {
            throw BackupException(REASON_FORMAT)
        }
        if (values.isEmpty()) return 0
        val editor = prefs.edit()
        for ((key, value) in values) {
            @Suppress("UNCHECKED_CAST")
            when (value) {
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                is String -> editor.putString(key, value)
                is Set<*> -> editor.putStringSet(key, value as Set<String>)
            }
        }
        if (!editor.commit()) throw BackupException(REASON_IO)
        return values.size
    }

    companion object {
        const val NOTES_AUDIO_DIR = "notes_audio"
        const val REASON_FORMAT = "format"
        const val REASON_VERSION = "version"
        const val REASON_UNAVAILABLE = "unavailable"
        const val REASON_TOO_BIG = "too_big"
        const val REASON_IO = "io"
    }
}
