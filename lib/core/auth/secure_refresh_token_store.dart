import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'refresh_token_store.dart';

class SecureRefreshTokenStore implements RefreshTokenStore {
  SecureRefreshTokenStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivo_refresh_token';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<String?> read() {
    return _storage.read(key: storageKey);
  }

  @override
  Future<void> write(String token) {
    return _storage.write(key: storageKey, value: token);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
