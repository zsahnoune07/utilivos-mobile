import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/features/installs/data/models/install_models.dart';
import 'package:utilivos_mobile/core/notifications/update_notification_evaluator.dart';

DeviceInstallRecord _row({
  required String slug,
  required bool updateAvailable,
  String? installed,
  String? latest,
}) {
  final now = DateTime.now().toUtc();
  return DeviceInstallRecord(
    id: 'id-$slug',
    deviceId: 'd',
    pluginId: 'p-$slug',
    pluginSlug: slug,
    source: 'test',
    installedAt: now,
    installedVersion: installed,
    latestAvailableVersion: latest,
    updateAvailable: updateAvailable,
    lastUpdateCheckAt: now,
  );
}

void main() {
  test('findNewlyNoteworthyUpdates notifies on transition to update available', () {
    final before = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: false,
        installed: '1.0.0',
        latest: '1.0.0',
      ),
    ];
    final after = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: true,
        installed: '1.0.0',
        latest: '1.1.0',
      ),
    ];
    final fresh = findNewlyNoteworthyUpdates(
      before: before,
      after: after,
      dedupeKeys: <String>{},
      restrictToWidgetSlugs: false,
      widgetSlugs: <String>{},
    );
    expect(fresh, hasLength(1));
    expect(fresh.first.pluginSlug, 'a');
  });

  test('dedupeKeys suppresses repeat', () {
    final before = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: false,
        installed: '1.0.0',
        latest: '1.0.0',
      ),
    ];
    final after = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: true,
        installed: '1.0.0',
        latest: '1.1.0',
      ),
    ];
    final key = updateDedupeKey('a', '1.1.0');
    final fresh = findNewlyNoteworthyUpdates(
      before: before,
      after: after,
      dedupeKeys: <String>{key},
      restrictToWidgetSlugs: false,
      widgetSlugs: <String>{},
    );
    expect(fresh, isEmpty);
  });

  test('widget-only filter', () {
    final before = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: false,
        installed: '1.0.0',
        latest: '1.0.0',
      ),
    ];
    final after = <DeviceInstallRecord>[
      _row(
        slug: 'a',
        updateAvailable: true,
        installed: '1.0.0',
        latest: '1.1.0',
      ),
    ];
    final fresh = findNewlyNoteworthyUpdates(
      before: before,
      after: after,
      dedupeKeys: <String>{},
      restrictToWidgetSlugs: true,
      widgetSlugs: <String>{'b'},
    );
    expect(fresh, isEmpty);
  });
}
