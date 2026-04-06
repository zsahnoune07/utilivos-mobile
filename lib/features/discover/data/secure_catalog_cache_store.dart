import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'catalog_cache_store.dart';
import 'models/catalog_cache_snapshot.dart';

class SecureCatalogCacheStore implements CatalogCacheStore {
  SecureCatalogCacheStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivos_catalog_cache';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<CatalogCacheSnapshot> read() async {
    final rawPayload = await _storage.read(key: storageKey);
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return CatalogCacheSnapshot.empty;
    }

    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Stored catalog cache payload must be object.',
      );
    }

    return CatalogCacheSnapshot.fromJson(decoded);
  }

  @override
  Future<void> write(CatalogCacheSnapshot snapshot) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
