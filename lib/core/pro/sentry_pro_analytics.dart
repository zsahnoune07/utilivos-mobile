import 'package:sentry_flutter/sentry_flutter.dart';

import 'paywall_models.dart';
import 'pro_analytics.dart';

/// Release funnel breadcrumbs (no PII); requires [SentryFlutter.init] with a DSN.
class SentryProAnalytics implements ProAnalytics {
  const SentryProAnalytics();

  void _crumb(String message, Map<String, String> data) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: 'pro_analytics',
        level: SentryLevel.info,
        data: data,
      ),
    );
  }

  @override
  void paywallShown(PaywallRequest request) {
    _crumb('paywall_shown', <String, String>{
      'trigger': request.trigger.name,
      'source': request.triggerSource,
      'feature': request.blockedFeatureId ?? '',
    });
  }

  @override
  void paywallDismissed(PaywallRequest request, {required bool converted}) {
    _crumb('paywall_dismissed', <String, String>{
      'trigger': request.trigger.name,
      'converted': converted.toString(),
    });
  }

  @override
  void conversionStarted(PaywallRequest request, {required String productId}) {
    _crumb('conversion_started', <String, String>{
      'trigger': request.trigger.name,
      'product_id': productId,
    });
  }

  @override
  void conversionSuccess(PaywallRequest request, {required String productId}) {
    _crumb('conversion_success', <String, String>{
      'trigger': request.trigger.name,
      'product_id': productId,
    });
  }

  @override
  void blockedFeatureAttempted({
    required String featureId,
    required String source,
  }) {
    _crumb('blocked_feature', <String, String>{
      'feature_id': featureId,
      'source': source,
    });
  }
}
