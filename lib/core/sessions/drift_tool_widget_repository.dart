import 'package:drift/drift.dart';

import '../persistence/app_database.dart';
import 'tool_home_widget_record.dart';
import 'tool_widget_repository.dart';

class DriftToolWidgetRepository implements ToolWidgetRepository {
  DriftToolWidgetRepository(this._db);

  final AppDatabase _db;

  ToolHomeWidgetRecord _fromRow(ToolWidgetRow row) {
    return ToolHomeWidgetRecord(
      id: row.id,
      platform: row.platform,
      platformWidgetId: row.platformWidgetId,
      toolId: row.toolId,
      toolSlug: row.toolSlug,
      toolName: row.toolName,
      iconSource: row.iconSource,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastLaunchedAt: row.lastLaunchedAt,
      configurationJson: row.configurationJson,
    );
  }

  @override
  Future<List<ToolHomeWidgetRecord>> listAll() async {
    final rows = await _db.select(_db.toolWidgets).get();
    rows.sort((ToolWidgetRow a, ToolWidgetRow b) {
      final c = b.updatedAt.compareTo(a.updatedAt);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<ToolHomeWidgetRecord?> getById(String id) async {
    final row = await (_db.select(_db.toolWidgets)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<ToolHomeWidgetRecord?> findByPlatformWidget({
    required String platform,
    required String platformWidgetId,
  }) async {
    final row = await (_db.select(_db.toolWidgets)
          ..where(
            (t) =>
                t.platform.equals(platform) &
                t.platformWidgetId.equals(platformWidgetId),
          ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> upsert(ToolHomeWidgetRecord record) async {
    await _db.transaction(() async {
      await (_db.delete(_db.toolWidgets)
            ..where(
              (t) =>
                  t.platform.equals(record.platform) &
                  t.platformWidgetId.equals(record.platformWidgetId),
            ))
          .go();
      await _db.into(_db.toolWidgets).insert(
            ToolWidgetsCompanion.insert(
              id: record.id,
              platform: record.platform,
              platformWidgetId: record.platformWidgetId,
              toolId: record.toolId,
              toolSlug: record.toolSlug,
              toolName: record.toolName,
              iconSource: Value(record.iconSource),
              createdAt: record.createdAt,
              updatedAt: record.updatedAt,
              lastLaunchedAt: Value(record.lastLaunchedAt),
              configurationJson: Value(record.configurationJson),
            ),
          );
    });
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.toolWidgets)..where((t) => t.id.equals(id))).go();
  }
}
