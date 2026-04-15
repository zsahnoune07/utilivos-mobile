class PluginDownloadGrant {
  const PluginDownloadGrant({
    required this.url,
    required this.version,
    this.expiresAt,
    this.expiresInSeconds,
    this.method,
    this.checksumSha256,
    this.tier,
    this.publisherId,
    this.signature,
    this.signatureAlgorithm,
    this.signingPublicKey,
    this.signingPublicKeyId,
    this.signaturePayload,
    this.entitlementVerifiedAt,
    this.runtimeMode,
    this.runtimeContractVersion,
    this.designSystemVersion,
    this.sdkVersion,
  });

  final String url;
  final String version;
  final DateTime? expiresAt;
  /// Server-computed grant lifetime (optional; informational).
  final int? expiresInSeconds;
  /// HTTP method for [url], typically GET (optional).
  final String? method;
  final String? checksumSha256;
  final String? tier;
  final String? publisherId;
  final String? signature;
  final String? signatureAlgorithm;
  final String? signingPublicKey;
  final String? signingPublicKeyId;
  final BundleSignaturePayload? signaturePayload;
  final DateTime? entitlementVerifiedAt;
  final String? runtimeMode;
  final int? runtimeContractVersion;
  final int? designSystemVersion;
  final String? sdkVersion;

  factory PluginDownloadGrant.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final version = json['version'];
    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('Download payload must include url.');
    }
    if (version is! String || version.trim().isEmpty) {
      throw const FormatException('Download payload must include version.');
    }

    return PluginDownloadGrant(
      url: url,
      version: version,
      expiresAt: _readOptionalDateTime(json['expires_at']),
      expiresInSeconds: _readOptionalInt(json, const <String>[
        'expires_in_seconds',
      ]),
      method: _readOptionalString(json, const <String>['method']),
      checksumSha256: _readOptionalString(json, const <String>[
        'checksum_sha256',
        'sha256',
        'bundle_sha256',
      ]),
      tier: _readOptionalString(json, const <String>['tier']),
      publisherId: _readOptionalString(json, const <String>['publisher_id']),
      signature: _readOptionalString(json, const <String>['signature']),
      signatureAlgorithm: _readOptionalString(json, const <String>[
        'signature_algorithm',
      ]),
      signingPublicKey: _readOptionalString(json, const <String>[
        'signing_public_key',
      ]),
      signingPublicKeyId: _readOptionalString(json, const <String>[
        'signing_public_key_id',
      ]),
      signaturePayload: _readOptionalSigningPayload(json['signature_payload']),
      entitlementVerifiedAt: _readOptionalDateTime(
        json['entitlement_verified_at'],
      ),
      runtimeMode: _readOptionalString(json, const <String>['runtime_mode']),
      runtimeContractVersion: _readOptionalInt(json, const <String>[
        'runtime_contract_version',
      ]),
      designSystemVersion: _readOptionalInt(json, const <String>[
        'design_system_version',
      ]),
      sdkVersion: _readOptionalString(json, const <String>['sdk_version']),
    );
  }
}

class BundleSignaturePayload {
  const BundleSignaturePayload({
    required this.schemaVersion,
    required this.slug,
    required this.version,
    required this.bundleSha256,
    required this.tier,
    required this.publisherId,
  });

  final int schemaVersion;
  final String slug;
  final String version;
  final String bundleSha256;
  final String tier;
  final String publisherId;

  factory BundleSignaturePayload.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    final slug = json['slug'];
    final version = json['version'];
    final bundleSha256 = json['bundle_sha256'];
    final tier = json['tier'];
    final publisherId = json['publisher_id'];
    if (schemaVersion is! int ||
        slug is! String ||
        version is! String ||
        bundleSha256 is! String ||
        tier is! String ||
        publisherId is! String) {
      throw const FormatException(
        'Invalid signature payload in download grant.',
      );
    }
    return BundleSignaturePayload(
      schemaVersion: schemaVersion,
      slug: slug.trim(),
      version: version.trim(),
      bundleSha256: bundleSha256.trim().toLowerCase(),
      tier: tier.trim().toLowerCase(),
      publisherId: publisherId.trim(),
    );
  }
}

DateTime? _readOptionalDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.parse(raw).toUtc();
}

String? _readOptionalString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is! String) {
      continue;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    return trimmed;
  }
  return null;
}

BundleSignaturePayload? _readOptionalSigningPayload(Object? raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  return BundleSignaturePayload.fromJson(raw);
}

int? _readOptionalInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is int) {
      return raw;
    }
  }
  return null;
}
