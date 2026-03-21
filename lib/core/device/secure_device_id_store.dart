import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_id_store.dart';

class SecureDeviceIdStore implements DeviceIdStore {
  SecureDeviceIdStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivo_device_id';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<String?> read() {
    return _storage.read(key: storageKey);
  }

  @override
  Future<void> write(String deviceId) {
    return _storage.write(key: storageKey, value: deviceId);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
