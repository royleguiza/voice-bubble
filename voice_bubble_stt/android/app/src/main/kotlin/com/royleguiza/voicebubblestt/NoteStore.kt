package com.royleguiza.voicebubblestt

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.nio.channels.FileChannel
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.nio.file.attribute.FileTime
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONArray
import org.json.JSONObject

/**
 * Notas del widget — espejo EXACTO de Dart `NotesService._loadMerged`.
 *
 * Lee prefs `flutter.voice_notes_v1` + archivo `voice_notes.json` (el mismo
 * que Dart escribe atomico en filesDir), fusiona con dedup por id ganando
 * el mas reciente por updatedAt, ordena desc y topa en 50. Sin esta paridad
 * la app (merge) y el widget (antes solo prefs, sin dedup) podian mostrar
 * contenido distinto para la misma nota. Sin logs de contenido jamas.
 */
data class VbNote(
    val id: String,
    val titulo: String,
    val cuerpo: String,
    val createdAt: String,
    val updatedAt: String,
    val audioPath: String = "",
)

enum class NoteIndexState {
    MISSING,
    CORRUPT,
    EMPTY,
    VALID,
    UNAVAILABLE,
}

internal fun isAuthoritativeNoteState(state: NoteIndexState): Boolean {
    return state == NoteIndexState.EMPTY || state == NoteIndexState.VALID
}

internal fun isAuthoritativeNoteSnapshot(snapshot: NoteStoreLoad): Boolean {
    return isAuthoritativeNoteState(snapshot.fileState) &&
        isAuthoritativeNoteState(snapshot.prefsState)
}

data class NoteStoreLoad(
    val notes: List<VbNote>,
    val fileState: NoteIndexState,
    val prefsState: NoteIndexState,
)

enum class NoteSaveResult {
    SAVED,
    EMPTY,
    LIMIT_REACHED,
    NOT_FOUND,
    UNAVAILABLE,
    FAILED,
}

private enum class NoteMirrorWriteState {
    SAVED,
    FAILED,
    ROLLBACK_FAILED,
}

sealed class NoteDeleteResult {
    data class Deleted(val audioPaths: List<String>) : NoteDeleteResult()
    data object NotFound : NoteDeleteResult()
    data object Unavailable : NoteDeleteResult()
    data object Failed : NoteDeleteResult()
}

class NoteStore(
    private val context: Context,
    private val fileMirrorWriter: ((Context, String) -> Boolean)? = null,
) {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_DATA = "flutter.voice_notes_v1"
        const val NOTES_FILE = "voice_notes.json"
        const val LOCK_FILE_NAME = "$NOTES_FILE.lock"
        const val PENDING_KEY = "flutter.voice_notes_pending_v1"
        const val PENDING_LOCK_FILE_NAME = "$PENDING_KEY.lock"
        const val MAX_NOTES = 50
        const val MAX_PENDING = 15
        private const val LOCK_TIMEOUT_MS = 10000L
        private const val LOCK_STALE_MS = 30000L
        private const val LOCK_HEARTBEAT_MS = 5000L
        private const val LOCK_POLL_MS = 50L
        private const val AUDIO_SWEEP_GRACE_MS = 86400000L

        fun filesDirOf(context: Context): File = File(context.filesDir, NOTES_FILE)

        private fun syncDirectory(directory: File) {
            FileChannel.open(directory.toPath(), StandardOpenOption.READ).use { channel ->
                channel.force(true)
            }
        }

        private fun restoreFileMirror(
            context: Context,
            target: File,
            existed: Boolean,
            contents: String?,
        ): Boolean {
            return try {
                if (existed && contents != null) {
                    writeFileMirror(context, contents)
                } else if (!existed) {
                    val deleted = !target.exists() || target.delete()
                    if (deleted) syncDirectory(context.filesDir)
                    deleted
                } else {
                    false
                }
            } catch (_: Exception) {
                false
            }
        }

        private fun restorePrefsMirror(
            prefs: android.content.SharedPreferences,
            previous: String?,
        ): Boolean {
            return try {
                val restored = if (previous == null) {
                    prefs.edit().remove(KEY_DATA).commit()
                } else {
                    prefs.edit().putString(KEY_DATA, previous).commit()
                }
                restored && prefs.getString(KEY_DATA, null) == previous
            } catch (_: Exception) {
                false
            }
        }

        private fun writeFileMirror(context: Context, jsonArray: String): Boolean {
            val directory = context.filesDir
            val target = filesDirOf(context)
            if (!directory.isDirectory && !directory.mkdirs() && !directory.isDirectory) return false
            var temporary: File? = null
            return try {
                val path = Files.createTempFile(
                    directory.toPath(),
                    "${target.name}.",
                    ".tmp",
                )
                val temporaryFile = path.toFile()
                temporary = temporaryFile
                FileOutputStream(temporaryFile, false).use { output ->
                    output.write(jsonArray.toByteArray(StandardCharsets.UTF_8))
                    output.fd.sync()
                }
                Files.move(
                    temporaryFile.toPath(),
                    target.toPath(),
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING,
                )
                syncDirectory(directory)
                target.isFile && target.readText(StandardCharsets.UTF_8) == jsonArray
            } catch (_: Exception) {
                false
            } finally {
                val path = temporary
                if (path != null) {
                    try {
                        Files.deleteIfExists(path.toPath())
                    } catch (_: Exception) {}
                }
            }
        }

        internal fun <T> withCooperativeFileLock(
            lockFile: File,
            timeoutMs: Long = LOCK_TIMEOUT_MS,
            staleMs: Long = LOCK_STALE_MS,
            block: () -> T,
        ): T? {
            val directory = lockFile.parentFile ?: return null
            if (!directory.isDirectory && !directory.mkdirs() && !directory.isDirectory) return null
            val token = "${System.currentTimeMillis()}_${System.nanoTime()}_${UUID.randomUUID()}"
            val deadline = System.currentTimeMillis() + timeoutMs
            var acquired = false
            while (!acquired && System.currentTimeMillis() < deadline) {
                try {
                    Files.createFile(lockFile.toPath())
                    acquired = true
                    try {
                        Files.write(
                            lockFile.toPath(),
                            "$token\n${System.currentTimeMillis()}\n".toByteArray(StandardCharsets.UTF_8),
                            StandardOpenOption.WRITE,
                            StandardOpenOption.TRUNCATE_EXISTING,
                        )
                        Files.setLastModifiedTime(lockFile.toPath(), FileTime.fromMillis(System.currentTimeMillis()))
                    } catch (error: Exception) {
                        acquired = false
                        try {
                            Files.deleteIfExists(lockFile.toPath())
                        } catch (_: Exception) {}
                        throw error
                    }
                } catch (_: java.nio.file.FileAlreadyExistsException) {
                    var stale = false
                    try {
                        if (!lockFile.isFile) continue
                        val age = System.currentTimeMillis() -
                            Files.getLastModifiedTime(lockFile.toPath()).toMillis()
                        stale = age > staleMs
                    } catch (_: Exception) {}
                    if (stale) {
                        try {
                            Files.deleteIfExists(lockFile.toPath())
                        } catch (_: Exception) {}
                        continue
                    }
                    try {
                        Thread.sleep(LOCK_POLL_MS)
                    } catch (error: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return null
                    }
                } catch (_: Exception) {
                    try {
                        Thread.sleep(LOCK_POLL_MS)
                    } catch (error: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return null
                    }
                }
            }
            if (!acquired) return null
            val stopHeartbeat = AtomicBoolean(false)
            val heartbeatMs = minOf(LOCK_HEARTBEAT_MS, maxOf(1L, staleMs / 3L))
            val heartbeat = Thread {
                while (!stopHeartbeat.get()) {
                    try {
                        Thread.sleep(heartbeatMs)
                    } catch (_: InterruptedException) {
                        return@Thread
                    }
                    if (stopHeartbeat.get()) return@Thread
                    try {
                        val current = lockFile.readText(StandardCharsets.UTF_8)
                        if (current.startsWith(token)) {
                            Files.setLastModifiedTime(
                                lockFile.toPath(),
                                FileTime.fromMillis(System.currentTimeMillis()),
                            )
                        }
                    } catch (_: Exception) {}
                }
            }
            heartbeat.isDaemon = true
            heartbeat.start()
            return try {
                block()
            } finally {
                stopHeartbeat.set(true)
                heartbeat.interrupt()
                try {
                    val current = if (lockFile.exists()) {
                        lockFile.readText(StandardCharsets.UTF_8)
                    } else {
                        ""
                    }
                    if (current.startsWith(token)) Files.deleteIfExists(lockFile.toPath())
                } catch (_: Exception) {}
            }
        }
    }

    private data class RawIndexRead(
        val raw: String?,
        val available: Boolean,
    )

    private data class ParsedIndex(
        val notes: List<VbNote>,
        val state: NoteIndexState,
    )

    private data class ParsedPendingIndex(
        val audioPaths: Set<String>,
        val state: NoteIndexState,
    )

    fun load(): List<VbNote> = loadSnapshot().notes

    fun loadSnapshot(): NoteStoreLoad {
        return withStoreLock { loadSnapshotLocked() }
            ?: NoteStoreLoad(
                notes = emptyList(),
                fileState = NoteIndexState.UNAVAILABLE,
                prefsState = NoteIndexState.UNAVAILABLE,
            )
    }

    fun addUntitledNote(text: String, audioPath: String): NoteSaveResult {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return NoteSaveResult.EMPTY
        return withStoreLock {
            val snapshot = loadSnapshotLocked()
            if (!isWritable(snapshot)) return@withStoreLock NoteSaveResult.UNAVAILABLE
            if (snapshot.notes.size >= MAX_NOTES) return@withStoreLock NoteSaveResult.LIMIT_REACHED
            val now = java.time.Instant.now().toString()
            val note = VbNote(
                id = UUID.randomUUID().toString(),
                titulo = "",
                cuerpo = trimmed,
                createdAt = now,
                updatedAt = now,
                audioPath = audioPath,
            )
            val notes = ArrayList<VbNote>(MAX_NOTES)
            notes.add(note)
            for (previous in snapshot.notes) {
                if (notes.size >= MAX_NOTES) break
                notes.add(previous)
            }
            if (persistLocked(notes) == NoteMirrorWriteState.SAVED) {
                NoteSaveResult.SAVED
            } else {
                NoteSaveResult.FAILED
            }
        } ?: NoteSaveResult.UNAVAILABLE
    }

    fun saveNote(
        noteId: String?,
        titulo: String,
        cuerpo: String,
    ): NoteSaveResult {
        val title = titulo.trim()
        val body = cuerpo.trim()
        if (body.isEmpty()) return NoteSaveResult.EMPTY
        return withStoreLock {
            val snapshot = loadSnapshotLocked()
            if (!isWritable(snapshot)) return@withStoreLock NoteSaveResult.UNAVAILABLE
            val updated = snapshot.notes.toMutableList()
            if (noteId == null) {
                if (updated.size >= MAX_NOTES) return@withStoreLock NoteSaveResult.LIMIT_REACHED
                val now = java.time.Instant.now().toString()
                updated.add(
                    0,
                    VbNote(
                        id = UUID.randomUUID().toString(),
                        titulo = title,
                        cuerpo = body,
                        createdAt = now,
                        updatedAt = now,
                    ),
                )
            } else {
                val index = updated.indexOfFirst { it.id == noteId }
                if (index < 0) return@withStoreLock NoteSaveResult.NOT_FOUND
                updated[index] = updated[index].copy(
                    titulo = title,
                    cuerpo = body,
                    updatedAt = java.time.Instant.now().toString(),
                )
            }
            val limited = if (updated.size > MAX_NOTES) {
                updated.subList(0, MAX_NOTES)
            } else {
                updated
            }
            if (persistLocked(limited) == NoteMirrorWriteState.SAVED) {
                NoteSaveResult.SAVED
            } else {
                NoteSaveResult.FAILED
            }
        } ?: NoteSaveResult.UNAVAILABLE
    }

    fun deleteNote(noteId: String): NoteDeleteResult {
        return withStoreLock {
            val snapshot = loadSnapshotLocked()
            if (!isWritable(snapshot)) return@withStoreLock NoteDeleteResult.Unavailable
            val victims = snapshot.notes.filter { it.id == noteId }
            if (victims.isEmpty()) return@withStoreLock NoteDeleteResult.NotFound
            val remaining = snapshot.notes.filterNot { it.id == noteId }
            if (persistLocked(remaining) == NoteMirrorWriteState.SAVED) {
                NoteDeleteResult.Deleted(
                    victims.mapNotNull { victim ->
                        victim.audioPath.takeIf { it.isNotBlank() }
                    },
                )
            } else {
                NoteDeleteResult.Failed
            }
        } ?: NoteDeleteResult.Unavailable
    }

    fun reconcileOrphanedAudio(nowMs: Long = System.currentTimeMillis()): Boolean {
        return withStoreLock {
            val snapshot = loadSnapshotLocked()
            val authoritative = isAuthoritative(snapshot.fileState) &&
                isAuthoritative(snapshot.prefsState)
            val indexedPaths = LinkedHashSet<String>()
            var indexPathsUsable = true
            for (note in snapshot.notes) {
                if (note.audioPath.isBlank()) continue
                try {
                    indexedPaths.add(File(note.audioPath).canonicalPath)
                } catch (_: Exception) {
                    indexPathsUsable = false
                }
            }
            if (authoritative && !indexPathsUsable) return@withStoreLock false
            val audioDirectory = File(context.filesDir, "notes_audio")
            if (!audioDirectory.exists()) return@withStoreLock true
            val files = try {
                audioDirectory.listFiles()
            } catch (_: Exception) {
                return@withStoreLock false
            } ?: return@withStoreLock false
            var claimsReady = true
            for (file in files) {
                if (!file.isFile || !file.name.endsWith(".wav")) continue
                val claim = File(audioDirectory, ".${file.name}.pending")
                if (!authoritative) {
                    if (!ensureSweepClaim(claim)) claimsReady = false
                    continue
                }
                val path = try {
                    file.canonicalPath
                } catch (_: Exception) {
                    return@withStoreLock false
                }
                if (path in indexedPaths) {
                    if (!removeSweepClaim(claim)) return@withStoreLock false
                    continue
                }
                val age = fileAge(nowMs, file)
                if (age == null) return@withStoreLock false
                if (claim.isFile) {
                    val claimAge = fileAge(nowMs, claim)
                    if (claimAge == null) return@withStoreLock false
                    if (claimAge < AUDIO_SWEEP_GRACE_MS) continue
                    if (!removeSweepClaim(claim)) return@withStoreLock false
                } else {
                    if (age < AUDIO_SWEEP_GRACE_MS) continue
                    if (!deleteSweepFile(file)) return@withStoreLock false
                }
            }
            if (!authoritative) return@withStoreLock false
            claimsReady
        } ?: false
    }

    fun reconcilePendingAudio(nowMs: Long = System.currentTimeMillis()): Boolean {
        return withPendingLock {
            val read = readPending()
            val snapshot = parsePendingIndex(read)
            val audioDirectory = File(context.filesDir, "pending_notes")
            if (!audioDirectory.exists()) return@withPendingLock true
            val files = try {
                audioDirectory.listFiles()
            } catch (_: Exception) {
                return@withPendingLock false
            } ?: return@withPendingLock false
            val wavFiles = files.filter { it.isFile && it.name.endsWith(".wav") }
            if (wavFiles.isEmpty()) return@withPendingLock true
            if (snapshot.state == NoteIndexState.MISSING && read.available) {
                return@withPendingLock recoverMissingPending(wavFiles)
            }
            val authoritative = isAuthoritative(snapshot.state)
            var claimsReady = true
            for (file in wavFiles) {
                val path = try {
                    file.canonicalPath
                } catch (_: Exception) {
                    return@withPendingLock false
                }
                val claim = File(audioDirectory, ".${file.name}.pending")
                if (!authoritative) {
                    if (!ensureSweepClaim(claim)) claimsReady = false
                    continue
                }
                if (path in snapshot.audioPaths) {
                    if (!removeSweepClaim(claim)) return@withPendingLock false
                    continue
                }
                val age = fileAge(nowMs, file)
                if (age == null) return@withPendingLock false
                if (claim.isFile) {
                    val claimAge = fileAge(nowMs, claim)
                    if (claimAge == null) return@withPendingLock false
                    if (claimAge < AUDIO_SWEEP_GRACE_MS) continue
                    if (!removeSweepClaim(claim)) return@withPendingLock false
                } else {
                    if (age < AUDIO_SWEEP_GRACE_MS) continue
                    if (!deleteSweepFile(file)) return@withPendingLock false
                }
            }
            if (!authoritative) return@withPendingLock false
            claimsReady
        } ?: false
    }

    private fun recoverMissingPending(files: List<File>): Boolean {
        val candidates = ArrayList<PendingRecovery>()
        for (file in files) {
            val claim = File(file.parentFile, ".${file.name}.pending")
            if (!ensureSweepClaim(claim)) return false
            val id = file.name.removeSuffix(".wav")
            if (id.isBlank()) return false
            val path = try {
                file.canonicalPath
            } catch (_: Exception) {
                return false
            }
            val createdAt = fileTimestamp(file) ?: return false
            candidates.add(PendingRecovery(file, id, path, createdAt))
        }
        val prepared = candidates
            .sortedWith(
                compareByDescending<PendingRecovery> { it.createdAtMs }
                    .thenBy { it.id },
            )
            .take(MAX_PENDING)
        val arr = JSONArray()
        for (item in prepared) {
            arr.put(
                JSONObject()
                    .put("id", item.id)
                    .put("audioPath", item.path)
                    .put("createdAtMs", item.createdAtMs),
            )
        }
        val json = arr.toString()
        val prefs = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        } catch (_: Exception) {
            return false
        }
        val saved = try {
            prefs.edit().putString(PENDING_KEY, json).commit() &&
                prefs.getString(PENDING_KEY, null) == json
        } catch (_: Exception) {
            false
        }
        if (!saved) return false
        val preparedSet = prepared.toSet()
        for (item in candidates) {
            val claim = File(item.file.parentFile, ".${item.file.name}.pending")
            if (item in preparedSet) {
                if (!removeSweepClaim(claim)) return false
            } else if (!deleteSweepFile(item.file)) {
                return false
            } else if (!removeSweepClaim(claim)) {
                return false
            }
        }
        return true
    }

    private data class PendingRecovery(
        val file: File,
        val id: String,
        val path: String,
        val createdAtMs: Long,
    )

    private fun fileTimestamp(file: File): Long? {
        return try {
            if (!file.isFile) return null
            Files.getLastModifiedTime(file.toPath()).toMillis().takeIf { it > 0L }
        } catch (_: Exception) {
            null
        }
    }

    private fun fileAge(nowMs: Long, file: File): Long? {
        val timestamp = fileTimestamp(file) ?: return null
        return nowMs - timestamp
    }

    private fun ensureSweepClaim(claim: File): Boolean {
        if (claim.isFile) return true
        if (claim.exists()) return false
        return try {
            FileOutputStream(claim, false).use { output ->
                output.write(1)
                output.fd.sync()
            }
            val directory = claim.parentFile ?: return false
            FileChannel.open(directory.toPath(), StandardOpenOption.READ).use { channel ->
                channel.force(true)
            }
            claim.isFile
        } catch (_: Exception) {
            false
        }
    }

    private fun removeSweepClaim(claim: File): Boolean {
        return try {
            !claim.exists() || Files.deleteIfExists(claim.toPath())
        } catch (_: Exception) {
            false
        }
    }

    private fun deleteSweepFile(file: File): Boolean {
        return try {
            Files.deleteIfExists(file.toPath())
            !file.exists()
        } catch (_: Exception) {
            false
        }
    }

    private fun <T> withPendingLock(block: () -> T): T? {
        return try {
            withCooperativeFileLock(
                File(context.filesDir, PENDING_LOCK_FILE_NAME),
                block = block,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun readPending(): RawIndexRead {
        return try {
            RawIndexRead(
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getString(PENDING_KEY, null),
                true,
            )
        } catch (_: Exception) {
            RawIndexRead(null, false)
        }
    }

    private fun parsePendingIndex(read: RawIndexRead): ParsedPendingIndex {
        if (!read.available) return ParsedPendingIndex(emptySet(), NoteIndexState.UNAVAILABLE)
        val raw = read.raw ?: return ParsedPendingIndex(emptySet(), NoteIndexState.MISSING)
        if (raw.isBlank()) return ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
        return try {
            val arr = JSONArray(raw)
            val paths = LinkedHashSet<String>()
            for (index in 0 until arr.length()) {
                val item = arr.optJSONObject(index)
                    ?: return ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
                val id = item.opt("id") as? String
                val path = item.opt("audioPath") as? String
                val created = item.opt("createdAtMs") as? Number
                if (id.isNullOrBlank() || path.isNullOrBlank() ||
                    created == null || created.toLong() <= 0L) {
                    return ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
                }
                val audio = File(path)
                if (!audio.isFile) {
                    return ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
                }
                try {
                    paths.add(audio.canonicalPath)
                } catch (_: Exception) {
                    return ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
                }
            }
            val state = if (arr.length() == 0) NoteIndexState.EMPTY else NoteIndexState.VALID
            ParsedPendingIndex(paths, state)
        } catch (_: Exception) {
            ParsedPendingIndex(emptySet(), NoteIndexState.CORRUPT)
        }
    }

    private fun <T> withStoreLock(block: () -> T): T? {
        return try {
            withCooperativeFileLock(File(context.filesDir, LOCK_FILE_NAME), block = block)
        } catch (_: Exception) {
            null
        }
    }

    private fun loadSnapshotLocked(): NoteStoreLoad {
        val prefsIndex = parse(readPrefs())
        val fileIndex = parse(readFile())
        return NoteStoreLoad(
            notes = merge(fileIndex.notes, prefsIndex.notes, true),
            fileState = fileIndex.state,
            prefsState = prefsIndex.state,
        )
    }

    private fun persistLocked(notes: List<VbNote>): NoteMirrorWriteState {
        val arr = JSONArray()
        for (note in notes) {
            val obj = JSONObject()
                .put("id", note.id)
                .put("titulo", note.titulo)
                .put("cuerpo", note.cuerpo)
                .put("createdAt", note.createdAt)
                .put("updatedAt", note.updatedAt)
            if (note.audioPath.isNotBlank()) obj.put("audioPath", note.audioPath)
            arr.put(obj)
        }
        val jsonArray = arr.toString()
        val target = filesDirOf(context)
        val existed = target.exists()
        val previous = if (existed) {
            try {
                target.readText(StandardCharsets.UTF_8)
            } catch (_: Exception) {
                return NoteMirrorWriteState.FAILED
            }
        } else {
            null
        }
        val prefs = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        } catch (_: Exception) {
            return NoteMirrorWriteState.FAILED
        }
        val previousPrefs = try {
            prefs.getString(KEY_DATA, null)
        } catch (_: Exception) {
            return NoteMirrorWriteState.FAILED
        }
        val fileWritten = try {
            fileMirrorWriter?.invoke(context, jsonArray)
                ?: writeFileMirror(context, jsonArray)
        } catch (_: Exception) {
            false
        }
        if (!fileWritten) {
            val fileRestored =
                restoreFileMirror(context, target, existed, previous)
            val prefsRestored = restorePrefsMirror(prefs, previousPrefs)
            return if (fileRestored && prefsRestored) {
                NoteMirrorWriteState.FAILED
            } else {
                NoteMirrorWriteState.ROLLBACK_FAILED
            }
        }
        val published = try {
            prefs.edit().putString(KEY_DATA, jsonArray).commit() &&
                prefs.getString(KEY_DATA, null) == jsonArray
        } catch (_: Exception) {
            false
        }
        if (published) return NoteMirrorWriteState.SAVED
        val fileRestored =
            if (fileMirrorWriter == null) {
                restoreFileMirror(context, target, existed, previous)
            } else {
                restoreFileMirrorWithWriter(
                    context,
                    target,
                    existed,
                    previous,
                    fileMirrorWriter,
                )
            }
        val prefsRestored = restorePrefsMirror(prefs, previousPrefs)
        return if (prefsRestored && fileRestored) {
            NoteMirrorWriteState.FAILED
        } else {
            NoteMirrorWriteState.ROLLBACK_FAILED
        }
    }

    private fun restoreFileMirrorWithWriter(
        context: Context,
        target: File,
        existed: Boolean,
        contents: String?,
        writer: (Context, String) -> Boolean,
    ): Boolean {
        return try {
            if (existed && contents != null) {
                writer(context, contents) && target.isFile &&
                    target.readText(StandardCharsets.UTF_8) == contents
            } else if (!existed) {
                val deleted = !target.exists() || target.delete()
                if (deleted) syncDirectory(context.filesDir)
                deleted
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isWritable(snapshot: NoteStoreLoad): Boolean {
        return isAuthoritativeNoteSnapshot(snapshot) ||
            (snapshot.fileState == NoteIndexState.MISSING &&
                snapshot.prefsState == NoteIndexState.MISSING) ||
            (snapshot.fileState == NoteIndexState.MISSING &&
                isAuthoritativeNoteState(snapshot.prefsState)) ||
            (snapshot.prefsState == NoteIndexState.MISSING &&
                isAuthoritativeNoteState(snapshot.fileState))
    }

    private fun readPrefs(): RawIndexRead {
        return try {
            RawIndexRead(
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getString(KEY_DATA, null),
                true,
            )
        } catch (_: Exception) {
            RawIndexRead(null, false)
        }
    }

    private fun readFile(): RawIndexRead {
        return try {
            val file = filesDirOf(context)
            RawIndexRead(if (file.exists()) file.readText() else null, true)
        } catch (_: Exception) {
            RawIndexRead(null, false)
        }
    }

    private fun parse(read: RawIndexRead): ParsedIndex {
        if (!read.available) return ParsedIndex(emptyList(), NoteIndexState.UNAVAILABLE)
        val raw = read.raw ?: return ParsedIndex(emptyList(), NoteIndexState.MISSING)
        if (raw.isBlank()) return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<VbNote>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val id = requiredString(obj, "id", false)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val title = requiredString(obj, "titulo", true)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val body = requiredString(obj, "cuerpo", true)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val createdAt = requiredString(obj, "createdAt", false)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val updatedAt = requiredString(obj, "updatedAt", false)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val created = parseTimestamp(createdAt)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                val updated = parseTimestamp(updatedAt)
                    ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                if (updated < created) {
                    return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                }
                val audioPath = if (obj.has("audioPath") && !obj.isNull("audioPath")) {
                    requiredString(obj, "audioPath", false)
                        ?: return ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
                } else {
                    ""
                }
                out.add(
                    VbNote(
                        id = id,
                        titulo = title,
                        cuerpo = body,
                        createdAt = createdAt,
                        updatedAt = updatedAt,
                        audioPath = audioPath,
                    )
                )
            }
            val state = if (out.isEmpty()) NoteIndexState.EMPTY else NoteIndexState.VALID
            ParsedIndex(out.sortedByDescending { parseEpoch(it.updatedAt) }, state)
        } catch (_: Exception) {
            ParsedIndex(emptyList(), NoteIndexState.CORRUPT)
        }
    }

    private fun requiredString(
        obj: JSONObject,
        key: String,
        allowEmpty: Boolean,
    ): String? {
        if (!obj.has(key) || obj.isNull(key)) return null
        val value = obj.opt(key) as? String ?: return null
        return if (allowEmpty || value.isNotBlank()) value else null
    }

    private fun isAuthoritative(state: NoteIndexState): Boolean {
        return isAuthoritativeNoteState(state)
    }

    private fun merge(
        fileNotes: List<VbNote>,
        prefsNotes: List<VbNote>,
        limited: Boolean,
    ): List<VbNote> {
        val byId = LinkedHashMap<String, VbNote>()
        for (note in fileNotes) {
            val current = byId[note.id]
            if (current == null || parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt)) {
                byId[note.id] = note
            }
        }
        for (note in prefsNotes) {
            val current = byId[note.id]
            if (current == null || parseEpoch(note.updatedAt) > parseEpoch(current.updatedAt)) {
                byId[note.id] = note
            }
        }
        val out = byId.values.sortedByDescending { parseEpoch(it.updatedAt) }
        return if (limited && out.size > MAX_NOTES) out.subList(0, MAX_NOTES) else out
    }

    private fun parseTimestamp(iso: String): Long? {
        if (iso.isBlank()) return null
        return try {
            java.time.Instant.parse(iso).toEpochMilli()
        } catch (_: Exception) {
            try {
                java.time.OffsetDateTime.parse(iso).toInstant().toEpochMilli()
            } catch (_: Exception) {
                try {
                    java.time.LocalDateTime.parse(iso)
                        .atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
                } catch (_: Exception) {
                    null
                }
            }
        }
    }

    private fun parseEpoch(iso: String): Long {
        return parseTimestamp(iso) ?: 0L
    }
}
