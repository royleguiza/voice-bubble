package com.royleguiza.voicebubblestt

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.attribute.FileTime
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class TranscriptionHistoryLogicTest {
    @Test
    fun mergesFileAndStringListEntries() {
        val fileEntries = listOf(
            record("archivo", "2026-08-23T10:00:00Z"),
            record("mismo-instante", "2026-08-23T10:00:00+00:00"),
        )
        val preferencesEntries = listOf(
            record("prefs", "2026-08-23T12:00:00+02:00"),
        )

        val merged = TranscriptionHistoryLogic.merge(fileEntries, preferencesEntries)

        assertEquals(listOf("archivo", "mismo-instante", "prefs"), merged)
    }

    @Test
    fun keepsDifferentTextsAtTheSameInstant() {
        val fileEntries = listOf(record("uno", "2026-08-23T10:00:00Z"))
        val preferencesEntries = listOf(record("dos", "2026-08-23T12:00:00+02:00"))

        val merged = TranscriptionHistoryLogic.merge(fileEntries, preferencesEntries)

        assertEquals(2, merged.size)
        assertEquals(setOf("uno", "dos"), merged.toSet())
    }

    @Test
    fun collapsesDuplicateAcrossTimezoneAndSubMicrosecondPrecision() {
        val fileEntries = listOf(
            record("duplicada", "2026-08-23T10:00:00.1234567Z"),
        )
        val preferencesEntries = listOf(
            record("duplicada", "2026-08-23T12:00:00.123456+02:00"),
        )

        val merged = TranscriptionHistoryLogic.merge(fileEntries, preferencesEntries)

        assertEquals(listOf("duplicada"), merged)
    }

    @Test
    fun rejectsNonCanonicalAndInvalidTimestamps() {
        val invalid = listOf(
            "2026-02-30T10:00:00Z",
            "2026-08-23",
            "2026-08-23T10:00:00",
            "2026-08-23T25:00:00Z",
            "2026-08-23T10:00:00+19:00",
            "9999-12-31T23:59:59-18:00",
            "0000-01-01T00:00:00+18:00",
            "2026-08-23T10:00:00Z-basura",
        )

        for (value in invalid) {
            assertNull("timestamp aceptado: $value", TranscriptionHistoryLogic.parseTimestamp(value))
        }
    }

    @Test
    fun validatesLegacyOverflowAfterUtcConversionInBothOffsetDirections() {
        val positive = ZoneId.of("+02:00")
        val negative = ZoneId.of("-02:00")

        assertEquals(
            Instant.parse("0000-01-01T02:00:00Z"),
            TranscriptionHistoryLogic.parseHistoryTimestamp(
                "0000-01-01T00:00:00",
                negative,
            ),
        )
        assertNull(
            TranscriptionHistoryLogic.parseHistoryTimestamp(
                "0000-01-01T00:00:00",
                positive,
            ),
        )
        assertEquals(
            Instant.parse("9999-12-31T21:59:59Z"),
            TranscriptionHistoryLogic.parseHistoryTimestamp(
                "9999-12-31T23:59:59",
                positive,
            ),
        )
        assertNull(
            TranscriptionHistoryLogic.parseHistoryTimestamp(
                "9999-12-31T23:59:59",
                negative,
            ),
        )
    }

    @Test
    fun acceptsLegacyLocalTimestampsOnlyInHistoryParser() {
        val raw = "2026-08-23T10:00:00.123"
        val zone = ZoneId.of("America/Argentina/Buenos_Aires")

        assertNull(TranscriptionHistoryLogic.parseTimestamp(raw))
        assertEquals(
            LocalDateTime.parse(raw).atZone(zone).toInstant(),
            TranscriptionHistoryLogic.parseHistoryTimestamp(raw, zone),
        )
    }

    @Test
    fun appliesFifoAfterMergeAndDeduplication() {
        val entries = (0..24).map { index ->
            record(
                "item-$index",
                Instant.ofEpochSecond(1_700_000_000L + index).toString(),
            )
        }

        val normalized = TranscriptionHistoryLogic.merge(
            emptyList<TranscriptionHistoryRecord<String>>(),
            entries,
        )

        assertEquals(20, normalized.size)
        assertEquals("item-24", normalized.first())
        assertEquals("item-5", normalized.last())
    }

    @Test
    fun appliesDeterministicFifoToThirtyThreeTiedEntries() {
        val entries = (0 until 33).map { index ->
            record("item-$index", "2026-08-23T10:00:00.000000Z")
        }

        val normalized = TranscriptionHistoryLogic.normalize(entries)

        assertEquals((0 until 20).map { "item-$it" }, normalized)
    }

    @Test
    fun normalizesThirtyThreeTiedEntriesAcrossAllSources() {
        val instant = TranscriptionHistoryLogic.parseTimestamp("2026-08-23T10:00:00.000000Z")
            ?: error("invalid fixture timestamp")
        val records = buildList<TranscriptionHistoryRecord<String>> {
            add(
                TranscriptionHistoryRecord(
                    "memory",
                    "memory",
                    instant,
                    TranscriptionHistorySource.MEMORY,
                    0,
                ),
            )
            for (index in 0 until 16) {
                add(
                    TranscriptionHistoryRecord(
                        "file-$index",
                        "file-$index",
                        instant,
                        TranscriptionHistorySource.FILE,
                        index,
                    ),
                )
            }
            for (index in 0 until 16) {
                add(
                    TranscriptionHistoryRecord(
                        "prefs-$index",
                        "prefs-$index",
                        instant,
                        TranscriptionHistorySource.PREFERENCES,
                        index,
                    ),
                )
            }
        }

        val normalized = TranscriptionHistoryLogic.normalize(records)

        assertEquals(
            listOf("memory") +
                (0 until 16).map { "file-$it" } +
                (0 until 3).map { "prefs-$it" },
            normalized,
        )
    }

    @Test
    fun usesTheSameUnicodeBlankRuleAsDart() {
        for (codePoint in listOf(0x001C, 0x0085, 0xFEFF, 0x0020, 0x00A0)) {
            assertTrue(
                "code point $codePoint",
                TranscriptionHistoryLogic.isBlankText(String(Character.toChars(codePoint))),
            )
        }
        assertTrue(TranscriptionHistoryLogic.isBlankText(" \u001C\u0085\uFEFF"))
        assertFalse(TranscriptionHistoryLogic.isBlankText("\u001Ctexto"))
    }

    @Test
    fun decodesOnlyTheExactJsonStringListRepresentation() {
        assertEquals(
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!",
            TranscriptionHistoryLogic.JSON_LIST_PREFIX,
        )
        val json = JSONArray()
            .put(jsonEntry("prefs", "2026-08-23T10:00:00Z").toString())
            .toString()

        assertEquals(
            json,
            TranscriptionHistoryLogic.decodeFlutterStringList(
                TranscriptionHistoryLogic.JSON_LIST_PREFIX + json,
            ),
        )
        assertNull(TranscriptionHistoryLogic.decodeFlutterStringList(json))
        assertNull(
            TranscriptionHistoryLogic.decodeFlutterStringList(
                " ${TranscriptionHistoryLogic.JSON_LIST_PREFIX}$json",
            ),
        )
        assertNull(
            TranscriptionHistoryLogic.decodeFlutterStringList(
                TranscriptionHistoryLogic.JSON_LIST_PREFIX.dropLast(1) + json,
            ),
        )
    }

    @Test
    fun repositoryReadsRealFileAndFlutterPayloadThroughProductionParsers() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val fileEntries = JSONArray()
                .put(jsonEntry("archivo", "2026-08-23T10:00:00Z"))
                .put(jsonEntry("otro", "2026-08-23T10:00:00+00:00"))
                .put(jsonEntry("duplicada", "2026-08-23T10:00:00.1234567Z"))
                .put(jsonEntry("invalida", "2026-02-30T10:00:00Z"))
            file.writeText(fileEntries.toString(), Charsets.UTF_8)
            val preferences = flutterPayload(
                jsonEntry("prefs", "2026-08-23T12:00:00+02:00").toString(),
                jsonEntry("duplicada", "2026-08-23T12:00:00.123456+02:00").toString(),
                "not-json",
            )
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, preferences),
            )

            val loaded = repository.loadHistory()

            assertEquals(
                listOf("duplicada", "archivo", "otro", "prefs"),
                loaded.map { it.getString("text") },
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryParsesLegacyLocalTimestampsInExplicitNonUtcZone() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            file.writeText(
                JSONArray()
                    .put(jsonEntry("local", "2026-08-23T09:00:00"))
                    .toString(),
                Charsets.UTF_8,
            )
            val preferences = flutterPayload(
                jsonEntry("local", "2026-08-23T12:00:00Z").toString(),
            )
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, preferences),
                legacyZone = ZoneId.of("America/Argentina/Buenos_Aires"),
            )

            val loaded = repository.loadHistory()

            assertEquals(listOf("local"), loaded.map { it.getString("text") })
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryRejectsObjectItemsAndUnicodeBlankTextInRealPayload() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val payloadJson = JSONArray()
                .put(jsonEntry("valida", "2026-08-23T10:00:00Z").toString())
                .put(jsonEntry("objeto", "2026-08-23T10:00:00Z"))
                .put(jsonEntry("\u001C", "2026-08-23T10:00:00Z").toString())
                .put(jsonEntry("\u0085", "2026-08-23T10:00:00Z").toString())
                .put(jsonEntry("\uFEFF", "2026-08-23T10:00:00Z").toString())
                .toString()
            val payload = TranscriptionHistoryLogic.JSON_LIST_PREFIX + payloadJson
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, payload),
            )

            val loaded = repository.loadHistory()

            assertEquals(listOf("valida"), loaded.map { it.getString("text") })
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryAppliesFifoToThirtyThreeTiedEntries() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val entries = JSONArray()
            for (index in 0 until 33) {
                entries.put(jsonEntry("item-$index", "2026-08-23T10:00:00.000000Z"))
            }
            file.writeText(entries.toString(), Charsets.UTF_8)
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, null),
            )

            val loaded = repository.loadHistory()

            assertEquals((0 until 20).map { "item-$it" }, loaded.map { it.getString("text") })
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryCanonicalizesPayloadBeforeReturningAndPublishing() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            file.writeText(
                JSONArray()
                    .put(jsonEntry("archivo", "2026-08-23T12:00:00.1234567+02:00"))
                    .put(jsonEntry("otro", "2026-08-23T10:00:00.123456Z"))
                    .toString(),
                Charsets.UTF_8,
            )
            val repository = TranscriptionHistoryRepository(
                fileStorage(
                    directory,
                    flutterPayload(
                        jsonEntry("prefs", "2026-08-23T12:00:00+02:00").toString(),
                    ),
                ),
            )

            assertTrue(
                repository.addTranscription(
                    "nuevo",
                    "2026-08-23T13:00:00+02:00",
                ),
            )
            val loaded = repository.loadHistory()
            assertEquals(
                listOf("nuevo", "archivo", "otro", "prefs"),
                loaded.map { it.getString("text") },
            )
            assertEquals(
                listOf(
                    "2026-08-23T11:00:00.000000Z",
                    "2026-08-23T10:00:00.123456Z",
                    "2026-08-23T10:00:00.123456Z",
                    "2026-08-23T10:00:00.000000Z",
                ),
                loaded.map { it.getString("timestamp") },
            )
            val expected = JSONArray()
                .put(canonicalEntry("nuevo", "2026-08-23T11:00:00.000000Z"))
                .put(canonicalEntry("archivo", "2026-08-23T10:00:00.123456Z"))
                .put(canonicalEntry("otro", "2026-08-23T10:00:00.123456Z"))
                .put(canonicalEntry("prefs", "2026-08-23T10:00:00.000000Z"))
            assertEquals(expected.toString(), JSONArray(file.readText(Charsets.UTF_8)).toString())
            assertFalse(file.readText(Charsets.UTF_8).contains("+02:00"))
            assertFalse(file.readText(Charsets.UTF_8).contains("1234567"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryAddReadsFileAndPreferencesBeforePublishing() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            file.writeText(
                JSONArray()
                    .put(jsonEntry("archivo", "2026-08-23T09:00:00Z"))
                    .toString(),
                Charsets.UTF_8,
            )
            val preferences = flutterPayload(
                jsonEntry("prefs", "2026-08-23T12:00:00+02:00").toString(),
            )
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, preferences),
            )

            assertTrue(
                repository.addTranscription("memoria", "2026-08-23T11:00:00Z"),
            )
            assertEquals(
                listOf("memoria", "prefs", "archivo"),
                repository.loadHistory().map { it.getString("text") },
            )
            assertEquals(
                listOf("memoria", "prefs", "archivo"),
                JSONArray(file.readText(Charsets.UTF_8)).let { array ->
                    List(array.length()) { index -> array.getJSONObject(index).getString("text") }
                },
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryAddRejectsEmptyTextWithoutChangingPublishedFile() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val original = JSONArray()
                .put(jsonEntry("prev", "2026-08-23T10:00:00Z"))
                .toString()
            file.writeText(original, Charsets.UTF_8)
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, null),
            )

            assertFalse(
                repository.addTranscription(" \u001C\u0085", "2026-08-23T11:00:00Z"),
            )
            assertEquals(original, file.readText(Charsets.UTF_8))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryReportsAtomicWriteFailureAndKeepsPublishedFile() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val original = JSONArray()
                .put(jsonEntry("prev", "2026-08-23T10:00:00Z"))
                .toString()
            file.writeText(original, Charsets.UTF_8)
            val delegate = fileStorage(directory, null)
            val repository = TranscriptionHistoryRepository(
                MoveFailureStorage(delegate, file),
            )

            assertFalse(
                repository.addTranscription("nuevo", "2026-08-23T11:00:00Z"),
            )
            assertTrue(file.isDirectory)
            assertEquals(
                "published",
                String(Files.readAllBytes(file.toPath().resolve("published")), Charsets.UTF_8),
            )
            assertTrue(
                directory.listFiles().orEmpty().none { it.name.endsWith(".tmp") },
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryDoesNotPublishWhenExistingFileReadFails() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val original = JSONArray()
                .put(jsonEntry("published", "2026-08-23T10:00:00Z"))
                .toString()
            file.writeText(original, Charsets.UTF_8)
            val repository = TranscriptionHistoryRepository(
                ReadFailingStorage(fileStorage(directory, null)),
            )

            assertFalse(
                repository.addTranscription("nuevo", "2026-08-23T11:00:00Z"),
            )
            assertEquals(original, file.readText(Charsets.UTF_8))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun productionStorageReportsReadErrorForExistingUnreadablePath() {
        val directory = Files.createTempDirectory("c02-read-error-").toFile()
        try {
            val target = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            target.mkdirs()
            val marker = target.toPath().resolve("published")
            Files.write(marker, "published".toByteArray())
            val read = fileStorage(directory, null).readHistoryFile()

            assertTrue(read is TranscriptionHistoryReadResult.Error)
            assertEquals(
                "published",
                String(Files.readAllBytes(marker), Charsets.UTF_8),
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryAddCollapsesDuplicateBeforeFifoCut() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val base = Instant.ofEpochSecond(1_700_000_000L)
            val fileEntries = JSONArray()
            for (index in 0 until 20) {
                fileEntries.put(
                    jsonEntry(
                        "item-$index",
                        base.plusSeconds(index.toLong()).toString(),
                    ),
                )
            }
            file.writeText(fileEntries.toString(), Charsets.UTF_8)
            val preferences = flutterPayload(
                jsonEntry("item-10", base.plusSeconds(10).toString()).toString(),
            )
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, preferences),
            )

            assertTrue(
                repository.addTranscription(
                    "nueva",
                    base.plusSeconds(20).toString(),
                ),
            )
            val texts = repository.loadHistory().map { it.getString("text") }
            assertEquals(20, texts.size)
            assertEquals("nueva", texts.first())
            assertEquals(1, texts.count { it == "item-10" })
            assertEquals("item-1", texts.last())
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun repositoryAddMergesMemoryFilePreferencesWithThirtyThreeTiedEntries() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val timestamp = "2026-08-23T10:00:00.000000Z"
            val fileEntries = JSONArray()
            for (index in 0 until 16) {
                fileEntries.put(jsonEntry("file-$index", timestamp))
            }
            file.writeText(fileEntries.toString(), Charsets.UTF_8)
            val preferenceEntries = Array(16) { index ->
                jsonEntry("prefs-$index", timestamp).toString()
            }
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, flutterPayload(*preferenceEntries)),
            )

            assertTrue(repository.addTranscription("memory", timestamp))

            val expected = listOf("memory") +
                (0 until 16).map { "file-$it" } +
                (0 until 3).map { "prefs-$it" }
            assertEquals(
                expected,
                repository.loadHistory().map { it.getString("text") },
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun concurrentAddsFromSeparateRepositoriesKeepBothEntries() {
        val directory = Files.createTempDirectory("c02-history-").toFile()
        try {
            val first = TranscriptionHistoryRepository(
                fileStorage(
                    directory,
                    flutterPayload(
                        jsonEntry("semilla", "2026-08-23T10:00:00Z").toString(),
                    ),
                ),
            )
            val second = TranscriptionHistoryRepository(
                fileStorage(
                    directory,
                    flutterPayload(
                        jsonEntry("semilla", "2026-08-23T10:00:00Z").toString(),
                    ),
                ),
            )
            val start = CyclicBarrier(2)
            val executor = Executors.newFixedThreadPool(2)
            try {
                val firstResult = executor.submit<Boolean> {
                    start.await(5, TimeUnit.SECONDS)
                    first.addTranscription("uno", "2026-08-23T10:00:01Z")
                }
                val secondResult = executor.submit<Boolean> {
                    start.await(5, TimeUnit.SECONDS)
                    second.addTranscription("dos", "2026-08-23T10:00:02Z")
                }

                assertTrue(firstResult.get(5, TimeUnit.SECONDS))
                assertTrue(secondResult.get(5, TimeUnit.SECONDS))
            } finally {
                executor.shutdownNow()
            }

            val texts = first.loadHistory().map { it.getString("text") }
            assertEquals(setOf("semilla", "uno", "dos"), texts.toSet())
            assertEquals(3, texts.size)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun productionPublisherUsesAtomicMoveAndCleansTemporaryFiles() {
        val directory = Files.createTempDirectory("c02-publisher-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val storage = fileStorage(directory, null)

            storage.writeHistoryFileAtomically("[]")

            assertEquals("[]", file.readText(Charsets.UTF_8))
            assertTrue(directory.listFiles().orEmpty().none { it.name.endsWith(".tmp") })
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun productionPublisherReportsRealMoveFailure() {
        val directory = Files.createTempDirectory("c02-publisher-failure-").toFile()
        try {
            val target = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            target.mkdirs()
            Files.write(target.toPath().resolve("published"), "published".toByteArray())
            val storage = fileStorage(directory, null)
            var failed = false

            try {
                storage.writeHistoryFileAtomically("[]")
            } catch (_: IOException) {
                failed = true
            }

            assertTrue(failed)
            assertTrue(target.isDirectory)
            assertEquals(
                "published",
                String(Files.readAllBytes(target.toPath().resolve("published")), Charsets.UTF_8),
            )
            assertTrue(directory.listFiles().orEmpty().none { it.name.endsWith(".tmp") })
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun concurrentReaderNeverSeesPartialJson() {
        val directory = Files.createTempDirectory("c02-reader-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            file.writeText(
                JSONArray()
                    .put(jsonEntry("before", "2026-08-23T10:00:00Z"))
                    .toString(),
                Charsets.UTF_8,
            )
            val storage = fileStorage(directory, null)
            val repository = TranscriptionHistoryRepository(storage)
            val start = CyclicBarrier(2)
            val readerReady = CountDownLatch(1)
            val writerDone = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            try {
                val reader = executor.submit<Int> {
                    start.await(5, TimeUnit.SECONDS)
                    var observations = 0
                    val first = storage.readHistoryFile()
                    assertTrue(first is TranscriptionHistoryReadResult.Content)
                    JSONArray((first as TranscriptionHistoryReadResult.Content).value)
                    readerReady.countDown()
                    while (writerDone.count > 0 || observations < 3) {
                        val read = storage.readHistoryFile()
                        assertTrue(read is TranscriptionHistoryReadResult.Content)
                        val array = JSONArray(
                            (read as TranscriptionHistoryReadResult.Content).value,
                        )
                        assertTrue(array.length() == 1 || array.length() == 2)
                        observations++
                    }
                    observations
                }
                val writer = executor.submit<Boolean> {
                    start.await(5, TimeUnit.SECONDS)
                    assertTrue(readerReady.await(5, TimeUnit.SECONDS))
                    try {
                        repository.addTranscription(
                            "after" + "x".repeat(512 * 1024),
                            "2026-08-23T10:00:01Z",
                        )
                    } finally {
                        writerDone.countDown()
                    }
                }

                assertTrue(writer.get(10, TimeUnit.SECONDS))
                assertTrue(reader.get(10, TimeUnit.SECONDS) >= 3)
            } finally {
                executor.shutdownNow()
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun acceptsPlusMinusFourteenAndRejectsBeyond() {
        assertTrue(
            TranscriptionHistoryLogic.parseTimestamp("2026-08-23T10:00:00+14:00") != null,
        )
        assertTrue(
            TranscriptionHistoryLogic.parseTimestamp("2026-08-23T10:00:00-14:00") != null,
        )
        assertTrue(
            TranscriptionHistoryLogic.parseTimestamp("2026-08-23T10:00:00Z") != null,
        )
        for (value in listOf(
            "2026-08-23T10:00:00+14:01",
            "2026-08-23T10:00:00-14:01",
            "2026-08-23T10:00:00+15:00",
            "2026-08-23T10:00:00-15:00",
            "2026-08-23T10:00:00+18:00",
            "2026-08-23T10:00:00+19:00",
        )) {
            assertNull("timestamp aceptado: $value", TranscriptionHistoryLogic.parseTimestamp(value))
        }
    }

    @Test
    fun rejectsDstGapAndFixesOverlapDeterministically() {
        val berlin = ZoneId.of("Europe/Berlin")
        assertNull(
            TranscriptionHistoryLogic.parseHistoryTimestamp("2026-03-29T02:30:00", berlin),
        )
        val overlap = TranscriptionHistoryLogic.parseHistoryTimestamp("2026-10-25T02:30:00", berlin)
        assertTrue(overlap != null)
        assertEquals(
            overlap,
            TranscriptionHistoryLogic.parseHistoryTimestamp("2026-10-25T02:30:00", berlin),
        )
        assertTrue(
            TranscriptionHistoryLogic.parseTimestamp("2026-03-29T01:30:00+01:00") != null,
        )
        assertTrue(
            TranscriptionHistoryLogic.parseTimestamp("2026-03-29T03:30:00+02:00") != null,
        )
    }

    @Test
    fun lockStaleIsRecovered() {
        val directory = Files.createTempDirectory("c02-lock-stale-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            file.writeText(
                JSONArray().put(jsonEntry("prev", "2026-08-23T10:00:00Z")).toString(),
                Charsets.UTF_8,
            )
            val lock = File(directory, TranscriptionHistoryRepository.LOCK_FILE_NAME)
            val staleTime = System.currentTimeMillis() - 20000L
            lock.writeText("stale-token\n$staleTime\n", Charsets.UTF_8)
            Files.setLastModifiedTime(lock.toPath(), FileTime.fromMillis(staleTime))
            val repository = TranscriptionHistoryRepository(
                fileStorage(directory, null),
            )

            assertTrue(repository.addTranscription("tras-stale", "2026-08-23T10:00:05Z"))
            assertTrue(!lock.exists() || !lock.readText(Charsets.UTF_8).startsWith("stale-token"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun lockTimeoutIsFailClosed() {
        val directory = Files.createTempDirectory("c02-lock-timeout-").toFile()
        try {
            val file = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            val original = JSONArray()
                .put(jsonEntry("prev", "2026-08-23T10:00:00Z"))
                .toString()
            file.writeText(original, Charsets.UTF_8)
            val holder = acquireTranscriptionHistoryLock(directory)
            assertTrue(holder != null)
            try {
                val second = acquireTranscriptionHistoryLock(
                    directory,
                    timeoutMs = 200L,
                    staleMs = HISTORY_LOCK_STALE_MS,
                )
                assertNull(second)
                assertEquals(original, file.readText(Charsets.UTF_8))
            } finally {
                releaseTranscriptionHistoryLock(directory, holder!!)
            }
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun productionPublisherControlsMissingDirectory() {
        val parent = Files.createTempDirectory("c02-missing-").toFile()
        try {
            val directory = File(parent, "ausente/sub")
            assertTrue(!directory.exists())
            val storage = fileStorage(directory, null)
            storage.writeHistoryFileAtomically("[]")
            val target = File(directory, TranscriptionHistoryRepository.FILE_NAME)
            assertEquals("[]", target.readText(Charsets.UTF_8))
            assertTrue(directory.listFiles().orEmpty().none { it.name.endsWith(".tmp") })
        } finally {
            parent.deleteRecursively()
        }
    }

    private fun fileStorage(
        directory: File,
        preferences: String?,
    ): FileTranscriptionHistoryStorage = FileTranscriptionHistoryStorage(directory) {
        if (preferences == null) {
            TranscriptionHistoryReadResult.Missing
        } else {
            TranscriptionHistoryReadResult.Content(preferences)
        }
    }

    private fun record(value: String, timestamp: String): TranscriptionHistoryRecord<String> {
        val instant = TranscriptionHistoryLogic.parseTimestamp(timestamp)
            ?: error("invalid fixture timestamp: $timestamp")
        return TranscriptionHistoryRecord(value, value, instant)
    }

    private fun jsonEntry(text: String, timestamp: String): JSONObject =
        JSONObject().put("text", text).put("timestamp", timestamp)

    private fun canonicalEntry(text: String, timestamp: String): JSONObject =
        JSONObject().put("text", text).put("timestamp", timestamp)

    private fun flutterPayload(vararg entries: String): String {
        val array = JSONArray()
        for (entry in entries) {
            array.put(entry)
        }
        return TranscriptionHistoryLogic.JSON_LIST_PREFIX + array.toString()
    }

    private class ReadFailingStorage(
        private val delegate: TranscriptionHistoryStorage,
    ) : TranscriptionHistoryStorage by delegate {
        override fun readHistoryFile(): TranscriptionHistoryReadResult =
            TranscriptionHistoryReadResult.Error(IOException("read failed"))
    }

    private class MoveFailureStorage(
        private val delegate: TranscriptionHistoryStorage,
        private val target: File,
    ) : TranscriptionHistoryStorage by delegate {
        private var prepared = false

        override fun writeHistoryFileAtomically(contents: String) {
            if (!prepared) {
                Files.deleteIfExists(target.toPath())
                Files.createDirectories(target.toPath())
                Files.write(target.toPath().resolve("published"), "published".toByteArray())
                prepared = true
            }
            delegate.writeHistoryFileAtomically(contents)
        }
    }
}
