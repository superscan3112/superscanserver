package com.example.superscanserver

import android.content.Intent
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.superscanserver/input"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "inputText") {
                val text = call.argument<String>("text")
                if (text != null) {
                    if (!isAccessibilityServiceEnabled()) {
                        // Prompt user to enable the accessibility service
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.error("ACCESSIBILITY_SERVICE_DISABLED", "Please enable the accessibility service", null)
                    } else {
                        val intent = Intent(this, InputAccessibilityService::class.java)
                        intent.putExtra("text", text)
                        startService(intent)
                        result.success(null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Text argument was null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED, 0)
        if (accessibilityEnabled == 1) {
            val service = "${packageName}/${InputAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            if (enabledServices != null) {
                return enabledServices.split(":").contains(service)
            }
        }
        return false
    }
}