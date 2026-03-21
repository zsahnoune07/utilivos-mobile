import 'package:flutter/foundation.dart';

import '../entitlement/entitlement_controller.dart';
import 'free_tier_usage_store.dart';
import 'freemium_limits.dart';

/// Single place for "can user do X?" — UI and runtime bridge should use this.
class PremiumCapabilityService extends ChangeNotifier {
  PremiumCapabilityService({
    required EntitlementController entitlementController,
    required FreeTierUsageStore usageStore,
  }) : _entitlement = entitlementController,
       _usage = usageStore {
    _entitlement.addListener(_onEntitlementChanged);
  }

  final EntitlementController _entitlement;
  final FreeTierUsageStore _usage;

  void _onEntitlementChanged() {
    notifyListeners();
  }

  bool get hasPremiumAccess => _entitlement.hasPremiumAccess;

  bool get isEntitlementReady => _entitlement.isReady;

  bool canPinMoreTools(int currentPinnedCount) {
    if (hasPremiumAccess) {
      return true;
    }
    return currentPinnedCount < FreemiumLimits.maxPinnedTools;
  }

  bool canCreateMoreFolders(int currentFolderCount) {
    if (hasPremiumAccess) {
      return true;
    }
    return currentFolderCount < FreemiumLimits.maxFolders;
  }

  bool get canPersistToolState => hasPremiumAccess;

  bool get canRestoreSession => hasPremiumAccess;

  bool get canUseUnlimitedStorageActions => hasPremiumAccess;

  bool get canAddHomeScreenLaunchers => hasPremiumAccess;

  /// Full access to Pro catalog tools (not preview mode).
  bool get canUsePremiumToolFullAccess => hasPremiumAccess;

  /// When false, Pro-tier bundles may still open in preview mode.
  bool shouldRunPremiumBundleInPreviewMode() {
    return !hasPremiumAccess;
  }

  bool canPerformStorageAction() {
    if (hasPremiumAccess) {
      return true;
    }
    return _usage.remainingFreeStorageActionsToday > 0;
  }

  int get remainingFreeStorageActionsToday =>
      _usage.remainingFreeStorageActionsToday;

  Future<void> recordStorageActionConsumed() async {
    if (hasPremiumAccess) {
      return;
    }
    await _usage.recordStorageAction();
    notifyListeners();
  }

  Future<void> recordToolEngagement(String pluginSlug) async {
    await _usage.recordToolLaunch(pluginSlug);
    notifyListeners();
  }

  /// Call after [FreeTierUsageStore.debugResetAll] so listeners refresh quotas.
  void refreshQuotas() {
    notifyListeners();
  }

  bool get shouldOfferSoftPaywall =>
      !hasPremiumAccess && _usage.shouldOfferSoftPaywall;

  Future<void> markSoftPaywallDismissed() async {
    await _usage.markSoftPaywallDismissed();
    notifyListeners();
  }

  @override
  void dispose() {
    _entitlement.removeListener(_onEntitlementChanged);
    super.dispose();
  }
}
