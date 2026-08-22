package com.royleguiza.voicebubblestt

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.royleguiza.voicebubblestt/floating_bubble"
    private val KEYBOARD_CHANNEL = "com.royleguiza.voicebubblestt/keyboard"
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
                            val intent = Intent(this@MainActivity, FloatingBubbleService::class.java)
                            ContextCompat.startForegroundService(this@MainActivity, intent)
                            result.success(true)
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

    override fun onDestroy() {
        FloatingBubbleService.onBubbleActionListener = null
        super.onDestroy()
    }
}
