package com.utilivo.utilivo_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.TypedValue
import kotlin.math.min

internal object UtilivoWidgetIcons {

  fun cornerRadiusPx(context: Context, cornerDp: Float): Float =
      TypedValue.applyDimension(
          TypedValue.COMPLEX_UNIT_DIP,
          cornerDp,
          context.resources.displayMetrics,
      )

  /** Smaller side of the widget in pixels (for square 1×1 icon tiles). */
  fun widgetMinSidePx(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int): Int {
    val dm = context.resources.displayMetrics
    fun dpToPx(dp: Int): Int {
      if (dp <= 0) {
        return 0
      }
      return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), dm).toInt()
    }
    val (wDp, hDp) = ToolHomeWidgetLayout.widgetSizeDp(appWidgetManager, widgetId)
    val w = dpToPx(wDp)
    val h = dpToPx(hDp)
    val side =
        when {
          w > 0 && h > 0 -> minOf(w, h)
          w > 0 -> w
          h > 0 -> h
          else -> dpToPx(72)
        }
    val minPx = dpToPx(40)
    val maxPx = dpToPx(640)
    return side.coerceIn(minPx, maxPx)
  }

  /**
   * Uniformly scales [source] to **fit inside** a square (letterboxing if needed), then clips to
   * rounded corners — avoids the “zoomed/cropped” look of center-crop for 1×1 tiles.
   */
  fun roundedSquareBitmap(source: Bitmap, sidePx: Int, cornerRadiusPx: Float): Bitmap {
    val output = Bitmap.createBitmap(sidePx, sidePx, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(output)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val rect = RectF(0f, 0f, sidePx.toFloat(), sidePx.toFloat())
    val clip = Path().apply { addRoundRect(rect, cornerRadiusPx, cornerRadiusPx, Path.Direction.CW) }
    canvas.clipPath(clip)
    val scale =
        min(
            sidePx.toFloat() / source.width.toFloat(),
            sidePx.toFloat() / source.height.toFloat(),
        )
    val matrix = Matrix()
    matrix.postScale(scale, scale)
    matrix.postTranslate(
        (sidePx - source.width * scale) / 2f,
        (sidePx - source.height * scale) / 2f,
    )
    canvas.drawBitmap(source, matrix, paint)
    return output
  }
}
