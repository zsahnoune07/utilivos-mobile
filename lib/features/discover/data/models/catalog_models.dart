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
    this.categoryColor,
    this.proPreview = false,
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
  final String? categoryColor;

  /// When this tool is Pro-tier ([isPro]), free users may install/run preview builds only if the API
  /// sets `pro_preview` / `premium_preview` / `allows_free_preview_install` to true.
  final bool proPreview;

  /// API may use `pro`, `paid`, or `premium` for the paid catalog tier (product copy: Pro).
  static bool tierIsPro(String pricingType) {
    final normalized = pricingType.trim().toLowerCase();
    return normalized == 'pro' ||
        normalized == 'paid' ||
        normalized == 'premium';
  }

  bool get isPro => tierIsPro(pricingType);

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
      thumbnailUrl: _readOptionalString(json, const <String>[
        'thumbnail_url',
        'ThumbnailUrl',
        'image_url',
        'ImageUrl',
        'logo_url',
        'LogoUrl',
        'icon_url',
        'IconUrl',
      ]),
      categoryColor: _readOptionalString(json, const <String>[
        'category_color',
        'CategoryColor',
      ]),
      proPreview: previewFromApi == true,
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
      'category_color': categoryColor,
      'pro_preview': proPreview,
    };
  }
}

class PluginVersionSummary {
  const PluginVersionSummary({
    required this.id,
    required this.version,
    this.changelog,
  });

  final String id;
  final String version;
  final String? changelog;

  factory PluginVersionSummary.fromJson(Map<String, dynamic> json) {
    return PluginVersionSummary(
      id: _readRequiredString(json, const <String>['id', 'ID']),
      version: _readRequiredString(json, const <String>['version', 'Version']),
      changelog: _readOptionalString(json, const <String>[
        'changelog',
        'Changelog',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'version': version,
      'changelog': changelog,
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
      return trimmed.isEmpty ? null : value;
    }
  }
  return null;
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
