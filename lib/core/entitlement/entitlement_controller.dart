import 'dart:async';

import 'package:flutter/foundation.dart';

import '../networking/network_exception.dart';
import 'entitlement_store.dart';
import 'entitlement_verification_api.dart';
import 'models/entitlement_verification_result.dart';
import 'models/pro_entitlement.dart';

enum EntitlementState { initializing, ready, failed }

enum BillingVerificationOutcome { activated, pending, rejected }

class EntitlementController extends ChangeNotifier {
  EntitlementController({
    required EntitlementStore store,
    EntitlementVerificationApi? verificationApi,
    String platform = 'android',
    String packageName = 'com.utilivos.utilivos_mobile',
    Duration offlineGracePeriod = const Duration(days: 3),
    Duration backgroundReverifyInterval = const Duration(minutes: 10),
    String? Function()? getDeviceId,
    Future<String?> Function(String productId)? storeTokenRefresher,
  }) : _store = store,
       _verificationApi = verificationApi,
       _platform = platform.trim().isEmpty ? 'android' : platform.trim(),
       _packageName = packageName.trim(),
       _offlineGracePeriod = offlineGracePeriod,
       _backgroundReverifyInterval = backgroundReverifyInterval,
       _getDeviceId = getDeviceId,
       _storeTokenRefresher = storeTokenRefresher;

  final EntitlementStore _store;
  final EntitlementVerificationApi? _verificationApi;
  final String _platform;
  final String _packageName;
  final Duration _offlineGracePeriod;
  final Duration _backgroundReverifyInterval;
  final String? Function()? _getDeviceId;
  final Future<String?> Function(String productId)? _storeTokenRefresher;

  bool _bootstrapStarted = false;
  bool _verificationInFlight = false;
  EntitlementState _state = EntitlementState.initializing;
  ProEntitlement _entitlement = ProEntitlement.inactive();
  String? _errorMessage;
  Timer? _backgroundReverifyTimer;

  EntitlementState get state => _state;
  bool get isInitializing => _state == EntitlementState.initializing;
  bool get isReady => _state == EntitlementState.ready;
  bool get hasFailed => _state == EntitlementState.failed;
  String? get errorMessage => _errorMessage;
  ProEntitlement get entitlement => _entitlement;

  bool get hasProAccess {
    if (!_entitlement.proActive) {
      return false;
    }

    final now = DateTime.now().toUtc();
    if (_entitlement.storeExpiresAt != null &&
        now.isAfter(_entitlement.storeExpiresAt!)) {
      return false;
    }

    if (_entitlement.graceExpiresAt != null &&
        now.isAfter(_entitlement.graceExpiresAt!)) {
      return false;
    }

    return true;
  }

  String? get activeAssertionToken {
    final token = _entitlement.assertionToken;
    final expiresAt = _entitlement.assertionExpiresAt;
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
      return null;
    }
    return token;
  }

  Future<void> bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;
    _state = EntitlementState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      final storedEntitlement = await _store.read().timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
      _entitlement = _normalizeStoredEntitlement(
        storedEntitlement ?? ProEntitlement.inactive(),
      );
      _state = EntitlementState.ready;
      try {
        await _store.write(_entitlement).timeout(const Duration(seconds: 12));
      } on TimeoutException {
        // Proceed with normalized in-memory state if secure storage write hangs.
      }
    } catch (error) {
      _entitlement = ProEntitlement.inactive();
      _state = EntitlementState.failed;
      _errorMessage = 'Failed to load entitlement state: $error';
      notifyListeners();
      return;
    }

    _scheduleBackgroundReverify();
    notifyListeners();
    unawaited(backgroundReverify(reason: 'bootstrap'));
  }

  Future<void> retryBootstrap() async {
    _bootstrapStarted = false;
    await bootstrap();
  }

  Future<BillingVerificationOutcome> activateFromBillingPurchase({
    required String productId,
    required String purchaseToken,
    String entitlementType = 'one_time',
  }) async {
    final trimmedProductId = productId.trim();
    final trimmedToken = purchaseToken.trim();
    if (trimmedProductId.isEmpty || trimmedToken.isEmpty) {
      _errorMessage = 'Missing billing product id or store token.';
      notifyListeners();
      return BillingVerificationOutcome.rejected;
    }

    final now = DateTime.now().toUtc();
    _entitlement = _entitlement.copyWith(
      proActive: false,
      updatedAt: now,
      entitlementType: entitlementType,
      productId: trimmedProductId,
      purchaseToken: trimmedToken,
      verificationSource: 'billing_pending_verification',
    );
    await _persist(_entitlement);

    if (_verificationApi == null) {
      final fallbackEntitlement = _entitlement.copyWith(
        proActive: true,
        updatedAt: now,
        lastVerificationAt: now,
        graceExpiresAt: now.add(_offlineGracePeriod),
        verificationSource: 'billing_local_fallback',
      );
      await _persist(fallbackEntitlement);
      _scheduleBackgroundReverify();
      return BillingVerificationOutcome.activated;
    }

    try {
      final verification = await _verificationApi.verify(
        platform: _platform,
        productId: trimmedProductId,
        storeToken: trimmedToken,
        packageName: _packageName,
        deviceId: _getDeviceId?.call(),
      );
      final persisted = _entitlementFromVerification(
        verification: verification,
        productId: trimmedProductId,
        purchaseToken: trimmedToken,
        fallbackEntitlementType: entitlementType,
        verificationSource: 'server_verified_after_billing',
      );
      await _persist(persisted);
      _scheduleBackgroundReverify();
      return verification.proActive
          ? BillingVerificationOutcome.activated
          : BillingVerificationOutcome.rejected;
    } on NetworkException catch (error) {
      return _handleVerificationNetworkFailure(
        error: error,
        productId: trimmedProductId,
        purchaseToken: trimmedToken,
        entitlementType: entitlementType,
      );
    } catch (error) {
      _errorMessage = 'Entitlement verification failed: $error';
      await _persist(
        _entitlement.copyWith(
          proActive: false,
          updatedAt: now,
          verificationSource: 'verification_failed',
        ),
      );
      return BillingVerificationOutcome.rejected;
    }
  }

  Future<void> backgroundReverify({String reason = 'background'}) async {
    if (_verificationInFlight || _verificationApi == null) {
      return;
    }
    final productId = _entitlement.productId?.trim();
    if (productId == null || productId.isEmpty) {
      return;
    }

    var purchaseToken = _entitlement.purchaseToken?.trim();
    if (purchaseToken == null || purchaseToken.isEmpty) {
      final refresher = _storeTokenRefresher;
      if (refresher == null) {
        return;
      }
      purchaseToken = (await refresher(productId))?.trim();
      if (purchaseToken == null || purchaseToken.isEmpty) {
        return;
      }
    }

    _verificationInFlight = true;
    try {
      final verification = await _verificationApi.verify(
        platform: _platform,
        productId: productId,
        storeToken: purchaseToken,
        packageName: _packageName,
        deviceId: _getDeviceId?.call(),
      );
      await _persist(
        _entitlementFromVerification(
          verification: verification,
          productId: productId,
          purchaseToken: purchaseToken,
          fallbackEntitlementType: _entitlement.entitlementType ?? 'one_time',
          verificationSource: 'server_reverify_$reason',
        ),
      );
    } on NetworkException catch (error) {
      await _applyGraceAfterNetworkFailure(error, reason: reason);
    } catch (_) {
      // Keep previous entitlement state for non-network background failures.
    } finally {
      _verificationInFlight = false;
    }
  }

  Future<void> setInactive() async {
    final now = DateTime.now().toUtc();
    await _persist(
      _entitlement.copyWith(
        proActive: false,
        updatedAt: now,
        purchaseToken: null,
        assertionToken: null,
        assertionExpiresAt: null,
        verificationSource: 'manual_clear',
      ),
    );
  }

  void onAppResumed() {
    final now = DateTime.now().toUtc();
    final last = _entitlement.lastVerificationAt;
    if (last != null &&
        now.difference(last) < const Duration(minutes: 2)) {
      return;
    }
    unawaited(backgroundReverify(reason: 'app_resumed'));
  }

  ProEntitlement _normalizeStoredEntitlement(ProEntitlement stored) {
    final now = DateTime.now().toUtc();
    var normalized = stored;

    if (normalized.proActive && normalized.graceExpiresAt == null) {
      final baseTime = normalized.lastVerificationAt ?? normalized.updatedAt;
      normalized = normalized.copyWith(
        graceExpiresAt: baseTime.add(_offlineGracePeriod),
      );
    }

    if (normalized.proActive && !hasProAccessFor(normalized, now)) {
      normalized = normalized.copyWith(
        proActive: false,
        updatedAt: now,
        assertionToken: null,
        assertionExpiresAt: null,
        verificationSource: 'grace_or_store_expired_on_bootstrap',
      );
    }

    final assertion = normalized.assertionToken?.trim();
    final storedToken = normalized.purchaseToken?.trim();
    if (assertion != null &&
        assertion.isNotEmpty &&
        storedToken != null &&
        storedToken.isNotEmpty) {
      normalized = normalized.copyWith(purchaseToken: null);
    }

    return normalized;
  }

  bool hasProAccessFor(ProEntitlement entitlement, DateTime now) {
    if (!entitlement.proActive) {
      return false;
    }
    if (entitlement.storeExpiresAt != null &&
        now.isAfter(entitlement.storeExpiresAt!)) {
      return false;
    }
    if (entitlement.graceExpiresAt != null &&
        now.isAfter(entitlement.graceExpiresAt!)) {
      return false;
    }
    return true;
  }

  ProEntitlement _entitlementFromVerification({
    required EntitlementVerificationResult verification,
    required String productId,
    required String purchaseToken,
    required String fallbackEntitlementType,
    required String verificationSource,
  }) {
    final now = DateTime.now().toUtc();
    final assertion = verification.assertionToken?.trim();
    final shouldClearPersistedStoreToken = verification.proActive &&
        assertion != null &&
        assertion.isNotEmpty;
    return ProEntitlement(
      proActive: verification.proActive,
      updatedAt: now,
      entitlementType: verification.entitlementType ?? fallbackEntitlementType,
      productId: productId,
      purchaseToken: shouldClearPersistedStoreToken ? null : purchaseToken,
      storeExpiresAt: verification.expiresAt,
      assertionToken: verification.assertionToken,
      assertionExpiresAt: verification.assertionExpiresAt,
      graceExpiresAt: verification.proActive
          ? now.add(_offlineGracePeriod)
          : null,
      verificationState: verification.verificationState,
      lastVerificationAt: now,
      verificationSource: verificationSource,
    );
  }

  BillingVerificationOutcome _handleVerificationNetworkFailure({
    required NetworkException error,
    required String productId,
    required String purchaseToken,
    required String entitlementType,
  }) {
    final now = DateTime.now().toUtc();
    final isNetworkError =
        error.kind == NetworkExceptionKind.noConnection ||
        error.kind == NetworkExceptionKind.timeout;

    if (!isNetworkError) {
      _errorMessage = error.message;
      unawaited(
        _persist(
          _entitlement.copyWith(
            proActive: false,
            updatedAt: now,
            verificationSource: 'verification_failed_non_network',
          ),
        ),
      );
      return BillingVerificationOutcome.rejected;
    }

    final canUseGrace = hasProAccessFor(_entitlement, now);
    if (canUseGrace) {
      unawaited(
        _persist(
          _entitlement.copyWith(
            proActive: true,
            updatedAt: now,
            verificationSource: 'offline_grace_after_billing',
          ),
        ),
      );
      return BillingVerificationOutcome.activated;
    }

    unawaited(
      _persist(
        _entitlement.copyWith(
          proActive: false,
          updatedAt: now,
          productId: productId,
          purchaseToken: purchaseToken,
          entitlementType: entitlementType,
          verificationSource: 'verification_pending_offline',
        ),
      ),
    );
    _scheduleBackgroundReverify();
    return BillingVerificationOutcome.pending;
  }

  Future<void> _applyGraceAfterNetworkFailure(
    NetworkException error, {
    required String reason,
  }) async {
    final now = DateTime.now().toUtc();
    final isNetworkError =
        error.kind == NetworkExceptionKind.noConnection ||
        error.kind == NetworkExceptionKind.timeout;
    if (!isNetworkError) {
      return;
    }

    if (hasProAccessFor(_entitlement, now)) {
      await _persist(
        _entitlement.copyWith(
          proActive: true,
          updatedAt: now,
          verificationSource: 'offline_grace_$reason',
        ),
      );
      return;
    }

    if (_entitlement.proActive) {
      await _persist(
        _entitlement.copyWith(
          proActive: false,
          updatedAt: now,
          assertionToken: null,
          assertionExpiresAt: null,
          verificationSource: 'grace_expired_$reason',
        ),
      );
    }
  }

  void _scheduleBackgroundReverify() {
    _backgroundReverifyTimer?.cancel();
    final hasProductId = _entitlement.productId?.trim().isNotEmpty ?? false;
    final hasStoredToken = _entitlement.purchaseToken?.trim().isNotEmpty ?? false;
    final canRefreshToken = _storeTokenRefresher != null && hasProductId;
    final canReverify =
        _verificationApi != null &&
        hasProductId &&
        (hasStoredToken || canRefreshToken);
    if (!canReverify) {
      return;
    }
    _backgroundReverifyTimer = Timer.periodic(
      _backgroundReverifyInterval,
      (_) => unawaited(backgroundReverify(reason: 'interval')),
    );
  }

  Future<void> _persist(ProEntitlement entitlement) async {
    await _store.write(entitlement);
    _entitlement = entitlement;
    _state = EntitlementState.ready;
    _errorMessage = null;
    notifyListeners();
  }

  /// Debug / local QA only: treat the device as Pro for in-app gates and downloads.
  ///
  /// The assertion string is synthetic; your API must accept
  /// `DEBUG_UTILIVO_LOCAL_PRO` in dev/staging, or use catalog preview installs
  /// without an assertion. Stripped in release (no-op).
  Future<void> debugGrantLocalProEntitlement() async {
    if (!kDebugMode) {
      return;
    }
    final now = DateTime.now().toUtc();
    await _persist(
      ProEntitlement(
        proActive: true,
        updatedAt: now,
        entitlementType: 'debug_local',
        productId: 'debug_pro',
        purchaseToken: 'debug_purchase_token',
        assertionToken: 'DEBUG_UTILIVO_LOCAL_PRO',
        assertionExpiresAt: now.add(const Duration(days: 365)),
        graceExpiresAt: now.add(const Duration(days: 365)),
        verificationState: 'debug',
        lastVerificationAt: now,
        verificationSource: 'debug_local_simulation',
      ),
    );
  }

  /// Debug: clear simulated or real stored entitlement (same as inactive reset).
  Future<void> debugClearLocalProEntitlement() async {
    if (!kDebugMode) {
      return;
    }
    await setInactive();
  }

  @override
  void dispose() {
    _backgroundReverifyTimer?.cancel();
    super.dispose();
  }
}
