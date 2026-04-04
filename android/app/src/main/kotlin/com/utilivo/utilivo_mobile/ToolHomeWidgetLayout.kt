package com.utilivo.utilivo_mobile

import android.appwidget.AppWidgetManager
import kotlin.math.max
import kotlin.math.min

/** Launcher grid helpers for [ToolHomeWidgetProvider]. */
internal object ToolHomeWidgetLayout {

  /**
   * Current widget span in **dp** from [AppWidgetManager.getAppWidgetOptions] (see Android app widget
   * sizing docs).
   */
  fun widgetSizeDp(appWidgetManager: AppWidgetManager, widgetId: Int): Pair<Int, Int> {
    val opts = appWidgetManager.getAppWidgetOptions(widgetId)
    var w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
    var h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
    if (w <= 0 || h <= 0) {
      val info = appWidgetManager.getAppWidgetInfo(widgetId)
      if (info != null) {
        if (w <= 0) {
          w = info.minWidth
        }
        if (h <= 0) {
          h = info.minHeight
        }
      }
    }
    if (w <= 0) {
      w = 72
    }
    if (h <= 0) {
      h = 72
    }
    return Pair(w, h)
  }

  /**
   * **1×1** (square icon-only): both sides nearly equal. **2×1**: two cells wide, one tall
   * (horizontal resize only in [tool_home_widget_info]).
   */
  fun isOneByOne(wDp: Int, hDp: Int): Boolean {
    val minSide = min(wDp, hDp)
    val maxSide = max(wDp, hDp)
    val tolDp = 22
    return maxSide <= minSide + tolDp
  }
}
