import 'package:drift/drift.dart';

import '../persistence/app_database.dart';
import 'ephemeral_runtime_state_repository.dart';

class DriftEphemeralRuntimeStateRepository
    implements EphemeralRuntimeStateRepository {
  DriftEphemeralRuntimeStateRepository(this._db);

  final AppDatabase _db;

  EphemeralRuntimeState _fromRow(EphemeralRuntimeStateRow row) {
    return EphemeralRuntimeState(
      launchToken: row.launchToken,
      toolId: row.toolId,
      toolSlug: row.toolSlug,
      stateJson: row.stateJson,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      expiresAt: row.expiresAt,
    );
  }

  @override
  Future<EphemeralRuntimeState?> get(String launchToken) async {
    final row = await (_db.select(_db.ephemeralRuntimeStates)
          ..where((t) => t.launchToken.equals(launchToken)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> upsert(EphemeralRuntimeState state) async {
    await _db.into(_db.ephemeralRuntimeStates).insertOnConflictUpdate(
          EphemeralRuntimeStatesCompanion.insert(
            launchToken: state.launchToken,
            toolId: state.toolId,
            toolSlug: state.toolSlug,
            stateJson: state.stateJson,
            createdAt: state.createdAt,
            updatedAt: state.updatedAt,
            expiresAt: Value(state.expiresAt),
          ),
        );
  }

  @override
  Future<void> delete(String launchToken) async {
    await (_db.delete(_db.ephemeralRuntimeStates)
          ..where((t) => t.launchToken.equals(launchToken)))
        .go();
  }

  @override
  Future<int> deleteExpiredBefore(DateTime now) async {
    return (_db.delete(_db.ephemeralRuntimeStates)
          ..where(
            (t) =>
                t.expiresAt.isNotNull() & t.expiresAt.isSmallerThanValue(now),
          ))
        .go();
  }

  @override
  Future<int> deleteUpdatedBefore(DateTime threshold) async {
    return (_db.delete(_db.ephemeralRuntimeStates)
          ..where((t) => t.updatedAt.isSmallerThanValue(threshold)))
        .go();
  }
}
