import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../cache/tool_icon_cache_manager.dart';
import 'app_skeletons.dart';

class ToolThumbnail extends StatelessWidget {
  const ToolThumbnail({
    required this.imageUrl,
    this.localPath,
    this.baseUrl,
    this.size = 52,
    this.borderRadius = 10,
    this.fallbackIcon = Icons.extension_outlined,
    super.key,
  });

  final String? imageUrl;
  final String? localPath;
  final String? baseUrl;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback(context);

    if (localPath != null &&
        localPath!.isNotEmpty &&
        File(localPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(localPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final normalizedUrl = _normalizeImageUrl(imageUrl);
            if (normalizedUrl != null) {
              return _networkImage(normalizedUrl, fallback);
            }
            return fallback;
          },
        ),
      );
    }

    final normalizedUrl = _normalizeImageUrl(imageUrl);
    if (normalizedUrl == null) {
      return fallback;
    }

    return _networkImage(normalizedUrl, fallback);
  }

  Widget _networkImage(String url, Widget fallback) {
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
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, color: Theme.of(context).colorScheme.primary),
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
