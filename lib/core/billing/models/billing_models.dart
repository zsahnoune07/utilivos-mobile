enum BillingPurchaseStatus { pending, purchased, restored, canceled, error }

class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final String price;
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
