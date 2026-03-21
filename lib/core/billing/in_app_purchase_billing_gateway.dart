import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_gateway.dart';
import 'models/billing_models.dart';

class InAppPurchaseBillingGateway implements BillingGateway {
  InAppPurchaseBillingGateway({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
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

  final InAppPurchase _inAppPurchase;
  final StreamController<BillingPurchaseUpdate> _purchaseUpdatesController =
      StreamController<BillingPurchaseUpdate>.broadcast();
  final Map<String, ProductDetails> _productsById = <String, ProductDetails>{};

  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

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
    _productsById
      ..clear()
      ..addEntries(
        response.productDetails.map(
          (ProductDetails details) =>
              MapEntry<String, ProductDetails>(details.id, details),
        ),
      );

    return response.productDetails
        .map(
          (ProductDetails details) => BillingProduct(
            id: details.id,
            title: details.title,
            description: details.description,
            price: details.price,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> buyNonConsumable(String productId) async {
    await buyProduct(productId);
  }

  @override
  Future<void> buyProduct(String productId) async {
    final product = _productsById[productId];
    if (product == null) {
      throw StateError('Product $productId is not loaded.');
    }

    final success = await _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!success) {
      throw StateError('Failed to launch purchase flow for $productId.');
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
