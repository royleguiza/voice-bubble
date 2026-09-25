package com.royleguiza.voicebubblestt

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.IBinder
import java.io.File
import java.io.FileOutputStream
import java.nio.channels.FileChannel
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

internal enum class PendingEnqueueResult {
    COMMITTED,
    COMMITTED_WITH_CLEANUP_FAILURE,
    FAILED,
}

internal enum class WidgetToggleOutcome {
    START,
    STOP,
    IGNORED,
}

private enum class EvictionCleanupResult {
    DELETED,
    REGISTERED,
    FAILED,
}

class WidgetDictationService(
    private val storageContext: Context? = null,
    private val deleteFile: (File) -> Boolean = { file ->
        Files.deleteIfExists(file.toPath())
        !file.exists()
    },
) : Service() {

    companion object {
        const val ACTION_TOGGLE = "com.royleguiza.voicebubblestt.WIDGET_TOGGLE"
        const val ACTION_CANCEL = "com.royleguiza.voicebubblestt.WIDGET_CANCEL"
        const val EXTRA_WIDGET_ID = "widgetId"
        private const val CHANNEL_ID = "widget_dictation_channel"
        private const val NOTIF_ID = 2002
    }

    internal data class StoredWav(
        val path: String,
        val sweepClaim: File?,
    )

    @Volatile
    private var isRecording = false

    @Volatile
    private var isBusy = false

    private var client: SpeechToTextClient? = null
    private val mainHandler by lazy { android.os.Handler(android.os.Looper.getMainLooper()) }
    private val persistenceLock = Any()
    private var autoStopRunnable: Runnable? = null
    private var savedResetRunnable: Runnable? = null
    private var pendingResetRunnable: Runnable? = null
    private var soundPool: SoundPool? = null
    private var soundStart = 0
    private var soundStop = 0
    private var soundCancel = 0

    private fun storageContextOrSelf(): Context = storageContext ?: this

    override fun onBind(intent: Intent?): IBinder? = null

    internal fun reconcileDurableAudio() {
        val noteStore = NoteStore(storageContextOrSelf())
        noteStore.reconcileOrphanedAudio()
        noteStore.reconcilePendingAudio()
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onDestroy() {
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        savedResetRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingResetRunnable?.let { mainHandler.removeCallbacks(it) }
        autoStopRunnable = null
        savedResetRunnable = null
        pendingResetRunnable = null
        isRecording = false
        releaseMicrophone()
        releaseMicSounds()
        super.onDestroy()
    }

    /**
     * Sonidos del teclado (Ajustes → Teclado → Micrófono, opt-in con
     * flutter.kb_mic_sounds_enabled; estilos flutter.kb_mic_start_style /
     * flutter.kb_mic_stop_style, default "3"). Misma fuente que el teclado.
     */
    private fun ensureMicSounds() {
        if (soundPool != null) return
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val pool = SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(attrs)
                .build()
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val startStyle = prefs.getString("flutter.kb_mic_start_style", "3")
                ?.takeIf { it == "1" || it == "2" || it == "3" || it == "4" } ?: "3"
            val stopStyle = prefs.getString("flutter.kb_mic_stop_style", "3")
                ?.takeIf { it == "1" || it == "2" || it == "3" || it == "4" } ?: "3"
            val pkg = packageName
            soundStart = pool.load(this, resources.getIdentifier("mic_start_$startStyle", "raw", pkg), 1)
            soundStop = pool.load(this, resources.getIdentifier("mic_stop_$stopStyle", "raw", pkg), 1)
            soundCancel = pool.load(this, R.raw.mic_cancel, 1)
            soundPool = pool
        } catch (_: Exception) {
            soundPool = null
        }
    }

    private fun playMicSound(kind: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!prefs.getBoolean("flutter.kb_mic_sounds_enabled", false)) return
            ensureMicSounds()
            val id = when (kind) {
                "start" -> soundStart
                "stop" -> soundStop
                else -> soundCancel
            }
            if (id != 0) soundPool?.play(id, 1f, 1f, 1, 0, 1f)
        } catch (_: Exception) {}
    }

    private fun releaseMicSounds() {
        try {
            soundPool?.release()
        } catch (_: Exception) {}
        soundPool = null
        soundStart = 0
        soundStop = 0
        soundCancel = 0
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Widget dictado",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Grabacion desde widget" }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun notif(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder.setContentTitle("VoiceBubble")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        BackgroundWork.execute { reconcileDurableAudio() }
        val action = intent?.action
        val widgetId = intent?.getIntExtra(EXTRA_WIDGET_ID, -1) ?: -1

        when (action) {
            ACTION_TOGGLE -> {
                when (handleToggle()) {
                    WidgetToggleOutcome.STOP -> stopAndTranscribe()
                    WidgetToggleOutcome.START -> startRecording(widgetId)
                    WidgetToggleOutcome.IGNORED -> {}
                }
            }
            ACTION_CANCEL -> cancelRecording()
        }
        return START_NOT_STICKY
    }

    internal fun handleToggle(): WidgetToggleOutcome {
        if (isBusy) return WidgetToggleOutcome.IGNORED
        isBusy = true
        return if (isRecording) WidgetToggleOutcome.STOP else WidgetToggleOutcome.START
    }

    private fun cancelRecording() {
        if (!isRecording) return
        isRecording = false
        playMicSound("cancel")
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        try {
            client?.cancelRecording()
        } catch (_: Exception) {}
        client = null
        releaseMicrophone()
        updateWidgetsState("idle")
        try {
            stopForeground(true)
        } catch (_: Exception) {}
        stopSelf()
    }

    @Volatile
    internal var microphoneClaim: Long = 0L
        private set

    internal fun claimMicrophoneForDictation(): Long {
        if (isRecording) return microphoneClaim
        val claim = BackgroundWork.tryClaimMicrophone()
        microphoneClaim = claim
        return claim
    }

    internal fun releaseMicrophone() {
        val claim = microphoneClaim
        microphoneClaim = 0L
        BackgroundWork.releaseMicrophone(claim)
    }

    private fun startRecording(widgetId: Int) {
        if (isRecording) return
        updateWidgetsState("recording")
        if (claimMicrophoneForDictation() == 0L) {
            updateWidgetsState("error")
            mainHandler.postDelayed({
                updateWidgetsState("idle")
            }, 1600)
            stopSelf()
            return
        }
        val speechClient = SpeechToTextClient(this)
        client = speechClient
        if (!speechClient.hasMicPermission()) {
            releaseMicrophone()
            updateWidgetsState("error")
            mainHandler.postDelayed({
                updateWidgetsState("idle")
            }, 1600)
            stopSelf()
            return
        }
        // Foreground requerido para mic en background (Android 14+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif("Grabando..."), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIF_ID, notif("Grabando..."))
        }
        isRecording = true
        playMicSound("start")
        BackgroundWork.execute {
            val ok = try {
                speechClient.startRecording()
            } catch (_: Exception) {
                false
            }
            if (!ok) {
                BackgroundWork.postMain {
                    isRecording = false
                    isBusy = false
                    releaseMicrophone()
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
            }
        }
        // Tope igual que el teclado: MAX_SECONDS (300s). Solo corta si el
        // usuario no pausó antes; el envío lo dispara siempre el usuario.
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable { if (isRecording) stopAndTranscribe() }
        autoStopRunnable = runnable
        mainHandler.postDelayed(runnable, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun stopAndTranscribe() {
        if (!isRecording) return
        isRecording = false
        playMicSound("stop")
        updateWidgetsState("transcribing")
        val speechClient = client ?: run {
            isBusy = false
            releaseMicrophone()
            return
        }
        BackgroundWork.execute {
            val wav = try {
                speechClient.stopRecording()
            } finally {
                releaseMicrophone()
            }
            if (speechClient.isEmptyCapture(wav)) {
                BackgroundWork.postMain {
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
                return@execute
            }
            val config = speechClient.loadConfig()
            if (config.apiKey.isBlank()) {
                BackgroundWork.postMain {
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
                return@execute
            }
            speechClient.transcribe(wav, config, onDone = { text ->
                val durableSaved = synchronized(persistenceLock) {
                    if (text == null || text.isBlank()) {
                        false
                    } else {
                        saveUntitledNote(text.trim(), wav)
                    }
                }
                BackgroundWork.postMain {
                    updateWidgetsState(if (durableSaved) "saved" else "idle")
                    savedResetRunnable?.let { mainHandler.removeCallbacks(it) }
                    val runnable = Runnable {
                        updateWidgetsState("idle")
                        stopForeground(true)
                        stopSelf()
                    }
                    savedResetRunnable = runnable
                    mainHandler.postDelayed(runnable, 1200)
                }
            }, onError = { message ->
                BackgroundWork.execute {
                    val enqueueResult = if (isDeferredQueueEnabled() && !isAuthError(message)) {
                        enqueuePendingWavResult(wav)
                    } else {
                        PendingEnqueueResult.FAILED
                    }
                    val enqueued = enqueueResult != PendingEnqueueResult.FAILED
                    BackgroundWork.postMain {
                        if (enqueued) {
                            updateWidgetsState("pending")
                            pendingResetRunnable?.let { mainHandler.removeCallbacks(it) }
                            val runnable = Runnable {
                                updateWidgetsState("idle")
                                stopForeground(true)
                                stopSelf()
                            }
                            pendingResetRunnable = runnable
                            mainHandler.postDelayed(runnable, 2000)
                        } else {
                            updateWidgetsState("idle")
                            stopForeground(true)
                            stopSelf()
                        }
                    }
                }
            })
        }
    }

    private fun saveUntitledNote(text: String, wav: ByteArray): Boolean {
        val stored = writeWavFile(
            "notes_audio",
            "${UUID.randomUUID()}.wav",
            wav,
            true,
        ) ?: return false
        val result = NoteStore(storageContextOrSelf()).addUntitledNote(text, stored.path)
        if (result != NoteSaveResult.SAVED) {
            try {
                stored.sweepClaim?.delete()
            } catch (_: Exception) {}
            return false
        }
        try {
            stored.sweepClaim?.delete()
        } catch (_: Exception) {}
        return true
    }

    /**
     * Cola diferida (mismo contrato que Dart `PendingNoteQueue`):
     * WAV durable en `filesDir/pending_notes/<id>.wav` + entrada
     * `{id, audioPath, createdAtMs}` al inicio de
     * `flutter.voice_notes_pending_v1`, tope 15 FIFO (descarta el más
     * viejo y su WAV). La app la transcribe con "Transcribir con nube".
     * Solo con el flag `flutter.notes_deferred_queue_enabled` en ON.
     */
    private fun isDeferredQueueEnabled(): Boolean = try {
        storageContextOrSelf()
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.notes_deferred_queue_enabled", false)
    } catch (_: Exception) {
        false
    }

    private fun isAuthError(message: String): Boolean =
        message.contains("API key", ignoreCase = true)

    private fun syncDirectory(directory: File) {
        FileChannel.open(directory.toPath(), StandardOpenOption.READ).use { channel ->
            channel.force(true)
        }
    }

    internal fun writeWavFile(
        dirName: String,
        fileName: String,
        wav: ByteArray,
        protectFromSweep: Boolean,
    ): StoredWav? {
        val directory = File(storageContextOrSelf().filesDir, dirName)
        var temporary: File? = null
        var claim: File? = null
        var published = false
        return try {
            if (!directory.isDirectory && !directory.mkdirs() && !directory.isDirectory) return null
            if (protectFromSweep) {
                val claimFile = File(directory, ".${fileName}.pending")
                claim = claimFile
                FileOutputStream(claimFile, false).use { output ->
                    output.write(1)
                    output.fd.sync()
                }
                syncDirectory(directory)
            }
            val temporaryPath = Files.createTempFile(
                directory.toPath(),
                ".$fileName.",
                ".tmp",
            )
            val temporaryFile = temporaryPath.toFile()
            temporary = temporaryFile
            FileOutputStream(temporaryFile, false).use { output ->
                output.write(wav)
                output.fd.sync()
            }
            val destination = File(directory, fileName)
            Files.move(
                temporaryFile.toPath(),
                destination.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
            syncDirectory(directory)
            if (!destination.isFile || !destination.readBytes().contentEquals(wav)) return null
            published = true
            StoredWav(destination.absolutePath, claim)
        } catch (_: Exception) {
            null
        } finally {
            val path = temporary
            if (path != null) {
                try {
                    Files.deleteIfExists(path.toPath())
                } catch (_: Exception) {}
            }
            if (!published) {
                val path = claim
                if (path != null) {
                    try {
                        Files.deleteIfExists(path.toPath())
                    } catch (_: Exception) {}
                }
            }
        }
    }

    internal fun enqueuePendingWav(wav: ByteArray): Boolean =
        enqueuePendingWavResult(wav) != PendingEnqueueResult.FAILED

    internal fun enqueuePendingWavResult(wav: ByteArray): PendingEnqueueResult {
        return synchronized(persistenceLock) {
            try {
                NoteStore.withCooperativeFileLock(
                    File(storageContextOrSelf().filesDir, NoteStore.PENDING_LOCK_FILE_NAME),
                ) {
                    enqueuePendingWavLocked(wav)
                } ?: PendingEnqueueResult.FAILED
            } catch (_: Exception) {
                PendingEnqueueResult.FAILED
            }
        }
    }

    private fun hasPendingWav(): Boolean {
        return try {
            File(storageContextOrSelf().filesDir, "pending_notes")
                .listFiles()
                ?.any { it.isFile && it.name.endsWith(".wav") } == true
        } catch (_: Exception) {
            true
        }
    }

    private fun enqueuePendingWavLocked(wav: ByteArray): PendingEnqueueResult {
        return try {
            val prefs = storageContextOrSelf()
                .getSharedPreferences(NoteStore.PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(NoteStore.PENDING_KEY, null)
            if (raw == null && hasPendingWav()) return PendingEnqueueResult.FAILED
            val id = UUID.randomUUID().toString()
            val stored = writeWavFile("pending_notes", "$id.wav", wav, true)
                ?: return PendingEnqueueResult.FAILED
            val arr = if (raw == null) JSONArray() else JSONArray(raw)
            val nowMs = System.currentTimeMillis()
            val obj = JSONObject()
                .put("id", id)
                .put("audioPath", stored.path)
                .put("createdAtMs", nowMs)
            val old = ArrayList<JSONObject>()
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: return PendingEnqueueResult.FAILED
                val id = item.opt("id") as? String
                val path = item.opt("audioPath") as? String
                val created = item.opt("createdAtMs") as? Number
                if (id.isNullOrBlank() || path.isNullOrBlank() ||
                    created == null || created.toLong() <= 0L ||
                    !File(path).isFile) {
                    return PendingEnqueueResult.FAILED
                }
                old.add(item)
            }
            val merged = JSONArray()
            merged.put(obj)
            for (item in old.take(NoteStore.MAX_PENDING - 1)) merged.put(item)
            val json = merged.toString()
            val saved = prefs.edit()
                .putString(NoteStore.PENDING_KEY, json)
                .commit() && prefs.getString(NoteStore.PENDING_KEY, null) == json
            if (!saved) return PendingEnqueueResult.FAILED
            var cleanupComplete = true
            for (item in old.drop(NoteStore.MAX_PENDING - 1)) {
                val victimPath = item.optString("audioPath")
                if (victimPath.isNotBlank()) {
                    val cleanup = deleteOrRegisterEvicted(File(victimPath))
                    cleanupComplete = cleanup == EvictionCleanupResult.DELETED && cleanupComplete
                }
            }
            try {
                stored.sweepClaim?.delete()
            } catch (_: Exception) {}
            refreshWidgets()
            if (cleanupComplete) {
                PendingEnqueueResult.COMMITTED
            } else {
                PendingEnqueueResult.COMMITTED_WITH_CLEANUP_FAILURE
            }
        } catch (_: Exception) {
            PendingEnqueueResult.FAILED
        }
    }

    private fun deleteOrRegisterEvicted(file: File): EvictionCleanupResult {
        if (!file.exists()) return EvictionCleanupResult.DELETED
        try {
            deleteFile(file)
        } catch (_: Exception) {}
        if (!file.exists()) return EvictionCleanupResult.DELETED
        val directory = file.parentFile ?: return EvictionCleanupResult.FAILED
        val claim = File(directory, ".${file.name}.pending")
        return try {
            FileOutputStream(claim, false).use { output ->
                output.write(1)
                output.fd.sync()
            }
            claim.setLastModified(System.currentTimeMillis())
            syncDirectory(directory)
            EvictionCleanupResult.REGISTERED
        } catch (_: Exception) {
            EvictionCleanupResult.FAILED
        }
    }

    private fun updateWidgetsState(state: String) {
        if (state != "recording" && state != "transcribing") isBusy = false
        try {
            refreshWidgets(state)
        } catch (_: Exception) {}
    }

    private fun refreshWidgets(state: String = "idle") {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val noteIds = appWidgetManager.getAppWidgetIds(
                ComponentName(this, WidgetNotesProvider::class.java),
            )
            for (id in noteIds) {
                WidgetNotesProvider.updateOneWithState(this, appWidgetManager, id, state)
            }
        } catch (_: Exception) {}
    }
}
