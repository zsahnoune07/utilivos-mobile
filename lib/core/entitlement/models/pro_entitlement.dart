class ProEntitlement {
  const ProEntitlement({
    required this.proActive,
    required this.updatedAt,
    this.entitlementType,
    this.productId,
    this.purchaseToken,
    this.storeExpiresAt,
    this.assertionToken,
    this.assertionExpiresAt,
    this.graceExpiresAt,
    this.verificationState,
    this.lastVerificationAt,
    this.verificationSource,
  });

  final bool proActive;
  final DateTime updatedAt;
  final String? entitlementType;
  final String? productId;
  final String? purchaseToken;
  final DateTime? storeExpiresAt;
  final String? assertionToken;
  final DateTime? assertionExpiresAt;
  final DateTime? graceExpiresAt;
  final String? verificationState;
  final DateTime? lastVerificationAt;
  final String? verificationSource;

  static ProEntitlement inactive() {
    return ProEntitlement(
      proActive: false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pro_active': proActive,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'entitlement_type': entitlementType,
      'product_id': productId,
      'purchase_token': purchaseToken,
      'store_expires_at': storeExpiresAt?.toUtc().toIso8601String(),
      'assertion_token': assertionToken,
      'assertion_expires_at': assertionExpiresAt?.toUtc().toIso8601String(),
      'grace_expires_at': graceExpiresAt?.toUtc().toIso8601String(),
      'verification_state': verificationState,
      'last_verification_at': lastVerificationAt?.toUtc().toIso8601String(),
      'verification_source': verificationSource,
    };
  }

  factory ProEntitlement.fromJson(Map<String, dynamic> json) {
    final proActive = json['pro_active'];
    final rawUpdatedAt = json['updated_at'];
    if (proActive is! bool || rawUpdatedAt is! String) {
      throw const FormatException('Invalid entitlement payload.');
    }

    return ProEntitlement(
      proActive: proActive,
      updatedAt: DateTime.parse(rawUpdatedAt).toUtc(),
      entitlementType: _readOptionalString(json['entitlement_type']),
      productId: _readOptionalString(json['product_id']),
      purchaseToken: _readOptionalString(json['purchase_token']),
      storeExpiresAt: _readOptionalDateTime(json['store_expires_at']),
      assertionToken: _readOptionalString(json['assertion_token']),
      assertionExpiresAt: _readOptionalDateTime(json['assertion_expires_at']),
      graceExpiresAt: _readOptionalDateTime(json['grace_expires_at']),
      verificationState: _readOptionalString(json['verification_state']),
      lastVerificationAt: _readOptionalDateTime(json['last_verification_at']),
      verificationSource: _readOptionalString(json['verification_source']),
    );
  }

  static const Object _unset = Object();

  ProEntitlement copyWith({
    bool? proActive,
    DateTime? updatedAt,
    Object? entitlementType = _unset,
    Object? productId = _unset,
    Object? purchaseToken = _unset,
    Object? storeExpiresAt = _unset,
    Object? assertionToken = _unset,
    Object? assertionExpiresAt = _unset,
    Object? graceExpiresAt = _unset,
    Object? verificationState = _unset,
    Object? lastVerificationAt = _unset,
    Object? verificationSource = _unset,
  }) {
    return ProEntitlement(
      proActive: proActive ?? this.proActive,
      updatedAt: updatedAt ?? this.updatedAt,
      entitlementType: identical(entitlementType, _unset)
          ? this.entitlementType
          : entitlementType as String?,
      productId: identical(productId, _unset)
          ? this.productId
          : productId as String?,
      purchaseToken: identical(purchaseToken, _unset)
          ? this.purchaseToken
          : purchaseToken as String?,
      storeExpiresAt: identical(storeExpiresAt, _unset)
          ? this.storeExpiresAt
          : storeExpiresAt as DateTime?,
      assertionToken: identical(assertionToken, _unset)
          ? this.assertionToken
          : assertionToken as String?,
      assertionExpiresAt: identical(assertionExpiresAt, _unset)
          ? this.assertionExpiresAt
          : assertionExpiresAt as DateTime?,
      graceExpiresAt: identical(graceExpiresAt, _unset)
          ? this.graceExpiresAt
          : graceExpiresAt as DateTime?,
      verificationState: identical(verificationState, _unset)
          ? this.verificationState
          : verificationState as String?,
      lastVerificationAt: identical(lastVerificationAt, _unset)
          ? this.lastVerificationAt
          : lastVerificationAt as DateTime?,
      verificationSource: identical(verificationSource, _unset)
          ? this.verificationSource
          : verificationSource as String?,
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
  return raw;
}

DateTime? _readOptionalDateTime(Object? raw) {
  final rawString = _readOptionalString(raw);
  if (rawString == null) {
    return null;
  }
  return DateTime.parse(rawString).toUtc();
}
