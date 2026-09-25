package com.royleguiza.voicebubblestt

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.nio.file.FileAlreadyExistsException
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.nio.file.attribute.BasicFileAttributes
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

internal sealed class TranscriptionHistoryReadResult {
    data object Missing : TranscriptionHistoryReadResult()
    data class Content(val value: String) : TranscriptionHistoryReadResult()
    data object Corrupt : TranscriptionHistoryReadResult()
    data class Error(val cause: Throwable) : TranscriptionHistoryReadResult()
}

internal interface TranscriptionHistoryStorage {
    val historyDirectory: File
    fun readHistoryFile(): TranscriptionHistoryReadResult
    fun readFlutterStringList(): TranscriptionHistoryReadResult
    fun writeHistoryFileAtomically(contents: String)
}

internal const val HISTORY_LOCK_TIMEOUT_MS = 5000L
internal const val HISTORY_LOCK_STALE_MS = 10000L
internal const val HISTORY_LOCK_POLL_MS = 50L

internal fun acquireTranscriptionHistoryLock(
    directory: File,
    timeoutMs: Long = HISTORY_LOCK_TIMEOUT_MS,
    staleMs: Long = HISTORY_LOCK_STALE_MS,
): String? {
    try {
        directory.mkdirs()
    } catch (_: Exception) {}
    val lockFile = File(directory, TranscriptionHistoryRepository.LOCK_FILE_NAME)
    val token = "${System.currentTimeMillis()}_${System.nanoTime()}_${UUID.randomUUID()}"
    val deadline = System.currentTimeMillis() + timeoutMs
    while (System.currentTimeMillis() < deadline) {
        try {
            Files.createFile(lockFile.toPath())
            try {
                Files.write(
                    lockFile.toPath(),
                    "$token\n${System.currentTimeMillis()}\n".toByteArray(Charsets.UTF_8),
                    StandardOpenOption.WRITE,
                    StandardOpenOption.TRUNCATE_EXISTING,
                )
            } catch (_: Exception) {
                try {
                    Files.deleteIfExists(lockFile.toPath())
                } catch (_: Exception) {}
                throw IOException("lock write failed")
            }
            return token
        } catch (_: FileAlreadyExistsException) {
            var stale = false
            try {
                if (!lockFile.exists()) continue
                val age = try {
                    System.currentTimeMillis() -
                        Files.getLastModifiedTime(lockFile.toPath()).toMillis()
                } catch (_: Exception) {
                    0L
                }
                var contentAge = age
                try {
                    val lines = Files.readAllLines(lockFile.toPath(), Charsets.UTF_8)
                    if (lines.size >= 2) {
                        val stamped = lines[1].trim().toLongOrNull()
                        if (stamped != null) {
                            contentAge = System.currentTimeMillis() - stamped
                        }
                    }
                } catch (_: Exception) {}
                if (age > staleMs || contentAge > staleMs) {
                    stale = true
                }
            } catch (_: Exception) {}
            if (stale) {
                try {
                    Files.deleteIfExists(lockFile.toPath())
                } catch (_: Exception) {}
                continue
            }
            try {
                Thread.sleep(HISTORY_LOCK_POLL_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return null
            }
        } catch (_: NoSuchFileException) {
            try {
                directory.mkdirs()
            } catch (_: Exception) {}
            try {
                Thread.sleep(HISTORY_LOCK_POLL_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return null
            }
        } catch (_: Exception) {
            try {
                Thread.sleep(HISTORY_LOCK_POLL_MS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return null
            }
        }
    }
    return null
}

internal fun releaseTranscriptionHistoryLock(directory: File, token: String) {
    try {
        val lockFile = File(directory, TranscriptionHistoryRepository.LOCK_FILE_NAME)
        if (!lockFile.exists()) return
        val current = try {
            lockFile.readText(Charsets.UTF_8)
        } catch (_: Exception) {
            return
        }
        if (current.startsWith(token)) {
            try {
                Files.deleteIfExists(lockFile.toPath())
            } catch (_: Exception) {}
        }
    } catch (_: Exception) {}
}

internal fun <T> withTranscriptionHistoryFileLock(
    directory: File,
    timeoutMs: Long = HISTORY_LOCK_TIMEOUT_MS,
    staleMs: Long = HISTORY_LOCK_STALE_MS,
    block: () -> T,
): T {
    val token = acquireTranscriptionHistoryLock(directory, timeoutMs, staleMs)
        ?: throw IOException("timeout acquiring history lock")
    try {
        return block()
    } finally {
        releaseTranscriptionHistoryLock(directory, token)
    }
}

internal class FileTranscriptionHistoryStorage(
    private val directory: File,
    private val preferencesReader: () -> TranscriptionHistoryReadResult = {
        TranscriptionHistoryReadResult.Missing
    },
) : TranscriptionHistoryStorage {
    override val historyDirectory: File
        get() = directory

    private val targetFile: File
        get() = File(directory, TranscriptionHistoryRepository.FILE_NAME)

    override fun readHistoryFile(): TranscriptionHistoryReadResult {
        val path = targetFile.toPath()
        return try {
            try {
                Files.readAttributes(path, BasicFileAttributes::class.java)
            } catch (error: NoSuchFileException) {
                return TranscriptionHistoryReadResult.Missing
            }
            TranscriptionHistoryReadResult.Content(
                String(Files.readAllBytes(path), Charsets.UTF_8),
            )
        } catch (error: Exception) {
            TranscriptionHistoryReadResult.Error(error)
        }
    }

    override fun readFlutterStringList(): TranscriptionHistoryReadResult =
        preferencesReader()

    override fun writeHistoryFileAtomically(contents: String) {
        try {
            directory.mkdirs()
        } catch (_: Exception) {}
        val target = targetFile.toPath()
        var temporaryPath: Path? = null
        try {
            val path = Files.createTempFile(
                directory.toPath(),
                "${TranscriptionHistoryRepository.FILE_NAME}.",
                ".tmp",
            )
            temporaryPath = path
            Files.write(
                path,
                contents.toByteArray(Charsets.UTF_8),
                StandardOpenOption.WRITE,
                StandardOpenOption.TRUNCATE_EXISTING,
            )
            Files.move(
                path,
                target,
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (error: Exception) {
            throw IOException("No se pudo publicar el historial atómicamente", error)
        } finally {
            val path = temporaryPath
            if (path != null) {
                try {
                    Files.deleteIfExists(path)
                } catch (_: Exception) {}
            }
        }
    }
}

private class AndroidTranscriptionHistoryStorage(
    private val context: Context,
) : TranscriptionHistoryStorage {
    private val fileStorage = FileTranscriptionHistoryStorage(
        directory = context.filesDir,
        preferencesReader = {
            try {
                val value = context.getSharedPreferences(
                    TranscriptionHistoryRepository.PREFS_NAME,
                    Context.MODE_PRIVATE,
                ).getString(
                    TranscriptionHistoryRepository.SHARED_HISTORY_KEY,
                    null,
                )
                if (value == null) {
                    TranscriptionHistoryReadResult.Missing
                } else {
                    TranscriptionHistoryReadResult.Content(value)
                }
            } catch (error: Exception) {
                TranscriptionHistoryReadResult.Error(error)
            }
        },
    )

    override val historyDirectory: File
        get() = fileStorage.historyDirectory

    override fun readHistoryFile(): TranscriptionHistoryReadResult =
        fileStorage.readHistoryFile()

    override fun readFlutterStringList(): TranscriptionHistoryReadResult =
        fileStorage.readFlutterStringList()

    override fun writeHistoryFileAtomically(contents: String) {
        fileStorage.writeHistoryFileAtomically(contents)
    }
}

class TranscriptionHistoryRepository internal constructor(
    private val storage: TranscriptionHistoryStorage,
    private val legacyZone: ZoneId = ZoneId.systemDefault(),
) {
    constructor(context: Context) : this(
        AndroidTranscriptionHistoryStorage(context),
        ZoneId.systemDefault(),
    )

    companion object {
        const val FILE_NAME = "transcription_history.json"
        const val LOCK_FILE_NAME = "$FILE_NAME.lock"
        const val MAX_ITEMS = 20
        const val SHARED_HISTORY_KEY = "flutter.transcriptions"
        const val PREFS_NAME = "FlutterSharedPreferences"
    }

    private sealed class RecordsResult {
        data class Success(
            val records: List<TranscriptionHistoryRecord<JSONObject>>,
        ) : RecordsResult()

        data class Failure(val cause: Throwable) : RecordsResult()
    }

    fun loadHistory(): List<JSONObject> = try {
        withTranscriptionHistoryFileLock(
            storage.historyDirectory,
        ) {
            when (val result = loadRecords()) {
                is RecordsResult.Success -> result.records.map { it.value }
                is RecordsResult.Failure -> emptyList()
            }
        }
    } catch (_: Exception) {
        emptyList()
    }

    fun addTranscription(text: String, timestampIso: String? = null): Boolean {
        if (TranscriptionHistoryLogic.isBlankText(text)) return false
        val instant = if (timestampIso == null) {
            Instant.now()
        } else {
            TranscriptionHistoryLogic.parseTimestamp(timestampIso) ?: return false
        }
        val newEntry = JSONObject()
            .put("text", text)
            .put("timestamp", TranscriptionHistoryLogic.canonicalTimestamp(instant))
        val newRecord = recordFromJson(
            newEntry,
            TranscriptionHistorySource.MEMORY,
            0,
        ) ?: return false
        return try {
            withTranscriptionHistoryFileLock(storage.historyDirectory) {
                when (val result = loadRecords()) {
                    is RecordsResult.Failure -> false
                    is RecordsResult.Success -> {
                        val current = result.records.map { record ->
                            if (record.source == TranscriptionHistorySource.MEMORY) {
                                record.copy(sourceIndex = record.sourceIndex + 1)
                            } else {
                                record
                            }
                        }
                        val out = TranscriptionHistoryLogic.normalize(
                            listOf(newRecord) + current,
                        )
                        saveAtomic(out)
                    }
                }
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun loadRecords(): RecordsResult {
        val fileEntries = readFileEntries()
        if (fileEntries is RecordsResult.Failure) return fileEntries
        val preferencesEntries = readPreferencesEntries()
        if (preferencesEntries is RecordsResult.Failure) return preferencesEntries
        return RecordsResult.Success(
            TranscriptionHistoryLogic.mergeRecords(
                (fileEntries as RecordsResult.Success).records,
                (preferencesEntries as RecordsResult.Success).records,
            ),
        )
    }

    private fun readFileEntries(): RecordsResult {
        return when (val read = storage.readHistoryFile()) {
            TranscriptionHistoryReadResult.Missing ->
                RecordsResult.Success(emptyList())
            TranscriptionHistoryReadResult.Corrupt ->
                RecordsResult.Failure(IOException("historial corrupto"))
            is TranscriptionHistoryReadResult.Error ->
                RecordsResult.Failure(read.cause)
            is TranscriptionHistoryReadResult.Content ->
                parseObjectArray(read.value)
        }
    }

    private fun readPreferencesEntries(): RecordsResult {
        return when (val read = storage.readFlutterStringList()) {
            TranscriptionHistoryReadResult.Missing ->
                RecordsResult.Success(emptyList())
            TranscriptionHistoryReadResult.Corrupt ->
                RecordsResult.Failure(IOException("prefs corruptas"))
            is TranscriptionHistoryReadResult.Error ->
                RecordsResult.Failure(read.cause)
            is TranscriptionHistoryReadResult.Content -> {
                val json = TranscriptionHistoryLogic.decodeFlutterStringList(read.value)
                if (json == null) {
                    RecordsResult.Success(emptyList())
                } else {
                    parseStringList(json)
                }
            }
        }
    }

    private fun parseObjectArray(raw: String): RecordsResult {
        if (raw.trim().isEmpty()) return RecordsResult.Success(emptyList())
        return try {
            val array = JSONArray(raw)
            val out = ArrayList<TranscriptionHistoryRecord<JSONObject>>(array.length())
            for (index in 0 until array.length()) {
                val obj = array.optJSONObject(index) ?: continue
                val record = recordFromJson(
                    obj,
                    TranscriptionHistorySource.FILE,
                    index,
                ) ?: continue
                out.add(record)
            }
            RecordsResult.Success(out)
        } catch (error: Exception) {
            RecordsResult.Failure(IOException("historial corrupto", error))
        }
    }

    private fun parseStringList(raw: String): RecordsResult {
        if (raw.trim().isEmpty()) return RecordsResult.Success(emptyList())
        return try {
            val array = JSONArray(raw)
            val out = ArrayList<TranscriptionHistoryRecord<JSONObject>>(array.length())
            for (index in 0 until array.length()) {
                val item = array.opt(index)
                if (item !is String) continue
                val obj = try {
                    JSONObject(item)
                } catch (_: Exception) {
                    null
                } ?: continue
                val record = recordFromJson(
                    obj,
                    TranscriptionHistorySource.PREFERENCES,
                    index,
                ) ?: continue
                out.add(record)
            }
            RecordsResult.Success(out)
        } catch (error: Exception) {
            RecordsResult.Failure(IOException("prefs corruptas", error))
        }
    }

    private fun recordFromJson(
        obj: JSONObject,
        source: TranscriptionHistorySource,
        sourceIndex: Int,
    ): TranscriptionHistoryRecord<JSONObject>? {
        val text = obj.opt("text") as? String ?: return null
        if (TranscriptionHistoryLogic.isBlankText(text)) return null
        val timestamp = obj.opt("timestamp") as? String ?: return null
        val instant = TranscriptionHistoryLogic.parseHistoryTimestamp(timestamp, legacyZone)
            ?: return null
        val canonical = canonicalObject(text, instant)
        return TranscriptionHistoryRecord(canonical, text, instant, source, sourceIndex)
    }

    private fun canonicalObject(text: String, instant: Instant): JSONObject =
        JSONObject()
            .put("text", text)
            .put("timestamp", TranscriptionHistoryLogic.canonicalTimestamp(instant))

    private fun saveAtomic(items: List<JSONObject>): Boolean {
        return try {
            val array = JSONArray()
            for (item in items) {
                val text = item.opt("text") as? String ?: return false
                val timestamp = item.opt("timestamp") as? String ?: return false
                val instant = TranscriptionHistoryLogic.parseTimestamp(timestamp)
                    ?: return false
                array.put(canonicalObject(text, instant))
            }
            storage.writeHistoryFileAtomically(array.toString())
            true
        } catch (_: Exception) {
            false
        }
    }
}
