/// Values stored in [InstalledTools.status] (Drift).
abstract final class InstallToolRowStatus {
  InstallToolRowStatus._();

  static const String installed = 'installed';
  static const String updating = 'updating';
  static const String failed = 'failed';
}
