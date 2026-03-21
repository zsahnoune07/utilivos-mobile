import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'entitlement_store.dart';
import 'models/premium_entitlement.dart';

class SecureEntitlementStore implements EntitlementStore {
  SecureEntitlementStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivo_premium_entitlement';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<PremiumEntitlement?> read() async {
    final rawPayload = await _storage.read(key: storageKey);
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }

    final parsed = jsonDecode(rawPayload);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException(
        'Stored entitlement payload must be an object.',
      );
    }
    return PremiumEntitlement.fromJson(parsed);
  }

  @override
  Future<void> write(PremiumEntitlement entitlement) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(entitlement.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
