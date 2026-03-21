package com.utilivo.utilivo_mobile

import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.utilivo.utilivo_mobile/runtime",
        ).setMethodCallHandler { call, result ->
            if (call.method != "configureToolRuntimeWebView") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val rawIdentifier = call.argument<Number>("webViewIdentifier")
            if (rawIdentifier == null) {
                result.error("missing_identifier", "webViewIdentifier is required.", null)
                return@setMethodCallHandler
            }

            val webView: WebView? =
                WebViewFlutterAndroidExternalApi.getWebView(
                    flutterEngine,
                    rawIdentifier.toLong(),
                )

            if (webView == null) {
                result.error("missing_webview", "Could not resolve Android WebView.", null)
                return@setMethodCallHandler
            }

            @Suppress("DEPRECATION")
            val settings = webView.settings
            settings.allowFileAccess = true
            settings.allowContentAccess = true
            settings.allowFileAccessFromFileURLs = true
            settings.allowUniversalAccessFromFileURLs = true
            result.success(null)
        }
    }
}
