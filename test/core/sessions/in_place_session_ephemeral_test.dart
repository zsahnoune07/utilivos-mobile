import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/persistence/app_database.dart';
import 'package:utilivos_mobile/core/sessions/drift_ephemeral_runtime_state_repository.dart';
import 'package:utilivos_mobile/core/sessions/drift_tool_session_repository.dart';
import 'package:utilivos_mobile/core/sessions/runtime_state_scope_service.dart';
import 'package:utilivos_mobile/core/sessions/session_snapshot_normalizer.dart';
import 'package:utilivos_mobile/core/sessions/tool_session_service.dart';

/// In-place session load must overwrite ephemeral storage for a fixed
/// launch token (same runtime instance), not create a new token.
void main() {
  test(
    'named session row normalizes to payload and persists under same launchToken',
    () async {
      final db = AppDatabase.memory();
      addTearDown(() async {
        await db.close();
      });
      final sessions = ToolSessionService(DriftToolSessionRepository(db));
      final scope = RuntimeStateScopeService(
        DriftEphemeralRuntimeStateRepository(db),
      );
      final id = await sessions.saveNamedSession(
        toolId: 't1',
        toolSlug: 'slug',
        name: 'Work',
        payload: <String, dynamic>{'field_a': 42},
      );
      final row = await sessions.getSession(id);
      expect(row, isNotNull);
      final ephemeralJson =
          SessionSnapshotNormalizer.ephemeralStateJsonFromNamedSessionRow(
        row!.stateJson,
      );
      const launchToken = 'launch_same_instance';
      await scope.persistEphemeral(
        launchToken: launchToken,
        toolId: 't1',
        toolSlug: 'slug',
        stateJson: ephemeralJson,
      );
      final ep = await scope.loadEphemeral(launchToken);
      expect(ep?.stateJson, isNotNull);
      expect(ep!.stateJson, contains('field_a'));
      expect(ep.stateJson, contains('42'));
    },
  );
}
