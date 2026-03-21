import '../entitlement/entitlement_controller.dart';
import 'freemium_limits.dart';

/// Decides whether a pin toggle toward "pinned" is allowed for the current user.
abstract class PinningPolicy {
  bool allowPinChange({
    required int currentPinnedCount,
    required bool targetPinned,
  });
}

class UnlimitedPinningPolicy implements PinningPolicy {
  const UnlimitedPinningPolicy();

  @override
  bool allowPinChange({
    required int currentPinnedCount,
    required bool targetPinned,
  }) {
    return true;
  }
}

class FreemiumPinningPolicy implements PinningPolicy {
  FreemiumPinningPolicy(this._entitlement);

  final EntitlementController _entitlement;

  @override
  bool allowPinChange({
    required int currentPinnedCount,
    required bool targetPinned,
  }) {
    if (!targetPinned) {
      return true;
    }
    if (_entitlement.hasProAccess) {
      return true;
    }
    return currentPinnedCount < FreemiumLimits.maxPinnedTools;
  }
}
