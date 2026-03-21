import 'models/catalog_cache_snapshot.dart';

abstract interface class CatalogCacheStore {
  Future<CatalogCacheSnapshot> read();
  Future<void> write(CatalogCacheSnapshot snapshot);
  Future<void> clear();
}
