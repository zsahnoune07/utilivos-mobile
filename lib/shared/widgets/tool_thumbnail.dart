import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../cache/tool_icon_cache_manager.dart';
import 'app_skeletons.dart';

const bool _enableIconDebugLogs = true;

class ToolThumbnail extends StatelessWidget {
  const ToolThumbnail({
    this.imageUrl,
    this.localPath,
    this.baseUrl,
    this.debugToolSlug,
    this.debugThumbnailUrl,
    this.debugIconUrl,
    this.size = 52,
    this.borderRadius = 10,
    this.fallbackIcon = Icons.extension_outlined,
    this.fallbackIconColor,
    this.fallbackIconSize,

    /// When true, the error/placeholder state is only an icon (no filled tile).
    /// Use when an outer container already provides the background (e.g. home cards).
    this.transparentFallback = false,
    super.key,
  });

  final String? imageUrl;
  final String? localPath;
  final String? baseUrl;
  final String? debugToolSlug;
  final String? debugThumbnailUrl;
  final String? debugIconUrl;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final double? fallbackIconSize;
  final bool transparentFallback;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback(context);
    final normalizedUrl = _normalizeImageUrl(imageUrl);
    final localFile = _resolveLocalFile(localPath);
    final source = normalizedUrl != null
        ? 'network'
        : (localFile != null ? 'local' : 'placeholder');

    if (kDebugMode && _enableIconDebugLogs) {
      final raw = imageUrl?.trim();
      final isAbsolute =
          raw != null &&
          (raw.startsWith('https://') || raw.startsWith('http://'));
      debugPrint(
        '[ToolThumbnail] ${{'tool': debugToolSlug, 'thumbnail_url': debugThumbnailUrl, 'icon_url': debugIconUrl, 'local_icon_path': localPath, 'raw_image_url': imageUrl, 'is_absolute_url': isAbsolute, 'resolved_image_url': normalizedUrl, 'resolved_source': source}}',
      );
      if (normalizedUrl != null) {
        _debugLogCacheProbe(normalizedUrl);
      }
    }

    // Prefer CDN/API URL when [imageUrl] is non-null; when callers omit the URL (e.g.
    // installed tools with an extracted local icon), the local file is used first.
    if (normalizedUrl != null) {
      return _networkImage(
        context,
        normalizedUrl,
        fallback,
        localFallbackFile: localFile,
      );
    }

    if (localFile != null) {
      return _localImage(localFile, fallback);
    }

    return fallback;
  }

  File? _resolveLocalFile(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final file = File(trimmed);
    return file.existsSync() ? file : null;
  }

  Widget _localImage(File file, Widget fallback) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? st) {
          return fallback;
        },
      ),
    );
  }

  Widget _networkImage(
    BuildContext context,
    String url,
    Widget fallback, {
    File? localFallbackFile,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: ToolIconCacheManager.instance,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => AppSkeletonBox(
          width: size,
          height: size,
          borderRadius: borderRadius,
        ),
        errorWidget: (_, requestedUrl, error) {
          if (kDebugMode && _enableIconDebugLogs) {
            debugPrint(
              '[ToolThumbnail] IMAGE ERROR url=$requestedUrl error=$error '
              'tool=$debugToolSlug',
            );
          }
          if (localFallbackFile != null) {
            return Image.file(
              localFallbackFile,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? st) {
                    return fallback;
                  },
            );
          }
          return fallback;
        },
      ),
    );
  }

  void _debugLogCacheProbe(String url) {
    ToolIconCacheManager.instance
        .getFileFromCache(url)
        .then((cached) {
          if (kDebugMode && _enableIconDebugLogs) {
            debugPrint(
              '[ToolThumbnail] cache ${cached == null ? 'MISS' : 'HIT'} key=$url',
            );
          }
        })
        .catchError((Object error) {
          if (kDebugMode && _enableIconDebugLogs) {
            debugPrint(
              '[ToolThumbnail] cache probe error key=$url error=$error',
            );
          }
        });
  }

  Widget _fallback(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = fallbackIconColor ?? colorScheme.primary;
    final iconSize = fallbackIconSize ?? (size * 0.45).clamp(22.0, 40.0);
    final icon = Icon(fallbackIcon, color: iconColor, size: iconSize);
    if (transparentFallback) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: icon),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: icon),
      ),
    );
  }

  String? _normalizeImageUrl(String? rawUrl) {
    if (rawUrl == null) {
      return null;
    }
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    if (uri.hasScheme && uri.hasAuthority) {
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }
      return trimmed;
    }

    final rawBase = baseUrl?.trim();
    if (rawBase == null || rawBase.isEmpty) {
      return null;
    }
    final baseUri = Uri.tryParse(rawBase);
    if (baseUri == null ||
        !baseUri.hasScheme ||
        !baseUri.hasAuthority ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https')) {
      return null;
    }
    return baseUri.resolve(trimmed).toString();
  }
}
