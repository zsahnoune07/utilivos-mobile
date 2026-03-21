import 'models/billing_models.dart';

abstract interface class BillingGateway {
  Stream<BillingPurchaseUpdate> get purchaseUpdates;

  Future<bool> isAvailable();
  Future<List<BillingProduct>> queryProducts(Set<String> productIds);
  Future<void> buyNonConsumable(String productId);
  Future<void> restorePurchases();
  void dispose();
}
