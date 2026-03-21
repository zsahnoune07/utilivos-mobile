import 'paywall_models.dart';

/// Hooks for subscription funnel analytics; replace with Firebase/Amplitude etc.
abstract class ProAnalytics {
  void paywallShown(PaywallRequest request);

  void paywallDismissed(PaywallRequest request, {required bool converted});

  void conversionStarted(PaywallRequest request, {required String productId});

  void conversionSuccess(PaywallRequest request, {required String productId});

  void blockedFeatureAttempted({
    required String featureId,
    required String source,
  });
}

/// Logs in debug mode only; no-op in release unless kDebugMode.
class DebugProAnalytics implements ProAnalytics {
  @override
  void paywallShown(PaywallRequest request) {
    assert(() {
      // ignore: avoid_print
      print(
        '[ProAnalytics] paywall_shown trigger=${request.trigger.name} '
        'source=${request.triggerSource} feature=${request.blockedFeatureId}',
      );
      return true;
    }());
  }

  @override
  void paywallDismissed(PaywallRequest request, {required bool converted}) {
    assert(() {
      // ignore: avoid_print
      print(
        '[ProAnalytics] paywall_dismissed converted=$converted '
        'trigger=${request.trigger.name}',
      );
      return true;
    }());
  }

  @override
  void conversionStarted(PaywallRequest request, {required String productId}) {
    assert(() {
      // ignore: avoid_print
      print(
        '[ProAnalytics] conversion_started product=$productId '
        'trigger=${request.trigger.name}',
      );
      return true;
    }());
  }

  @override
  void conversionSuccess(PaywallRequest request, {required String productId}) {
    assert(() {
      // ignore: avoid_print
      print(
        '[ProAnalytics] conversion_success product=$productId '
        'trigger=${request.trigger.name}',
      );
      return true;
    }());
  }

  @override
  void blockedFeatureAttempted({
    required String featureId,
    required String source,
  }) {
    assert(() {
      // ignore: avoid_print
      print(
        '[ProAnalytics] blocked_feature feature=$featureId source=$source',
      );
      return true;
    }());
  }
}
