import 'models/pro_entitlement.dart';

abstract interface class EntitlementStore {
  Future<ProEntitlement?> read();
  Future<void> write(ProEntitlement entitlement);
  Future<void> clear();
}
