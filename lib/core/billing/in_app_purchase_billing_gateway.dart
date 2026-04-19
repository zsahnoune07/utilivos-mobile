import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/app_config.dart';
import 'billing_gateway.dart';
import 'models/billing_models.dart';

/// Play Billing subscription expansion + offer tokens; one-time SKUs by id.
class InAppPurchaseBillingGateway implements BillingGateway {
  InAppPurchaseBillingGateway({
    required AppConfig appConfig,
    InAppPurchase? inAppPurchase,
  }) : _appConfig = appConfig,
       _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseDetailsList,
      onError: (Object error) {
        _purchaseUpdatesController.add(
          BillingPurchaseUpdate(
            status: BillingPurchaseStatus.error,
            productId: 'unknown',
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  final AppConfig _appConfig;
  final InAppPurchase _inAppPurchase;
  final StreamController<BillingPurchaseUpdate> _purchaseUpdatesController =
      StreamController<BillingPurchaseUpdate>.broadcast();

  /// One-time / non-subscription products keyed by Play product id.
  final Map<String, ProductDetails> _oneTimeProductsById =
      <String, ProductDetails>{};

  /// Resolved subscription row per plan (correct offer token / index).
  final Map<ProSubscriptionPlan, GooglePlayProductDetails>
  _subscriptionDetailsByPlan =
      <ProSubscriptionPlan, GooglePlayProductDetails>{};

  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates =>
      _purchaseUpdatesController.stream;

  @override
  Future<bool> isAvailable() {
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    final response = await _inAppPurchase.queryProductDetails(productIds);
    _oneTimeProductsById.clear();
    _subscriptionDetailsByPlan.clear();

    final Map<ProSubscriptionPlan, GooglePlayProductDetails> best =
        <ProSubscriptionPlan, GooglePlayProductDetails>{};

    for (final ProductDetails details in response.productDetails) {
      if (!_isAndroid) {
        final oneId = _appConfig.proOneTimeProductId.trim();
        if (oneId.isNotEmpty && details.id == oneId) {
          _oneTimeProductsById[details.id] = details;
        }
        continue;
      }
      if (details is GooglePlayProductDetails &&
          details.subscriptionIndex != null) {
        final plan = _planForGoogleSubscription(details);
        if (plan == null) {
          continue;
        }
        final existing = best[plan];
        if (existing == null ||
            _preferGoogleSubscriptionOffer(details, existing)) {
          best[plan] = details;
        }
      } else {
        _oneTimeProductsById[details.id] = details;
      }
    }
    _subscriptionDetailsByPlan.addAll(best);

    return _buildBillingProductsList();
  }

  ProSubscriptionPlan? _planForGoogleSubscription(GooglePlayProductDetails d) {
    final offer = _subscriptionOffer(d);
    if (offer == null) {
      return null;
    }
    final basePlanId = offer.basePlanId.trim();
    final monthly = _appConfig.proSubscriptionMonthlyBasePlanId.trim();
    final annual = _appConfig.proSubscriptionAnnualBasePlanId.trim();
    if (monthly.isNotEmpty && basePlanId == monthly) {
      return ProSubscriptionPlan.monthly;
    }
    if (annual.isNotEmpty && basePlanId == annual) {
      return ProSubscriptionPlan.annual;
    }
    return null;
  }

  SubscriptionOfferDetailsWrapper? _subscriptionOffer(
    GooglePlayProductDetails d,
  ) {
    final i = d.subscriptionIndex;
    if (i == null) {
      return null;
    }
    final offers = d.productDetails.subscriptionOfferDetails;
    if (offers == null || i >= offers.length) {
      return null;
    }
    return offers[i];
  }

  /// Prefer plain base-plan row (`offerId == null`) over promotional rows.
  bool _preferGoogleSubscriptionOffer(
    GooglePlayProductDetails candidate,
    GooglePlayProductDetails incumbent,
  ) {
    final c = _subscriptionOffer(candidate);
    final inc = _subscriptionOffer(incumbent);
    if (c == null || inc == null) {
      return false;
    }
    if (c.offerId == null && inc.offerId != null) {
      return true;
    }
    if (c.offerId != null && inc.offerId == null) {
      return false;
    }
    return false;
  }

  List<BillingProduct> _buildBillingProductsList() {
    final out = <BillingProduct>[];

    if (_subscriptionDetailsByPlan.containsKey(ProSubscriptionPlan.annual)) {
      final d = _subscriptionDetailsByPlan[ProSubscriptionPlan.annual]!;
      out.add(
        BillingProduct(
          id: d.id,
          title: d.title,
          description: d.description,
          price: d.price,
          plan: ProSubscriptionPlan.annual,
        ),
      );
    }
    if (_subscriptionDetailsByPlan.containsKey(ProSubscriptionPlan.monthly)) {
      final d = _subscriptionDetailsByPlan[ProSubscriptionPlan.monthly]!;
      out.add(
        BillingProduct(
          id: d.id,
          title: d.title,
          description: d.description,
          price: d.price,
          plan: ProSubscriptionPlan.monthly,
        ),
      );
    }

    for (final ProductDetails d in _oneTimeProductsById.values) {
      out.add(
        BillingProduct(
          id: d.id,
          title: d.title,
          description: d.description,
          price: d.price,
        ),
      );
    }

    return out;
  }

  @override
  Future<void> buyNonConsumable(String productId) {
    return buyProduct(productId);
  }

  @override
  Future<void> buyProduct(String productId) async {
    final product = _oneTimeProductsById[productId];
    if (product == null) {
      throw StateError(
        'Product $productId is not loaded or is a subscription.',
      );
    }

    final success = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!success) {
      throw StateError('Failed to launch purchase flow for $productId.');
    }
  }

  @override
  Future<void> buySubscriptionPlan(ProSubscriptionPlan plan) async {
    if (!_isAndroid) {
      throw StateError(
        'Subscription base-plan purchase is only implemented for Android.',
      );
    }
    final details = _subscriptionDetailsByPlan[plan];
    if (details == null) {
      throw StateError('Subscription plan $plan is not loaded.');
    }

    final success = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!success) {
      throw StateError('Failed to launch purchase flow for plan $plan.');
    }
  }

  @override
  Future<void> restorePurchases() {
    return _inAppPurchase.restorePurchases();
  }

  void _onPurchaseDetailsList(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchaseUpdatesController.add(
            BillingPurchaseUpdate(
              status: BillingPurchaseStatus.pending,
              productId: purchase.productID,
            ),
          );
          break;
        case PurchaseStatus.purchased:
          _purchaseUpdatesController.add(
            BillingPurchaseUpdate(
              status: BillingPurchaseStatus.purchased,
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
            ),
          );
          break;
        case PurchaseStatus.restored:
          _purchaseUpdatesController.add(
            BillingPurchaseUpdate(
              status: BillingPurchaseStatus.restored,
              productId: purchase.productID,
              purchaseToken: purchase.verificationData.serverVerificationData,
            ),
          );
          break;
        case PurchaseStatus.error:
          _purchaseUpdatesController.add(
            BillingPurchaseUpdate(
              status: BillingPurchaseStatus.error,
              productId: purchase.productID,
              errorMessage:
                  purchase.error?.message ?? 'Unknown purchase error.',
            ),
          );
          break;
        case PurchaseStatus.canceled:
          _purchaseUpdatesController.add(
            BillingPurchaseUpdate(
              status: BillingPurchaseStatus.canceled,
              productId: purchase.productID,
            ),
          );
          break;
      }

      if (purchase.pendingCompletePurchase) {
        unawaited(_inAppPurchase.completePurchase(purchase));
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    _purchaseUpdatesController.close();
  }
}
