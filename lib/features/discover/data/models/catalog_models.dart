class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
    this.color,
  });

  final String id;
  final String slug;
  final String name;
  final String? icon;
  final String? color;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: _readRequiredString(json, const <String>['id', 'ID']),
      slug: _readRequiredString(json, const <String>['slug', 'Slug']),
      name: _readRequiredString(json, const <String>['name', 'Name']),
      icon: _readOptionalString(json, const <String>['icon', 'Icon']),
      color: _readOptionalString(json, const <String>['color', 'Color']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }
}

class CatalogPlugin {
  const CatalogPlugin({
    required this.id,
    required this.slug,
    required this.name,
    required this.categorySlug,
    required this.categoryName,
    required this.pricingType,
    this.shortDescription,
    this.longDescription,
    this.currentVersionId,
    this.thumbnailUrl,
    this.iconUrl,
    this.categoryColor,
    this.proPreview = false,
    this.tags = const <String>[],
  });

  final String id;
  final String slug;
  final String name;
  final String categorySlug;
  final String categoryName;
  final String pricingType;
  final String? shortDescription;
  final String? longDescription;
  final String? currentVersionId;
  final String? thumbnailUrl;
  final String? iconUrl;
  final String? categoryColor;

  /// When this tool is Pro-tier ([isPro]), free users may install/run preview builds only if the API
  /// sets `pro_preview` / `premium_preview` / `allows_free_preview_install` to true.
  final bool proPreview;

  /// Search / discover tags from API (array or comma-separated string).
  final List<String> tags;

  /// API may use `pro`, `paid`, or `premium` for the paid catalog tier (product copy: Pro).
  static bool tierIsPro(String pricingType) {
    final normalized = pricingType.trim().toLowerCase();
    return normalized == 'pro' ||
        normalized == 'paid' ||
        normalized == 'premium';
  }

  bool get isPro => tierIsPro(pricingType);

  /// Image URL or relative path for Tool Library / detail headers.
  ///
  /// Priority:
  /// 1) [thumbnailUrl] (future-ready dedicated thumbnail variant)
  /// 2) [iconUrl] (current CDN icon source)
  /// Otherwise falls back to the catalog icon route (`/v1/plugins/{slug}/icon`),
  /// matching the server when `icon_url` is unset so browse lists still load icons.
  String get catalogIconRef {
    final thumb = thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }
    final icon = iconUrl?.trim();
    if (icon != null && icon.isNotEmpty) {
      return icon;
    }
    final s = slug.trim();
    if (s.isEmpty) {
      return '';
    }
    return '/v1/plugins/${Uri.encodeComponent(s)}/icon';
  }

  /// Square list-row icon: prefer [iconUrl], then the catalog icon route, then [thumbnailUrl].
  ///
  /// Use in Tool Library rows where letterboxed thumbnails look padded; [catalogIconRef] still
  /// prefers thumbnail for hero/detail contexts.
  String get catalogListIconRef {
    final icon = iconUrl?.trim();
    if (icon != null && icon.isNotEmpty) {
      return icon;
    }
    final s = slug.trim();
    if (s.isNotEmpty) {
      return '/v1/plugins/${Uri.encodeComponent(s)}/icon';
    }
    final thumb = thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }
    return '';
  }

  /// Install/download from catalog without an active subscription.
  bool canFreeUserAttemptInstall(bool hasProAccess) {
    if (!isPro) {
      return true;
    }
    if (hasProAccess) {
      return true;
    }
    return proPreview;
  }

  factory CatalogPlugin.fromJson(Map<String, dynamic> json) {
    final pricingType = _readRequiredString(json, const <String>[
      'pricing_type',
      'PricingType',
    ]);
    final previewFromApi = _readOptionalBool(json, const <String>[
      'pro_preview',
      'ProPreview',
      'premium_preview',
      'PremiumPreview',
      'allows_free_preview_install',
      'AllowsFreePreviewInstall',
    ]);
    final parsedThumbnail = _readOptionalString(json, const <String>[
      'thumbnail_url',
      'ThumbnailUrl',
      'image_url',
      'ImageUrl',
      'logo_url',
      'LogoUrl',
    ]);
    final parsedIconUrl = _readOptionalString(json, const <String>[
      'icon_url',
      'IconUrl',
    ]);

    return CatalogPlugin(
      id: _readRequiredString(json, const <String>['id', 'ID']),
      slug: _readRequiredString(json, const <String>['slug', 'Slug']),
      name: _readRequiredString(json, const <String>['name', 'Name']),
      categorySlug: _readRequiredString(json, const <String>[
        'category_slug',
        'CategorySlug',
      ]),
      categoryName: _readRequiredString(json, const <String>[
        'category_name',
        'CategoryName',
      ]),
      pricingType: pricingType,
      shortDescription: _readOptionalString(json, const <String>[
        'short_description',
        'ShortDescription',
      ]),
      longDescription: _readOptionalString(json, const <String>[
        'long_description',
        'LongDescription',
      ]),
      currentVersionId: _readOptionalString(json, const <String>[
        'current_version_id',
        'CurrentVersionID',
      ]),
      thumbnailUrl: parsedThumbnail,
      iconUrl: parsedIconUrl,
      categoryColor: _readOptionalString(json, const <String>[
        'category_color',
        'CategoryColor',
      ]),
      proPreview: previewFromApi == true,
      tags: _parseTagsJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'name': name,
      'category_slug': categorySlug,
      'category_name': categoryName,
      'pricing_type': pricingType,
      'short_description': shortDescription,
      'long_description': longDescription,
      'current_version_id': currentVersionId,
      'thumbnail_url': thumbnailUrl,
      'icon_url': iconUrl,
      'category_color': categoryColor,
      'pro_preview': proPreview,
      'tags': tags,
    };
  }
}

class PluginVersionSummary {
  const PluginVersionSummary({
    required this.id,
    required this.version,
    this.changelog,
    this.updateMandatory = false,
  });

  final String id;
  final String version;
  final String? changelog;
  final bool updateMandatory;

  factory PluginVersionSummary.fromJson(Map<String, dynamic> json) {
    return PluginVersionSummary(
      id: _readRequiredString(json, const <String>['id', 'ID']),
      version: _readRequiredString(json, const <String>['version', 'Version']),
      changelog: _readOptionalString(json, const <String>[
        'changelog',
        'Changelog',
      ]),
      updateMandatory:
          _readOptionalBool(json, const <String>[
            'update_mandatory',
            'UpdateMandatory',
          ]) ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'version': version,
      'changelog': changelog,
      'update_mandatory': updateMandatory,
    };
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
      if (trimmed.isEmpty) {
        continue;
      }
      return value;
    }
  }
  return null;
}

List<String> _parseTagsJson(Map<String, dynamic> json) {
  const keys = <String>['tags', 'Tags', 'tool_tags', 'ToolTags'];
  for (final key in keys) {
    final value = json[key];
    if (value is String) {
      return value
          .split(',')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);
    }
    if (value is List) {
      final out = <String>[];
      for (final e in value) {
        if (e is String) {
          final t = e.trim();
          if (t.isNotEmpty) {
            out.add(t);
          }
        }
      }
      return out;
    }
  }
  return const <String>[];
}

bool? _readOptionalBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final t = value.trim().toLowerCase();
      if (t == 'true') {
        return true;
      }
      if (t == 'false') {
        return false;
      }
    }
    if (value is num) {
      if (value == 1) {
        return true;
      }
      if (value == 0) {
        return false;
      }
    }
  }
  return null;
}
