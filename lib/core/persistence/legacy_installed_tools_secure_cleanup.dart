import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Best-effort removal of pre-Drift installed-tools payload from secure storage.
Future<void> deleteLegacyInstalledToolsSecureStorageKey() async {
  const storage = FlutterSecureStorage();
  await storage.delete(key: _legacyKey);
}

const String _legacyKey = 'utilivo_installed_tools';
