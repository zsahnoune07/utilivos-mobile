import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared cache manager for marketplace icon thumbnails.
///
/// A dedicated key prevents eviction conflicts with unrelated cached content
/// and keeps icon reuse stable across app relaunches.
class ToolIconCacheManager {
  ToolIconCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'utilivo-tool-icon-cache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 400,
    ),
  );
}
