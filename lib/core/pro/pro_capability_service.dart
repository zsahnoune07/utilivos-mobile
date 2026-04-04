import 'package:flutter/foundation.dart';

import '../entitlement/entitlement_controller.dart';
import 'free_tier_usage_store.dart';
import 'freemium_limits.dart';

/// Single place for "can user do X?" — UI and runtime bridge should use this.
class ProCapabilityService extends ChangeNotifier {
  ProCapabilityService({
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

  bool get hasProAccess => _entitlement.hasProAccess;

  bool get isEntitlementReady => _entitlement.isReady;

  bool canPinMoreTools(int currentPinnedCount) {
    if (hasProAccess) {
      return true;
    }
    return currentPinnedCount < FreemiumLimits.maxPinnedTools;
  }

  bool canCreateMoreFolders(int currentFolderCount) {
    if (hasProAccess) {
      return true;
    }
    return currentFolderCount < FreemiumLimits.maxFolders;
  }

  bool get canPersistToolState => hasProAccess;

  bool get canRestoreSession => hasProAccess;

  bool get canUseUnlimitedStorageActions => hasProAccess;

  bool get canAddHomeScreenLaunchers => hasProAccess;

  /// Free tier: one registered home-screen widget; reconfiguring the same slot is allowed.
  /// Pro: unlimited.
  bool canAddHomeScreenWidget({
    required int registeredWidgetCount,
    required bool isReplacingExisting,
  }) {
    if (hasProAccess) {
      return true;
    }
    if (isReplacingExisting) {
      return true;
    }
    return registeredWidgetCount < FreemiumLimits.maxHomeScreenWidgets;
  }

  /// Full access to Pro catalog tools (not preview mode).
  bool get canUseProToolFullAccess => hasProAccess;

  /// When false, Pro-tier bundles may still open in preview mode.
  bool shouldRunProBundleInPreviewMode() {
    return !hasProAccess;
  }

  bool canPerformStorageAction() {
    if (hasProAccess) {
      return true;
    }
    return _usage.remainingFreeStorageActionsToday > 0;
  }

  int get remainingFreeStorageActionsToday =>
      _usage.remainingFreeStorageActionsToday;

  Future<void> recordStorageActionConsumed() async {
    if (hasProAccess) {
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
      !hasProAccess && _usage.shouldOfferSoftPaywall;

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
