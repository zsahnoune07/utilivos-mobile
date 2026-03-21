package com.utilivo.utilivo_mobile

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
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
            when (call.method) {
                "configureToolRuntimeWebView" -> {
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
                "requestPinToolShortcut" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val slug = call.argument<String>("pluginSlug")?.trim().orEmpty()
                    if (slug.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val toolName =
                        call.argument<String>("toolName")?.trim()?.takeIf { it.isNotEmpty() } ?: slug
                    val sm = getSystemService(ShortcutManager::class.java)
                    if (sm == null || !sm.isRequestPinShortcutSupported) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val uri = Uri.parse("utilivo://tool/$slug?restore=1")
                    val launchIntent =
                        Intent(Intent.ACTION_VIEW, uri, this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                    val shortcut =
                        ShortcutInfo.Builder(this, "utilivo_tool_${slug.hashCode()}")
                            .setShortLabel(toolName.take(12))
                            .setLongLabel(toolName)
                            .setIcon(Icon.createWithResource(this, android.R.drawable.ic_menu_compass))
                            .setIntent(launchIntent)
                            .build()
                    result.success(sm.requestPinShortcut(shortcut, null))
                }
                else -> result.notImplemented()
            }
        }
    }
}
