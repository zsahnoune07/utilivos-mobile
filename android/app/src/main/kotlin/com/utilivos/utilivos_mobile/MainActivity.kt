package com.utilivos.utilivos_mobile

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.webkit.WebStorage
import android.webkit.WebView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

open class MainActivity : FlutterActivity() {

    companion object {
        @JvmField
        var pendingWidgetConfigureAppWidgetId: Int? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.utilivos.utilivos_mobile/runtime",
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

                    val clearWebStorage = call.argument<Boolean>("clearWebStorage") == true
                    if (clearWebStorage) {
                        WebStorage.getInstance().deleteAllData()
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
                    val uri = Uri.parse("utilivos://tool/$slug?restore=1")
                    val launchIntent =
                        Intent(Intent.ACTION_VIEW, uri, this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }
                    val shortcut =
                        ShortcutInfo.Builder(this, "utilivos_tool_${slug.hashCode()}")
                            .setShortLabel(toolName.take(12))
                            .setLongLabel(toolName)
                            .setIcon(Icon.createWithResource(this, android.R.drawable.ic_menu_compass))
                            .setIntent(launchIntent)
                            .build()
                    result.success(sm.requestPinShortcut(shortcut, null))
                }
                "showRuntimeNotification" -> {
                    val title = call.argument<String>("title")?.trim().orEmpty()
                    val body = call.argument<String>("body")?.trim().orEmpty()
                    if (title.isEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val manager = NotificationManagerCompat.from(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }
                    val channelId = "utilivos_runtime_alerts"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = NotificationChannel(
                            channelId,
                            "Tool runtime alerts",
                            NotificationManager.IMPORTANCE_DEFAULT,
                        )
                        channel.description = "Notifications raised by running tools."
                        manager.createNotificationChannel(channel)
                    }
                    val notification = NotificationCompat.Builder(this, channelId)
                        .setSmallIcon(android.R.drawable.ic_dialog_info)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                        .build()
                    manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
                    result.success(true)
                }
                "getPendingWidgetConfigureId" -> {
                    val v = pendingWidgetConfigureAppWidgetId
                    pendingWidgetConfigureAppWidgetId = null
                    result.success(v)
                }
                "completeWidgetConfigure" -> {
                    val ok = call.argument<Boolean>("success") == true
                    if (this@MainActivity !is WidgetConfigureActivity) {
                        result.error(
                            "bad_activity",
                            "completeWidgetConfigure is only valid from widget configuration.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    val appWidgetId =
                        intent.getIntExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_ID,
                            AppWidgetManager.INVALID_APPWIDGET_ID,
                        )
                    val out = Intent()
                    if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        out.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    }
                    setResult(
                        if (ok) Activity.RESULT_OK else Activity.RESULT_CANCELED,
                        out,
                    )
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
