import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'local_install_removals_store.dart';

/// Persists removal tombstones in [AppDatabase] ([SyncKv]).
class DriftLocalInstallRemovalsStore implements LocalInstallRemovalsStore {
  DriftLocalInstallRemovalsStore(this._db);

  final AppDatabase _db;

  static const String _rowKey = 'local_install_removal_slugs_v1';

  @override
  Future<Set<String>> read() async {
    final row = await (_db.select(_db.syncKv)
          ..where((r) => r.rowKey.equals(_rowKey)))
        .getSingleOrNull();
    final raw = row?.value;
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>{};
      }
      return decoded
          .map((e) => e.toString().trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> write(Set<String> normalizedSlugs) async {
    final sorted = normalizedSlugs.toList()..sort();
    await _db.into(_db.syncKv).insertOnConflictUpdate(
          SyncKvCompanion.insert(
            rowKey: _rowKey,
            value: Value(jsonEncode(sorted)),
          ),
        );
  }
}
