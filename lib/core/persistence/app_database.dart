import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Single-row categories list cache (JSON array + timestamp).
@DataClassName('CatCategoriesRow')
class CatCategories extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get itemsJson => text()();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Paginated plugin list cache rows (matches [CatalogCacheSnapshot.pluginPages] keys).
@DataClassName('CatPluginPageRow')
class CatPluginPages extends Table {
  TextColumn get pageKey => text()();

  TextColumn get itemsJson => text()();

  TextColumn get nextCursor => text().nullable()();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {pageKey};
}

@DataClassName('CatPluginDetailRow')
class CatPluginDetails extends Table {
  TextColumn get slugKey => text()();

  TextColumn get pluginJson => text()();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {slugKey};
}

@DataClassName('CatPluginVersionRow')
class CatPluginVersions extends Table {
  TextColumn get slugKey => text()();

  TextColumn get itemsJson => text()();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {slugKey};
}

/// Generic string key/value for sync and other lightweight metadata.
@DataClassName('SyncKvRow')
class SyncKv extends Table {
  TextColumn get rowKey => text()();

  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {rowKey};
}

/// Local installed tools (plugin slug is unique). [metadataJson] holds the full
/// install payload JSON for forward-compatible fields.
@DataClassName('InstalledToolRow')
class InstalledTools extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get toolId => text().unique()();

  TextColumn get version => text().withDefault(const Constant(''))();

  DateTimeColumn get installedAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get status => text().withDefault(const Constant('installed'))();

  TextColumn get source => text().nullable()();

  TextColumn get metadataJson => text()();
}

/// Named saved session for an installed tool (Pro). [stateJson] holds envelope JSON.
@DataClassName('ToolSessionRow')
class ToolSessions extends Table {
  TextColumn get id => text()();

  TextColumn get toolId => text()();

  TextColumn get toolSlug => text()();

  TextColumn get installId => text().nullable()();

  TextColumn get toolVersion => text().nullable()();

  TextColumn get name => text()();

  TextColumn get stateJson => text()();

  IntColumn get stateSchemaVersion =>
      integer().withDefault(const Constant(1))();

  TextColumn get toolManifestVersion => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  BoolColumn get isFavorite =>
      boolean().withDefault(const Constant(false))();

  TextColumn get previewText => text().nullable()();

  IntColumn get stateSizeBytes => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {toolId, name},
      ];
}

/// Per-launch ephemeral tool state; deleted on dispose or cleanup.
@DataClassName('EphemeralRuntimeStateRow')
class EphemeralRuntimeStates extends Table {
  TextColumn get launchToken => text()();

  TextColumn get toolId => text()();

  TextColumn get toolSlug => text()();

  TextColumn get stateJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {launchToken};
}

/// Home screen widget instance mapped to a tool (Phase 4+).
@DataClassName('ToolWidgetRow')
class ToolWidgets extends Table {
  TextColumn get id => text()();

  TextColumn get platform => text()();

  TextColumn get platformWidgetId => text()();

  TextColumn get toolId => text()();

  TextColumn get toolSlug => text()();

  TextColumn get toolName => text()();

  TextColumn get iconSource => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastLaunchedAt => dateTime().nullable()();

  TextColumn get configurationJson => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {platform, platformWidgetId},
      ];
}

@DriftDatabase(
  tables: <Type>[
    CatCategories,
    CatPluginPages,
    CatPluginDetails,
    CatPluginVersions,
    SyncKv,
    InstalledTools,
    ToolSessions,
    EphemeralRuntimeStates,
    ToolWidgets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Production DB under app documents (`utilivos_app.sqlite`).
  factory AppDatabase.createPersistent() {
    return AppDatabase(driftDatabase(name: 'utilivos_app'));
  }

  /// In-memory DB for tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS tool_sessions_tool_id_updated_at '
        'ON tool_sessions (tool_id, updated_at DESC)',
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(installedTools);
      }
      if (from < 3) {
        await m.createTable(toolSessions);
        await m.createTable(ephemeralRuntimeStates);
        await m.createTable(toolWidgets);
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS tool_sessions_tool_id_updated_at '
          'ON tool_sessions (tool_id, updated_at DESC)',
        );
      }
    },
  );
}
