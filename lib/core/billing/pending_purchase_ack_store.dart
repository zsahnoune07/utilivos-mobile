import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers product ids whose Play Billing acknowledgement ([completePurchase]) failed,
/// so cold starts can call [reconcilePendingPurchaseAcknowledgements].
abstract class PendingPurchaseAckStore {
  Future<Set<String>> readPendingProductIds();

  Future<void> markPending(String productId);

  Future<void> clearPending(String productId);
}

class SecurePendingPurchaseAckStore implements PendingPurchaseAckStore {
  SecurePendingPurchaseAckStore({
    FlutterSecureStorage? storage,
    this.storageKey = _defaultKey,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _defaultKey = 'utilivos_pending_purchase_ack_products';

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<Set<String>> readPendingProductIds() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <String>{};
    }
    final out = <String>{};
    for (final e in decoded) {
      if (e is String && e.trim().isNotEmpty) {
        out.add(e.trim());
      }
    }
    return out;
  }

  @override
  Future<void> markPending(String productId) async {
    final t = productId.trim();
    if (t.isEmpty) {
      return;
    }
    final pending = await readPendingProductIds();
    pending.add(t);
    await _storage.write(
      key: storageKey,
      value: jsonEncode(pending.toList()..sort()),
    );
  }

  @override
  Future<void> clearPending(String productId) async {
    final t = productId.trim();
    if (t.isEmpty) {
      return;
    }
    final pending = await readPendingProductIds();
    if (!pending.remove(t)) {
      return;
    }
    if (pending.isEmpty) {
      await _storage.delete(key: storageKey);
      return;
    }
    await _storage.write(
      key: storageKey,
      value: jsonEncode(pending.toList()..sort()),
    );
  }
}
