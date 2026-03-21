enum PaywallTrigger {
  /// User hit a Pro-only action (export, persist, etc.).
  hardGate,

  /// Shown after repeated engaged use; must never block cold start.
  softEngagement,

  /// Pin/folder/storage caps.
  limitReached,

  /// Contextual upsell tied to a specific feature label.
  contextualFeature,
}

enum PaywallResult {
  dismissed,
  purchased,
  restored,
}

class PaywallRequest {
  const PaywallRequest({
    required this.trigger,
    required this.triggerSource,
    this.blockedFeatureId,
    this.contextMessage,
    this.fullScreen = true,
  });

  final PaywallTrigger trigger;
  final String triggerSource;
  final String? blockedFeatureId;
  final String? contextMessage;

  /// When true, use a full-screen route instead of a bottom sheet.
  final bool fullScreen;
}
