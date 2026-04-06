package com.utilivos.utilivos_mobile

import android.appwidget.AppWidgetManager
import android.os.Bundle

/// Hosts the same Flutter entrypoint as [MainActivity] while the user picks a tool
/// for a newly placed home screen widget (Android APPWIDGET_CONFIGURE).
class WidgetConfigureActivity : MainActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    val id =
        intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
    if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
      MainActivity.pendingWidgetConfigureAppWidgetId = id
    }
    super.onCreate(savedInstanceState)
  }
}
