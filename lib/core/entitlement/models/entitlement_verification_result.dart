class EntitlementVerificationResult {
  const EntitlementVerificationResult({
    required this.proActive,
    this.entitlementType,
    this.expiresAt,
    this.assertionToken,
    this.assertionExpiresAt,
    this.verificationState,
  });

  final bool proActive;
  final String? entitlementType;
  final DateTime? expiresAt;
  final String? assertionToken;
  final DateTime? assertionExpiresAt;
  final String? verificationState;

  factory EntitlementVerificationResult.fromJson(Map<String, dynamic> json) {
    final proActive = json['pro_active'];
    if (proActive is! bool) {
      throw const FormatException(
        'Entitlement verification payload must include boolean field "pro_active".',
      );
    }

    return EntitlementVerificationResult(
      proActive: proActive,
      entitlementType: _readOptionalString(json['entitlement_type']),
      expiresAt: _readOptionalDateTime(json['expires_at']),
      assertionToken: _readOptionalString(json['assertion_token']),
      assertionExpiresAt: _readOptionalDateTime(json['assertion_expires_at']),
      verificationState: _readOptionalString(json['verification_state']),
    );
  }
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

DateTime? _readOptionalDateTime(Object? raw) {
  final value = _readOptionalString(raw);
  if (value == null) {
    return null;
  }
  return DateTime.parse(value).toUtc();
}
