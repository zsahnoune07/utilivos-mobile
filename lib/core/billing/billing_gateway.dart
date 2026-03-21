import 'models/billing_models.dart';

abstract interface class BillingGateway {
  Stream<BillingPurchaseUpdate> get purchaseUpdates;

  Future<bool> isAvailable();
  Future<List<BillingProduct>> queryProducts(Set<String> productIds);
  Future<void> buyNonConsumable(String productId);

  /// Same store flow as [buyNonConsumable]; used for subscriptions and alternate SKUs.
  Future<void> buyProduct(String productId);

  Future<void> restorePurchases();
  void dispose();
}
