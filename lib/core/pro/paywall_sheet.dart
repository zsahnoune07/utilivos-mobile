import 'package:flutter/material.dart';

import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import 'paywall_offer_view.dart';
import '../pro/pro_analytics.dart';
import '../pro/pro_purchase_controller.dart';

/// Compact bottom sheet paywall.
Future<PaywallResult> showPaywallSheet({
  required BuildContext context,
  required PaywallRequest request,
  required ProPurchaseController purchaseController,
  required EntitlementController entitlementController,
  required ProAnalytics analytics,
  bool fullScreen = false,
}) async {
  PaywallResult outcome = PaywallResult.dismissed;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    constraints: fullScreen
        ? BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height)
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
              compact: true,
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
