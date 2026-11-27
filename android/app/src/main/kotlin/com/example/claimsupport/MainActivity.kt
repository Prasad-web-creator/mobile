package com.example.claimsupport

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "policy_pal/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.arguments as? String
                if (text.isNullOrBlank()) {
                    result.error("empty", "Nothing to share", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                try {
                    startActivity(Intent.createChooser(intent, null))
                    result.success(null)
                } catch (error: ActivityNotFoundException) {
                    result.error("unavailable", "Sharing is unavailable", null)
                }
            }
    }
}
