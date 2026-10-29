# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Drift / sqlite (native)
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# Sentry (Android SDK + NDK breadcrumbs)
-keepattributes SourceFile,LineNumberTable
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Google Play Billing (in_app_purchase)
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.**

# WebView / AndroidX WebKit (webview_flutter)
-keep class androidx.webkit.** { *; }
-dontwarn androidx.webkit.**
