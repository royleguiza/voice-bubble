package com.royleguiza.voicebubblestt

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQUEST_POST_NOTIFICATIONS = 2001
    }

    private val CHANNEL = "com.royleguiza.voicebubblestt/floating_bubble"
    private val KEYBOARD_CHANNEL = "com.royleguiza.voicebubblestt/keyboard"
    private val TRACKPAD_CHANNEL = "com.royleguiza.voicebubblestt/floating_trackpad"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> {
                        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else {
                            true
                        }
                        result.success(canDraw)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this@MainActivity)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    }
                    "startBubble" -> {
                        try {
                            val hasMicPermission = ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!hasMicPermission) {
                                // Sin RECORD_AUDIO, un FGS tipo microphone crashea con
                                // SecurityException en Android 14+: no arrancar nunca.
                                result.error(
                                    "MIC_PERMISSION_DENIED",
                                    "VoiceBubble necesita el permiso de micrófono para iniciar la burbuja.",
                                    null
                                )
                            } else {
                                ensurePostNotificationsPermission()
                                val intent = Intent(this@MainActivity, FloatingBubbleService::class.java)
                                ContextCompat.startForegroundService(this@MainActivity, intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("START_ERROR", e.message, null)
                        }
                    }
                    "stopBubble" -> {
                        try {
                            val intent = Intent(this@MainActivity, FloatingBubbleService::class.java)
                            stopService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_ERROR", e.message, null)
                        }
                    }
                    "isBubbleRunning" -> {
                        result.success(FloatingBubbleService.isRunning)
                    }
                    "updateBubbleState" -> {
                        val state = call.argument<String>("state") ?: "idle"
                        FloatingBubbleService.updateState(state)
                        result.success(true)
                    }
                    "pushHistoryEntry" -> {
                        // Write-through Dart->nativo: la modal lee el archivo
                        // unificado, así ve lo dictado con la píldora/la app.
                        // SPK-04: Dart envía su timestamp ya persistido para
                        // identidad exacta entre ambas escrituras.
                        // I/O fuera del main (disco): la respuesta vuelve al
                        // main porque MethodChannel lo exige.
                        val text = call.argument<String>("text") ?: ""
                        val timestamp = call.argument<String>("timestamp")
                        BackgroundWork.executeWithResult(
                            block = {
                                try {
                                    TranscriptionHistoryRepository(this@MainActivity)
                                        .addTranscription(text, timestamp)
                                    true
                                } catch (_: Exception) {
                                    false
                                }
                            },
                            onResult = { ok -> result.success(ok ?: false) }
                        )
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEYBOARD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isKeyboardEnabled" -> {
                    val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
                    val enabled = imm.enabledInputMethodList.any {
                        it.packageName == packageName
                    }
                    result.success(enabled)
                }
                "isKeyboardSelected" -> {
                    val defaultIme = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.DEFAULT_INPUT_METHOD,
                    ) ?: ""
                    result.success(defaultIme.startsWith(packageName))
                }
                "openKeyboardSettings" -> {
                    val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "showInputMethodPicker" -> {
                    val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showInputMethodPicker()
                    result.success(true)
                }
                "isKeyboardRecording" -> {
                    result.success(VoiceKeyboardService.keyboardRecordingActive)
                }
                "commitText" -> {
                    val text = call.argument<String>("text") ?: ""
                    result.success(VoiceKeyboardService.commitFromExternal(text))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRACKPAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this@MainActivity)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this@MainActivity)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "isAccessibilityGranted" -> {
                    result.success(VoiceBubbleAccessibilityService.isConnected())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "openAppDetailsSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "startTrackpadBubble" -> {
                    try {
                        FloatingTrackpadService.start(this@MainActivity)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_TRACKPAD_ERROR", e.message, null)
                    }
                }
                "stopTrackpadBubble" -> {
                    try {
                        FloatingTrackpadService.stop(this@MainActivity)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_TRACKPAD_ERROR", e.message, null)
                    }
                }
                "isTrackpadBubbleRunning" -> {
                    result.success(FloatingTrackpadService.isRunning)
                }
                else -> result.notImplemented()
            }
        }

        FloatingBubbleService.onBubbleActionListener = object : FloatingBubbleService.BubbleActionListener {
            override fun onBubbleTap() {
                runOnUiThread {
                    methodChannel?.invokeMethod("onBubbleTap", null)
                }
            }

            override fun onBubbleClose() {
                runOnUiThread {
                    methodChannel?.invokeMethod("onBubbleClose", null)
                }
            }
        }
    }

    /**
     * Android 13+ pide POST_NOTIFICATIONS en runtime (fire-and-forget): la
     * burbuja funciona aunque se deniegue; solo se ocultaria su notificacion
     * de servicio en primer plano. En API < 33 no hace falta.
     */
    private fun ensurePostNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_POST_NOTIFICATIONS
            )
        }
    }

    override fun onDestroy() {
        FloatingBubbleService.onBubbleActionListener = null
        super.onDestroy()
    }
}
