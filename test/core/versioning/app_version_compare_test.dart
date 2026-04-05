import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/versioning/app_version_compare.dart';

void main() {
  group('normalizeAppVersionLabel', () {
    test('strips build suffix after +', () {
      expect(normalizeAppVersionLabel('1.2.3+45'), '1.2.3');
    });
  });

  group('isHostAppBelowMinimum', () {
    test('no minimum → never below', () {
      expect(
        isHostAppBelowMinimum(currentAppVersion: '0.0.1', minimumVersion: null),
        isFalse,
      );
      expect(
        isHostAppBelowMinimum(currentAppVersion: '0.0.1', minimumVersion: ''),
        isFalse,
      );
      expect(
        isHostAppBelowMinimum(currentAppVersion: '0.0.1', minimumVersion: '  '),
        isFalse,
      );
    });

    test('invalid minimum → do not block', () {
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '1.0.0',
          minimumVersion: 'x.y.z',
        ),
        isFalse,
      );
    });

    test('current below minimum', () {
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '1.0.0',
          minimumVersion: '1.0.1',
        ),
        isTrue,
      );
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '1.0.0+99',
          minimumVersion: '2',
        ),
        isTrue,
      );
    });

    test('current meets or exceeds minimum', () {
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '1.0.1',
          minimumVersion: '1.0.0',
        ),
        isFalse,
      );
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '2.0.0',
          minimumVersion: '1.9.9',
        ),
        isFalse,
      );
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: '1.0.0',
          minimumVersion: '1.0.0',
        ),
        isFalse,
      );
    });

    test('unparseable current with valid minimum → below', () {
      expect(
        isHostAppBelowMinimum(
          currentAppVersion: 'dev',
          minimumVersion: '1.0.0',
        ),
        isTrue,
      );
    });
  });

  group('compareAppVersionLabels', () {
    test('orders semver-like labels', () {
      expect(compareAppVersionLabels('1.0.0', '1.0.1'), lessThan(0));
      expect(compareAppVersionLabels('2', '1.9'), greaterThan(0));
    });
  });
}
