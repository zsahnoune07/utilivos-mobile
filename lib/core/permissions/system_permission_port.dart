import 'package:permission_handler/permission_handler.dart';

/// Test seam around OS permission queries (see [PermissionHandlerSystemPort]).
abstract class SystemPermissionPort {
  Future<PermissionStatus> status(Permission permission);

  Future<PermissionStatus> request(Permission permission);

  Future<bool> openOsSettings();
}

class PermissionHandlerSystemPort implements SystemPermissionPort {
  const PermissionHandlerSystemPort();

  @override
  Future<PermissionStatus> status(Permission permission) {
    return permission.status;
  }

  @override
  Future<PermissionStatus> request(Permission permission) {
    return permission.request();
  }

  @override
  Future<bool> openOsSettings() => openAppSettings();
}

Permission? permissionForManifestType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'camera':
      return Permission.camera;
    case 'microphone':
      return Permission.microphone;
    case 'location':
      return Permission.locationWhenInUse;
    default:
      return null;
  }
}
