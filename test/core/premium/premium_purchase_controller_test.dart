import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/billing/billing_gateway.dart';
import 'package:utilivos_mobile/core/billing/models/billing_models.dart';
import 'package:utilivos_mobile/core/config/app_config.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivos_mobile/core/entitlement/models/pro_entitlement.dart';
import 'package:utilivos_mobile/core/pro/pro_purchase_controller.dart';

void main() {
  test('initialize loads billing products when store is available', () async {
    final gateway = _FakeBillingGateway(
      available: true,
      products: const <BillingProduct>[
        BillingProduct(
          id: 'utilivos_pro_one_time',
          title: 'Utilivos Pro',
          description: 'Unlock Pro tools',
          price: r'$9.99',
        ),
      ],
    );
    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
    );
    await entitlementController.bootstrap();

    final controller = ProPurchaseController(
      config: _config(),
      billingGateway: gateway,
      entitlementController: entitlementController,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.storeAvailable, true);
    expect(controller.availableProducts, hasLength(1));
    expect(controller.canPurchase, true);
  });

  test('purchase update unlocks entitlement for Pro product', () async {
    final gateway = _FakeBillingGateway(
      available: true,
      products: const <BillingProduct>[
        BillingProduct(
          id: 'utilivos_pro_one_time',
          title: 'Utilivos Pro',
          description: 'Unlock Pro tools',
          price: r'$9.99',
        ),
      ],
    );
    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
    );
    await entitlementController.bootstrap();

    final controller = ProPurchaseController(
      config: _config(),
      billingGateway: gateway,
      entitlementController: entitlementController,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    gateway.emit(
      const BillingPurchaseUpdate(
        status: BillingPurchaseStatus.purchased,
        productId: 'utilivos_pro_one_time',
        purchaseToken: 'purchase-token-1',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(entitlementController.hasProAccess, true);
    expect(
      entitlementController.entitlement.productId,
      'utilivos_pro_one_time',
    );
    expect(controller.statusMessage, 'Pro unlocked and verified successfully.');
  });

  test('restore update unlocks entitlement for subscription product', () async {
    final gateway = _FakeBillingGateway(
      available: true,
      products: const <BillingProduct>[
        BillingProduct(
          id: 'utilivos_pro_subscription',
          title: 'Utilivos Pro (annual)',
          description: 'Annual Pro access',
          price: r'$29.99',
          plan: ProSubscriptionPlan.annual,
        ),
        BillingProduct(
          id: 'utilivos_pro_subscription',
          title: 'Utilivos Pro (monthly)',
          description: 'Monthly Pro access',
          price: r'$4.99',
          plan: ProSubscriptionPlan.monthly,
        ),
      ],
    );
    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
    );
    await entitlementController.bootstrap();

    final controller = ProPurchaseController(
      config: _config(),
      billingGateway: gateway,
      entitlementController: entitlementController,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    gateway.emit(
      const BillingPurchaseUpdate(
        status: BillingPurchaseStatus.restored,
        productId: 'utilivos_pro_subscription',
        purchaseToken: 'restore-token-1',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(entitlementController.hasProAccess, true);
    expect(entitlementController.entitlement.entitlementType, 'subscription');
    expect(controller.statusMessage, 'Pro restored and verified successfully.');
  });

  test(
    'reconciliation-sourced restore activates Pro without restored status line',
    () async {
      final gateway = _FakeBillingGateway(
        available: true,
        products: const <BillingProduct>[
          BillingProduct(
            id: 'utilivos_pro_subscription',
            title: 'Utilivos Pro (annual)',
            description: 'Annual Pro access',
            price: r'$29.99',
            plan: ProSubscriptionPlan.annual,
          ),
          BillingProduct(
            id: 'utilivos_pro_subscription',
            title: 'Utilivos Pro (monthly)',
            description: 'Monthly Pro access',
            price: r'$4.99',
            plan: ProSubscriptionPlan.monthly,
          ),
        ],
      );
      final entitlementController = EntitlementController(
        store: _InMemoryEntitlementStore(),
      );
      await entitlementController.bootstrap();

      final controller = ProPurchaseController(
        config: _config(),
        billingGateway: gateway,
        entitlementController: entitlementController,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      gateway.emit(
        const BillingPurchaseUpdate(
          status: BillingPurchaseStatus.restored,
          productId: 'utilivos_pro_subscription',
          purchaseToken: 'reconcile-token',
          source: BillingPurchaseEventSource.ackReconciliation,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(entitlementController.hasProAccess, true);
      expect(
        controller.statusMessage,
        isNot(equals('Pro restored and verified successfully.')),
      );
    },
  );

  test('purchaseSubscriptionPlan delegates to billing gateway', () async {
    final gateway = _FakeBillingGateway(
      available: true,
      products: const <BillingProduct>[
        BillingProduct(
          id: 'utilivos_pro_subscription',
          title: 'Annual',
          description: '',
          price: r'$29.99',
          plan: ProSubscriptionPlan.annual,
        ),
        BillingProduct(
          id: 'utilivos_pro_subscription',
          title: 'Monthly',
          description: '',
          price: r'$4.99',
          plan: ProSubscriptionPlan.monthly,
        ),
      ],
    );
    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
    );
    await entitlementController.bootstrap();

    final controller = ProPurchaseController(
      config: _config(),
      billingGateway: gateway,
      entitlementController: entitlementController,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.purchaseSubscriptionPlan(ProSubscriptionPlan.monthly);

    expect(gateway.lastSubscriptionPlan, ProSubscriptionPlan.monthly);
  });
}

AppConfig _config() {
  return const AppConfig(
    appName: 'Utilivos',
    apiBaseUrl: 'https://api.example.test',
    androidPackageName: 'com.utilivos.app',
    proOneTimeProductId: 'utilivos_pro_one_time',
    proSubscriptionProductId: 'utilivos_pro_subscription',
    proSubscriptionMonthlyBasePlanId: 'monthly',
    proSubscriptionAnnualBasePlanId: 'annual',
  );
}

class _InMemoryEntitlementStore implements EntitlementStore {
  ProEntitlement? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<ProEntitlement?> read() async {
    return _value;
  }

  @override
  Future<void> write(ProEntitlement entitlement) async {
    _value = entitlement;
  }
}

class _FakeBillingGateway implements BillingGateway {
  _FakeBillingGateway({required this.available, required this.products});

  final bool available;
  final List<BillingProduct> products;
  final StreamController<BillingPurchaseUpdate> _updates =
      StreamController<BillingPurchaseUpdate>.broadcast();

  ProSubscriptionPlan? lastSubscriptionPlan;

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<void> buyNonConsumable(String productId) async {}

  @override
  Future<void> buyProduct(String productId) async {}

  @override
  Future<void> buySubscriptionPlan(ProSubscriptionPlan plan) async {
    lastSubscriptionPlan = plan;
  }

  @override
  Future<void> reconcilePendingPurchaseAcknowledgements() async {}

  @override
  Future<String?> fetchStoreVerificationDataForProduct(String productId) async =>
      null;

  @override
  void dispose() {
    _updates.close();
  }

  void emit(BillingPurchaseUpdate update) {
    _updates.add(update);
  }

  @override
  Future<bool> isAvailable() async {
    return available;
  }

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    return products
        .where((BillingProduct product) => productIds.contains(product.id))
        .toList();
  }

  @override
  Future<void> restorePurchases() async {}
}
