import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/device/device_id_store.dart';
import 'package:utilivos_mobile/core/device/device_identity_manager.dart';

void main() {
  test('creates and persists device id when store is empty', () async {
    final store = _InMemoryDeviceIdStore();
    final manager = DeviceIdentityManager(store: store);

    final first = await manager.ensureDeviceId();
    final second = await manager.ensureDeviceId();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(await store.read(), first);
  });

  test('restores persisted device id', () async {
    final store = _InMemoryDeviceIdStore(initialValue: 'dev-existing-id');
    final manager = DeviceIdentityManager(store: store);

    final restored = await manager.ensureDeviceId();

    expect(restored, 'dev-existing-id');
    expect(manager.currentDeviceId, 'dev-existing-id');
  });

  test('regenerate creates a new id and persists it', () async {
    final store = _InMemoryDeviceIdStore(initialValue: 'dev-old-id');
    final manager = DeviceIdentityManager(store: store);
    await manager.ensureDeviceId();

    final regenerated = await manager.regenerateDeviceId();

    expect(regenerated, isNot('dev-old-id'));
    expect(await store.read(), regenerated);
    expect(manager.currentDeviceId, regenerated);
  });
}

class _InMemoryDeviceIdStore implements DeviceIdStore {
  _InMemoryDeviceIdStore({String? initialValue}) : _value = initialValue;

  String? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<String?> read() async {
    return _value;
  }

  @override
  Future<void> write(String deviceId) async {
    _value = deviceId;
  }
}
