import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Verifies the integration_test harness. Run from repo root:
/// `flutter test integration_test/app_binding_test.dart`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration binding pumps a trivial widget', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Text('integration_ok')));
    expect(find.text('integration_ok'), findsOneWidget);
  });
}
