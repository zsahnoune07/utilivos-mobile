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

@DriftDatabase(
  tables: <Type>[
    CatCategories,
    CatPluginPages,
    CatPluginDetails,
    CatPluginVersions,
    SyncKv,
    InstalledTools,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Production DB under app documents (`utilivo_app.sqlite`).
  factory AppDatabase.createPersistent() {
    return AppDatabase(driftDatabase(name: 'utilivo_app'));
  }

  /// In-memory DB for tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(installedTools);
      }
    },
  );
}
