import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'installs_organization_store.dart';
import 'models/installs_organization_models.dart';

class SecureInstallsOrganizationStore implements InstallsOrganizationStore {
  SecureInstallsOrganizationStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivo_installs_organization';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<InstallsOrganizationState> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return InstallsOrganizationState.empty;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Stored installs organization payload must be an object.',
      );
    }
    return InstallsOrganizationState.fromJson(decoded);
  }

  @override
  Future<void> write(InstallsOrganizationState state) {
    return _storage.write(key: storageKey, value: jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
