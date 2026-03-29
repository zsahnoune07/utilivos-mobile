import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'install_tool_row_status.dart';
import 'installed_tools_read_result.dart';
import 'installed_tools_store.dart';
import 'models/install_models.dart';

/// Drift-backed install list; [metadataJson] mirrors [DeviceInstallRecord.toJson].
class DriftInstalledToolsStore implements InstalledToolsStore {
  DriftInstalledToolsStore(this._db);

  final AppDatabase _db;

  @override
  Future<InstalledToolsStoreReadResult> read() async {
    final rows = await _db.select(_db.installedTools).get();
    rows.sort((InstalledToolRow a, InstalledToolRow b) {
      final t = a.installedAt.compareTo(b.installedAt);
      if (t != 0) {
        return t;
      }
      return a.toolId.compareTo(b.toolId);
    });
    final out = <DeviceInstallRecord>[];
    var skipped = 0;
    for (final row in rows) {
      final record = _tryRecordFromRow(row);
      if (record != null) {
        out.add(record);
      } else {
        skipped++;
      }
    }
    return InstalledToolsStoreReadResult(
      installs: out,
      skippedInvalidRowCount: skipped,
    );
  }

  @override
  Future<void> write(List<DeviceInstallRecord> installs) async {
    await _db.transaction(() async {
      await _db.delete(_db.installedTools).go();
      for (final install in installs) {
        await _db.into(_db.installedTools).insert(_companionFor(install));
      }
    });
  }

  @override
  Future<void> clear() async {
    await _db.delete(_db.installedTools).go();
  }

  @override
  Stream<List<DeviceInstallRecord>> watch() {
    return _db
        .select(_db.installedTools)
        .watch()
        .map((List<InstalledToolRow> rows) {
                rows.sort((InstalledToolRow a, InstalledToolRow b) {
                  final t = a.installedAt.compareTo(b.installedAt);
                  if (t != 0) {
                    return t;
                  }
                  return a.toolId.compareTo(b.toolId);
                });
                final out = <DeviceInstallRecord>[];
                for (final row in rows) {
                  final record = _tryRecordFromRow(row);
                  if (record != null) {
                    out.add(record);
                  }
                }
                return out;
              });
  }

  static DeviceInstallRecord? _tryRecordFromRow(InstalledToolRow row) {
    try {
      final decoded = jsonDecode(row.metadataJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return DeviceInstallRecord.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static InstalledToolsCompanion _companionFor(DeviceInstallRecord install) {
    final updatedAt = install.updatedAt ?? install.installedAt;
    return InstalledToolsCompanion(
      toolId: Value(install.pluginSlug),
      version: Value(install.installedVersion ?? ''),
      installedAt: Value(install.installedAt),
      updatedAt: Value(updatedAt),
      status: const Value(InstallToolRowStatus.installed),
      source: Value(install.source),
      metadataJson: Value(jsonEncode(install.toJson())),
    );
  }
}
