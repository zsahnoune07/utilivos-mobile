import '../../features/discover/data/drift_catalog_cache_store.dart';
import '../../features/discover/data/secure_catalog_cache_store.dart';
import '../../features/installs/data/drift_installs_sync_meta_store.dart';
import '../../features/installs/data/secure_installs_sync_meta_store.dart';
import 'app_database.dart';
import 'legacy_installed_tools_secure_cleanup.dart';

/// One-time copy from legacy secure storage into Drift when Drift tables are empty.
Future<void> migrateSecureToolCachesToDriftIfNeeded(AppDatabase db) async {
  await deleteLegacyInstalledToolsSecureStorageKey();
  await _migrateCatalog(db);
  await _migrateInstallsSyncMeta(db);
}

Future<void> _migrateCatalog(AppDatabase db) async {
  final drift = DriftCatalogCacheStore(db);
  final current = await drift.read();
  if (current.categories != null || current.pluginPages.isNotEmpty) {
    return;
  }
  try {
    final secure = SecureCatalogCacheStore();
    final legacy = await secure.read();
    if (legacy.categories == null && legacy.pluginPages.isEmpty) {
      return;
    }
    await drift.write(legacy);
  } catch (_) {
    // Best-effort; fresh sync will repopulate.
  }
}

Future<void> _migrateInstallsSyncMeta(AppDatabase db) async {
  final drift = DriftInstallsSyncMetaStore(db);
  if (await drift.readLastSyncedAt() != null) {
    return;
  }
  try {
    final secure = SecureInstallsSyncMetaStore();
    final at = await secure.readLastSyncedAt();
    if (at != null) {
      await drift.writeLastSyncedAt(at);
    }
  } catch (_) {
    // Ignore.
  }
}
