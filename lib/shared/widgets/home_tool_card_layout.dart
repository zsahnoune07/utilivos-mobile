/// Shared layout metrics for home tool grid cards and matching loading skeleton.
abstract final class HomeToolCardLayout {
  static const double cardBorderRadius = 18;
  static const double gridChildHorizontalPadding = 8;

  static double verticalPadding({required bool compact}) =>
      compact ? 9.0 : 11.0;

  /// [gridCellMaxWidth] is the width of one grid tile (including side padding).
  static double iconBoxSide(double gridCellMaxWidth) {
    final inner = gridCellMaxWidth - 2 * gridChildHorizontalPadding;
    return (inner * 0.92).clamp(52.0, 68.0);
  }

  static double iconCornerRadius(double iconBox) =>
      (iconBox * 0.21).clamp(12.0, 16.0);

  static double iconGlyphSize(double iconBox) =>
      (iconBox * 0.45).clamp(26.0, 32.0);

  static double artworkInset(double iconBox) => iconBox * 0.1;
}
