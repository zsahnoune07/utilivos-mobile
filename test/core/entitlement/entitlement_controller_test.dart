import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_verification_api.dart';
import 'package:utilivos_mobile/core/entitlement/models/entitlement_verification_result.dart';
import 'package:utilivos_mobile/core/entitlement/models/pro_entitlement.dart';
import 'package:utilivos_mobile/core/networking/network_exception.dart';

void main() {
  test('bootstrap restores persisted entitlement', () async {
    final now = DateTime.now().toUtc();
    final store = _InMemoryEntitlementStore(
      initial: ProEntitlement(
        proActive: true,
        updatedAt: now,
        entitlementType: 'one_time',
        productId: 'utilivos_pro_one_time',
      ),
    );
    final controller = EntitlementController(store: store);

    await controller.bootstrap();

    expect(controller.isReady, true);
    expect(controller.hasProAccess, true);
    expect(controller.entitlement.productId, 'utilivos_pro_one_time');
  });

  test(
    'activateFromBillingPurchase verifies with server and stores assertion',
    () async {
      final store = _InMemoryEntitlementStore();
      final controller = EntitlementController(
        store: store,
        verificationApi: _FakeVerificationApi((_) async {
          return EntitlementVerificationResult(
            proActive: true,
            entitlementType: 'one_time',
            assertionToken: 'assertion-token',
            assertionExpiresAt: DateTime.now().toUtc().add(
              const Duration(minutes: 15),
            ),
          );
        }),
      );
      await controller.bootstrap();

      final outcome = await controller.activateFromBillingPurchase(
        productId: 'utilivos_pro_one_time',
        purchaseToken: 'purchase-token-abc',
      );

      expect(outcome, BillingVerificationOutcome.activated);
      expect(controller.hasProAccess, true);
      expect(controller.activeAssertionToken, 'assertion-token');
      expect(controller.entitlement.purchaseToken, isNull);
      expect((await store.read())?.proActive, true);
    },
  );

  test('inactive verification keeps Pro locked', () async {
    final controller = EntitlementController(
      store: _InMemoryEntitlementStore(),
      verificationApi: _FakeVerificationApi((_) async {
        return const EntitlementVerificationResult(
          proActive: false,
          entitlementType: 'one_time',
        );
      }),
    );
    await controller.bootstrap();

    final outcome = await controller.activateFromBillingPurchase(
      productId: 'utilivos_pro_one_time',
      purchaseToken: 'purchase-token-abc',
    );

    expect(outcome, BillingVerificationOutcome.rejected);
    expect(controller.hasProAccess, false);
  });

  test(
    'network failure uses offline grace when entitlement is recently verified',
    () async {
      final now = DateTime.now().toUtc();
      final controller = EntitlementController(
        store: _InMemoryEntitlementStore(
          initial: ProEntitlement(
            proActive: true,
            updatedAt: now,
            entitlementType: 'one_time',
            productId: 'utilivos_pro_one_time',
            purchaseToken: 'purchase-token-abc',
            graceExpiresAt: now.add(const Duration(hours: 1)),
            lastVerificationAt: now,
            verificationSource: 'server_verified',
          ),
        ),
        verificationApi: _FakeVerificationApi((_) async {
          throw const NetworkException(
            kind: NetworkExceptionKind.noConnection,
            message: 'offline',
          );
        }),
      );
      await controller.bootstrap();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.hasProAccess, true);
      expect(
        controller.entitlement.verificationSource,
        startsWith('offline_grace_'),
      );
    },
  );

  test(
    'expired grace window deactivates Pro during background reverify',
    () async {
      final now = DateTime.now().toUtc();
      final controller = EntitlementController(
        store: _InMemoryEntitlementStore(
          initial: ProEntitlement(
            proActive: true,
            updatedAt: now,
            entitlementType: 'one_time',
            productId: 'utilivos_pro_one_time',
            purchaseToken: 'purchase-token-abc',
            graceExpiresAt: now.subtract(const Duration(minutes: 1)),
            lastVerificationAt: now.subtract(const Duration(minutes: 10)),
            verificationSource: 'server_verified',
          ),
        ),
        verificationApi: _FakeVerificationApi((_) async {
          throw const NetworkException(
            kind: NetworkExceptionKind.noConnection,
            message: 'offline',
          );
        }),
      );
      await controller.bootstrap();
      await controller.backgroundReverify(reason: 'test');

      expect(controller.hasProAccess, false);
      expect(controller.entitlement.proActive, false);
    },
  );

  test('setInactive persists locked entitlement state', () async {
    final store = _InMemoryEntitlementStore();
    final controller = EntitlementController(store: store);
    await controller.bootstrap();
    await controller.activateFromBillingPurchase(
      productId: 'utilivos_pro_one_time',
      purchaseToken: 'purchase-token-abc',
    );

    await controller.setInactive();

    expect(controller.hasProAccess, false);
    expect((await store.read())?.proActive, false);
  });
}

class _InMemoryEntitlementStore implements EntitlementStore {
  _InMemoryEntitlementStore({this.initial});

  final ProEntitlement? initial;
  ProEntitlement? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<ProEntitlement?> read() async {
    return _value ?? initial;
  }

  @override
  Future<void> write(ProEntitlement entitlement) async {
    _value = entitlement;
  }
}

class _FakeVerificationApi implements EntitlementVerificationApi {
  _FakeVerificationApi(this._handler);

  final Future<EntitlementVerificationResult> Function(
    VerifyInvocation invocation,
  )
  _handler;

  @override
  Future<EntitlementVerificationResult> verify({
    required String platform,
    required String productId,
    required String storeToken,
    required String packageName,
    String? deviceId,
  }) {
    return _handler(
      VerifyInvocation(
        platform: platform,
        productId: productId,
        storeToken: storeToken,
        packageName: packageName,
        deviceId: deviceId,
      ),
    );
  }
}

class VerifyInvocation {
  const VerifyInvocation({
    required this.platform,
    required this.productId,
    required this.storeToken,
    required this.packageName,
    this.deviceId,
  });

  final String platform;
  final String productId;
  final String storeToken;
  final String packageName;
  final String? deviceId;
}
