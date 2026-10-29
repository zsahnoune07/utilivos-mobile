enum BillingPurchaseStatus { pending, purchased, restored, canceled, error }

/// Where a billing stream update originated (controls user-visible status text).
enum BillingPurchaseEventSource {
  /// User purchase flow or explicit "Restore purchases" tap.
  userFlow,

  /// Cold-start pending-ack reconciliation ([restorePurchases] for Play).
  ackReconciliation,

  /// Internal restore while resolving store verification payload.
  storeVerification,
}

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
    this.source = BillingPurchaseEventSource.userFlow,
  });

  final BillingPurchaseStatus status;
  final String productId;
  final String? purchaseToken;
  final String? errorMessage;
  final BillingPurchaseEventSource source;
}
