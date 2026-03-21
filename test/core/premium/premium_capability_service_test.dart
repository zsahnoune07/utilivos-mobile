import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivo_mobile/core/entitlement/models/premium_entitlement.dart';
import 'package:utilivo_mobile/core/premium/free_tier_usage_store.dart';
import 'package:utilivo_mobile/core/premium/freemium_limits.dart';
import 'package:utilivo_mobile/core/premium/premium_capability_service.dart';

void main() {
  test('free user respects pin and folder caps and storage quota', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final entitlement = EntitlementController(store: _MemEntitlementStore());
    await entitlement.bootstrap();
    final usage = await FreeTierUsageStore.open();
    final service = PremiumCapabilityService(
      entitlementController: entitlement,
      usageStore: usage,
    );
    addTearDown(service.dispose);
    addTearDown(entitlement.dispose);

    expect(service.hasPremiumAccess, false);
    expect(service.canPinMoreTools(0), true);
    expect(service.canPinMoreTools(FreemiumLimits.maxPinnedTools), false);
    expect(service.canCreateMoreFolders(0), true);
    expect(service.canCreateMoreFolders(FreemiumLimits.maxFolders), false);
    expect(service.canPersistToolState, false);
    expect(service.canPerformStorageAction(), true);
    await usage.recordStorageAction();
    await usage.recordStorageAction();
    await usage.recordStorageAction();
    await usage.recordStorageAction();
    await usage.recordStorageAction();
    expect(service.remainingFreeStorageActionsToday, 0);
    expect(service.canPerformStorageAction(), false);
  });

  test('Pro user bypasses caps', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final now = DateTime.now().toUtc();
    final store = _MemEntitlementStore(
      initial: PremiumEntitlement(
        premiumActive: true,
        updatedAt: now,
        graceExpiresAt: now.add(const Duration(days: 3)),
        lastVerificationAt: now,
        verificationSource: 'test',
      ),
    );
    final entitlement = EntitlementController(store: store);
    await entitlement.bootstrap();
    final usage = await FreeTierUsageStore.open();
    final service = PremiumCapabilityService(
      entitlementController: entitlement,
      usageStore: usage,
    );
    addTearDown(service.dispose);
    addTearDown(entitlement.dispose);

    expect(service.hasPremiumAccess, true);
    expect(service.canPinMoreTools(99), true);
    expect(service.canCreateMoreFolders(99), true);
    expect(service.canPersistToolState, true);
  });
}

class _MemEntitlementStore implements EntitlementStore {
  _MemEntitlementStore({PremiumEntitlement? initial}) : _v = initial;

  PremiumEntitlement? _v;

  @override
  Future<void> clear() async {
    _v = null;
  }

  @override
  Future<PremiumEntitlement?> read() async => _v;

  @override
  Future<void> write(PremiumEntitlement entitlement) async {
    _v = entitlement;
  }
}
