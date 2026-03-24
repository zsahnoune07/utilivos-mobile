/// Persists lightweight metadata for installs sync (e.g. last successful sync time).
abstract interface class InstallsSyncMetaStore {
  Future<DateTime?> readLastSyncedAt();

  Future<void> writeLastSyncedAt(DateTime at);
}

/// No-op implementation for tests and optional omission.
class NoopInstallsSyncMetaStore implements InstallsSyncMetaStore {
  const NoopInstallsSyncMetaStore();

  @override
  Future<DateTime?> readLastSyncedAt() async => null;

  @override
  Future<void> writeLastSyncedAt(DateTime at) async {}
}
