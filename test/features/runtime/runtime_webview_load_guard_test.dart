import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/features/runtime/application/runtime_webview_load_guard.dart';

void main() {
  test('clear before timeout prevents onTimeout', () async {
    var fired = false;
    final guard = RuntimeWebViewLoadGuard(
      onTimeout: () => fired = true,
      timeout: const Duration(milliseconds: 50),
    );
    addTearDown(guard.dispose);

    guard.arm();
    guard.clear();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, false);
  });

  test('arm without clear invokes onTimeout', () async {
    var fired = false;
    final guard = RuntimeWebViewLoadGuard(
      onTimeout: () => fired = true,
      timeout: const Duration(milliseconds: 40),
    );
    addTearDown(guard.dispose);

    guard.arm();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fired, true);
  });

  test('re-arm resets deadline', () async {
    var count = 0;
    final guard = RuntimeWebViewLoadGuard(
      onTimeout: () => count++,
      timeout: const Duration(milliseconds: 60),
    );
    addTearDown(guard.dispose);

    guard.arm();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    guard.arm();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(count, 0);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(count, 1);
  });
}
