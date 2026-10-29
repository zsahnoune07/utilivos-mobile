import 'dart:async';
import 'dart:math';

import 'device_id_store.dart';

class DeviceIdentityManager {
  DeviceIdentityManager({required DeviceIdStore store}) : _store = store;

  final DeviceIdStore _store;
  String? _currentDeviceId;

  String? get currentDeviceId => _currentDeviceId;

  Future<String> ensureDeviceId() async {
    if (_currentDeviceId != null && _currentDeviceId!.trim().isNotEmpty) {
      return _currentDeviceId!;
    }

    final persisted = (await _store
            .read()
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () => null,
            ))
        ?.trim();
    if (persisted != null && persisted.isNotEmpty) {
      _currentDeviceId = persisted;
      return persisted;
    }

    final generated = _generateDeviceId();
    try {
      await _store.write(generated).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // Keep in-memory id so the app can proceed if secure storage is wedged.
    }
    _currentDeviceId = generated;
    return generated;
  }

  Future<String> regenerateDeviceId() async {
    final generated = _generateDeviceId();
    try {
      await _store.write(generated).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // Same as [ensureDeviceId]: prefer a usable session over a hung write.
    }
    _currentDeviceId = generated;
    return generated;
  }

  Future<void> clear() async {
    _currentDeviceId = null;
    await _store.clear();
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final now = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(16);
    final entropy = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'dev-$now-$entropy';
  }
}
