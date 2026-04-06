package com.utilivos.utilivos_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class ToolHomeWidgetProvider : HomeWidgetProvider() {

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle?,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    onUpdate(
        context,
        appWidgetManager,
        intArrayOf(appWidgetId),
        HomeWidgetPlugin.getData(context),
    )
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val slugKey = "tool_slug_$widgetId"
      val nameKey = "tool_name_$widgetId"
      val iconPathKey = "tool_icon_path_$widgetId"
      val slug = widgetData.getString(slugKey, null)?.trim().orEmpty()
      val displayName = widgetData.getString(nameKey, null)?.trim().orEmpty()
      val iconPath = widgetData.getString(iconPathKey, null)?.trim().orEmpty()

      val (wDp, hDp) = ToolHomeWidgetLayout.widgetSizeDp(appWidgetManager, widgetId)
      val oneByOne = ToolHomeWidgetLayout.isOneByOne(wDp, hDp)
      val layoutId = if (oneByOne) R.layout.widget_tool_compact else R.layout.widget_tool_overlay
      val views = RemoteViews(context.packageName, layoutId)
      if (!oneByOne) {
        applyOverlayTitleStyle(context, views)
      }

      if (slug.isEmpty()) {
        if (!oneByOne) {
          views.setTextViewText(R.id.widget_tool_name, "Tap to choose tool")
        }
        bindUnconfiguredIcon(context, appWidgetManager, widgetId, views, oneByOne)
        val configureIntent =
            Intent(context, WidgetConfigureActivity::class.java).apply {
              flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
              putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        flags = flags or PendingIntent.FLAG_IMMUTABLE
        val pending = PendingIntent.getActivity(context, widgetId, configureIntent, flags)
        views.setOnClickPendingIntent(R.id.widget_root, pending)
      } else {
        val title = if (displayName.isNotEmpty()) displayName else slug
        if (!oneByOne) {
          views.setTextViewText(R.id.widget_tool_name, title)
        }
        bindConfiguredIcon(context, appWidgetManager, widgetId, views, oneByOne, iconPath)
        val uri =
            Uri.parse(
                "utilivos://tool/$slug?widget=$widgetId&name=${Uri.encode(title)}",
            )
        val pending =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                uri,
            )
        views.setOnClickPendingIntent(R.id.widget_root, pending)
      }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun bindUnconfiguredIcon(
      context: Context,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
      views: RemoteViews,
      oneByOne: Boolean,
  ) {
    val bmp = BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher) ?: return
    if (oneByOne) {
      val side = UtilivosWidgetIcons.widgetMinSidePx(context, appWidgetManager, widgetId)
      val radius = UtilivosWidgetIcons.cornerRadiusPx(context, 12f)
      val rounded = UtilivosWidgetIcons.roundedSquareBitmap(bmp, side, radius)
      views.setImageViewBitmap(R.id.widget_tool_icon, rounded)
    } else {
      views.setImageViewBitmap(R.id.widget_tool_icon, bmp)
    }
  }

  private fun bindConfiguredIcon(
      context: Context,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
      views: RemoteViews,
      oneByOne: Boolean,
      iconPath: String,
  ) {
    val bmp: Bitmap? =
        if (iconPath.isNotEmpty()) {
          try {
            BitmapFactory.decodeFile(iconPath)
          } catch (_: Exception) {
            null
          }
        } else {
          null
        }
    val source = bmp ?: BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
    if (source == null) {
      views.setImageViewResource(R.id.widget_tool_icon, R.mipmap.ic_launcher)
      return
    }
    if (oneByOne) {
      val side = UtilivosWidgetIcons.widgetMinSidePx(context, appWidgetManager, widgetId)
      val radius = UtilivosWidgetIcons.cornerRadiusPx(context, 12f)
      val rounded = UtilivosWidgetIcons.roundedSquareBitmap(source, side, radius)
      views.setImageViewBitmap(R.id.widget_tool_icon, rounded)
    } else {
      views.setImageViewBitmap(R.id.widget_tool_icon, source)
    }
  }

  private fun applyOverlayTitleStyle(context: Context, views: RemoteViews) {
    val night =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    val bg = if (night) Color.BLACK else Color.WHITE
    val fg = if (night) Color.WHITE else Color.parseColor("#FF121212")
    views.setInt(R.id.widget_tool_name, "setTextColor", fg)
    views.setInt(R.id.widget_tool_name, "setBackgroundColor", bg)
  }
}
