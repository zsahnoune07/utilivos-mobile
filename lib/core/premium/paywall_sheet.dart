import 'package:flutter/material.dart';

import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import 'paywall_offer_page.dart';
import 'paywall_offer_view.dart';
import 'premium_analytics.dart';
import 'premium_purchase_controller.dart';

/// Compact bottom sheet with optional drill-in to full comparison page.
Future<PaywallResult> showPaywallSheet({
  required BuildContext context,
  required PaywallRequest request,
  required PremiumPurchaseController purchaseController,
  required EntitlementController entitlementController,
  required PremiumAnalytics analytics,
  bool fullScreen = false,
}) async {
  PaywallResult outcome = PaywallResult.dismissed;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: fullScreen
        ? BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height,
          )
        : null,
    builder: (BuildContext sheetContext) {
      return AnimatedPadding(
        padding: MediaQuery.viewInsetsOf(sheetContext),
        duration: const Duration(milliseconds: 120),
        child: SafeArea(
          child: SizedBox(
            height: fullScreen
                ? MediaQuery.sizeOf(sheetContext).height
                : MediaQuery.sizeOf(sheetContext).height * 0.88,
            child: PaywallOfferView(
              request: request,
              purchaseController: purchaseController,
              entitlementController: entitlementController,
              analytics: analytics,
              showCompareTable: false,
              compact: true,
              onSeeFullPlans: () async {
                final nav = Navigator.of(sheetContext, rootNavigator: true);
                final r = await nav.push<PaywallResult>(
                  MaterialPageRoute<PaywallResult>(
                    builder: (BuildContext ctx) => PaywallOfferPage(
                      request: request,
                      purchaseController: purchaseController,
                      entitlementController: entitlementController,
                      analytics: analytics,
                    ),
                  ),
                );
                if (r == PaywallResult.purchased && sheetContext.mounted) {
                  outcome = PaywallResult.purchased;
                  Navigator.of(sheetContext).pop();
                }
              },
              onClose: (PaywallResult r) {
                outcome = r;
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ),
      );
    },
  );
  return outcome;
}
