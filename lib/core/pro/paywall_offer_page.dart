import 'package:flutter/material.dart';

import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import 'paywall_offer_view.dart';
import '../pro/pro_analytics.dart';
import '../pro/pro_purchase_controller.dart';

/// Full-screen Pro offer (preferred over sheet for main CTAs).
class PaywallOfferPage extends StatelessWidget {
  const PaywallOfferPage({
    required this.request,
    required this.purchaseController,
    required this.entitlementController,
    required this.analytics,
    super.key,
  });

  final PaywallRequest request;
  final ProPurchaseController purchaseController;
  final EntitlementController entitlementController;
  final ProAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PaywallOfferView(
          request: request,
          purchaseController: purchaseController,
          entitlementController: entitlementController,
          analytics: analytics,
          compact: false,
          onClose: (PaywallResult r) {
            Navigator.of(context).pop(r);
          },
        ),
      ),
    );
  }
}
