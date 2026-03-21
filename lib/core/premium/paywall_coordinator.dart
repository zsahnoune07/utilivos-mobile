import 'package:flutter/material.dart';

import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import 'paywall_offer_page.dart';
import 'paywall_sheet.dart';
import 'premium_analytics.dart';
import 'premium_purchase_controller.dart';

/// Central entry to present the paywall from anywhere (no cold-start auto-show).
class PaywallCoordinator {
  PaywallCoordinator({
    required PremiumPurchaseController purchaseController,
    required EntitlementController entitlementController,
    required PremiumAnalytics analytics,
  }) : _purchase = purchaseController,
       _entitlement = entitlementController,
       _analytics = analytics;

  final PremiumPurchaseController _purchase;
  final EntitlementController _entitlement;
  final PremiumAnalytics _analytics;

  Future<PaywallResult> show(
    BuildContext context,
    PaywallRequest request,
  ) async {
    if (_entitlement.hasPremiumAccess) {
      return PaywallResult.purchased;
    }
    _analytics.paywallShown(request);
    if (request.fullScreen) {
      final result = await Navigator.of(context, rootNavigator: true)
          .push<PaywallResult>(
        MaterialPageRoute<PaywallResult>(
          builder: (BuildContext ctx) => PaywallOfferPage(
            request: request,
            purchaseController: _purchase,
            entitlementController: _entitlement,
            analytics: _analytics,
          ),
        ),
      );
      return result ?? PaywallResult.dismissed;
    }
    return showPaywallSheet(
      context: context,
      request: request,
      purchaseController: _purchase,
      entitlementController: _entitlement,
      analytics: _analytics,
    );
  }
}
