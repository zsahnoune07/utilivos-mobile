import 'models/premium_entitlement.dart';

abstract interface class EntitlementStore {
  Future<PremiumEntitlement?> read();
  Future<void> write(PremiumEntitlement entitlement);
  Future<void> clear();
}
