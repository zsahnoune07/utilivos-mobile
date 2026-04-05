import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:utilivo_mobile/core/permissions/system_permission_port.dart';
import 'package:utilivo_mobile/core/permissions/tool_permission_coordinator.dart';
import 'package:utilivo_mobile/core/tool_manifest/tool_manifest_models.dart';
import 'package:utilivo_mobile/l10n/app_localizations.dart';
import 'package:utilivo_mobile/l10n/app_localizations_en.dart';

class _FakePort implements SystemPermissionPort {
  _FakePort(this.initial, {this.requestResult});

  final Map<Permission, PermissionStatus> initial;
  final PermissionStatus? requestResult;
  int requestCount = 0;

  @override
  Future<PermissionStatus> status(Permission permission) async {
    return initial[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    requestCount++;
    final next = requestResult ?? PermissionStatus.granted;
    initial[permission] = next;
    return next;
  }

  @override
  Future<bool> openOsSettings() async => true;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

ParsedToolManifest _manifestCamera() {
  return const ParsedToolManifest(
    permissions: <ToolManifestPermission>[
      ToolManifestPermission(type: 'camera', rationale: 'Need camera'),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('granted status skips dialog', (WidgetTester tester) async {
    late ToolPermissionFlowResult result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                final port = _FakePort(<Permission, PermissionStatus>{
                  Permission.camera: PermissionStatus.granted,
                });
                result = await ToolPermissionCoordinator(port: port)
                    .ensureSystemPermissions(
                      context: context,
                      manifest: _manifestCamera(),
                      l10n: AppLocalizationsEn(),
                    );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(result, ToolPermissionFlowResult.granted);
  });

  testWidgets('shows rationale then requests', (WidgetTester tester) async {
    late ToolPermissionFlowResult result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                final port = _FakePort(<Permission, PermissionStatus>{
                  Permission.camera: PermissionStatus.denied,
                });
                result = await ToolPermissionCoordinator(port: port)
                    .ensureSystemPermissions(
                      context: context,
                      manifest: _manifestCamera(),
                      l10n: AppLocalizationsEn(),
                    );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, ToolPermissionFlowResult.granted);
  });

  testWidgets('cancel on rationale', (WidgetTester tester) async {
    late ToolPermissionFlowResult result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                final port = _FakePort(<Permission, PermissionStatus>{
                  Permission.camera: PermissionStatus.denied,
                });
                result = await ToolPermissionCoordinator(port: port)
                    .ensureSystemPermissions(
                      context: context,
                      manifest: _manifestCamera(),
                      l10n: AppLocalizationsEn(),
                    );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, ToolPermissionFlowResult.cancelled);
  });

  testWidgets('permanently denied before dialog', (WidgetTester tester) async {
    late ToolPermissionFlowResult result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                final port = _FakePort(<Permission, PermissionStatus>{
                  Permission.camera: PermissionStatus.permanentlyDenied,
                });
                result = await ToolPermissionCoordinator(port: port)
                    .ensureSystemPermissions(
                      context: context,
                      manifest: _manifestCamera(),
                      l10n: AppLocalizationsEn(),
                    );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(result, ToolPermissionFlowResult.permanentlyDenied);
  });

  testWidgets('denied after OS request', (WidgetTester tester) async {
    late ToolPermissionFlowResult result;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                final port = _FakePort(
                  <Permission, PermissionStatus>{
                    Permission.camera: PermissionStatus.denied,
                  },
                  requestResult: PermissionStatus.denied,
                );
                result = await ToolPermissionCoordinator(port: port)
                    .ensureSystemPermissions(
                      context: context,
                      manifest: _manifestCamera(),
                      l10n: AppLocalizationsEn(),
                    );
              },
              child: const Text('go'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, ToolPermissionFlowResult.denied);
  });
}
