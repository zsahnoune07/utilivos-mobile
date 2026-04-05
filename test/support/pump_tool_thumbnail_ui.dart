import 'package:flutter_test/flutter_test.dart';

/// Tool thumbnails use repeating placeholder animations while images load.
/// [WidgetTester.pumpAndSettle] never completes in that state; advance bounded
/// virtual time instead.
Future<void> pumpToolThumbnailUiSettled(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
