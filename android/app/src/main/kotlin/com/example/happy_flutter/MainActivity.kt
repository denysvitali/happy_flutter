package com.example.happy_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.happy_flutter/deep_links"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sentry SDK is initialized during Flutter engine attach (before this
        // callback runs), so we can safely mutate the options here. The plugin
        // has already set a beforeSend for sdk-name tagging — we chain after it
        // so ANR body shrinking runs as the innermost step.
        try {
            AnrBodyShrinker.install(Sentry.getCurrentScopes().options)
        } catch (e: Throwable) {
            android.util.Log.w(
                "HappyFlutter",
                "Failed to install AnrBodyShrinker; ANR events will not be shrunk",
                e,
            )
        }

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
