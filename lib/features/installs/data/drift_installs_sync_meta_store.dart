import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'installs_sync_meta_store.dart';

/// Persists installs sync timestamps in [AppDatabase] ([SyncKv]).
class DriftInstallsSyncMetaStore implements InstallsSyncMetaStore {
  DriftInstallsSyncMetaStore(this._db);

  final AppDatabase _db;

  static const String _installsLastSyncedKey = 'installs_last_synced_at';

  @override
  Future<DateTime?> readLastSyncedAt() async {
    final row = await (_db.select(_db.syncKv)
          ..where((r) => r.rowKey.equals(_installsLastSyncedKey)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.trim())?.toUtc();
  }

  @override
  Future<void> writeLastSyncedAt(DateTime at) async {
    await _db.into(_db.syncKv).insertOnConflictUpdate(
      SyncKvCompanion.insert(
        rowKey: _installsLastSyncedKey,
        value: Value(at.toUtc().toIso8601String()),
      ),
    );
  }
}
