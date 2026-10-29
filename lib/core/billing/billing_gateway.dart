import 'models/billing_models.dart';

abstract interface class BillingGateway {
  Stream<BillingPurchaseUpdate> get purchaseUpdates;

  Future<bool> isAvailable();
  Future<List<BillingProduct>> queryProducts(Set<String> productIds);
  Future<void> buyNonConsumable(String productId);

  /// Same store flow as [buyNonConsumable]; used for one-time (non-subscription) SKUs.
  Future<void> buyProduct(String productId);

  /// Google Play subscription base plan, or future iOS StoreKit subscription SKU.
  Future<void> buySubscriptionPlan(ProSubscriptionPlan plan);

  Future<void> restorePurchases();

  /// Replays unconsumed purchases so [purchaseUpdates] can run [completePurchase] again.
  Future<void> reconcilePendingPurchaseAcknowledgements();

  /// Obtains the latest Play [serverVerificationData] for [productId] (e.g. after local token was cleared).
  Future<String?> fetchStoreVerificationDataForProduct(String productId);

  void dispose();
}
