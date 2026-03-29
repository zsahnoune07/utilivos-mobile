package com.utilivo.utilivo_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ToolHomeWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val slugKey = "tool_slug_$widgetId"
      val nameKey = "tool_name_$widgetId"
      val slug = widgetData.getString(slugKey, null)?.trim().orEmpty()
      val displayName = widgetData.getString(nameKey, null)?.trim().orEmpty()

      val views =
          RemoteViews(context.packageName, R.layout.widget_tool).apply {
            if (slug.isEmpty()) {
              setTextViewText(R.id.widget_tool_name, "Tap to choose tool")
              setImageViewResource(R.id.widget_tool_icon, R.mipmap.ic_launcher)
              val configureIntent =
                  Intent(context, WidgetConfigureActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                  }
              var flags = PendingIntent.FLAG_UPDATE_CURRENT
              flags = flags or PendingIntent.FLAG_IMMUTABLE
              val pending = PendingIntent.getActivity(context, widgetId, configureIntent, flags)
              setOnClickPendingIntent(R.id.widget_root, pending)
            } else {
              val title = if (displayName.isNotEmpty()) displayName else slug
              setTextViewText(R.id.widget_tool_name, title)
              setImageViewResource(R.id.widget_tool_icon, R.mipmap.ic_launcher)
              val uri =
                  Uri.parse(
                      "utilivo://tool/$slug?widget=$widgetId&name=${Uri.encode(title)}",
                  )
              val pending =
                  HomeWidgetLaunchIntent.getActivity(
                      context,
                      MainActivity::class.java,
                      uri,
                  )
              setOnClickPendingIntent(R.id.widget_root, pending)
            }
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
