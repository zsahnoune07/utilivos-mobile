import 'package:drift/drift.dart';

import '../persistence/app_database.dart';
import 'named_tool_session.dart';
import 'session_exceptions.dart';
import 'tool_session_repository.dart';

class DriftToolSessionRepository implements ToolSessionRepository {
  DriftToolSessionRepository(this._db);

  final AppDatabase _db;

  NamedToolSession _fromRow(ToolSessionRow row) {
    return NamedToolSession(
      id: row.id,
      toolId: row.toolId,
      toolSlug: row.toolSlug,
      installId: row.installId,
      toolVersion: row.toolVersion,
      name: row.name,
      stateJson: row.stateJson,
      stateSchemaVersion: row.stateSchemaVersion,
      toolManifestVersion: row.toolManifestVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastOpenedAt: row.lastOpenedAt,
      isFavorite: row.isFavorite,
      previewText: row.previewText,
      stateSizeBytes: row.stateSizeBytes,
    );
  }

  ToolSessionsCompanion _companion(NamedToolSession s) {
    return ToolSessionsCompanion.insert(
      id: s.id,
      toolId: s.toolId,
      toolSlug: s.toolSlug,
      installId: Value(s.installId),
      toolVersion: Value(s.toolVersion),
      name: s.name,
      stateJson: s.stateJson,
      stateSchemaVersion: Value(s.stateSchemaVersion),
      toolManifestVersion: Value(s.toolManifestVersion),
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      lastOpenedAt: Value(s.lastOpenedAt),
      isFavorite: Value(s.isFavorite),
      previewText: Value(s.previewText),
      stateSizeBytes: Value(s.stateSizeBytes),
    );
  }

  @override
  Future<List<NamedToolSession>> listForTool(String toolId) async {
    final rows = await (_db.select(_db.toolSessions)
          ..where((t) => t.toolId.equals(toolId)))
        .get();
    rows.sort((ToolSessionRow a, ToolSessionRow b) {
      final c = b.updatedAt.compareTo(a.updatedAt);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<NamedToolSession?> getById(String id) async {
    final row = await (_db.select(_db.toolSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<NamedToolSession?> findByToolAndName({
    required String toolId,
    required String name,
  }) async {
    final row = await (_db.select(_db.toolSessions)
          ..where(
            (t) => t.toolId.equals(toolId) & t.name.equals(name),
          ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> putReplacingName(NamedToolSession session) async {
    await _db.transaction(() async {
      await (_db.delete(_db.toolSessions)
            ..where(
              (t) =>
                  t.toolId.equals(session.toolId) & t.name.equals(session.name),
            ))
          .go();
      await _db.into(_db.toolSessions).insert(_companion(session));
    });
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.toolSessions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> rename({required String id, required String newName}) async {
    final current = await getById(id);
    if (current == null) {
      return;
    }
    final other = await findByToolAndName(
      toolId: current.toolId,
      name: newName,
    );
    if (other != null && other.id != id) {
      throw SessionNameConflictException(current.toolId, newName);
    }
    await (_db.update(_db.toolSessions)..where((t) => t.id.equals(id))).write(
      ToolSessionsCompanion(
        name: Value(newName),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> touchLastOpened(String id) async {
    await (_db.update(_db.toolSessions)..where((t) => t.id.equals(id))).write(
      ToolSessionsCompanion(
        lastOpenedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
