import 'dart:async';

import 'installed_tools_read_result.dart';
import 'models/install_models.dart';

abstract interface class InstalledToolsStore {
  Future<InstalledToolsStoreReadResult> read();
  Future<void> write(List<DeviceInstallRecord> installs);
  Future<void> clear();

  /// Emits the current list whenever persisted installs change.
  Stream<List<DeviceInstallRecord>> watch();
}
