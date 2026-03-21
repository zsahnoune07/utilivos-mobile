import 'package:flutter/foundation.dart';

import '../entitlement/entitlement_controller.dart';
import '../device/device_identity_manager.dart';

enum AppBootstrapState { initializing, ready, failed }

class AppBootstrapController extends ChangeNotifier {
  AppBootstrapController({
    required DeviceIdentityManager deviceIdentityManager,
    required EntitlementController entitlementController,
  }) : _deviceIdentityManager = deviceIdentityManager,
       _entitlementController = entitlementController;

  final DeviceIdentityManager _deviceIdentityManager;
  final EntitlementController _entitlementController;
  bool _bootstrapStarted = false;
  AppBootstrapState _state = AppBootstrapState.initializing;
  String? _deviceId;
  String? _errorMessage;

  AppBootstrapState get state => _state;
  bool get isInitializing => _state == AppBootstrapState.initializing;
  bool get isReady => _state == AppBootstrapState.ready;
  bool get hasFailed => _state == AppBootstrapState.failed;
  String? get deviceId => _deviceId;
  String? get errorMessage => _errorMessage;

  Future<void> bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;

    _state = AppBootstrapState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _deviceId = await _deviceIdentityManager.ensureDeviceId();
      await _entitlementController.bootstrap();
      _state = AppBootstrapState.ready;
    } catch (error) {
      _state = AppBootstrapState.failed;
      _errorMessage = 'Failed to initialize device identity: $error';
    }
    notifyListeners();
  }

  Future<void> retryBootstrap() async {
    _bootstrapStarted = false;
    await bootstrap();
  }

  Future<void> regenerateDeviceId() async {
    final regenerated = await _deviceIdentityManager.regenerateDeviceId();
    _deviceId = regenerated;
    notifyListeners();
  }
}
