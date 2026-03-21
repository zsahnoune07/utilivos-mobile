import 'dart:async';

import 'package:flutter/foundation.dart';

import '../billing/billing_gateway.dart';
import '../billing/models/billing_models.dart';
import '../config/app_config.dart';
import '../entitlement/entitlement_controller.dart';

class ProPurchaseController extends ChangeNotifier {
  ProPurchaseController({
    required AppConfig config,
    required BillingGateway billingGateway,
    required EntitlementController entitlementController,
  }) : _config = config,
       _billingGateway = billingGateway,
       _entitlementController = entitlementController;

  final AppConfig _config;
  final BillingGateway _billingGateway;
  final EntitlementController _entitlementController;

  StreamSubscription<BillingPurchaseUpdate>? _purchaseUpdatesSubscription;
  bool _initialized = false;

  bool _storeAvailable = false;
  bool _isLoadingProducts = false;
  bool _isPurchaseInProgress = false;
  bool _isRestoreInProgress = false;
  String? _statusMessage;
  String? _errorMessage;
  List<BillingProduct> _availableProducts = const <BillingProduct>[];

  bool get storeAvailable => _storeAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPurchaseInProgress => _isPurchaseInProgress;
  bool get isRestoreInProgress => _isRestoreInProgress;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  List<BillingProduct> get availableProducts => _availableProducts;
  bool get canPurchase =>
      _storeAvailable && !_isLoadingProducts && _availableProducts.isNotEmpty;
  String get configuredOneTimeProductId => _config.proOneTimeProductId;
  String get configuredSubscriptionProductId =>
      _config.proSubscriptionProductId;

  /// Falls back to legacy [AppConfig.proSubscriptionProductId] when annual id unset.
  String get resolvedAnnualProductId {
    final explicit = _config.proSubscriptionAnnualProductId.trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    return _config.proSubscriptionProductId.trim();
  }

  String get resolvedMonthlyProductId =>
      _config.proSubscriptionMonthlyProductId.trim();

  /// Prefer annual → monthly → one-time for default selection in paywall.
  String? get defaultSelectedProductId {
    final annual = resolvedAnnualProductId;
    if (annual.isNotEmpty) {
      return annual;
    }
    final monthly = resolvedMonthlyProductId;
    if (monthly.isNotEmpty) {
      return monthly;
    }
    return _config.proOneTimeProductId;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _purchaseUpdatesSubscription = _billingGateway.purchaseUpdates.listen(
      _onPurchaseUpdate,
    );

    _isLoadingProducts = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeAvailable = await _billingGateway.isAvailable();
      if (!_storeAvailable) {
        _statusMessage =
            'Google Play Billing is unavailable on this device/runtime. '
            'Use debug tools to simulate Pro while validating UX.';
        return;
      }

      final productIds = <String>{
        _config.proOneTimeProductId,
        if (_config.proSubscriptionProductId.trim().isNotEmpty)
          _config.proSubscriptionProductId.trim(),
        if (_config.proSubscriptionMonthlyProductId.trim().isNotEmpty)
          _config.proSubscriptionMonthlyProductId.trim(),
        if (_config.proSubscriptionAnnualProductId.trim().isNotEmpty)
          _config.proSubscriptionAnnualProductId.trim(),
      };

      final products = await _billingGateway.queryProducts(productIds);
      _availableProducts = products;
      if (products.isEmpty) {
        _statusMessage =
            'No Pro products were returned for configured product IDs.';
      } else {
        _statusMessage = 'Pro products loaded.';
      }
    } catch (error) {
      _errorMessage = 'Failed to initialize billing: $error';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> purchasePro() async {
    final id = defaultSelectedProductId;
    if (id == null || id.isEmpty) {
      _errorMessage = 'No Pro product IDs are configured.';
      notifyListeners();
      return;
    }
    await purchaseProduct(id);
  }

  Future<void> purchaseProduct(String productId) async {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    if (!_storeAvailable) {
      _errorMessage = 'Google Play Billing is not available.';
      notifyListeners();
      return;
    }

    final trimmed = productId.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Invalid product id.';
      notifyListeners();
      return;
    }

    _isPurchaseInProgress = true;
    _statusMessage = 'Opening purchase flow...';
    notifyListeners();

    try {
      await _billingGateway.buyProduct(trimmed);
    } catch (error) {
      _isPurchaseInProgress = false;
      _errorMessage = 'Could not start purchase flow: $error';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    if (!_storeAvailable) {
      _errorMessage = 'Google Play Billing is not available.';
      notifyListeners();
      return;
    }

    _isRestoreInProgress = true;
    _statusMessage = 'Restoring previous purchases...';
    notifyListeners();

    try {
      await _billingGateway.restorePurchases();
    } catch (error) {
      _isRestoreInProgress = false;
      _errorMessage = 'Failed to start restore flow: $error';
      notifyListeners();
    }
  }

  bool _isProProductId(String productId) {
    if (productId == _config.proOneTimeProductId) {
      return true;
    }
    final monthly = resolvedMonthlyProductId;
    if (monthly.isNotEmpty && productId == monthly) {
      return true;
    }
    final annual = resolvedAnnualProductId;
    if (annual.isNotEmpty && productId == annual) {
      return true;
    }
    final legacy = _config.proSubscriptionProductId.trim();
    return legacy.isNotEmpty && productId == legacy;
  }

  String _entitlementTypeForProduct(String productId) {
    if (productId == _config.proOneTimeProductId) {
      return 'one_time';
    }
    return 'subscription';
  }

  Future<void> _onPurchaseUpdate(BillingPurchaseUpdate update) async {
    switch (update.status) {
      case BillingPurchaseStatus.pending:
        _statusMessage = 'Purchase pending confirmation...';
        break;
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        if (_isProProductId(update.productId)) {
          final outcome = await _entitlementController
              .activateFromBillingPurchase(
                productId: update.productId,
                purchaseToken: update.purchaseToken ?? '',
                entitlementType: _entitlementTypeForProduct(update.productId),
              );

          switch (outcome) {
            case BillingVerificationOutcome.activated:
              _statusMessage = update.status == BillingPurchaseStatus.restored
                  ? 'Pro restored and verified successfully.'
                  : 'Pro unlocked and verified successfully.';
              _errorMessage = null;
              break;
            case BillingVerificationOutcome.pending:
              _statusMessage =
                  'Purchase recorded. Waiting for online entitlement verification.';
              _errorMessage = null;
              break;
            case BillingVerificationOutcome.rejected:
              _statusMessage = null;
              _errorMessage =
                  'Purchase could not be verified. Pro remains locked.';
              break;
          }
        } else {
          _statusMessage = 'Purchase received for ${update.productId}.';
        }
        _isPurchaseInProgress = false;
        _isRestoreInProgress = false;
        break;
      case BillingPurchaseStatus.canceled:
        _isPurchaseInProgress = false;
        _isRestoreInProgress = false;
        _statusMessage = 'Purchase canceled.';
        break;
      case BillingPurchaseStatus.error:
        _isPurchaseInProgress = false;
        _isRestoreInProgress = false;
        _errorMessage = update.errorMessage ?? 'Purchase failed.';
        break;
    }
    notifyListeners();
  }

  /// Debug: simulate billing UX without a store (messages only).
  void debugSimulatePurchaseCanceled() {
    if (!kDebugMode) {
      return;
    }
    _isPurchaseInProgress = false;
    _isRestoreInProgress = false;
    _errorMessage = null;
    _statusMessage = 'Purchase canceled (simulated).';
    notifyListeners();
  }

  /// Debug: simulate a failed purchase attempt (messages only).
  void debugSimulatePurchaseFailed() {
    if (!kDebugMode) {
      return;
    }
    _isPurchaseInProgress = false;
    _isRestoreInProgress = false;
    _statusMessage = null;
    _errorMessage = 'Purchase failed (simulated).';
    notifyListeners();
  }

  /// Debug: clear purchase status lines from the panel.
  void debugClearPurchaseMessages() {
    if (!kDebugMode) {
      return;
    }
    _statusMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseUpdatesSubscription?.cancel();
    _billingGateway.dispose();
    super.dispose();
  }
}
