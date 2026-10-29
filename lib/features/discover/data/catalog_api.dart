import '../../../core/networking/api_client.dart';
import '../../../core/networking/models/cursor_page.dart';
import '../../../core/networking/network_exception.dart';
import 'catalog_cache_store.dart';
import 'models/catalog_cache_snapshot.dart';
import 'models/catalog_models.dart';

typedef CatalogNowProvider = DateTime Function();

class CatalogCachePolicy {
  const CatalogCachePolicy({
    this.freshFor = const Duration(minutes: 30),
    this.maxStale = const Duration(days: 14),
  });

  final Duration freshFor;
  final Duration maxStale;

  bool isFresh(DateTime cachedAt, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now().toUtc();
    return referenceNow.difference(cachedAt) <= freshFor;
  }

  bool isStaleFallbackAllowed(DateTime cachedAt, {DateTime? now}) {
    final referenceNow = now ?? DateTime.now().toUtc();
    return referenceNow.difference(cachedAt) <= maxStale;
  }
}

class CatalogApi {
  CatalogApi(
    this._apiClient, {
    CatalogCacheStore? cacheStore,
    CatalogCachePolicy cachePolicy = const CatalogCachePolicy(),
    CatalogNowProvider? nowProvider,
  }) : _cacheStore = cacheStore ?? const _NoopCatalogCacheStore(),
       _cachePolicy = cachePolicy,
       _nowProvider = nowProvider ?? _defaultNow;

  final ApiClient _apiClient;
  final CatalogCacheStore _cacheStore;
  final CatalogCachePolicy _cachePolicy;
  final CatalogNowProvider _nowProvider;
  Future<void> _cacheWriteQueue = Future<void>.value();

  Future<List<CatalogCategory>> listCategories({
    bool forceRefresh = false,
  }) async {
    final cachedSnapshot = await _readCacheSnapshot();
    final cachedCategories = cachedSnapshot.categories;
    if (!forceRefresh &&
        cachedCategories != null &&
        _cachePolicy.isFresh(cachedCategories.cachedAt, now: _now())) {
      return cachedCategories.items;
    }

    try {
      final categories = await _apiClient.get<List<CatalogCategory>>(
        '/v1/categories',
        skipAuth: true,
        decodeData: _decodeCategories,
      );
      await _mutateCache((CatalogCacheSnapshot snapshot) {
        return snapshot.copyWith(
          categories: CachedCategories(items: categories, cachedAt: _now()),
        );
      });
      return categories;
    } on NetworkException catch (error) {
      if (cachedCategories != null &&
          _isFallbackAllowedForError(error) &&
          _cachePolicy.isStaleFallbackAllowed(
            cachedCategories.cachedAt,
            now: _now(),
          )) {
        return cachedCategories.items;
      }
      rethrow;
    }
  }

  Future<CursorPage<CatalogPlugin>> listPlugins({
    String? category,
    String? search,
    String? tag,
    String? cursor,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _pluginPageCacheKey(
      category: category,
      search: search,
      tag: tag,
      cursor: cursor,
      limit: limit,
    );
    final cachedSnapshot = await _readCacheSnapshot();
    final cachedPage = cachedSnapshot.pluginPages[cacheKey];
    if (!forceRefresh &&
        cachedPage != null &&
        _cachePolicy.isFresh(cachedPage.cachedAt, now: _now())) {
      return CursorPage<CatalogPlugin>(
        items: cachedPage.items,
        nextCursor: cachedPage.nextCursor,
      );
    }

    try {
      final page = await _apiClient.get<CursorPage<CatalogPlugin>>(
        '/v1/plugins',
        queryParameters: <String, dynamic>{
          'status': 'published',
          'limit': limit,
          if (category != null && category.trim().isNotEmpty)
            'category': category,
          if (search != null && search.trim().isNotEmpty) 'search': search,
          if (tag != null && tag.trim().isNotEmpty) 'tag': tag,
          if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
        },
        skipAuth: true,
        decodeData: _decodePluginsPage,
      );

      await _mutateCache((CatalogCacheSnapshot snapshot) {
        final updatedPages = Map<String, CachedPluginPage>.from(
          snapshot.pluginPages,
        );
        final now = _now();
        updatedPages[cacheKey] = CachedPluginPage(
          items: page.items,
          nextCursor: page.nextCursor,
          cachedAt: now,
        );
        final updatedDetails = Map<String, CachedPluginDetail>.from(
          snapshot.pluginDetails,
        );
        for (final plugin in page.items) {
          final key = plugin.slug.trim().toLowerCase();
          if (key.isEmpty) {
            continue;
          }
          final previous = updatedDetails[key]?.plugin;
          updatedDetails[key] = CachedPluginDetail(
            plugin: _mergeListRowIntoCachedDetail(plugin, previous),
            cachedAt: now,
          );
        }
        return snapshot.copyWith(
          pluginPages: updatedPages,
          pluginDetails: updatedDetails,
        );
      });
      return page;
    } on NetworkException catch (error) {
      if (cachedPage != null &&
          _isFallbackAllowedForError(error) &&
          _cachePolicy.isStaleFallbackAllowed(
            cachedPage.cachedAt,
            now: _now(),
          )) {
        return CursorPage<CatalogPlugin>(
          items: cachedPage.items,
          nextCursor: cachedPage.nextCursor,
        );
      }
      rethrow;
    }
  }

  Future<CatalogPlugin> getPluginBySlug(
    String slug, {
    bool forceRefresh = false,
  }) async {
    final rawSlug = slug.trim();
    if (rawSlug.isEmpty) {
      throw const NetworkException(
        kind: NetworkExceptionKind.client,
        message: 'Plugin slug must not be empty.',
      );
    }
    final normalizedSlug = rawSlug.toLowerCase();
    final cachedSnapshot = await _readCacheSnapshot();
    final cachedPlugin = cachedSnapshot.pluginDetails[normalizedSlug];
    if (!forceRefresh &&
        cachedPlugin != null &&
        _cachePolicy.isFresh(cachedPlugin.cachedAt, now: _now())) {
      return cachedPlugin.plugin;
    }

    try {
      final plugin = await _apiClient.get<CatalogPlugin>(
        '/v1/plugins/${Uri.encodeComponent(rawSlug)}',
        skipAuth: true,
        decodeData: _decodePlugin,
      );

      await _mutateCache((CatalogCacheSnapshot snapshot) {
        final updatedDetails = Map<String, CachedPluginDetail>.from(
          snapshot.pluginDetails,
        );
        updatedDetails[normalizedSlug] = CachedPluginDetail(
          plugin: plugin,
          cachedAt: _now(),
        );
        return snapshot.copyWith(pluginDetails: updatedDetails);
      });
      return plugin;
    } on NetworkException catch (error) {
      if (cachedPlugin != null &&
          _isFallbackAllowedForError(error) &&
          _cachePolicy.isStaleFallbackAllowed(
            cachedPlugin.cachedAt,
            now: _now(),
          )) {
        return cachedPlugin.plugin;
      }
      rethrow;
    }
  }

  Future<List<PluginVersionSummary>> listPluginVersions(
    String slug, {
    bool forceRefresh = false,
  }) async {
    final rawSlug = slug.trim();
    if (rawSlug.isEmpty) {
      throw const NetworkException(
        kind: NetworkExceptionKind.client,
        message: 'Plugin slug must not be empty.',
      );
    }
    final normalizedSlug = rawSlug.toLowerCase();
    final cachedSnapshot = await _readCacheSnapshot();
    final cachedVersions = cachedSnapshot.pluginVersions[normalizedSlug];
    if (!forceRefresh &&
        cachedVersions != null &&
        _cachePolicy.isFresh(cachedVersions.cachedAt, now: _now())) {
      return cachedVersions.items;
    }

    try {
      final versions = await _apiClient.get<List<PluginVersionSummary>>(
        '/v1/plugins/${Uri.encodeComponent(rawSlug)}/versions',
        skipAuth: true,
        decodeData: _decodePluginVersions,
      );

      await _mutateCache((CatalogCacheSnapshot snapshot) {
        final updatedVersions = Map<String, CachedPluginVersions>.from(
          snapshot.pluginVersions,
        );
        updatedVersions[normalizedSlug] = CachedPluginVersions(
          items: versions,
          cachedAt: _now(),
        );
        return snapshot.copyWith(pluginVersions: updatedVersions);
      });
      return versions;
    } on NetworkException catch (error) {
      if (cachedVersions != null &&
          _isFallbackAllowedForError(error) &&
          _cachePolicy.isStaleFallbackAllowed(
            cachedVersions.cachedAt,
            now: _now(),
          )) {
        return cachedVersions.items;
      }
      rethrow;
    }
  }

  List<CatalogCategory> _decodeCategories(Object? rawData) {
    if (rawData is! List) {
      throw const FormatException('Categories payload must be a list.');
    }

    return rawData
        .map((Object? entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Each category item must be an object.',
            );
          }
          return CatalogCategory.fromJson(entry);
        })
        .toList(growable: false);
  }

  CursorPage<CatalogPlugin> _decodePluginsPage(Object? rawData) {
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Plugins payload must be an object.');
    }
    return CursorPage<CatalogPlugin>.fromJson(rawData, CatalogPlugin.fromJson);
  }

  CatalogPlugin _decodePlugin(Object? rawData) {
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Plugin payload must be an object.');
    }
    return CatalogPlugin.fromJson(rawData);
  }

  List<PluginVersionSummary> _decodePluginVersions(Object? rawData) {
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Plugin versions payload must be an object.');
    }
    final rawItems = rawData['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Plugin versions payload must include an items list.',
      );
    }
    return rawItems
        .map((Object? entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Each plugin version item must be an object.',
            );
          }
          return PluginVersionSummary.fromJson(entry);
        })
        .toList(growable: false);
  }

  Future<CatalogCacheSnapshot> _readCacheSnapshot() async {
    try {
      return await _cacheStore.read();
    } catch (_) {
      return CatalogCacheSnapshot.empty;
    }
  }

  Future<void> _mutateCache(
    CatalogCacheSnapshot Function(CatalogCacheSnapshot current) mutate,
  ) {
    _cacheWriteQueue = _cacheWriteQueue.then((_) async {
      final snapshot = await _readCacheSnapshot();
      final updated = mutate(snapshot);
      try {
        await _cacheStore.write(updated);
      } catch (_) {
        // Cache writes are best-effort and must never fail catalog reads.
      }
    });
    return _cacheWriteQueue;
  }

  bool _isFallbackAllowedForError(NetworkException error) {
    return switch (error.kind) {
      NetworkExceptionKind.client || NetworkExceptionKind.unauthorized => false,
      _ => true,
    };
  }

  DateTime _now() => _nowProvider().toUtc();

  /// Merges a list-row [incoming] into any existing detail cache so we do not
  /// drop fields that the list endpoint omits (e.g. long description).
  CatalogPlugin _mergeListRowIntoCachedDetail(
    CatalogPlugin incoming,
    CatalogPlugin? previous,
  ) {
    if (previous == null) {
      return incoming;
    }
    return CatalogPlugin(
      id: incoming.id,
      slug: incoming.slug,
      name: incoming.name,
      categorySlug: incoming.categorySlug,
      categoryName: incoming.categoryName,
      pricingType: incoming.pricingType,
      shortDescription: incoming.shortDescription ?? previous.shortDescription,
      longDescription: incoming.longDescription ?? previous.longDescription,
      currentVersionId: incoming.currentVersionId ?? previous.currentVersionId,
      thumbnailUrl: incoming.thumbnailUrl ?? previous.thumbnailUrl,
      iconUrl: incoming.iconUrl ?? previous.iconUrl,
      categoryColor: incoming.categoryColor ?? previous.categoryColor,
      proPreview: incoming.proPreview || previous.proPreview,
      tags: incoming.tags.isNotEmpty ? incoming.tags : previous.tags,
    );
  }

  /// All distinct plugins currently in the catalog disk cache (browse pages + detail entries).
  Future<List<CatalogPlugin>> collectCachedPluginsUnion() async {
    final snapshot = await _readCacheSnapshot();
    final bySlug = <String, CatalogPlugin>{};
    void take(CatalogPlugin p) {
      final k = p.slug.trim().toLowerCase();
      if (k.isEmpty) {
        return;
      }
      bySlug[k] = p;
    }

    for (final page in snapshot.pluginPages.values) {
      for (final p in page.items) {
        take(p);
      }
    }
    for (final detail in snapshot.pluginDetails.values) {
      take(detail.plugin);
    }
    return bySlug.values.toList(growable: false);
  }

  String _pluginPageCacheKey({
    String? category,
    String? search,
    String? tag,
    String? cursor,
    required int limit,
  }) {
    return <String>[
      'category=${_normalizeCacheKeyPart(category)}',
      'search=${_normalizeCacheKeyPart(search)}',
      'tag=${_normalizeCacheKeyPart(tag)}',
      'cursor=${_normalizeCacheKeyPart(cursor)}',
      'limit=$limit',
    ].join('|');
  }

  String _normalizeCacheKeyPart(String? value) {
    if (value == null) {
      return '-';
    }
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '-';
    }
    return Uri.encodeComponent(trimmed);
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}

class _NoopCatalogCacheStore implements CatalogCacheStore {
  const _NoopCatalogCacheStore();

  @override
  Future<void> clear() async {}

  @override
  Future<CatalogCacheSnapshot> read() async {
    return CatalogCacheSnapshot.empty;
  }

  @override
  Future<void> write(CatalogCacheSnapshot snapshot) async {}
}
