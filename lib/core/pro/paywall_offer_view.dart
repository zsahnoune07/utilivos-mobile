import 'package:flutter/material.dart';

import '../billing/models/billing_models.dart';
import '../entitlement/entitlement_controller.dart';
import 'paywall_models.dart';
import '../pro/pro_analytics.dart';
import '../pro/pro_purchase_controller.dart';

/// Shared paywall content: value props, Free vs Pro comparison, plan picker, CTAs.
class PaywallOfferView extends StatefulWidget {
  const PaywallOfferView({
    required this.request,
    required this.purchaseController,
    required this.entitlementController,
    required this.analytics,
    required this.onClose,
    this.showCompareTable = true,
    this.compact = false,
    this.onSeeFullPlans,
    super.key,
  });

  final PaywallRequest request;
  final ProPurchaseController purchaseController;
  final EntitlementController entitlementController;
  final ProAnalytics analytics;
  final void Function(PaywallResult result) onClose;

  /// Full [PaywallOfferPage] sets true; bottom sheet may set false and link here.
  final bool showCompareTable;

  /// Tighter spacing for modal sheet.
  final bool compact;

  /// When set (e.g. compact sheet), opens full comparison without nesting sheets.
  final VoidCallback? onSeeFullPlans;

  @override
  State<PaywallOfferView> createState() => _PaywallOfferViewState();
}

class _PaywallOfferViewState extends State<PaywallOfferView> {
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.purchaseController.defaultSelectedProductId;
    widget.entitlementController.addListener(_onEntitlementChanged);
    widget.purchaseController.addListener(_onPurchaseChanged);
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
        productId: _selectedProductId ?? 'unknown',
      );
      widget.onClose(PaywallResult.purchased);
    }
  }

  void _onPurchaseChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  BillingProduct? _productFor(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final p in widget.purchaseController.availableProducts) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final annualId = widget.purchaseController.resolvedAnnualProductId;
    final monthlyId = widget.purchaseController.resolvedMonthlyProductId;
    final annual = _productFor(annualId);
    final monthly = _productFor(monthlyId);
    final oneTime = _productFor(widget.purchaseController.configuredOneTimeProductId);

    if (_selectedProductId == null || _productFor(_selectedProductId) == null) {
      _selectedProductId =
          annual?.id ?? monthly?.id ?? oneTime?.id ?? _selectedProductId;
    }

    final msg = widget.request.contextMessage;
    final pad = widget.compact
        ? const EdgeInsets.fromLTRB(16, 4, 16, 16)
        : const EdgeInsets.fromLTRB(20, 8, 20, 24);
    final gap = widget.compact ? 12.0 : 20.0;

    return SingleChildScrollView(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!widget.compact) ...<Widget>[
            Text(
              'Utilivos Pro',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Speed, saved workflows, and power tools—without watering down the free tier.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (msg != null && msg.isNotEmpty) ...<Widget>[
            SizedBox(height: gap * 0.5),
            Text(
              msg,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: gap),
          const _Bullet(text: 'Unlimited pinned tools'),
          const _Bullet(text: 'Unlimited folders for organization'),
          const _Bullet(text: 'Full access to Pro catalog tools'),
          const _Bullet(text: 'Save and resume work across launches'),
          const _Bullet(text: 'Unlimited exports and file actions'),
          const _Bullet(text: 'Unlimited home screen widgets'),
          const _Bullet(text: 'Home screen shortcuts for instant launch'),
          if (widget.showCompareTable) ...<Widget>[
            SizedBox(height: gap),
            Text(
              'Free vs Pro',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const _CompareTable(),
            const SizedBox(height: 6),
            Text(
              '* Pro tools are locked by default; the catalog can enable a free preview install per tool.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: gap),
          if (annual != null)
            _PlanCard(
              title: 'Best value · Annual',
              subtitle: annual.price,
              selected: _selectedProductId == annual.id,
              emphasized: true,
              onTap: () => setState(() => _selectedProductId = annual.id),
            ),
          if (monthly != null) ...<Widget>[
            const SizedBox(height: 10),
            _PlanCard(
              title: 'Monthly',
              subtitle: monthly.price,
              selected: _selectedProductId == monthly.id,
              emphasized: false,
              onTap: () => setState(() => _selectedProductId = monthly.id),
            ),
          ],
          if (oneTime != null && annual == null && monthly == null) ...<Widget>[
            const SizedBox(height: 10),
            _PlanCard(
              title: 'Lifetime',
              subtitle: oneTime.price,
              selected: _selectedProductId == oneTime.id,
              emphasized: true,
              onTap: () => setState(() => _selectedProductId = oneTime.id),
            ),
          ],
          if (widget.purchaseController.availableProducts.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Store prices load when billing is available. Configure SKUs in AppConfig; '
              'use Settings → Developer (debug) to simulate Pro without the store.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.purchaseController.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              widget.purchaseController.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: gap * 0.8),
          FilledButton(
            onPressed: widget.purchaseController.isPurchaseInProgress ||
                    !widget.purchaseController.storeAvailable
                ? null
                : _selectedProductId == null
                    ? null
                    : () async {
                        final id = _selectedProductId!;
                        widget.analytics.conversionStarted(
                          widget.request,
                          productId: id,
                        );
                        await widget.purchaseController.purchaseProduct(id);
                      },
            child: widget.purchaseController.isPurchaseInProgress
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock Pro'),
          ),
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
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Billing is unavailable on this device. Pro may still apply if you subscribed elsewhere.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (widget.onSeeFullPlans != null) ...<Widget>[
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.onSeeFullPlans,
              child: const Text('See full comparison & details'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5));
    Widget cell(String text, {bool header = false, bool center = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: header ? FontWeight.w700 : FontWeight.w400,
            fontSize: header ? 13 : 12.5,
          ),
          textAlign: center ? TextAlign.center : TextAlign.start,
        ),
      );
    }

    TableRow row(String feature, String free, String pro) {
      return TableRow(
        children: <Widget>[
          cell(feature),
          cell(free, center: true),
          cell(pro, center: true),
        ],
      );
    }

    return Table(
      border: TableBorder(
        left: side,
        top: side,
        right: side,
        bottom: side,
        horizontalInside: side,
        verticalInside: side,
      ),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.4),
      },
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          children: <Widget>[
            cell('Feature', header: true),
            cell('Free', header: true, center: true),
            cell('Pro', header: true, center: true),
          ],
        ),
        row('Pinned tools', '3', 'Unlimited'),
        row('Folders', '3', 'Unlimited'),
        row('Pro catalog', 'Locked / preview*', 'Full access'),
        row('Save & resume', '—', 'Yes'),
        row('Exports & files / day', 'Limited', 'Unlimited'),
        row('Home screen widgets', '1', 'Unlimited'),
        row('Home shortcuts', '—', 'Yes'),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.emphasized,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: emphasized
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
