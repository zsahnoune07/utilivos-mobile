import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/tool_manifest/tool_manifest_models.dart';
import 'package:utilivo_mobile/core/tool_manifest/tool_manifest_reader.dart';

void main() {
  group('parseManifestMap', () {
    test('parses min_app_version and mixed permissions', () {
      final m = parseManifestMap(<String, dynamic>{
        'min_app_version': '1.2.0',
        'permissions': <dynamic>[
          'storage',
          <String, dynamic>{
            'type': 'camera',
            'rationale': 'Scan codes',
          },
        ],
      });
      expect(m.minAppVersion, '1.2.0');
      expect(m.permissions.length, 2);
      expect(m.permissions[0].type, 'storage');
      expect(m.permissions[1].type, 'camera');
      expect(m.permissions[1].rationale, 'Scan codes');
      final system = m.systemPermissions.toList();
      expect(system.length, 1);
      expect(system[0].type, 'camera');
    });

    test('systemTypes includes location', () {
      expect(ParsedToolManifest.isSystemType('location'), isTrue);
      expect(ParsedToolManifest.isHostOnlyType('storage'), isTrue);
    });
  });
}
