package com.royleguiza.voicebubblestt

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.nio.file.attribute.FileTime
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class WidgetNotesBehaviorTest {
    @Test
    fun staleClaimIsReleasedWithoutDeletingWav() {
        val root = Files.createTempDirectory("c04-claim-").toFile()
        try {
            val preferences = MemoryPreferences()
            val json = "[]"
            File(root, NoteStore.NOTES_FILE).writeText(json, Charsets.UTF_8)
            preferences.edit().putString(NoteStore.KEY_DATA, json).commit()
            val audioDirectory = File(root, "notes_audio").apply { mkdirs() }
            val wav = File(audioDirectory, "pending.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val claim = File(audioDirectory, ".pending.wav.pending").apply { writeBytes(byteArrayOf(1)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))
            Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))

            assertTrue(NoteStore(TestContext(root, preferences)).reconcileOrphanedAudio())
            assertFalse(claim.exists())
            assertTrue(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun claimedOrphanIsCleanedOnTheFollowingAuthoritativeSweep() {
        val root = Files.createTempDirectory("c04-claim-follow-up-").toFile()
        try {
            val preferences = MemoryPreferences()
            val json = "[]"
            File(root, NoteStore.NOTES_FILE).writeText(json, Charsets.UTF_8)
            preferences.edit().putString(NoteStore.KEY_DATA, json).commit()
            val audioDirectory = File(root, "notes_audio").apply { mkdirs() }
            val wav = File(audioDirectory, "orphan.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val claim = File(audioDirectory, ".orphan.wav.pending").apply { writeBytes(byteArrayOf(1)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))
            Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))
            val store = NoteStore(TestContext(root, preferences))

            assertTrue(store.reconcileOrphanedAudio())
            assertFalse(claim.exists())
            assertTrue(wav.exists())
            assertTrue(store.reconcileOrphanedAudio())
            assertFalse(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun staleClaimIsReleasedForIndexedWav() {
        val root = Files.createTempDirectory("c04-indexed-claim-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "notes_audio").apply { mkdirs() }
            val wav = File(audioDirectory, "indexed.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val claim = File(audioDirectory, ".indexed.wav.pending").apply { writeBytes(byteArrayOf(1)) }
            val json = noteIndex(wav.absolutePath)
            File(root, NoteStore.NOTES_FILE).writeText(json, Charsets.UTF_8)
            preferences.edit().putString(NoteStore.KEY_DATA, json).commit()
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))

            assertTrue(NoteStore(TestContext(root, preferences)).reconcileOrphanedAudio())
            assertFalse(claim.exists())
            assertTrue(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun failedIndexCommitRestoresBothMirrorsAndDoesNotDeletePublishedWav() {
        val root = Files.createTempDirectory("c04-index-failure-").toFile()
        try {
            val preferences = MemoryPreferences(failNextCommit = true)
            val json = noteIndex("")
            File(root, NoteStore.NOTES_FILE).writeText(json, Charsets.UTF_8)
            preferences.seed(NoteStore.KEY_DATA, json)
            val wav = File(root, "new.wav").apply { writeBytes(byteArrayOf(4, 5, 6)) }

            val result = NoteStore(TestContext(root, preferences))
                .addUntitledNote("nueva", wav.absolutePath)

            assertEquals(NoteSaveResult.FAILED, result)
            assertEquals(json, File(root, NoteStore.NOTES_FILE).readText(Charsets.UTF_8))
            assertEquals(json, preferences.getString(NoteStore.KEY_DATA, null))
            assertTrue(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun failedPublishAfterReplacementRollsBackFileAndPrefs() {
        val root = Files.createTempDirectory("c04-publish-failure-").toFile()
        try {
            val preferences = MemoryPreferences()
            val previous = noteIndex("")
            File(root, NoteStore.NOTES_FILE).writeText(previous, Charsets.UTF_8)
            preferences.seed(NoteStore.KEY_DATA, previous)
            var firstPublish = true
            val store = NoteStore(
                TestContext(root, preferences),
                fileMirrorWriter = { context, encoded ->
                    val directory = context.filesDir
                    val temporary = File.createTempFile("publish-", ".tmp", directory)
                    temporary.writeText(encoded, Charsets.UTF_8)
                    Files.move(
                        temporary.toPath(),
                        File(directory, NoteStore.NOTES_FILE).toPath(),
                        StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING,
                    )
                    if (firstPublish) {
                        firstPublish = false
                        false
                    } else {
                        true
                    }
                },
            )

            assertEquals(NoteSaveResult.FAILED, store.addUntitledNote("nueva", "/tmp/new.wav"))
            assertEquals(previous, File(root, NoteStore.NOTES_FILE).readText(Charsets.UTF_8))
            assertEquals(previous, preferences.getString(NoteStore.KEY_DATA, null))
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun onStartCommandRunsDurableAudioSweep() {
        val root = Files.createTempDirectory("c04-lifecycle-").toFile()
        try {
            val preferences = MemoryPreferences()
            File(root, NoteStore.NOTES_FILE).writeText("[]", Charsets.UTF_8)
            preferences.seed(NoteStore.KEY_DATA, "[]")
            val audioDirectory = File(root, "notes_audio").apply { mkdirs() }
            val orphan = File(audioDirectory, "lifecycle-orphan.wav").apply {
                writeBytes(byteArrayOf(1, 2, 3))
            }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(orphan.toPath(), FileTime.fromMillis(old))
            val service = WidgetDictationService(TestContext(root, preferences))

            assertEquals(
                android.app.Service.START_NOT_STICKY,
                service.onStartCommand(null, 0, 1),
            )
            var attempts = 0
            while (orphan.exists() && attempts < 200) {
                Thread.sleep(10)
                attempts += 1
            }

            assertFalse(orphan.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun failedPreferenceCommitDoesNotMutateTheStore() {
        val preferences = MemoryPreferences(failNextCommit = true)
        preferences.seed(NoteStore.KEY_DATA, "before")

        assertFalse(preferences.edit().putString(NoteStore.KEY_DATA, "after").commit())
        assertEquals("before", preferences.getString(NoteStore.KEY_DATA, null))
    }

    @Test
    fun firstInstallationCreatesTheFirstNoteInBothMirrors() {
        val root = Files.createTempDirectory("c04-first-install-").toFile()
        try {
            val preferences = MemoryPreferences()
            val wav = File(root, "first.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val store = NoteStore(TestContext(root, preferences))

            assertEquals(NoteSaveResult.SAVED, store.addUntitledNote("primera", wav.absolutePath))
            assertTrue(File(root, NoteStore.NOTES_FILE).isFile)
            assertTrue(preferences.getString(NoteStore.KEY_DATA, null)?.contains("primera") == true)
            assertEquals(1, store.loadSnapshot().notes.size)
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun dictationServiceWritesAndEnqueuesRealDurableWav() {
        val root = Files.createTempDirectory("c04-dictation-service-").toFile()
        try {
            val preferences = MemoryPreferences()
            preferences.seed(NoteStore.PENDING_KEY, "[]")
            val service = WidgetDictationService(TestContext(root, preferences))
            val wav = byteArrayOf(1, 2, 3, 4)

            val stored = requireNotNull(
                service.writeWavFile(
                    "pending_notes",
                    "service-test.wav",
                    wav,
                    true,
                ),
            )
            assertTrue(File(stored.path).readBytes().contentEquals(wav))
            assertTrue(File(File(root, "pending_notes"), ".service-test.wav.pending").isFile)
            stored.sweepClaim?.delete()
            assertTrue(service.enqueuePendingWav(wav))
            val raw = preferences.getString(NoteStore.PENDING_KEY, null)
            assertTrue(raw != null)
            val queued = File(JSONArray(raw!!).getJSONObject(0).getString("audioPath"))
            assertTrue(queued.isFile)
            assertFalse(File(queued.parentFile, ".${queued.name}.pending").exists())
            assertFalse(File(root, NoteStore.PENDING_LOCK_FILE_NAME).exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun failedPendingEvictionPreservesAndRegistersTheVictim() {
        val root = Files.createTempDirectory("c04-eviction-failure-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val old = JSONArray()
            var victim: File? = null
            repeat(NoteStore.MAX_PENDING) { index ->
                val file = File(audioDirectory, "old-$index.wav")
                file.writeBytes(byteArrayOf(1, 2, 3))
                old.put(
                    JSONObject()
                        .put("id", "old-$index")
                        .put("audioPath", file.absolutePath)
                        .put("createdAtMs", index + 1L),
                )
                if (index == NoteStore.MAX_PENDING - 1) victim = file
            }
            preferences.seed(NoteStore.PENDING_KEY, old.toString())
            val service = WidgetDictationService(
                TestContext(root, preferences),
                deleteFile = { false },
            )

            val result = service.enqueuePendingWavResult(byteArrayOf(4, 5, 6))

            assertEquals(PendingEnqueueResult.COMMITTED_WITH_CLEANUP_FAILURE, result)
            val retained = requireNotNull(victim)
            assertTrue(retained.isFile)
            assertTrue(File(retained.parentFile, ".${retained.name}.pending").isFile)
            val merged = JSONArray(requireNotNull(preferences.getString(NoteStore.PENDING_KEY, null)))
            assertEquals(NoteStore.MAX_PENDING, merged.length())
            assertFalse((0 until merged.length()).any {
                merged.getJSONObject(it).optString("audioPath") == retained.absolutePath
            })
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun enqueueFailsClosedWhenPendingIndexIsMissingAndWavExists() {
        val root = Files.createTempDirectory("c04-enqueue-fail-closed-").toFile()
        try {
            val preferences = MemoryPreferences()
            val service = WidgetDictationService(TestContext(root, preferences))
            val wav = byteArrayOf(1, 2, 3, 4)
            val stored = requireNotNull(
                service.writeWavFile("pending_notes", "service-test.wav", wav, true),
            )
            stored.sweepClaim?.delete()

            assertFalse(service.enqueuePendingWav(wav))
            assertTrue(File(stored.path).isFile)
            assertFalse(File(root, NoteStore.PENDING_LOCK_FILE_NAME).exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun missingPendingIndexAdoptsDurableWav() {
        val root = Files.createTempDirectory("c04-pending-adopt-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val wav = File(audioDirectory, "adopt.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))

            assertTrue(NoteStore(TestContext(root, preferences)).reconcilePendingAudio())
            val raw = preferences.getString(NoteStore.PENDING_KEY, null)
            assertTrue(raw != null)
            val item = JSONArray(raw!!).getJSONObject(0)
            assertEquals(wav.canonicalPath, item.getString("audioPath"))
            assertEquals("adopt", item.getString("id"))
            assertFalse(File(audioDirectory, ".adopt.wav.pending").exists())
            assertTrue(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun missingPendingRecoveryUsesMtimeEpochAndFifoKeepsNewest() {
        val root = Files.createTempDirectory("c04-pending-fifo-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val firstTimestamp = 1_700_000_000_000L
            val files = (0 until NoteStore.MAX_PENDING + 1).map { index ->
                File(audioDirectory, "pending-$index.wav").apply {
                    writeBytes(byteArrayOf(index.toByte()))
                    Files.setLastModifiedTime(
                        toPath(),
                        FileTime.fromMillis(firstTimestamp + index),
                    )
                }
            }
            val oldest = files.first()

            assertTrue(NoteStore(TestContext(root, preferences)).reconcilePendingAudio())

            val raw = requireNotNull(preferences.getString(NoteStore.PENDING_KEY, null))
            val recovered = JSONArray(raw)
            assertEquals(NoteStore.MAX_PENDING, recovered.length())
            assertEquals("pending-15", recovered.getJSONObject(0).getString("id"))
            assertEquals(firstTimestamp + 15, recovered.getJSONObject(0).getLong("createdAtMs"))
            assertEquals("pending-14", recovered.getJSONObject(1).getString("id"))
            assertEquals(firstTimestamp + 14, recovered.getJSONObject(1).getLong("createdAtMs"))
            assertFalse((0 until recovered.length()).any {
                recovered.getJSONObject(it).optString("id") == oldest.name.removeSuffix(".wav")
            })
            assertFalse(oldest.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun nonAuthoritativePendingSweepRegistersClaimsWithoutDeletingWav() {
        for (unavailable in listOf(false, true)) {
            val root = Files.createTempDirectory("c04-pending-recovery-").toFile()
            try {
                val preferences = MemoryPreferences()
                if (!unavailable) preferences.seed(NoteStore.PENDING_KEY, "{bad")
                val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
                val wav = File(audioDirectory, "recover.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
                val claim = File(audioDirectory, ".recover.wav.pending").apply { writeBytes(byteArrayOf(1)) }
                val old = System.currentTimeMillis() - 172800000L
                Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))
                Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))

                val store = NoteStore(
                    TestContext(root, preferences, unavailablePrefs = unavailable),
                )
                assertFalse(store.reconcilePendingAudio())
                assertTrue(wav.exists())
                assertTrue(claim.exists())
            } finally {
                root.deleteRecursively()
            }
        }
    }

    @Test
    fun nonAuthoritativeNoteSweepRegistersClaimsWithoutDeletingWav() {
        for (state in listOf("missing", "corrupt", "unavailable")) {
            val root = Files.createTempDirectory("c04-note-recovery-").toFile()
            try {
                val preferences = MemoryPreferences()
                if (state == "corrupt") {
                    File(root, NoteStore.NOTES_FILE).writeText("{bad", Charsets.UTF_8)
                    preferences.seed(NoteStore.KEY_DATA, "{bad")
                }
                val audioDirectory = File(root, "notes_audio").apply { mkdirs() }
                val wav = File(audioDirectory, "recover.wav").apply { writeBytes(byteArrayOf(1, 2, 3)) }
                val old = System.currentTimeMillis() - 172800000L
                Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))

                val store = NoteStore(
                    TestContext(root, preferences, unavailablePrefs = state == "unavailable"),
                )
                assertFalse(store.reconcileOrphanedAudio())
                assertTrue(wav.exists())
                assertTrue(File(audioDirectory, ".recover.wav.pending").exists())
            } finally {
                root.deleteRecursively()
            }
        }
    }

    @Test
    fun structurallyInvalidNoteIsCorrupt() {
        val root = Files.createTempDirectory("c04-structural-").toFile()
        try {
            val preferences = MemoryPreferences()
            val invalid = JSONArray().put(
                JSONObject()
                    .put("id", "x")
                    .put("titulo", "")
                    .put("cuerpo", "x")
                    .put("createdAt", "not-a-timestamp")
                    .put("updatedAt", "not-a-timestamp"),
            ).toString()
            File(root, NoteStore.NOTES_FILE).writeText(invalid, Charsets.UTF_8)
            preferences.seed(NoteStore.KEY_DATA, invalid)

            val snapshot = NoteStore(TestContext(root, preferences)).loadSnapshot()
            assertEquals(NoteIndexState.CORRUPT, snapshot.fileState)
            assertEquals(NoteIndexState.CORRUPT, snapshot.prefsState)
            assertTrue(snapshot.notes.isEmpty())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingSnapshotRejectsIndexEntryWhenWavIsMissing() {
        val root = Files.createTempDirectory("c04-pending-missing-wav-").toFile()
        try {
            val preferences = MemoryPreferences()
            val missing = File(root, "missing.wav").absolutePath
            preferences.seed(NoteStore.PENDING_KEY, pendingIndex(missing))

            val snapshot = loadWidgetPendingSnapshot(TestContext(root, preferences))
            assertEquals(NoteIndexState.CORRUPT, snapshot.state)
            assertTrue(snapshot.items.isEmpty())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun noteStorePendingParserTreatsMissingWavAsCorrupt() {
        val root = Files.createTempDirectory("c04-note-store-pending-parser-").toFile()
        try {
            val preferences = MemoryPreferences()
            preferences.seed(NoteStore.PENDING_KEY, pendingIndex(File(root, "missing.wav").absolutePath))
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val orphan = File(audioDirectory, "orphan.wav").apply { writeBytes(byteArrayOf(1)) }

            assertFalse(NoteStore(TestContext(root, preferences)).reconcilePendingAudio())
            assertTrue(orphan.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun missingMirrorAdoptsValidDataWithoutOverwritingIt() {
        val root = Files.createTempDirectory("c04-missing-mutation-").toFile()
        try {
            val preferences = MemoryPreferences()
            val published = noteIndex("")
            preferences.seed(NoteStore.KEY_DATA, published)

            val store = NoteStore(TestContext(root, preferences))
            val snapshot = store.loadSnapshot()
            assertEquals(NoteIndexState.MISSING, snapshot.fileState)
            assertEquals(NoteIndexState.VALID, snapshot.prefsState)
            assertFalse(isAuthoritativeNoteSnapshot(snapshot))
            assertEquals(NoteSaveResult.SAVED, store.addUntitledNote("nueva", "/tmp/new.wav"))
            assertTrue(File(root, NoteStore.NOTES_FILE).isFile)
            assertTrue(preferences.getString(NoteStore.KEY_DATA, null)?.contains("nueva") == true)
            assertEquals(NoteSaveResult.SAVED, store.saveNote("existing", "editada", "texto"))
            assertTrue(store.deleteNote("existing") is NoteDeleteResult.Deleted)
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun authoritativeGateProtectsProviderAndModalForEveryNonAuthoritativeState() {
        val root = Files.createTempDirectory("c04-gate-").toFile()
        try {
            val preferences = MemoryPreferences()
            val published = noteIndex("")
            preferences.seed(NoteStore.KEY_DATA, published)
            val file = File(root, NoteStore.NOTES_FILE)

            file.writeText(published, Charsets.UTF_8)
            assertTrue(isAuthoritativeNoteSnapshot(NoteStore(TestContext(root, preferences)).loadSnapshot()))

            file.delete()
            assertFalse(isAuthoritativeNoteSnapshot(NoteStore(TestContext(root, preferences)).loadSnapshot()))

            file.writeText("{bad", Charsets.UTF_8)
            assertFalse(isAuthoritativeNoteSnapshot(NoteStore(TestContext(root, preferences)).loadSnapshot()))

            assertFalse(
                isAuthoritativeNoteSnapshot(
                    NoteStore(TestContext(root, MemoryPreferences(), unavailablePrefs = true)).loadSnapshot(),
                ),
            )
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun providerAndActivityUseProductionStateResolvers() {
        val now = "2026-09-25T10:00:00Z"
        val note = VbNote("existing", "", "body", now, now)
        val ready = NoteStoreLoad(listOf(note), NoteIndexState.VALID, NoteIndexState.VALID)
        val emptyPending = WidgetPendingSnapshot(emptyList(), NoteIndexState.EMPTY)

        assertEquals(
            WidgetNotesUiState.AVAILABLE,
            WidgetNotesProvider.resolveState(ready, emptyPending, initialized = false),
        )
        assertEquals(
            ExistingNoteUiState.READY,
            WidgetNoteEditActivity.resolveExistingNoteState(ready, note.id),
        )
        assertEquals(
            ExistingNoteUiState.NOT_FOUND,
            WidgetNoteEditActivity.resolveExistingNoteState(ready, "missing"),
        )
        for (state in listOf(
            NoteIndexState.MISSING,
            NoteIndexState.CORRUPT,
            NoteIndexState.UNAVAILABLE,
        )) {
            val unavailable = NoteStoreLoad(emptyList(), state, NoteIndexState.VALID)
            assertEquals(
                WidgetNotesUiState.SHOW_UNAVAILABLE,
                WidgetNotesProvider.resolveState(unavailable, emptyPending, initialized = false),
            )
            assertEquals(
                WidgetNotesUiState.PRESERVE,
                WidgetNotesProvider.resolveState(unavailable, emptyPending, initialized = true),
            )
            assertEquals(
                ExistingNoteUiState.UNAVAILABLE,
                WidgetNoteEditActivity.resolveExistingNoteState(unavailable, note.id),
            )
        }
        val pendingCorrupt = WidgetPendingSnapshot(emptyList(), NoteIndexState.CORRUPT)
        assertEquals(
            WidgetNotesUiState.SHOW_UNAVAILABLE,
            WidgetNotesProvider.resolveState(ready, pendingCorrupt, initialized = false),
        )
    }

    @Test
    fun pendingSnapshotKeepsMissingCorruptAndUnavailableDistinct() {
        val root = Files.createTempDirectory("c04-pending-state-").toFile()
        try {
            val missing = loadWidgetPendingSnapshot(TestContext(root, MemoryPreferences()))
            assertEquals(NoteIndexState.MISSING, missing.state)
            assertFalse(missing.available)

            val corruptPreferences = MemoryPreferences()
            corruptPreferences.seed(NoteStore.PENDING_KEY, "{bad")
            val corrupt = loadWidgetPendingSnapshot(
                TestContext(root, corruptPreferences),
            )
            assertEquals(NoteIndexState.CORRUPT, corrupt.state)
            assertFalse(corrupt.available)

            val unavailable = loadWidgetPendingSnapshot(
                TestContext(root, MemoryPreferences(), unavailablePrefs = true),
            )
            assertEquals(NoteIndexState.UNAVAILABLE, unavailable.state)
            assertFalse(unavailable.available)
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingModalParserRejectsMalformedAndMissingAudioAsUnavailable() {
        val path = "/tmp/pending-target.wav"
        val valid = "[{\"id\":\"target\",\"audioPath\":\"$path\",\"createdAtMs\":1}]"
        assertFalse(parseWidgetPending(valid, "target") { true }.unavailable)
        assertEquals("target", parseWidgetPending(valid, "target") { true }.pending?.id)
        assertTrue(parseWidgetPending("{bad", "target") { true }.unavailable)
        assertTrue(
            parseWidgetPending(
                "[{\"id\":\"target\",\"audioPath\":\"$path\"},{}]",
                "target",
            ) { true }.unavailable,
        )
        assertTrue(parseWidgetPending(valid, "target") { false }.unavailable)
        assertTrue(parseWidgetPending(null, "target") { true }.unavailable)
        assertTrue(parseWidgetPending(valid, "target", available = false) { true }.unavailable)
        assertFalse(parseWidgetPending(valid, "other") { true }.unavailable)
    }

    @Test
    fun corruptIndexBlocksNoteMutationAndPreservesPublishedFile() {
        val root = Files.createTempDirectory("c04-corrupt-mutation-").toFile()
        try {
            val preferences = MemoryPreferences()
            val published = noteIndex("")
            File(root, NoteStore.NOTES_FILE).writeText(published, Charsets.UTF_8)
            preferences.seed(NoteStore.KEY_DATA, "{bad")

            val result = NoteStore(TestContext(root, preferences))
                .addUntitledNote("nueva", "/tmp/new.wav")

            assertEquals(NoteSaveResult.UNAVAILABLE, result)
            assertEquals(published, File(root, NoteStore.NOTES_FILE).readText(Charsets.UTF_8))
            assertEquals("{bad", preferences.getString(NoteStore.KEY_DATA, null))
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun unavailablePrefsRemainUnavailableAndDoNotBecomeEmpty() {
        val root = Files.createTempDirectory("c04-unavailable-").toFile()
        try {
            val json = noteIndex("")
            File(root, NoteStore.NOTES_FILE).writeText(json, Charsets.UTF_8)
            val snapshot = NoteStore(
                TestContext(root, MemoryPreferences(), unavailablePrefs = true),
            ).loadSnapshot()

            assertEquals(NoteIndexState.VALID, snapshot.fileState)
            assertEquals(NoteIndexState.UNAVAILABLE, snapshot.prefsState)
            assertEquals(1, snapshot.notes.size)
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun heartbeatPreventsActiveLockFromBecomingStale() {
        val root = Files.createTempDirectory("c04-lock-").toFile()
        try {
            val lock = File(root, NoteStore.LOCK_FILE_NAME)
            val entered = CountDownLatch(1)
            val release = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            try {
                val holder = executor.submit<Boolean?> {
                    NoteStore.withCooperativeFileLock(
                        lockFile = lock,
                        timeoutMs = 1000L,
                        staleMs = 180L,
                    ) {
                        entered.countDown()
                        release.await(2, TimeUnit.SECONDS)
                        true
                    }
                }
                assertTrue(entered.await(1, TimeUnit.SECONDS))
                val contender = executor.submit<Boolean?> {
                    NoteStore.withCooperativeFileLock(
                        lockFile = lock,
                        timeoutMs = 120L,
                        staleMs = 180L,
                    ) { true }
                }
                assertNull(contender.get(1, TimeUnit.SECONDS))
                release.countDown()
                assertEquals(true, holder.get(1, TimeUnit.SECONDS))
                assertFalse(lock.exists())
            } finally {
                release.countDown()
                executor.shutdownNow()
            }
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun malformedStaleLockIsRecovered() {
        val root = Files.createTempDirectory("c04-malformed-lock-").toFile()
        try {
            val lock = File(root, NoteStore.LOCK_FILE_NAME)
            lock.writeText("", Charsets.UTF_8)
            val old = System.currentTimeMillis() - 60000L
            Files.setLastModifiedTime(lock.toPath(), FileTime.fromMillis(old))

            assertEquals(
                true,
                NoteStore.withCooperativeFileLock(lock, timeoutMs = 500L, staleMs = 1000L) {
                    true
                },
            )
            assertFalse(lock.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingSweepRetiresStaleClaimWithoutDeletingWav() {
        val root = Files.createTempDirectory("c04-pending-claim-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val wav = File(audioDirectory, "pending.wav").apply { writeBytes(byteArrayOf(1, 2)) }
            val claim = File(audioDirectory, ".pending.wav.pending").apply { writeBytes(byteArrayOf(1)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))
            Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))
            preferences.seed(NoteStore.PENDING_KEY, "[]")

            assertTrue(NoteStore(TestContext(root, preferences)).reconcilePendingAudio())
            assertFalse(claim.exists())
            assertTrue(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingClaimIsCleanedOnTheFollowingAuthoritativeSweep() {
        val root = Files.createTempDirectory("c04-pending-claim-follow-up-").toFile()
        try {
            val preferences = MemoryPreferences()
            preferences.seed(NoteStore.PENDING_KEY, "[]")
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val wav = File(audioDirectory, "orphan.wav").apply { writeBytes(byteArrayOf(1, 2)) }
            val claim = File(audioDirectory, ".orphan.wav.pending").apply { writeBytes(byteArrayOf(1)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(wav.toPath(), FileTime.fromMillis(old))
            Files.setLastModifiedTime(claim.toPath(), FileTime.fromMillis(old))
            val store = NoteStore(TestContext(root, preferences))

            assertTrue(store.reconcilePendingAudio())
            assertFalse(claim.exists())
            assertTrue(wav.exists())
            assertTrue(store.reconcilePendingAudio())
            assertFalse(wav.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingSweepPreservesIndexedAudioAndDeletesOnlyStaleOrphans() {
        val root = Files.createTempDirectory("c04-pending-sweep-").toFile()
        try {
            val preferences = MemoryPreferences()
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val indexed = File(audioDirectory, "indexed.wav").apply { writeBytes(byteArrayOf(1, 2)) }
            val orphan = File(audioDirectory, "orphan.wav").apply { writeBytes(byteArrayOf(3, 4)) }
            val fresh = File(audioDirectory, "fresh.wav").apply { writeBytes(byteArrayOf(5, 6)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(indexed.toPath(), FileTime.fromMillis(old))
            Files.setLastModifiedTime(orphan.toPath(), FileTime.fromMillis(old))
            preferences.seed(NoteStore.PENDING_KEY, pendingIndex(indexed.absolutePath))

            assertTrue(NoteStore(TestContext(root, preferences)).reconcilePendingAudio())
            assertTrue(indexed.exists())
            assertFalse(orphan.exists())
            assertTrue(fresh.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    @Test
    fun pendingSweepKeepsWavWhenIndexIsUnavailable() {
        val root = Files.createTempDirectory("c04-pending-unavailable-").toFile()
        try {
            val audioDirectory = File(root, "pending_notes").apply { mkdirs() }
            val orphan = File(audioDirectory, "orphan.wav").apply { writeBytes(byteArrayOf(1, 2)) }
            val old = System.currentTimeMillis() - 172800000L
            Files.setLastModifiedTime(orphan.toPath(), FileTime.fromMillis(old))

            assertFalse(
                NoteStore(
                    TestContext(root, MemoryPreferences(), unavailablePrefs = true),
                ).reconcilePendingAudio(),
            )
            assertTrue(orphan.exists())
        } finally {
            root.deleteRecursively()
        }
    }

    private fun noteIndex(audioPath: String): String {
        val now = "2026-09-25T10:00:00Z"
        val note = JSONObject()
            .put("id", "existing")
            .put("titulo", "")
            .put("cuerpo", "existing")
            .put("createdAt", now)
            .put("updatedAt", now)
        if (audioPath.isNotBlank()) note.put("audioPath", audioPath)
        return JSONArray().put(note).toString()
    }

    @Test
    fun memoryPreferencesRegistersAndUnregistersListeners() {
        val preferences = MemoryPreferences()
        var changes = 0
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
            changes += 1
        }

        preferences.registerOnSharedPreferenceChangeListener(listener)
        preferences.edit().putString("registered", "value").commit()
        preferences.unregisterOnSharedPreferenceChangeListener(listener)
        preferences.edit().putString("unregistered", "value").commit()

        assertEquals(1, changes)
    }

    private fun pendingIndex(audioPath: String): String {
        return JSONArray().put(
            JSONObject()
                .put("id", "pending")
                .put("audioPath", audioPath)
                .put("createdAtMs", 1L),
        ).toString()
    }

    private class TestContext(
        private val root: File,
        private val preferences: SharedPreferences,
        private val unavailablePrefs: Boolean = false,
        base: Context = RuntimeEnvironment.getApplication(),
    ) : ContextWrapper(base) {
        override fun getFilesDir(): File = root

        override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences {
            if (unavailablePrefs) throw IllegalStateException("prefs unavailable")
            return preferences
        }
    }

    private class MemoryPreferences(
        private var failNextCommit: Boolean = false,
    ) : SharedPreferences {
        private val values = HashMap<String, Any?>()
        private val listeners = LinkedHashSet<SharedPreferences.OnSharedPreferenceChangeListener>()

        fun seed(key: String, value: String) {
            values[key] = value
        }

        override fun getAll(): MutableMap<String, *> = values.toMutableMap()

        override fun getString(key: String?, defValue: String?): String? =
            values[key] as? String ?: defValue

        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? {
            @Suppress("UNCHECKED_CAST")
            return (values[key] as? Set<String>)?.toMutableSet() ?: defValues
        }

        override fun getInt(key: String?, defValue: Int): Int = values[key] as? Int ?: defValue

        override fun getLong(key: String?, defValue: Long): Long = values[key] as? Long ?: defValue

        override fun getFloat(key: String?, defValue: Float): Float = values[key] as? Float ?: defValue

        override fun getBoolean(key: String?, defValue: Boolean): Boolean =
            values[key] as? Boolean ?: defValue

        override fun contains(key: String?): Boolean = values.containsKey(key)

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) {
            if (listener != null) listeners.add(listener)
        }

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) {
            if (listener != null) listeners.remove(listener)
        }

        override fun edit(): SharedPreferences.Editor = MemoryEditor()

        private inner class MemoryEditor : SharedPreferences.Editor {
            private val pending = HashMap<String, Any?>()
            private val removed = HashSet<String>()
            private var clearRequested = false

            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun putStringSet(
                key: String?,
                values: MutableSet<String>?,
            ): SharedPreferences.Editor {
                pending[key!!] = values
                return this
            }

            override fun putInt(key: String?, value: Int): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun putLong(key: String?, value: Long): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun putFloat(key: String?, value: Float): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun remove(key: String?): SharedPreferences.Editor {
                removed.add(key!!)
                return this
            }

            override fun clear(): SharedPreferences.Editor {
                clearRequested = true
                removed.clear()
                return this
            }

            override fun commit(): Boolean {
                if (failNextCommit) {
                    failNextCommit = false
                    return false
                }
                val changed = LinkedHashSet<String>()
                if (clearRequested) {
                    changed.addAll(values.keys)
                    values.clear()
                }
                for (key in removed) {
                    if (values.remove(key) != null || key !in values) changed.add(key)
                }
                for ((key, value) in pending) {
                    if (values[key] != value) changed.add(key)
                    values[key] = value
                }
                for (key in changed) {
                    listeners.toList().forEach { listener ->
                        listener.onSharedPreferenceChanged(this@MemoryPreferences, key)
                    }
                }
                return true
            }

            override fun apply() {
                commit()
            }
        }
    }
}
