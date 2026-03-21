import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/install_models.dart';

class InstalledToolCard extends StatelessWidget {
  const InstalledToolCard({
    required this.install,
    required this.onTap,
    required this.onLongPress,
    this.iconPath,
    this.dominantColorHex,
    this.folderBadgeLabel,
    this.folderBadgeColor,
    super.key,
  });

  final DeviceInstallRecord install;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? iconPath;
  final String? dominantColorHex;
  final String? folderBadgeLabel;
  final Color? folderBadgeColor;

  static const List<int> _defaultAccentPalette = <int>[
    0xFF7C3AED, // violet
    0xFF2563EB, // blue
    0xFF059669, // emerald
    0xFFCA8A04, // yellow
    0xFFDC2626, // red
    0xFFDB2777, // pink
    0xFF7C2D12, // brown
    0xFF4F46E5, // indigo
    0xFF0D9488, // teal
    0xFFEA580C, // orange
  ];

  static Color _defaultAccentForSlug(String slug) {
    final index = slug.hashCode.abs() % _defaultAccentPalette.length;
    return Color(_defaultAccentPalette[index]);
  }

  static Color? _parseHexColor(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final hex = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    final withAlpha = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(withAlpha, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  static Color _cardTint(Color accent) => accent.withValues(alpha: 0.12);

  static Color _iconTint(Color accent, bool isDark) {
    if (isDark) {
      return accent.withValues(alpha: 0.22);
    }
    return accent.withValues(alpha: 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _parseHexColor(dominantColorHex) ??
        _defaultAccentForSlug(install.pluginSlug);
    final cardBg = _cardTint(accent);
    final iconBg = _iconTint(accent, isDark);
    final folderBadge = folderBadgeLabel?.trim();
    final hasFolderBadge = folderBadge != null && folderBadge.isNotEmpty;
    final resolvedFolderBadgeColor =
        folderBadgeColor ?? colorScheme.surfaceContainerHighest;
    final badgeBackground = Color.alphaBlend(
      resolvedFolderBadgeColor.withValues(alpha: isDark ? 0.26 : 0.22),
      colorScheme.surface,
    );
    final onBadgeColor =
        ThemeData.estimateBrightnessForColor(badgeBackground) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: Color.alphaBlend(cardBg, colorScheme.surface),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final compact = constraints.maxHeight < 170;
                final nameStyle =
                    (compact
                            ? Theme.of(context).textTheme.bodySmall
                            : Theme.of(context).textTheme.bodyMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        );
                final nameLineHeight =
                    (nameStyle?.fontSize ?? 13) * (nameStyle?.height ?? 1.35);
                final twoLineNameHeight = nameLineHeight * 2;
                final iconBoxSize = compact ? 48.0 : 58.0;
                final iconSize = compact ? 24.0 : 28.0;
                final iconRadius = compact ? 12.0 : 14.0;
                final verticalPadding = compact ? 8.0 : 10.0;
                final titleSpacing = compact ? 6.0 : 10.0;
                final topIndicatorHeight =
                    install.pinned || install.updateAvailable ? 16.0 : 0.0;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: topIndicatorHeight,
                        child: Row(
                          children: <Widget>[
                            if (install.pinned)
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            const Spacer(),
                            if (install.updateAvailable)
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: colorScheme.error,
                              ),
                          ],
                        ),
                      ),
                      if (topIndicatorHeight > 0) const SizedBox(height: 2),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: iconBoxSize,
                              height: iconBoxSize,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(iconRadius),
                              ),
                              child: iconPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        iconRadius,
                                      ),
                                      child: Image.file(
                                        File(iconPath!),
                                        width: iconBoxSize,
                                        height: iconBoxSize,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.extension,
                                                  color: accent,
                                                  size: iconSize,
                                                ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.extension,
                                      color: accent,
                                      size: iconSize,
                                    ),
                            ),
                            SizedBox(height: titleSpacing),
                            SizedBox(
                              height: twoLineNameHeight,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  install.displayName,
                                  style: nameStyle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (hasFolderBadge)
          Positioned(
            top: 6,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  key: Key('folder-badge-${install.pluginSlug}'),
                  constraints: const BoxConstraints(
                    maxWidth: 140,
                    maxHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: badgeBackground,
                    border: Border.all(
                      color: resolvedFolderBadgeColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    folderBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: onBadgeColor.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
