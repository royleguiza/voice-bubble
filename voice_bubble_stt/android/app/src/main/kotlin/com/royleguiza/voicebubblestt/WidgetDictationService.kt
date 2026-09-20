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
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class WidgetDictationService : Service() {

    companion object {
        const val ACTION_TOGGLE = "com.royleguiza.voicebubblestt.WIDGET_TOGGLE"
        const val EXTRA_WIDGET_ID = "widgetId"
        private const val CHANNEL_ID = "widget_dictation_channel"
        private const val NOTIF_ID = 2002
    }

    private var isRecording = false
    private var client: SpeechToTextClient? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var autoStopRunnable: Runnable? = null
    private var savedResetRunnable: Runnable? = null

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
        super.onDestroy()
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

        if (action == ACTION_TOGGLE) {
            if (isRecording) {
                stopAndTranscribe()
            } else {
                startRecording(widgetId)
            }
        }
        return START_NOT_STICKY
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
        // Auto-stop a los 60s por seguridad (MAX_SECONDS 300, pero widget corta antes).
        autoStopRunnable?.let { mainHandler.removeCallbacks(it) }
        val r = Runnable { if (isRecording) stopAndTranscribe() }
        autoStopRunnable = r
        mainHandler.postDelayed(r, 60000)
    }

    private fun stopAndTranscribe() {
        if (!isRecording) return
        isRecording = false
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
            val awm = AppWidgetManager.getInstance(this)
            val ctx = this
            // Compact y Row: delegan a Provider para preservar PendingIntents
            val compactIds = awm.getAppWidgetIds(ComponentName(ctx, WidgetCompactProvider::class.java))
            for (id in compactIds) {
                WidgetCompactProvider.updateOneWithState(ctx, awm, id, state)
            }
            val rowIds = awm.getAppWidgetIds(ComponentName(ctx, WidgetRowProvider::class.java))
            for (id in rowIds) {
                WidgetRowProvider.updateOneWithState(ctx, awm, id, state)
            }
            refreshWidgets()
        } catch (_: Exception) {}
    }

    private fun refreshWidgets() {
        try {
            val awm = AppWidgetManager.getInstance(this)
            val notesIds = awm.getAppWidgetIds(ComponentName(this, WidgetNotesProvider::class.java))
            for (id in notesIds) WidgetNotesProvider.updateOne(this, awm, id)
        } catch (_: Exception) {}
    }
}
