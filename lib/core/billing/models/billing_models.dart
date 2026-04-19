enum BillingPurchaseStatus { pending, purchased, restored, canceled, error }

/// Google Play: base plans under one subscription product. iOS (later): map to SKUs.
enum ProSubscriptionPlan { monthly, annual }

class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.plan,
  });

  /// Store product id (Play subscription id or one-time SKU).
  final String id;
  final String title;
  final String description;
  final String price;

  /// Set for subscription base-plan rows; null for one-time products.
  final ProSubscriptionPlan? plan;
}

class BillingPurchaseUpdate {
  const BillingPurchaseUpdate({
    required this.status,
    required this.productId,
    this.purchaseToken,
    this.errorMessage,
  });

  final BillingPurchaseStatus status;
  final String productId;
  final String? purchaseToken;
  final String? errorMessage;
}
