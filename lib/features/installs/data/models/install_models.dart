class DeviceInstallRecord {
  static const Object _unset = Object();

  const DeviceInstallRecord({
    required this.id,
    required this.deviceId,
    required this.pluginId,
    required this.pluginSlug,
    required this.source,
    required this.installedAt,
    this.installedVersionId,
    this.installedVersion,
    this.updatedAt,
    this.latestAvailableVersion,
    this.updateAvailable = false,
    this.updateMandatory = false,
    this.lastUpdateCheckAt,
    this.pluginName,
    this.categoryName,
    this.pluginDescription,
    this.pinned = false,
    this.categoryColor,
    this.iconPath,
    this.catalogThumbnailUrl,
    this.cardAccentColor,
    this.pricingTier,
    this.folderId,
    this.lastLaunchedAt,
  });

  final String id;
  final String deviceId;
  final String pluginId;
  final String pluginSlug;
  final String source;
  final DateTime installedAt;
  final String? installedVersionId;
  final String? installedVersion;
  final DateTime? updatedAt;
  final String? latestAvailableVersion;
  final bool updateAvailable;
  /// Latest catalog version requires update before running ([updateAvailable] must be true).
  final bool updateMandatory;
  final DateTime? lastUpdateCheckAt;
  final String? pluginName;
  final String? categoryName;
  final String? pluginDescription;
  final bool pinned;
  final String? categoryColor;
  final String? iconPath;
  /// Catalog `icon_url` / thumbnail from API — CDN-first rendering on device.
  final String? catalogThumbnailUrl;
  final String? cardAccentColor;
  final String? pricingTier;
  final String? folderId;
  final DateTime? lastLaunchedAt;

  String get displayName => pluginName ?? pluginSlug;

  /// Same contract as [CatalogPlugin.catalogIconRef] for stored catalog art.
  String get catalogIconRef {
    final t = catalogThumbnailUrl?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    final s = pluginSlug.trim();
    if (s.isEmpty) {
      return '';
    }
    return '/v1/plugins/${Uri.encodeComponent(s)}/icon';
  }

  /// List-style square icon when falling back to catalog (not local bundle).
  ///
  /// [catalogThumbnailUrl] should be hydrated with [CatalogPlugin.catalogListIconRef].
  String get catalogListIconRef => catalogIconRef;

  factory DeviceInstallRecord.fromJson(Map<String, dynamic> json) {
    return DeviceInstallRecord(
      id: _readRequiredString(json, const <String>['id', 'ID']),
      deviceId: _readRequiredString(json, const <String>[
        'device_id',
        'DeviceID',
      ]),
      pluginId: _readRequiredString(json, const <String>[
        'plugin_id',
        'PluginID',
      ]),
      pluginSlug: _readRequiredString(json, const <String>[
        'plugin_slug',
        'PluginSlug',
      ]),
      source: _readRequiredString(json, const <String>['source', 'Source']),
      installedAt: _readRequiredDateTime(json, const <String>[
        'installed_at',
        'InstalledAt',
      ]),
      installedVersionId: _readOptionalString(json, const <String>[
        'installed_version_id',
        'InstalledVersionID',
      ]),
      installedVersion: _readOptionalString(json, const <String>[
        'installed_version',
        'InstalledVersion',
      ]),
      updatedAt: _readOptionalDateTime(json, const <String>[
        'updated_at',
        'UpdatedAt',
      ]),
      latestAvailableVersion: _readOptionalString(json, const <String>[
        'latest_available_version',
      ]),
      updateAvailable: _readOptionalBool(json, const <String>[
        'update_available',
      ]),
      updateMandatory: _readOptionalBool(json, const <String>[
        'update_mandatory',
        'UpdateMandatory',
      ]),
      lastUpdateCheckAt: _readOptionalDateTime(json, const <String>[
        'last_update_check_at',
      ]),
      pluginName: _readOptionalString(json, const <String>[
        'plugin_name',
        'PluginName',
      ]),
      categoryName: _readOptionalString(json, const <String>[
        'category_name',
        'CategoryName',
      ]),
      pluginDescription: _readOptionalString(json, const <String>[
        'plugin_description',
        'PluginDescription',
      ]),
      pinned: _readOptionalBool(json, const <String>['pinned']),
      categoryColor: _readOptionalString(json, const <String>[
        'category_color',
        'CategoryColor',
      ]),
      iconPath: _readOptionalString(json, const <String>[
        'icon_path',
        'IconPath',
      ]),
      catalogThumbnailUrl: _readOptionalString(json, const <String>[
        'catalog_thumbnail_url',
        'CatalogThumbnailUrl',
        'icon_url',
        'IconUrl',
      ]),
      cardAccentColor: _readOptionalString(json, const <String>[
        'card_accent_color',
        'CardAccentColor',
      ]),
      pricingTier: _readOptionalString(json, const <String>[
        'pricing_tier',
        'PricingTier',
      ]),
      folderId: _readOptionalString(json, const <String>[
        'folder_id',
        'FolderID',
      ]),
      lastLaunchedAt: _readOptionalDateTime(json, const <String>[
        'last_launched_at',
        'LastLaunchedAt',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'device_id': deviceId,
      'plugin_id': pluginId,
      'plugin_slug': pluginSlug,
      'source': source,
      'installed_at': installedAt.toUtc().toIso8601String(),
      'installed_version_id': installedVersionId,
      'installed_version': installedVersion,
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'latest_available_version': latestAvailableVersion,
      'update_available': updateAvailable,
      'update_mandatory': updateMandatory,
      'last_update_check_at': lastUpdateCheckAt?.toUtc().toIso8601String(),
      'plugin_name': pluginName,
      'category_name': categoryName,
      'plugin_description': pluginDescription,
      'pinned': pinned,
      'category_color': categoryColor,
      'icon_path': iconPath,
      'catalog_thumbnail_url': catalogThumbnailUrl,
      'card_accent_color': cardAccentColor,
      'pricing_tier': pricingTier,
      'folder_id': folderId,
      'last_launched_at': lastLaunchedAt?.toUtc().toIso8601String(),
    };
  }

  DeviceInstallRecord copyWith({
    String? id,
    String? deviceId,
    String? pluginId,
    String? pluginSlug,
    String? source,
    DateTime? installedAt,
    String? installedVersionId,
    String? installedVersion,
    DateTime? updatedAt,
    String? latestAvailableVersion,
    bool? updateAvailable,
    bool? updateMandatory,
    DateTime? lastUpdateCheckAt,
    String? pluginName,
    String? categoryName,
    String? pluginDescription,
    bool? pinned,
    String? categoryColor,
    String? iconPath,
    String? catalogThumbnailUrl,
    String? cardAccentColor,
    String? pricingTier,
    Object? folderId = _unset,
    Object? lastLaunchedAt = _unset,
  }) {
    return DeviceInstallRecord(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      pluginId: pluginId ?? this.pluginId,
      pluginSlug: pluginSlug ?? this.pluginSlug,
      source: source ?? this.source,
      installedAt: installedAt ?? this.installedAt,
      installedVersionId: installedVersionId ?? this.installedVersionId,
      installedVersion: installedVersion ?? this.installedVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      latestAvailableVersion:
          latestAvailableVersion ?? this.latestAvailableVersion,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      updateMandatory: updateMandatory ?? this.updateMandatory,
      lastUpdateCheckAt: lastUpdateCheckAt ?? this.lastUpdateCheckAt,
      pluginName: pluginName ?? this.pluginName,
      categoryName: categoryName ?? this.categoryName,
      pluginDescription: pluginDescription ?? this.pluginDescription,
      pinned: pinned ?? this.pinned,
      categoryColor: categoryColor ?? this.categoryColor,
      iconPath: iconPath ?? this.iconPath,
      catalogThumbnailUrl: catalogThumbnailUrl ?? this.catalogThumbnailUrl,
      cardAccentColor: cardAccentColor ?? this.cardAccentColor,
      pricingTier: pricingTier ?? this.pricingTier,
      folderId: identical(folderId, _unset)
          ? this.folderId
          : folderId as String?,
      lastLaunchedAt: identical(lastLaunchedAt, _unset)
          ? this.lastLaunchedAt
          : lastLaunchedAt as DateTime?,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }
  throw FormatException('Missing required string field for keys: $keys');
}

String? _readOptionalString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : value;
    }
  }
  return null;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, List<String> keys) {
  final rawValue = _readOptionalString(json, keys);
  if (rawValue == null) {
    throw FormatException('Missing required datetime field for keys: $keys');
  }
  return DateTime.parse(rawValue).toUtc();
}

DateTime? _readOptionalDateTime(Map<String, dynamic> json, List<String> keys) {
  final rawValue = _readOptionalString(json, keys);
  if (rawValue == null) {
    return null;
  }
  return DateTime.parse(rawValue).toUtc();
}

bool _readOptionalBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
  }
  return false;
}
