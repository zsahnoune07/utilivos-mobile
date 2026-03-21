import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'installed_tools_store.dart';
import 'models/install_models.dart';

class SecureInstalledToolsStore implements InstalledToolsStore {
  SecureInstalledToolsStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivo_installed_tools';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<List<DeviceInstallRecord>> read() async {
    final rawPayload = await _storage.read(key: storageKey);
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return const <DeviceInstallRecord>[];
    }

    final decoded = jsonDecode(rawPayload);
    if (decoded is! List) {
      throw const FormatException(
        'Stored installed-tools payload must be a list.',
      );
    }

    return decoded
        .map((Object? entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Each installed-tools payload entry must be an object.',
            );
          }
          return DeviceInstallRecord.fromJson(entry);
        })
        .toList(growable: false);
  }

  @override
  Future<void> write(List<DeviceInstallRecord> installs) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(
        installs
            .map((DeviceInstallRecord install) => install.toJson())
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
