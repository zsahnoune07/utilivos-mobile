import 'ephemeral_runtime_state_repository.dart';
import 'session_state_envelope.dart';

/// Per-launch ephemeral persistence and janitorial cleanup.
class RuntimeStateScopeService {
  RuntimeStateScopeService(this._ephemeral);

  final EphemeralRuntimeStateRepository _ephemeral;

  Future<EphemeralRuntimeState?> loadEphemeral(String launchToken) {
    return _ephemeral.get(launchToken);
  }

  Future<void> persistEphemeral({
    required String launchToken,
    required String toolId,
    required String toolSlug,
    required String stateJson,
    DateTime? expiresAt,
  }) async {
    SessionStateEnvelope.enforceMaxUtf8Length(stateJson);
    final now = DateTime.now().toUtc();
    final existing = await _ephemeral.get(launchToken);
    await _ephemeral.upsert(
      EphemeralRuntimeState(
        launchToken: launchToken,
        toolId: toolId,
        toolSlug: toolSlug,
        stateJson: stateJson,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> clearLaunch(String launchToken) {
    return _ephemeral.delete(launchToken);
  }

  /// Deletes expired rows and rows not updated since [abandonedTtl] ago.
  Future<EphemeralCleanupSummary> runMaintenance({
    DateTime? now,
    Duration abandonedTtl = const Duration(days: 7),
  }) async {
    final n = now ?? DateTime.now().toUtc();
    final expired = await _ephemeral.deleteExpiredBefore(n);
    final stale = await _ephemeral.deleteUpdatedBefore(n.subtract(abandonedTtl));
    return EphemeralCleanupSummary(
      expiredRowsRemoved: expired,
      staleRowsRemoved: stale,
    );
  }
}

class EphemeralCleanupSummary {
  const EphemeralCleanupSummary({
    required this.expiredRowsRemoved,
    required this.staleRowsRemoved,
  });

  final int expiredRowsRemoved;
  final int staleRowsRemoved;
}
