import 'package:flutter/material.dart';

import '../billing/models/billing_models.dart';
import '../entitlement/entitlement_controller.dart';
import '../pro/pro_analytics.dart';
import '../pro/pro_purchase_controller.dart';
import 'paywall_models.dart';

/// Shared paywall content: value props, plan picker, and CTAs.
class PaywallOfferView extends StatefulWidget {
  const PaywallOfferView({
    required this.request,
    required this.purchaseController,
    required this.entitlementController,
    required this.analytics,
    required this.onClose,
    this.compact = false,
    super.key,
  });

  final PaywallRequest request;
  final ProPurchaseController purchaseController;
  final EntitlementController entitlementController;
  final ProAnalytics analytics;
  final void Function(PaywallResult result) onClose;

  /// Tighter spacing for modal sheet.
  final bool compact;

  @override
  State<PaywallOfferView> createState() => _PaywallOfferViewState();
}

class _PaywallOfferViewState extends State<PaywallOfferView> {
  ProSubscriptionPlan? _selectedSubscriptionPlan;
  bool _selectedOneTime = false;

  @override
  void initState() {
    super.initState();
    _selectedSubscriptionPlan = ProSubscriptionPlan.annual;
    widget.entitlementController.addListener(_onEntitlementChanged);
    widget.purchaseController.addListener(_onPurchaseChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _coerceSelection());
  }

  @override
  void dispose() {
    widget.entitlementController.removeListener(_onEntitlementChanged);
    widget.purchaseController.removeListener(_onPurchaseChanged);
    super.dispose();
  }

  void _onEntitlementChanged() {
    if (widget.entitlementController.hasProAccess && mounted) {
      widget.analytics.conversionSuccess(
        widget.request,
        productId: _analyticsProductLabel(),
      );
      widget.onClose(PaywallResult.purchased);
    }
  }

  void _onPurchaseChanged() {
    if (mounted) {
      _coerceSelection();
    }
  }

  String _analyticsProductLabel() {
    if (_selectedOneTime) {
      return widget.purchaseController.configuredOneTimeProductId ?? 'one_time';
    }
    if (_selectedSubscriptionPlan != null) {
      return '${widget.purchaseController.configuredSubscriptionProductId}:${_selectedSubscriptionPlan!.name}';
    }
    return 'unknown';
  }

  BillingProduct? _productForPlan(ProSubscriptionPlan plan) {
    return widget.purchaseController.billingProductForPlan(plan);
  }

  BillingProduct? _oneTimeProduct() {
    final id = widget.purchaseController.configuredOneTimeProductId;
    if (id == null) {
      return null;
    }
    for (final BillingProduct p
        in widget.purchaseController.availableProducts) {
      if (p.plan == null && p.id == id) {
        return p;
      }
    }
    return null;
  }

  bool _hasValidSelection() {
    if (_selectedOneTime) {
      return widget.purchaseController.configuredOneTimeProductId != null;
    }
    return _selectedSubscriptionPlan != null;
  }

  void _coerceSelection() {
    if (!mounted) {
      return;
    }
    final BillingProduct? annual = _productForPlan(ProSubscriptionPlan.annual);
    final BillingProduct? monthly = _productForPlan(
      ProSubscriptionPlan.monthly,
    );
    final BillingProduct? oneTime = _oneTimeProduct();

    setState(() {
      if (_selectedOneTime && oneTime == null) {
        _selectedOneTime = false;
      }
      if (_selectedSubscriptionPlan != null &&
          _productForPlan(_selectedSubscriptionPlan!) == null) {
        _selectedSubscriptionPlan = null;
      }
      if (!_selectedOneTime && _selectedSubscriptionPlan == null) {
        if (annual != null) {
          _selectedSubscriptionPlan = ProSubscriptionPlan.annual;
        } else if (monthly != null) {
          _selectedSubscriptionPlan = ProSubscriptionPlan.monthly;
        } else if (oneTime != null) {
          _selectedOneTime = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final BillingProduct? annual = _productForPlan(ProSubscriptionPlan.annual);
    final BillingProduct? monthly = _productForPlan(
      ProSubscriptionPlan.monthly,
    );
    final BillingProduct? oneTime = _oneTimeProduct();

    final pad = widget.compact
        ? const EdgeInsets.fromLTRB(16, 58, 16, 20)
        : const EdgeInsets.fromLTRB(20, 66, 20, 28);
    final gap = widget.compact ? 16.0 : 24.0;
    final titleStyle =
        (widget.compact
                ? theme.textTheme.headlineSmall
                : theme.textTheme.headlineMedium)
            ?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.7,
            );

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.alphaBlend(
                scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
                scheme.surface,
              ),
              Color.alphaBlend(
                scheme.secondary.withValues(alpha: isDark ? 0.22 : 0.10),
                scheme.surface,
              ),
              Color.alphaBlend(
                scheme.tertiary.withValues(alpha: isDark ? 0.18 : 0.06),
                scheme.surface,
              ),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: _PaywallBackdrop(compact: widget.compact),
              ),
            ),
            SingleChildScrollView(
              padding: pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Align(
                    child: _PillLabel(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Utilivos Pro',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Unlock the full Utilivos toolkit',
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const _SectionCard(
                    child: Column(
                      children: <Widget>[
                        _BenefitRow(
                          icon: Icons.push_pin_rounded,
                          text:
                              'Pin as many tools as you want and keep your most-used workflows on top.',
                        ),
                        _BenefitDivider(),
                        _BenefitRow(
                          icon: Icons.folder_open_rounded,
                          text:
                              'Create unlimited folders and organize tools around real projects.',
                        ),
                        _BenefitDivider(),
                        _BenefitRow(
                          icon: Icons.extension_rounded,
                          text:
                              'Open every Pro catalog tool instead of stopping at preview mode.',
                        ),
                        _BenefitDivider(),
                        _BenefitRow(
                          icon: Icons.history_toggle_off_rounded,
                          text:
                              'Save your place and resume work exactly where you left off.',
                        ),
                        _BenefitDivider(),
                        _BenefitRow(
                          icon: Icons.file_download_done_rounded,
                          text:
                              'Export, save, and share files without free-tier daily limits.',
                        ),
                        _BenefitDivider(),
                        _BenefitRow(
                          icon: Icons.widgets_outlined,
                          text:
                              'Add home screen widgets and shortcuts for instant launch.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  if (annual != null || monthly != null) ...<Widget>[
                    Row(
                      children: <Widget>[
                        if (annual != null)
                          Expanded(
                            child: _PlanOptionButton(
                              title: 'Yearly',
                              price: annual.price,
                              badgeLabel: 'BEST VALUE',
                              selected:
                                  !_selectedOneTime &&
                                  _selectedSubscriptionPlan ==
                                      ProSubscriptionPlan.annual,
                              highlighted: true,
                              onTap: () => setState(() {
                                _selectedOneTime = false;
                                _selectedSubscriptionPlan =
                                    ProSubscriptionPlan.annual;
                              }),
                            ),
                          ),
                        if (annual != null && monthly != null)
                          const SizedBox(width: 12),
                        if (monthly != null)
                          Expanded(
                            child: _PlanOptionButton(
                              title: 'Monthly',
                              price: monthly.price,
                              selected:
                                  !_selectedOneTime &&
                                  _selectedSubscriptionPlan ==
                                      ProSubscriptionPlan.monthly,
                              highlighted: false,
                              onTap: () => setState(() {
                                _selectedOneTime = false;
                                _selectedSubscriptionPlan =
                                    ProSubscriptionPlan.monthly;
                              }),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ] else if (oneTime != null) ...<Widget>[
                    _PlanOptionButton(
                      title: 'Lifetime',
                      price: oneTime.price,
                      badgeLabel: 'ONE-TIME',
                      selected: _selectedOneTime,
                      highlighted: true,
                      onTap: () => setState(() {
                        _selectedOneTime = true;
                        _selectedSubscriptionPlan = null;
                      }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed:
                        widget.purchaseController.isPurchaseInProgress ||
                            !widget.purchaseController.canPurchase ||
                            !_hasValidSelection()
                        ? null
                        : () async {
                            widget.analytics.conversionStarted(
                              widget.request,
                              productId: _analyticsProductLabel(),
                            );
                            if (_selectedOneTime) {
                              final id = widget
                                  .purchaseController
                                  .configuredOneTimeProductId;
                              if (id != null) {
                                await widget.purchaseController.purchaseProduct(
                                  id,
                                );
                              }
                            } else if (_selectedSubscriptionPlan != null) {
                              await widget.purchaseController
                                  .purchaseSubscriptionPlan(
                                    _selectedSubscriptionPlan!,
                                  );
                            }
                          },
                    child: widget.purchaseController.isPurchaseInProgress
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                  if (widget.purchaseController.isLoadingProducts) ...<Widget>[
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      icon: Icons.sync_rounded,
                      text: 'Loading live pricing from the store...',
                    ),
                  ] else if (widget
                      .purchaseController
                      .availableProducts
                      .isEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      icon: Icons.storefront_rounded,
                      text:
                          'Store prices appear here when billing is available. Configure SKUs in AppConfig or use Settings > Developer to simulate Pro while testing.',
                    ),
                  ],
                  if (widget.purchaseController.errorMessage !=
                      null) ...<Widget>[
                    const SizedBox(height: 12),
                    _InfoBanner(
                      icon: Icons.error_outline_rounded,
                      text: widget.purchaseController.errorMessage!,
                      tone: _BannerTone.error,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.purchaseController.isRestoreInProgress
                        ? null
                        : () async {
                            widget.analytics.conversionStarted(
                              widget.request,
                              productId: 'restore',
                            );
                            await widget.purchaseController.restorePurchases();
                          },
                    child: widget.purchaseController.isRestoreInProgress
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Restore purchases'),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.analytics.paywallDismissed(
                        widget.request,
                        converted: false,
                      );
                      widget.onClose(PaywallResult.dismissed);
                    },
                    child: const Text('Not now'),
                  ),
                  if (!widget.purchaseController.storeAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Billing is unavailable on this device. Pro may still apply if you subscribed elsewhere.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: widget.compact ? 8 : 10,
              left: widget.compact ? 12 : 16,
              child: _CloseButton(
                onPressed: () {
                  widget.analytics.paywallDismissed(
                    widget.request,
                    converted: false,
                  );
                  widget.onClose(PaywallResult.dismissed);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaywallBackdrop extends StatelessWidget {
  const _PaywallBackdrop({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: <Widget>[
        Positioned(
          top: compact ? -72 : -96,
          left: compact ? -80 : -110,
          child: _GlowOrb(
            color: scheme.primary.withValues(alpha: isDark ? 0.30 : 0.20),
            size: compact ? 220 : 300,
          ),
        ),
        Positioned(
          top: compact ? -12 : 0,
          right: compact ? -90 : -120,
          child: _GlowOrb(
            color: scheme.tertiary.withValues(alpha: isDark ? 0.24 : 0.12),
            size: compact ? 200 : 280,
          ),
        ),
        Positioned(
          top: compact ? 140 : 200,
          left: compact ? -30 : -10,
          child: _GlowOrb(
            color: scheme.secondary.withValues(alpha: isDark ? 0.20 : 0.11),
            size: compact ? 160 : 210,
          ),
        ),
        Positioned(
          bottom: compact ? -110 : -140,
          right: compact ? -90 : -130,
          child: _GlowOrb(
            color: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            size: compact ? 240 : 320,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(color: color, blurRadius: 38, spreadRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(
              scheme.surface.withValues(alpha: 0.80),
              scheme.surfaceContainerHighest,
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.close_rounded, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.08),
            scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          )
        : Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.018),
            scheme.surface.withValues(alpha: 0.98),
          );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

enum _BannerTone { neutral, accent, error }

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.tone = _BannerTone.neutral,
  });

  final IconData icon;
  final String text;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    late final Color background;
    late final Color iconColor;

    switch (tone) {
      case _BannerTone.accent:
        background = Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.12),
          scheme.surfaceContainerHighest,
        );
        iconColor = scheme.primary;
      case _BannerTone.error:
        background = Color.alphaBlend(
          scheme.error.withValues(alpha: 0.10),
          scheme.surfaceContainerHighest,
        );
        iconColor = scheme.error;
      case _BannerTone.neutral:
        background = scheme.surfaceContainerHighest.withValues(alpha: 0.8);
        iconColor = scheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                fontWeight: tone == _BannerTone.error ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    );
  }
}

class _PlanOptionButton extends StatelessWidget {
  const _PlanOptionButton({
    required this.title,
    required this.price,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    this.badgeLabel,
  });

  final String title;
  final String price;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = selected
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.16),
            scheme.surface,
          )
        : highlighted
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.06),
            scheme.surface,
          )
        : scheme.surface.withValues(alpha: 0.78);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : highlighted
                  ? scheme.primary.withValues(alpha: 0.34)
                  : scheme.outlineVariant.withValues(alpha: 0.38),
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected || highlighted
                ? <BoxShadow>[
                    BoxShadow(
                      color: scheme.shadow.withValues(
                        alpha: selected ? 0.08 : 0.04,
                      ),
                      blurRadius: selected ? 18 : 12,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? scheme.primary : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : highlighted
                              ? scheme.primary.withValues(alpha: 0.55)
                              : scheme.outline,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: scheme.onPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
                if (badgeLabel != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                if (highlighted && !selected) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Recommended',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
