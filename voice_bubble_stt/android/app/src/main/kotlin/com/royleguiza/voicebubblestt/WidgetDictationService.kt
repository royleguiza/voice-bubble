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
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class WidgetDictationService : Service() {

    companion object {
        const val ACTION_TOGGLE = "com.royleguiza.voicebubblestt.WIDGET_TOGGLE"
        const val ACTION_CANCEL = "com.royleguiza.voicebubblestt.WIDGET_CANCEL"
        const val EXTRA_WIDGET_ID = "widgetId"
        private const val CHANNEL_ID = "widget_dictation_channel"
        private const val NOTIF_ID = 2002
    }

    private var isRecording = false
    private var client: SpeechToTextClient? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var autoStopRunnable: Runnable? = null
    private var savedResetRunnable: Runnable? = null
    private var soundPool: SoundPool? = null
    private var soundStart = 0
    private var soundStop = 0
    private var soundCancel = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onDestroy() {
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        savedResetRunnable?.let { mainHandler.removeCallbacks(it) }
        autoStopRunnable = null
        savedResetRunnable = null
        isRecording = false
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
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Widget dictado",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Grabacion desde widget" }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun notif(text: String): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return b.setContentTitle("VoiceBubble")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val widgetId = intent?.getIntExtra(EXTRA_WIDGET_ID, -1) ?: -1

        when (action) {
            ACTION_TOGGLE -> {
                if (isRecording) {
                    stopAndTranscribe()
                } else {
                    startRecording(widgetId)
                }
            }
            ACTION_CANCEL -> cancelRecording()
        }
        return START_NOT_STICKY
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
        updateWidgetsState("idle")
        try {
            stopForeground(true)
        } catch (_: Exception) {}
        stopSelf()
    }

    private fun startRecording(widgetId: Int) {
        val c = SpeechToTextClient(this)
        client = c
        if (!c.hasMicPermission()) {
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
        updateWidgetsState("recording")
        BackgroundWork.execute {
            val ok = c.startRecording()
            if (!ok) {
                BackgroundWork.postMain {
                    isRecording = false
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
            }
        }
        // Tope igual que el teclado: MAX_SECONDS (300s). Solo corta si el
        // usuario no pausó antes; el envío lo dispara siempre el usuario.
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        val r = Runnable { if (isRecording) stopAndTranscribe() }
        autoStopRunnable = r
        mainHandler.postDelayed(r, SpeechToTextClient.MAX_SECONDS * 1000L)
    }

    private fun stopAndTranscribe() {
        if (!isRecording) return
        isRecording = false
        playMicSound("stop")
        updateWidgetsState("transcribing")
        val c = client ?: return
        BackgroundWork.execute {
            val wav = c.stopRecording()
            if (c.isEmptyCapture(wav)) {
                BackgroundWork.postMain {
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
                return@execute
            }
            val cfg = c.loadConfig()
            if (cfg.apiKey.isBlank()) {
                BackgroundWork.postMain {
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
                return@execute
            }
            c.transcribe(wav, cfg, onDone = { text ->
                BackgroundWork.postMain {
                    if (text != null && text.isNotBlank()) {
                        saveUntitledNote(text.trim())
                    }
                    updateWidgetsState("idle")
                    // Notifica save breve
                    updateWidgetsState("saved")
                    savedResetRunnable?.let { mainHandler.removeCallbacks(it) }
                    val sr = Runnable {
                        updateWidgetsState("idle")
                        stopForeground(true)
                        stopSelf()
                    }
                    savedResetRunnable = sr
                    mainHandler.postDelayed(sr, 1200)
                }
            }, onError = { _ ->
                BackgroundWork.postMain {
                    updateWidgetsState("idle")
                    stopForeground(true)
                    stopSelf()
                }
            })
        }
    }

    private fun saveUntitledNote(text: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.voice_notes_v1", null)
            val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
            val now = java.time.Instant.now().toString()
            val obj = JSONObject()
                .put("id", "${System.currentTimeMillis()}")
                .put("titulo", "")
                .put("cuerpo", text)
                .put("createdAt", now)
                .put("updatedAt", now)
            // Insertar al inicio
            val newArr = JSONArray()
            newArr.put(obj)
            for (i in 0 until arr.length()) {
                if (newArr.length() >= 50) break
                newArr.put(arr.getJSONObject(i))
            }
            prefs.edit().putString("flutter.voice_notes_v1", newArr.toString()).apply()
            // Tambien archivo atomico para NoteStore file path (opcional)
            // El Dart NotesService leera prefs, no hace falta file.
            refreshWidgets()
        } catch (_: Exception) {}
    }

    private fun updateWidgetsState(state: String) {
        try {
            refreshWidgets(state)
        } catch (_: Exception) {}
    }

    private fun refreshWidgets(state: String = "idle") {
        try {
            val awm = AppWidgetManager.getInstance(this)
            val notesIds = awm.getAppWidgetIds(ComponentName(this, WidgetNotesProvider::class.java))
            for (id in notesIds) WidgetNotesProvider.updateOneWithState(this, awm, id, state)
        } catch (_: Exception) {}
    }
}
