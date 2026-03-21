import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap_controller.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/premium/premium_purchase_controller.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_info_tile.dart';
import '../../../shared/widgets/app_surface_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.bootstrapController,
    required this.entitlementController,
    required this.premiumPurchaseController,
    super.key,
  });

  final AppBootstrapController bootstrapController;
  final EntitlementController entitlementController;
  final PremiumPurchaseController premiumPurchaseController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _regenerating = false;

  Future<void> _regenerateDeviceId() async {
    setState(() {
      _regenerating = true;
    });

    await widget.bootstrapController.regenerateDeviceId();

    if (!mounted) {
      return;
    }
    setState(() {
      _regenerating = false;
    });
  }

  void _goBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          widget.bootstrapController,
          widget.entitlementController,
          widget.premiumPurchaseController,
        ]),
        builder: (BuildContext context, Widget? child) {
        final entitlement = widget.entitlementController.entitlement;
        final isPremiumActive = widget.entitlementController.hasPremiumAccess;
        final purchaseController = widget.premiumPurchaseController;
        final productSummary = purchaseController.availableProducts.isEmpty
            ? 'No products loaded from Google Play.'
            : purchaseController.availableProducts
                  .map((product) => '${product.id} (${product.price})')
                  .join(', ');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            const Text(
              'Anonymous-device configuration and premium purchase controls.',
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppInfoTile(
                    leading: Icons.phone_android_outlined,
                    title: 'Anonymous Device ID',
                    subtitle:
                        'Used for install tracking and entitlement verification.',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.bootstrapController.deviceId ?? 'Not ready',
                  ),
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: 'Regenerate Device ID',
                    onPressed: _regenerating ? null : _regenerateDeviceId,
                    isLoading: _regenerating,
                    expand: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppInfoTile(
                    leading: isPremiumActive
                        ? Icons.workspace_premium
                        : Icons.workspace_premium_outlined,
                    title: isPremiumActive
                        ? 'Premium Active'
                        : 'Premium Locked',
                    subtitle: isPremiumActive
                        ? 'Premium is active on this device.'
                        : 'Upgrade once to unlock the full premium tool repository.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configured one-time SKU: '
                    '${purchaseController.configuredOneTimeProductId}',
                  ),
                  Text(
                    'Configured subscription SKU: '
                    '${purchaseController.configuredSubscriptionProductId.trim().isEmpty ? '(none)' : purchaseController.configuredSubscriptionProductId}',
                  ),
                  const SizedBox(height: 6),
                  Text('Loaded products: $productSummary'),
                  if (!purchaseController.storeAvailable) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'Store unavailable. Billing actions are disabled.',
                    ),
                  ],
                  if (entitlement.productId != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Active product: ${entitlement.productId}'),
                  ],
                  if (entitlement.updatedAt.millisecondsSinceEpoch >
                      0) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      'Last entitlement update: ${_formatTime(entitlement.updatedAt)}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppPrimaryButton(
                    label: isPremiumActive
                        ? 'Premium Already Active'
                        : 'Upgrade to Premium',
                    onPressed:
                        isPremiumActive || !purchaseController.canPurchase
                        ? null
                        : purchaseController.purchasePremium,
                    isLoading:
                        purchaseController.isPurchaseInProgress ||
                        purchaseController.isLoadingProducts,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'Restore Purchases',
                    onPressed:
                        purchaseController.isRestoreInProgress ||
                            !purchaseController.storeAvailable
                        ? null
                        : purchaseController.restorePurchases,
                    expand: true,
                  ),
                  if (purchaseController.statusMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(purchaseController.statusMessage!),
                  ],
                  if (purchaseController.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      purchaseController.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
