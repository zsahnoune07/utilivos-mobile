import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'catalog_cache_store.dart';
import 'models/catalog_cache_snapshot.dart';
import 'models/catalog_models.dart';

/// Normalized catalog cache in SQLite (replaces monolithic secure JSON blob).
class DriftCatalogCacheStore implements CatalogCacheStore {
  DriftCatalogCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<CatalogCacheSnapshot> read() async {
    return _db.transaction(() async {
      final catRow = await _db.select(_db.catCategories).getSingleOrNull();
      CachedCategories? categories;
      if (catRow != null) {
        final rawItems = jsonDecode(catRow.itemsJson);
        if (rawItems is List) {
          final items = rawItems
              .map((Object? e) {
                if (e is! Map<String, dynamic>) {
                  throw const FormatException('Category cache item must be an object.');
                }
                return CatalogCategory.fromJson(e);
              })
              .toList(growable: false);
          categories = CachedCategories(items: items, cachedAt: catRow.cachedAt);
        }
      }

      final pageRows = await _db.select(_db.catPluginPages).get();
      final pluginPages = <String, CachedPluginPage>{};
      for (final row in pageRows) {
        final rawItems = jsonDecode(row.itemsJson);
        if (rawItems is! List) {
          continue;
        }
        final items = rawItems
            .map((Object? e) {
              if (e is! Map<String, dynamic>) {
                throw const FormatException('Plugin page cache item must be an object.');
              }
              return CatalogPlugin.fromJson(e);
            })
            .toList(growable: false);
        pluginPages[row.pageKey] = CachedPluginPage(
          items: items,
          nextCursor: row.nextCursor,
          cachedAt: row.cachedAt,
        );
      }

      final detailRows = await _db.select(_db.catPluginDetails).get();
      final pluginDetails = <String, CachedPluginDetail>{};
      for (final row in detailRows) {
        final raw = jsonDecode(row.pluginJson);
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        pluginDetails[row.slugKey] = CachedPluginDetail(
          plugin: CatalogPlugin.fromJson(raw),
          cachedAt: row.cachedAt,
        );
      }

      final versionRows = await _db.select(_db.catPluginVersions).get();
      final pluginVersions = <String, CachedPluginVersions>{};
      for (final row in versionRows) {
        final rawItems = jsonDecode(row.itemsJson);
        if (rawItems is! List) {
          continue;
        }
        final items = rawItems
            .map((Object? e) {
              if (e is! Map<String, dynamic>) {
                throw const FormatException('Version cache item must be an object.');
              }
              return PluginVersionSummary.fromJson(e);
            })
            .toList(growable: false);
        pluginVersions[row.slugKey] = CachedPluginVersions(
          items: items,
          cachedAt: row.cachedAt,
        );
      }

      return CatalogCacheSnapshot(
        categories: categories,
        pluginPages: pluginPages,
        pluginDetails: pluginDetails,
        pluginVersions: pluginVersions,
      );
    });
  }

  @override
  Future<void> write(CatalogCacheSnapshot snapshot) async {
    await _db.transaction(() async {
      await _db.delete(_db.catCategories).go();
      await _db.delete(_db.catPluginPages).go();
      await _db.delete(_db.catPluginDetails).go();
      await _db.delete(_db.catPluginVersions).go();

      if (snapshot.categories != null) {
        final c = snapshot.categories!;
        await _db.into(_db.catCategories).insert(
          CatCategoriesCompanion.insert(
            itemsJson: jsonEncode(
              c.items.map((CatalogCategory e) => e.toJson()).toList(growable: false),
            ),
            cachedAt: c.cachedAt,
          ),
        );
      }

      for (final MapEntry<String, CachedPluginPage> e
          in snapshot.pluginPages.entries) {
        final CachedPluginPage p = e.value;
        await _db.into(_db.catPluginPages).insert(
          CatPluginPagesCompanion.insert(
            pageKey: e.key,
            itemsJson: jsonEncode(
              p.items.map((CatalogPlugin x) => x.toJson()).toList(growable: false),
            ),
            nextCursor: Value(p.nextCursor),
            cachedAt: p.cachedAt,
          ),
        );
      }

      for (final MapEntry<String, CachedPluginDetail> e
          in snapshot.pluginDetails.entries) {
        final CachedPluginDetail d = e.value;
        await _db.into(_db.catPluginDetails).insert(
          CatPluginDetailsCompanion.insert(
            slugKey: e.key,
            pluginJson: jsonEncode(d.plugin.toJson()),
            cachedAt: d.cachedAt,
          ),
        );
      }

      for (final MapEntry<String, CachedPluginVersions> e
          in snapshot.pluginVersions.entries) {
        final CachedPluginVersions v = e.value;
        await _db.into(_db.catPluginVersions).insert(
          CatPluginVersionsCompanion.insert(
            slugKey: e.key,
            itemsJson: jsonEncode(
              v.items
                  .map((PluginVersionSummary x) => x.toJson())
                  .toList(growable: false),
            ),
            cachedAt: v.cachedAt,
          ),
        );
      }
    });
  }

  @override
  Future<void> clear() async {
    await _db.transaction(() async {
      await _db.delete(_db.catCategories).go();
      await _db.delete(_db.catPluginPages).go();
      await _db.delete(_db.catPluginDetails).go();
      await _db.delete(_db.catPluginVersions).go();
    });
  }
}
