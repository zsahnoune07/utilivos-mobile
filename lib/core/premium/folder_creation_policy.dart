import '../entitlement/entitlement_controller.dart';
import 'freemium_limits.dart';

abstract class FolderCreationPolicy {
  bool allowCreateFolder(int currentFolderCount);
}

class UnlimitedFolderCreationPolicy implements FolderCreationPolicy {
  const UnlimitedFolderCreationPolicy();

  @override
  bool allowCreateFolder(int currentFolderCount) => true;
}

class FreemiumFolderCreationPolicy implements FolderCreationPolicy {
  FreemiumFolderCreationPolicy(this._entitlement);

  final EntitlementController _entitlement;

  @override
  bool allowCreateFolder(int currentFolderCount) {
    if (_entitlement.hasPremiumAccess) {
      return true;
    }
    return currentFolderCount < FreemiumLimits.maxFolders;
  }
}
