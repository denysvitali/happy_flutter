package com.example.happy_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.happy_flutter/deep_links"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialDeepLink") {
                val deepLink = getInitialDeepLink()
                if (deepLink != null) {
                    result.success(deepLink)
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle the intent that started the activity
        val deepLink = getDeepLinkFromIntent(intent)
        if (deepLink != null) {
            // Store it for Flutter to retrieve
            _initialDeepLink = deepLink
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        // Handle new intents (when app is already running)
        val deepLink = getDeepLinkFromIntent(intent)
        if (deepLink != null) {
            // Send to Flutter via method channel
            val flutterEngine = flutterEngine
            if (flutterEngine != null) {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onDeepLink", deepLink)
            }
        }
    }

    private fun getDeepLinkFromIntent(intent: Intent?): String? {
        if (intent == null) return null

        val data = intent.data
        if (data != null && data.scheme == "happy") {
            return data.toString()
        }

        return null
    }

    private fun getInitialDeepLink(): String? {
        return _initialDeepLink
    }

    companion object {
        private var _initialDeepLink: String? = null
    }
}
