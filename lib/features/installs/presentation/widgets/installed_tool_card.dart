import 'package:flutter/material.dart';

import 'package:utilivo_mobile/shared/widgets/home_tool_card_layout.dart';
import 'package:utilivo_mobile/shared/widgets/tool_thumbnail.dart';

import '../../data/models/install_models.dart';

class InstalledToolCard extends StatelessWidget {
  const InstalledToolCard({
    required this.install,
    required this.onTap,
    required this.onLongPress,
    this.iconPath,
    this.iconBaseUrl,
    this.dominantColorHex,
    this.folderBadgeLabel,
    this.folderBadgeColor,
    super.key,
  });

  final DeviceInstallRecord install;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? iconPath;

  /// API base URL for resolving relative catalog icon paths.
  final String? iconBaseUrl;
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
    final accent =
        _parseHexColor(dominantColorHex) ??
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
          borderRadius: BorderRadius.circular(
            HomeToolCardLayout.cardBorderRadius,
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(
              HomeToolCardLayout.cardBorderRadius,
            ),
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
                final iconBoxSize = HomeToolCardLayout.iconBoxSide(
                  constraints.maxWidth,
                );
                final iconRadius = HomeToolCardLayout.iconCornerRadius(
                  iconBoxSize,
                );
                final iconGlyphSize = HomeToolCardLayout.iconGlyphSize(
                  iconBoxSize,
                );
                final verticalPadding = HomeToolCardLayout.verticalPadding(
                  compact: compact,
                );
                final titleSpacing = compact ? 7.0 : 11.0;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: HomeToolCardLayout.gridChildHorizontalPadding,
                    vertical: verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      HomeToolCardLayout.cardBorderRadius,
                    ),
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
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _ToolCardIcon(
                              install: install,
                              iconPath: iconPath,
                              iconBaseUrl: iconBaseUrl,
                              accent: accent,
                              iconBg: iconBg,
                              boxSize: iconBoxSize,
                              cornerRadius: iconRadius,
                              glyphSize: iconGlyphSize,
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
        if (install.pinned)
          Positioned(
            top: -7,
            left: 8,
            child: IgnorePointer(
              child: Icon(
                Icons.push_pin_rounded,
                size: 17,
                color: colorScheme.primary.withValues(alpha: 0.82),
              ),
            ),
          ),
        if (install.updateAvailable)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Tooltip(
                message: 'Update available',
                child: Material(
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  color: colorScheme.primaryContainer,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
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

class _ToolCardIcon extends StatelessWidget {
  const _ToolCardIcon({
    required this.install,
    required this.iconPath,
    required this.iconBaseUrl,
    required this.accent,
    required this.iconBg,
    required this.boxSize,
    required this.cornerRadius,
    required this.glyphSize,
  });

  final DeviceInstallRecord install;
  final String? iconPath;
  final String? iconBaseUrl;
  final Color accent;
  final Color iconBg;
  final double boxSize;
  final double cornerRadius;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final iconRef = install.catalogListIconRef.trim();
    final localRef = iconPath?.trim();
    final preferLocalIcon = localRef != null && localRef.isNotEmpty;
    final hasCustomIcon =
        iconRef.isNotEmpty || (localRef != null && localRef.isNotEmpty);

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasCustomIcon
          ? ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: ToolThumbnail(
                imageUrl: preferLocalIcon ? null : install.catalogListIconRef,
                localPath: iconPath,
                baseUrl: iconBaseUrl,
                debugToolSlug: install.pluginSlug,
                debugThumbnailUrl: install.catalogThumbnailUrl,
                debugIconUrl: install.catalogThumbnailUrl,
                size: boxSize,
                borderRadius: cornerRadius,
                fallbackIcon: Icons.extension_rounded,
                fallbackIconColor: accent,
                fallbackIconSize: glyphSize,
                transparentFallback: true,
              ),
            )
          : Icon(Icons.extension_rounded, color: accent, size: glyphSize),
    );
  }
}
