import 'models/install_models.dart';

/// Result of reading persisted installs from [InstalledToolsStore], including
/// rows skipped due to invalid JSON or schema.
class InstalledToolsStoreReadResult {
  const InstalledToolsStoreReadResult({
    required this.installs,
    this.skippedInvalidRowCount = 0,
  });

  final List<DeviceInstallRecord> installs;
  final int skippedInvalidRowCount;
}
