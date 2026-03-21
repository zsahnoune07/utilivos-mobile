import 'models/install_models.dart';

abstract interface class InstalledToolsStore {
  Future<List<DeviceInstallRecord>> read();
  Future<void> write(List<DeviceInstallRecord> installs);
  Future<void> clear();
}
