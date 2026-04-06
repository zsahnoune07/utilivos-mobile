import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'installs_sync_meta_store.dart';

class SecureInstallsSyncMetaStore implements InstallsSyncMetaStore {
  SecureInstallsSyncMetaStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultKey = 'utilivos_installs_last_synced_at';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<DateTime?> readLastSyncedAt() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(raw.trim()).toUtc();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeLastSyncedAt(DateTime at) {
    return _storage.write(key: storageKey, value: at.toUtc().toIso8601String());
  }
}
