import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/persistence/app_database.dart';
import 'package:utilivo_mobile/features/discover/data/drift_catalog_cache_store.dart';
import 'package:utilivo_mobile/features/discover/data/models/catalog_cache_snapshot.dart';
import 'package:utilivo_mobile/features/discover/data/models/catalog_models.dart';

void main() {
  test('DriftCatalogCacheStore round-trips snapshot', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final store = DriftCatalogCacheStore(db);
    final now = DateTime.utc(2026, 3, 24, 12);
    final snapshot = CatalogCacheSnapshot(
      categories: CachedCategories(
        items: <CatalogCategory>[
          const CatalogCategory(
            id: 'c1',
            slug: 'util',
            name: 'Utilities',
          ),
        ],
        cachedAt: now,
      ),
      pluginPages: <String, CachedPluginPage>{
        'category=-|search=-|cursor=-|limit=20': CachedPluginPage(
          items: <CatalogPlugin>[
            const CatalogPlugin(
              id: 'p1',
              slug: 'alpha-tool',
              name: 'Alpha',
              categorySlug: 'util',
              categoryName: 'Utilities',
              pricingType: 'free',
              shortDescription: 'Short',
              currentVersionId: 'v1',
            ),
          ],
          nextCursor: 'next',
          cachedAt: now,
        ),
      },
      pluginDetails: <String, CachedPluginDetail>{
        'alpha-tool': CachedPluginDetail(
          plugin: const CatalogPlugin(
            id: 'p1',
            slug: 'alpha-tool',
            name: 'Alpha',
            categorySlug: 'util',
            categoryName: 'Utilities',
            pricingType: 'free',
            longDescription: 'Long body',
            currentVersionId: 'v1',
          ),
          cachedAt: now,
        ),
      },
      pluginVersions: <String, CachedPluginVersions>{
        'alpha-tool': CachedPluginVersions(
          items: <PluginVersionSummary>[
            const PluginVersionSummary(id: 'vid', version: '1.0.0'),
          ],
          cachedAt: now,
        ),
      },
    );

    await store.write(snapshot);
    final read = await store.read();

    expect(read.categories?.items, hasLength(1));
    expect(read.categories?.items.first.slug, 'util');
    expect(read.pluginPages, hasLength(1));
    expect(read.pluginPages.values.first.items.first.slug, 'alpha-tool');
    expect(read.pluginDetails['alpha-tool']?.plugin.longDescription, 'Long body');
    expect(read.pluginVersions['alpha-tool']?.items.first.version, '1.0.0');

    await store.clear();
    final cleared = await store.read();
    expect(cleared.categories, isNull);
    expect(cleared.pluginPages, isEmpty);
  });
}
