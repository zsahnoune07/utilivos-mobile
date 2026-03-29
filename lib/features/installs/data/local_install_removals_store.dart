/// Slugs the user removed on this device; used to ignore matching rows from
/// [/v1/installs] until they reinstall (no server DELETE yet).
abstract interface class LocalInstallRemovalsStore {
  Future<Set<String>> read();

  Future<void> write(Set<String> normalizedSlugs);
}

class NoopLocalInstallRemovalsStore implements LocalInstallRemovalsStore {
  const NoopLocalInstallRemovalsStore();

  @override
  Future<Set<String>> read() async => <String>{};

  @override
  Future<void> write(Set<String> normalizedSlugs) async {}
}
