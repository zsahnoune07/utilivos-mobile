import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/persistence/app_database.dart';
import 'package:utilivos_mobile/features/installs/data/drift_installed_tools_store.dart';
import 'package:utilivos_mobile/features/installs/data/models/install_models.dart';

void main() {
  test('DriftInstalledToolsStore round-trips installs', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final store = DriftInstalledToolsStore(db);
    final record = DeviceInstallRecord(
      id: 'i1',
      deviceId: 'd1',
      pluginId: 'p1',
      pluginSlug: 'alpha',
      source: 'marketplace',
      installedAt: DateTime.utc(2026, 1, 1),
      installedVersion: '1.0.0',
      updatedAt: DateTime.utc(2026, 1, 2),
      pluginName: 'Alpha',
    );

    await store.write(<DeviceInstallRecord>[record]);
    final read = await store.read();
    expect(read.installs.length, 1);
    expect(read.skippedInvalidRowCount, 0);
    expect(read.installs.single.pluginSlug, 'alpha');
    expect(read.installs.single.installedVersion, '1.0.0');
    expect(read.installs.single.pluginName, 'Alpha');

    final streamValues = await store.watch().take(1).toList();
    expect(streamValues.single.length, 1);
    expect(streamValues.single.single.pluginSlug, 'alpha');
  });
}
