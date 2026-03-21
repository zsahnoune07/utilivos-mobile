class DownloadedToolBundle {
  const DownloadedToolBundle({
    required this.pluginSlug,
    required this.version,
    required this.localPath,
    required this.sha256,
    required this.downloadedAt,
    this.manifestPath,
    this.entryFilePath,
    this.extractedPath,
    this.pluginName,
    this.manifestVersion,
    this.category,
    this.iconPath,
    this.iconAccentColor,
    this.verifiedTier,
    this.publisherId,
    this.signature,
    this.signatureAlgorithm,
    this.signatureVerifiedAt,
    this.signatureSchemaVersion,
    this.entitlementVerifiedAt,
  });

  final String pluginSlug;
  final String version;
  final String localPath;
  final String sha256;
  final DateTime downloadedAt;
  final String? manifestPath;
  final String? entryFilePath;
  final String? extractedPath;
  final String? pluginName;
  final String? manifestVersion;
  final String? category;
  final String? iconPath;
  final String? iconAccentColor;
  final String? verifiedTier;
  final String? publisherId;
  final String? signature;
  final String? signatureAlgorithm;
  final DateTime? signatureVerifiedAt;
  final int? signatureSchemaVersion;
  final DateTime? entitlementVerifiedAt;

  bool get isRunnable {
    final entry = entryFilePath?.trim();
    return entry != null && entry.isNotEmpty;
  }

  factory DownloadedToolBundle.fromJson(Map<String, dynamic> json) {
    return DownloadedToolBundle(
      pluginSlug: _readRequiredString(json, 'plugin_slug'),
      version: _readRequiredString(json, 'version'),
      localPath: _readRequiredString(json, 'local_path'),
      sha256: _readRequiredString(json, 'sha256'),
      downloadedAt: DateTime.parse(
        _readRequiredString(json, 'downloaded_at'),
      ).toUtc(),
      manifestPath: _readOptionalString(json, 'manifest_path'),
      entryFilePath: _readOptionalString(json, 'entry_file_path'),
      extractedPath: _readOptionalString(json, 'extracted_path'),
      pluginName: _readOptionalString(json, 'plugin_name'),
      manifestVersion: _readOptionalString(json, 'manifest_version'),
      category: _readOptionalString(json, 'category'),
      iconPath: _readOptionalString(json, 'icon_path'),
      iconAccentColor: _readOptionalString(json, 'icon_accent_color'),
      verifiedTier: _readOptionalString(json, 'verified_tier'),
      publisherId: _readOptionalString(json, 'publisher_id'),
      signature: _readOptionalString(json, 'signature'),
      signatureAlgorithm: _readOptionalString(json, 'signature_algorithm'),
      signatureVerifiedAt: _readOptionalDateTime(json, 'signature_verified_at'),
      signatureSchemaVersion: _readOptionalInt(
        json,
        'signature_schema_version',
      ),
      entitlementVerifiedAt: _readOptionalDateTime(
        json,
        'entitlement_verified_at',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plugin_slug': pluginSlug,
      'version': version,
      'local_path': localPath,
      'sha256': sha256,
      'downloaded_at': downloadedAt.toUtc().toIso8601String(),
      'manifest_path': manifestPath,
      'entry_file_path': entryFilePath,
      'extracted_path': extractedPath,
      'plugin_name': pluginName,
      'manifest_version': manifestVersion,
      'category': category,
      'icon_path': iconPath,
      'icon_accent_color': iconAccentColor,
      'verified_tier': verifiedTier,
      'publisher_id': publisherId,
      'signature': signature,
      'signature_algorithm': signatureAlgorithm,
      'signature_verified_at': signatureVerifiedAt?.toUtc().toIso8601String(),
      'signature_schema_version': signatureSchemaVersion,
      'entitlement_verified_at': entitlementVerifiedAt
          ?.toUtc()
          .toIso8601String(),
    };
  }

  DownloadedToolBundle copyWith({
    String? pluginSlug,
    String? version,
    String? localPath,
    String? sha256,
    DateTime? downloadedAt,
    String? manifestPath,
    String? entryFilePath,
    String? extractedPath,
    String? pluginName,
    String? manifestVersion,
    String? category,
    String? iconPath,
    String? iconAccentColor,
    String? verifiedTier,
    String? publisherId,
    String? signature,
    String? signatureAlgorithm,
    DateTime? signatureVerifiedAt,
    int? signatureSchemaVersion,
    DateTime? entitlementVerifiedAt,
  }) {
    return DownloadedToolBundle(
      pluginSlug: pluginSlug ?? this.pluginSlug,
      version: version ?? this.version,
      localPath: localPath ?? this.localPath,
      sha256: sha256 ?? this.sha256,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      manifestPath: manifestPath ?? this.manifestPath,
      entryFilePath: entryFilePath ?? this.entryFilePath,
      extractedPath: extractedPath ?? this.extractedPath,
      pluginName: pluginName ?? this.pluginName,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      category: category ?? this.category,
      iconPath: iconPath ?? this.iconPath,
      iconAccentColor: iconAccentColor ?? this.iconAccentColor,
      verifiedTier: verifiedTier ?? this.verifiedTier,
      publisherId: publisherId ?? this.publisherId,
      signature: signature ?? this.signature,
      signatureAlgorithm: signatureAlgorithm ?? this.signatureAlgorithm,
      signatureVerifiedAt: signatureVerifiedAt ?? this.signatureVerifiedAt,
      signatureSchemaVersion:
          signatureSchemaVersion ?? this.signatureSchemaVersion,
      entitlementVerifiedAt:
          entitlementVerifiedAt ?? this.entitlementVerifiedAt,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Missing required field "$key".');
  }
  return raw.trim();
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _readOptionalDateTime(Map<String, dynamic> json, String key) {
  final raw = _readOptionalString(json, key);
  if (raw == null) {
    return null;
  }
  return DateTime.parse(raw).toUtc();
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is int) {
    return raw;
  }
  return null;
}
