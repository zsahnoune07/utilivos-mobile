import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'downloaded_tool_bundle_store.dart';
import 'models/downloaded_tool_bundle.dart';

class SecureDownloadedToolBundleStore implements DownloadedToolBundleStore {
  SecureDownloadedToolBundleStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultStorageKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultStorageKey = 'utilivos_downloaded_tool_bundles';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<List<DownloadedToolBundle>> read() async {
    final rawPayload = await _storage.read(key: storageKey);
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return const <DownloadedToolBundle>[];
    }

    final decoded = jsonDecode(rawPayload);
    if (decoded is! List) {
      throw const FormatException(
        'Stored downloaded-bundles payload must be a list.',
      );
    }

    return decoded
        .map((Object? entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Each downloaded-bundle entry must be an object.',
            );
          }
          return DownloadedToolBundle.fromJson(entry);
        })
        .toList(growable: false);
  }

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(
        bundles
            .map((DownloadedToolBundle bundle) => bundle.toJson())
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
