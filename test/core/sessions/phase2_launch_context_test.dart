import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/navigation/app_routes.dart';
import 'package:utilivo_mobile/core/navigation/deep_link_parser.dart';
import 'package:utilivo_mobile/core/sessions/tool_launch_context.dart';

void main() {
  test('ToolLaunchContext ephemeral uses ephemeral persistence flags', () {
    final c = ToolLaunchContext.ephemeral(toolId: 'tid', toolSlug: 's');
    expect(c.usesEphemeralPersistence, isTrue);
    expect(c.shouldClearEphemeralOnDispose, isTrue);
    expect(c.legacyRestoreRequested, isFalse);
    expect(c.launchToken, startsWith('launch_'));
  });

  test('ToolLaunchContext legacy restore uses disk path flags', () {
    final c = ToolLaunchContext.legacyFileRestore(toolId: 'tid', toolSlug: 's');
    expect(c.usesEphemeralPersistence, isFalse);
    expect(c.shouldClearEphemeralOnDispose, isFalse);
    expect(c.legacyRestoreRequested, isTrue);
  });

  test('ToolLaunchContext widget matches ephemeral persistence', () {
    final c = ToolLaunchContext.widgetLaunch(
      toolId: 'tid',
      toolSlug: 's',
      widgetInstanceId: 'w1',
    );
    expect(c.usesEphemeralPersistence, isTrue);
    expect(c.widgetInstanceId, 'w1');
  });

  test('pluginRuntime URL includes widget query', () {
    final u = AppRoutes.pluginRuntime(
      'demo',
      widgetInstanceId: 'abc',
    );
    expect(u, contains('widget=abc'));
  });

  test('parseAppDeepLink forwards widget query', () {
    final route = parseAppDeepLink(
      Uri.parse('utilivo://tool/my-tool?widget=wid1'),
    );
    expect(route, isNotNull);
    expect(route, contains('widget=wid1'));
  });


  test('ToolLaunchContext named session uses ephemeral persistence', () {
    final c = ToolLaunchContext.namedSessionLaunch(
      toolId: 'tid',
      toolSlug: 's',
      sessionId: 'sess_1',
    );
    expect(c.usesEphemeralPersistence, isTrue);
    expect(c.shouldClearEphemeralOnDispose, isTrue);
    expect(c.legacyRestoreRequested, isFalse);
    expect(c.sessionId, 'sess_1');
  });

  test('pluginRuntime URL includes session query', () {
    final u = AppRoutes.pluginRuntime(
      'demo',
      sessionId: 'abc',
    );
    expect(u, contains('session=abc'));
  });

  test('parseAppDeepLink forwards session query', () {
    final route = parseAppDeepLink(
      Uri.parse('utilivo://tool/my-tool?session=sid1'),
    );
    expect(route, isNotNull);
    expect(route, contains('session=sid1'));
  });


  test('parseAppDeepLink forwards name query', () {
    final route = parseAppDeepLink(
      Uri.parse('utilivo://tool/demo?widget=w1&name=My%20Tool'),
    );
    expect(route, isNotNull);
    expect(route, contains('name='));
    expect(route, anyOf(contains('My+Tool'), contains('My%20Tool')));
  });

}
