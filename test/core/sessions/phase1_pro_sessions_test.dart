import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/persistence/app_database.dart';
import 'package:utilivo_mobile/core/sessions/drift_ephemeral_runtime_state_repository.dart';
import 'package:utilivo_mobile/core/sessions/drift_tool_session_repository.dart';
import 'package:utilivo_mobile/core/sessions/drift_tool_widget_repository.dart';
import 'package:utilivo_mobile/core/sessions/ephemeral_runtime_state_repository.dart';
import 'package:utilivo_mobile/core/sessions/runtime_state_scope_service.dart';
import 'package:utilivo_mobile/core/sessions/session_exceptions.dart';
import 'package:utilivo_mobile/core/sessions/session_state_envelope.dart';
import 'package:utilivo_mobile/core/sessions/tool_session_service.dart';
import 'package:utilivo_mobile/core/sessions/tool_widget_service.dart';

void main() {
  group('SessionStateEnvelope', () {
    test('roundTrip', () {
      final e = SessionStateEnvelope.build(
        toolSlug: 'demo',
        toolVersion: '1.0.0',
        payload: <String, dynamic>{'x': 1},
      );
      final again = SessionStateEnvelope.parse(e.serialize());
      expect(again.toolSlug, 'demo');
      expect(again.toolVersion, '1.0.0');
      expect(again.payload['x'], 1);
    });

    test('enforceMaxUtf8Length rejects oversized strings', () {
      final huge = 'x' * (SessionStateEnvelope.maxSerializedUtf8Bytes + 1);
      expect(
        () => SessionStateEnvelope.enforceMaxUtf8Length(huge),
        throwsA(isA<SessionStateTooLargeException>()),
      );
    });
  });

  group('ToolSessionService + Drift', () {
    late AppDatabase db;
    late ToolSessionService service;

    setUp(() {
      db = AppDatabase.memory();
      service = ToolSessionService(DriftToolSessionRepository(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('save list overwrite same name stable id', () async {
      final id1 = await service.saveNamedSession(
        toolId: 't1',
        toolSlug: 'slug',
        name: 'A',
        payload: <String, dynamic>{'k': 1},
      );
      final id2 = await service.saveNamedSession(
        toolId: 't1',
        toolSlug: 'slug',
        name: 'A',
        payload: <String, dynamic>{'k': 2},
      );
      expect(id2, id1);
      final list = await service.listSessions('t1');
      expect(list, hasLength(1));
      final env = await service.loadEnvelopeForSession(id1);
      expect(env?.payload['k'], 2);
    });

    test('rename conflicts', () async {
      await service.saveNamedSession(
        toolId: 't1',
        toolSlug: 's',
        name: 'one',
        payload: <String, dynamic>{},
      );
      final id2 = await service.saveNamedSession(
        toolId: 't1',
        toolSlug: 's',
        name: 'two',
        payload: <String, dynamic>{},
      );
      expect(
        () => service.renameSession(id: id2, newName: 'one'),
        throwsA(isA<SessionNameConflictException>()),
      );
    });

    test('saveNamedSession rejects empty name', () async {
      expect(
        () => service.saveNamedSession(
          toolId: 't',
          toolSlug: 's',
          name: '  ',
          payload: <String, dynamic>{},
        ),
        throwsArgumentError,
      );
    });

    test('updateNamedSessionState overwrites payload', () async {
      final id = await service.saveNamedSession(
        toolId: 't1',
        toolSlug: 'slug',
        name: 'S',
        payload: <String, dynamic>{'a': 1},
      );
      await service.updateNamedSessionState(
        id: id,
        payload: <String, dynamic>{'b': 2},
        toolVersion: '2.0.0',
      );
      final env = await service.loadEnvelopeForSession(id);
      expect(env?.payload['b'], 2);
      expect(env?.payload.containsKey('a'), isFalse);
      expect(env?.toolVersion, '2.0.0');
    });

    test('updateNamedSessionState missing id throws', () async {
      expect(
        () => service.updateNamedSessionState(
          id: 'nope',
          payload: <String, dynamic>{},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('RuntimeStateScopeService + Drift', () {
    late AppDatabase db;
    late RuntimeStateScopeService scope;

    setUp(() {
      db = AppDatabase.memory();
      scope = RuntimeStateScopeService(
        DriftEphemeralRuntimeStateRepository(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('persist load clear', () async {
      await scope.persistEphemeral(
        launchToken: 'lt1',
        toolId: 't',
        toolSlug: 's',
        stateJson: '{"a":1}',
      );
      final row = await scope.loadEphemeral('lt1');
      expect(row?.stateJson, '{"a":1}');
      await scope.clearLaunch('lt1');
      expect(await scope.loadEphemeral('lt1'), isNull);
    });

    test('runMaintenance removes expired and stale', () async {
      final repo = DriftEphemeralRuntimeStateRepository(db);
      final past = DateTime.utc(2020, 1, 1);
      final now = DateTime.utc(2025, 6, 1);
      await repo.upsert(
        EphemeralRuntimeState(
          launchToken: 'e1',
          toolId: 't',
          toolSlug: 's',
          stateJson: '{}',
          createdAt: past,
          updatedAt: past,
          expiresAt: DateTime.utc(2025, 1, 1),
        ),
      );
      await repo.upsert(
        EphemeralRuntimeState(
          launchToken: 'e2',
          toolId: 't',
          toolSlug: 's',
          stateJson: '{}',
          createdAt: past,
          updatedAt: past,
          expiresAt: null,
        ),
      );
      final summary = await scope.runMaintenance(
        now: now,
        abandonedTtl: const Duration(days: 1),
      );
      expect(summary.expiredRowsRemoved, 1);
      expect(summary.staleRowsRemoved, 1);
      expect(await repo.get('e1'), isNull);
      expect(await repo.get('e2'), isNull);
    });

    test('persistEphemeral rejects oversized json', () async {
      final pad =
          List.filled(SessionStateEnvelope.maxSerializedUtf8Bytes, 'a').join();
      final huge = '{"x":"$pad"}';
      expect(
        () => scope.persistEphemeral(
          launchToken: 'x',
          toolId: 't',
          toolSlug: 's',
          stateJson: huge,
        ),
        throwsA(isA<SessionStateTooLargeException>()),
      );
    });
  });

  group('ToolWidgetService + Drift', () {
    late AppDatabase db;
    late ToolWidgetService widgets;

    setUp(() {
      db = AppDatabase.memory();
      widgets = ToolWidgetService(DriftToolWidgetRepository(db));
    });

    tearDown(() async {
      await db.close();
    });

    test('upsert same platform widget id replaces single row', () async {
      await widgets.registerOrUpdateWidget(
        id: 'w1',
        platform: 'android',
        platformWidgetId: 'appwidget_42',
        toolId: 't',
        toolSlug: 's',
        toolName: 'Name A',
      );
      await widgets.registerOrUpdateWidget(
        id: 'w2',
        platform: 'android',
        platformWidgetId: 'appwidget_42',
        toolId: 't',
        toolSlug: 's',
        toolName: 'Name B',
      );
      final all = await widgets.listWidgets();
      expect(all, hasLength(1));
      expect(all.single.id, 'w2');
      expect(all.single.toolName, 'Name B');
    });

    test('findWidget by platform key', () async {
      await widgets.registerOrUpdateWidget(
        id: 'id1',
        platform: 'android',
        platformWidgetId: 'k',
        toolId: 't',
        toolSlug: 's',
        toolName: 'N',
      );
      final found = await widgets.findWidget(
        platform: 'android',
        platformWidgetId: 'k',
      );
      expect(found?.id, 'id1');
    });
  });
}
