/// Central caps for the free tier. Pro users bypass these via [EntitlementController.hasProAccess].
class FreemiumLimits {
  FreemiumLimits._();

  static const int maxPinnedTools = 3;
  static const int maxFolders = 3;

  /// Distinct home-screen tool widgets free users may register (Android / future platforms).
  static const int maxHomeScreenWidgets = 1;

  /// Free-tier storage/export/download actions per calendar day (host-enforced via bridge).
  static const int maxStorageActionsPerDay = 5;

  /// Distinct tool launches before a soft paywall may appear (non-blocking until dismissed).
  static const int softPaywallMinDistinctToolLaunches = 5;

  /// Minimum hours between soft paywall impressions after dismiss.
  static const int softPaywallCooldownHours = 48;
}
