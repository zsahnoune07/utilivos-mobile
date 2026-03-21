import 'models/installs_organization_models.dart';

abstract interface class InstallsOrganizationStore {
  Future<InstallsOrganizationState> read();
  Future<void> write(InstallsOrganizationState state);
  Future<void> clear();
}
