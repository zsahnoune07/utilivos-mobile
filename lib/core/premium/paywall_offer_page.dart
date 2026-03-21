import 'package:flutter/material.dart';

import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import 'paywall_offer_view.dart';
import 'premium_analytics.dart';
import 'premium_purchase_controller.dart';

/// Full-screen Pro offer with comparison table (preferred over sheet for main CTAs).
class PaywallOfferPage extends StatelessWidget {
  const PaywallOfferPage({
    required this.request,
    required this.purchaseController,
    required this.entitlementController,
    required this.analytics,
    super.key,
  });

  final PaywallRequest request;
  final PremiumPurchaseController purchaseController;
  final EntitlementController entitlementController;
  final PremiumAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilivo Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            analytics.paywallDismissed(request, converted: false);
            Navigator.of(context).pop(PaywallResult.dismissed);
          },
        ),
      ),
      body: SafeArea(
        child: PaywallOfferView(
          request: request,
          purchaseController: purchaseController,
          entitlementController: entitlementController,
          analytics: analytics,
          showCompareTable: true,
          compact: false,
          onClose: (PaywallResult r) {
            Navigator.of(context).pop(r);
          },
        ),
      ),
    );
  }
}
