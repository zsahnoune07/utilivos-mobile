import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap_controller.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/premium/free_tier_usage_store.dart';
import '../../../core/premium/paywall_coordinator.dart';
import '../../../core/premium/paywall_models.dart';
import '../../../core/premium/premium_capability_service.dart';
import '../../../core/premium/premium_purchase_controller.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_info_tile.dart';
import '../../../shared/widgets/app_surface_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.bootstrapController,
    required this.entitlementController,
    required this.premiumPurchaseController,
    required this.paywallCoordinator,
    required this.freeTierUsageStore,
    required this.premiumCapabilityService,
    super.key,
  });

  final AppBootstrapController bootstrapController;
  final EntitlementController entitlementController;
  final PremiumPurchaseController premiumPurchaseController;
  final PaywallCoordinator paywallCoordinator;
  final FreeTierUsageStore freeTierUsageStore;
  final PremiumCapabilityService premiumCapabilityService;

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
          widget.premiumCapabilityService,
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
              'Anonymous-device configuration and Pro subscription controls.',
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
                        ? 'Pro active'
                        : 'Pro locked',
                    subtitle: isPremiumActive
                        ? 'Pro is active on this device.'
                        : 'Upgrade to unlock the full Pro tool library and power features.',
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
                        ? 'Pro already active'
                        : 'Go Pro',
                    onPressed: isPremiumActive
                        ? null
                        : () => widget.paywallCoordinator.show(
                              context,
                              const PaywallRequest(
                                trigger: PaywallTrigger.contextualFeature,
                                triggerSource: 'settings',
                              ),
                            ),
                    isLoading: false,
                    expand: true,
                  ),
                  const SizedBox(height: 8),
                  AppSecondaryButton(
                    label: 'Restore purchases',
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
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: 12),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AppInfoTile(
                      leading: Icons.bug_report_outlined,
                      title: 'Developer — Pro & limits (debug only)',
                      subtitle:
                          'Validate paywall, gates, quotas, and deep links without store billing. '
                          'RevenueCat / Play sandbox integration can follow once UX is signed off.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Deep link example: utilivo://tool/{slug}?restore=1',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    AppPrimaryButton(
                      label: 'Simulate Pro (local)',
                      onPressed: () async {
                        await widget.entitlementController
                            .debugGrantLocalProEntitlement();
                      },
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Clear simulated Pro',
                      onPressed: () async {
                        await widget.entitlementController
                            .debugClearLocalProEntitlement();
                      },
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Simulate purchase canceled',
                      onPressed: purchaseController.debugSimulatePurchaseCanceled,
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Simulate purchase error',
                      onPressed: purchaseController.debugSimulatePurchaseFailed,
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Clear purchase status lines',
                      onPressed: purchaseController.debugClearPurchaseMessages,
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Reset free-tier usage counters',
                      onPressed: () async {
                        await widget.freeTierUsageStore.debugResetAll();
                        widget.premiumCapabilityService.refreshQuotas();
                      },
                      expand: true,
                    ),
                    const SizedBox(height: 8),
                    AppSecondaryButton(
                      label: 'Open paywall (test)',
                      onPressed: () {
                        unawaited(
                          widget.paywallCoordinator.show(
                            context,
                            const PaywallRequest(
                              trigger: PaywallTrigger.contextualFeature,
                              triggerSource: 'debug_panel',
                              contextMessage: 'Test paywall presentation.',
                            ),
                          ),
                        );
                      },
                      expand: true,
                    ),
                  ],
                ),
              ),
            ],
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
