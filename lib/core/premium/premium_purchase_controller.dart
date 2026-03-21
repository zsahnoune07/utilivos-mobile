import 'dart:async';

import 'package:flutter/foundation.dart';

import '../billing/billing_gateway.dart';
import '../billing/models/billing_models.dart';
import '../config/app_config.dart';
import '../entitlement/entitlement_controller.dart';

class PremiumPurchaseController extends ChangeNotifier {
  PremiumPurchaseController({
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
  String get configuredOneTimeProductId => _config.premiumOneTimeProductId;
  String get configuredSubscriptionProductId =>
      _config.premiumSubscriptionProductId;

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
            'Google Play Billing is unavailable on this device/runtime.';
        return;
      }

      final productIds = <String>{
        _config.premiumOneTimeProductId,
        if (_config.premiumSubscriptionProductId.trim().isNotEmpty)
          _config.premiumSubscriptionProductId.trim(),
      };

      final products = await _billingGateway.queryProducts(productIds);
      _availableProducts = products;
      if (products.isEmpty) {
        _statusMessage =
            'No premium products were returned for configured product IDs.';
      } else {
        _statusMessage = 'Premium products loaded.';
      }
    } catch (error) {
      _errorMessage = 'Failed to initialize billing: $error';
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> purchasePremium() async {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    if (!_storeAvailable) {
      _errorMessage = 'Google Play Billing is not available.';
      notifyListeners();
      return;
    }

    final product = _preferredProduct();
    if (product == null) {
      _errorMessage =
          'Premium product is unavailable. Verify product IDs in app config.';
      notifyListeners();
      return;
    }

    _isPurchaseInProgress = true;
    _statusMessage = 'Opening purchase flow...';
    notifyListeners();

    try {
      await _billingGateway.buyNonConsumable(product.id);
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

  BillingProduct? _preferredProduct() {
    final preferredId = _config.premiumOneTimeProductId;
    for (final product in _availableProducts) {
      if (product.id == preferredId) {
        return product;
      }
    }
    return _availableProducts.isEmpty ? null : _availableProducts.first;
  }

  bool _isPremiumProductId(String productId) {
    if (productId == _config.premiumOneTimeProductId) {
      return true;
    }
    return _config.premiumSubscriptionProductId.trim().isNotEmpty &&
        productId == _config.premiumSubscriptionProductId.trim();
  }

  Future<void> _onPurchaseUpdate(BillingPurchaseUpdate update) async {
    switch (update.status) {
      case BillingPurchaseStatus.pending:
        _statusMessage = 'Purchase pending confirmation...';
        break;
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        if (_isPremiumProductId(update.productId)) {
          final outcome = await _entitlementController
              .activateFromBillingPurchase(
                productId: update.productId,
                purchaseToken: update.purchaseToken ?? '',
                entitlementType:
                    update.productId == _config.premiumSubscriptionProductId
                    ? 'subscription'
                    : 'one_time',
              );

          switch (outcome) {
            case BillingVerificationOutcome.activated:
              _statusMessage = update.status == BillingPurchaseStatus.restored
                  ? 'Premium restored and verified successfully.'
                  : 'Premium unlocked and verified successfully.';
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
                  'Purchase could not be verified. Premium remains locked.';
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

  @override
  void dispose() {
    _purchaseUpdatesSubscription?.cancel();
    _billingGateway.dispose();
    super.dispose();
  }
}
