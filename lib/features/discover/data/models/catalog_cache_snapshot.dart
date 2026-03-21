import 'catalog_models.dart';

class CatalogCacheSnapshot {
  const CatalogCacheSnapshot({
    this.categories,
    this.pluginPages = const <String, CachedPluginPage>{},
    this.pluginDetails = const <String, CachedPluginDetail>{},
    this.pluginVersions = const <String, CachedPluginVersions>{},
  });

  final CachedCategories? categories;
  final Map<String, CachedPluginPage> pluginPages;
  final Map<String, CachedPluginDetail> pluginDetails;
  final Map<String, CachedPluginVersions> pluginVersions;

  static const CatalogCacheSnapshot empty = CatalogCacheSnapshot();

  factory CatalogCacheSnapshot.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final rawPluginPages = json['plugin_pages'];
    final rawPluginDetails = json['plugin_details'];
    final rawPluginVersions = json['plugin_versions'];

    return CatalogCacheSnapshot(
      categories: rawCategories is Map<String, dynamic>
          ? CachedCategories.fromJson(rawCategories)
          : null,
      pluginPages: _decodeMap(
        rawPluginPages,
        CachedPluginPage.fromJson,
        fieldName: 'plugin_pages',
      ),
      pluginDetails: _decodeMap(
        rawPluginDetails,
        CachedPluginDetail.fromJson,
        fieldName: 'plugin_details',
      ),
      pluginVersions: _decodeMap(
        rawPluginVersions,
        CachedPluginVersions.fromJson,
        fieldName: 'plugin_versions',
      ),
    );
  }

  CatalogCacheSnapshot copyWith({
    Object? categories = _unset,
    Map<String, CachedPluginPage>? pluginPages,
    Map<String, CachedPluginDetail>? pluginDetails,
    Map<String, CachedPluginVersions>? pluginVersions,
  }) {
    return CatalogCacheSnapshot(
      categories: identical(categories, _unset)
          ? this.categories
          : categories as CachedCategories?,
      pluginPages: pluginPages ?? this.pluginPages,
      pluginDetails: pluginDetails ?? this.pluginDetails,
      pluginVersions: pluginVersions ?? this.pluginVersions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categories': categories?.toJson(),
      'plugin_pages': <String, dynamic>{
        for (final entry in pluginPages.entries)
          entry.key: entry.value.toJson(),
      },
      'plugin_details': <String, dynamic>{
        for (final entry in pluginDetails.entries)
          entry.key: entry.value.toJson(),
      },
      'plugin_versions': <String, dynamic>{
        for (final entry in pluginVersions.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  static const Object _unset = Object();
}

class CachedCategories {
  const CachedCategories({required this.items, required this.cachedAt});

  final List<CatalogCategory> items;
  final DateTime cachedAt;

  factory CachedCategories.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Cached categories payload must have items.');
    }

    return CachedCategories(
      items: rawItems
          .map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw const FormatException(
                'Each cached category item must be an object.',
              );
            }
            return CatalogCategory.fromJson(entry);
          })
          .toList(growable: false),
      cachedAt: _readRequiredDateTime(json, 'cached_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((CatalogCategory item) => item.toJson()).toList(),
      'cached_at': cachedAt.toUtc().toIso8601String(),
    };
  }
}

class CachedPluginPage {
  const CachedPluginPage({
    required this.items,
    required this.nextCursor,
    required this.cachedAt,
  });

  final List<CatalogPlugin> items;
  final String? nextCursor;
  final DateTime cachedAt;

  factory CachedPluginPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Cached plugin page must have items.');
    }

    return CachedPluginPage(
      items: rawItems
          .map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw const FormatException(
                'Each cached plugin page item must be an object.',
              );
            }
            return CatalogPlugin.fromJson(entry);
          })
          .toList(growable: false),
      nextCursor: _readOptionalString(json['next_cursor']),
      cachedAt: _readRequiredDateTime(json, 'cached_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((CatalogPlugin item) => item.toJson()).toList(),
      'next_cursor': nextCursor,
      'cached_at': cachedAt.toUtc().toIso8601String(),
    };
  }
}

class CachedPluginDetail {
  const CachedPluginDetail({required this.plugin, required this.cachedAt});

  final CatalogPlugin plugin;
  final DateTime cachedAt;

  factory CachedPluginDetail.fromJson(Map<String, dynamic> json) {
    final rawPlugin = json['plugin'];
    if (rawPlugin is! Map<String, dynamic>) {
      throw const FormatException('Cached plugin detail must include plugin.');
    }
    return CachedPluginDetail(
      plugin: CatalogPlugin.fromJson(rawPlugin),
      cachedAt: _readRequiredDateTime(json, 'cached_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plugin': plugin.toJson(),
      'cached_at': cachedAt.toUtc().toIso8601String(),
    };
  }
}

class CachedPluginVersions {
  const CachedPluginVersions({required this.items, required this.cachedAt});

  final List<PluginVersionSummary> items;
  final DateTime cachedAt;

  factory CachedPluginVersions.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Cached plugin versions must have items.');
    }

    return CachedPluginVersions(
      items: rawItems
          .map((Object? entry) {
            if (entry is! Map<String, dynamic>) {
              throw const FormatException(
                'Each cached plugin version item must be an object.',
              );
            }
            return PluginVersionSummary.fromJson(entry);
          })
          .toList(growable: false),
      cachedAt: _readRequiredDateTime(json, 'cached_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((PluginVersionSummary item) => item.toJson()).toList(),
      'cached_at': cachedAt.toUtc().toIso8601String(),
    };
  }
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Missing required timestamp "$key".');
  }
  return DateTime.parse(raw).toUtc();
}

String? _readOptionalString(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

Map<String, T> _decodeMap<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson, {
  required String fieldName,
}) {
  if (raw == null) {
    return <String, T>{};
  }
  if (raw is! Map<String, dynamic>) {
    throw FormatException('Cached "$fieldName" payload must be an object.');
  }
  return raw.map<String, T>((String key, dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Cached "$fieldName" entry "$key" must be an object.',
      );
    }
    return MapEntry<String, T>(key, fromJson(value));
  });
}
