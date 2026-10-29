import '../logging/app_log.dart';
import '../networking/network_exception.dart';
import '../../features/discover/data/catalog_api.dart';
import '../../features/discover/data/models/catalog_models.dart';
import 'app_notification_service.dart';
import 'catalog_promotion_constants.dart';
import 'notification_preferences.dart';

/// Path 1 (plan): infrequent local poll for catalog tag [CatalogPromotionConstants.promotionTag].
class PromotionNotificationCoordinator {
  PromotionNotificationCoordinator({
    required CatalogApi catalogApi,
    required NotificationPreferences notificationPreferences,
    required AppNotificationService appNotificationService,
  }) : _catalogApi = catalogApi,
       _prefs = notificationPreferences,
       _notifications = appNotificationService;

  final CatalogApi _catalogApi;
  final NotificationPreferences _prefs;
  final AppNotificationService _notifications;

  static const Duration _minIntervalBetweenNotifications = Duration(hours: 24);
  static const Duration _minIntervalBetweenPollAttempts = Duration(minutes: 45);

  /// Last in-memory poll; avoids catalog traffic on every app resume.
  DateTime? _lastPollAtUtc;

  /// Called on app resume. At most one **notification** per 24h; API polled at most every 45m.
  Future<void> maybeNotifyAfterResume() async {
    if (!_prefs.isCategoryEnabled(UtilivosNotificationCategory.discover)) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (_lastPollAtUtc != null &&
        now.difference(_lastPollAtUtc!) < _minIntervalBetweenPollAttempts) {
      return;
    }
    _lastPollAtUtc = now;

    try {
      final page = await _catalogApi.listPlugins(
        tag: CatalogPromotionConstants.promotionTag,
        limit: 30,
        forceRefresh: true,
      );
      await _evaluate(page.items, now);
    } on NetworkException catch (e) {
      appLog(
        'PromotionNotificationCoordinator',
        'Catalog poll skipped.',
        error: e.message,
      );
    } catch (e, st) {
      appLog(
        'PromotionNotificationCoordinator',
        'Unexpected poll error.',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _evaluate(
    List<CatalogPlugin> items,
    DateTime nowUtc,
  ) async {
    if (items.isEmpty) {
      return;
    }
    final seen = _prefs.readDiscoverSeenPluginIds();
    final currentIds = items
        .map((e) => e.id.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (seen.isEmpty) {
      await _prefs.setDiscoverSeenPluginIds(currentIds);
      return;
    }

    final newly = <CatalogPlugin>[];
    for (final p in items) {
      final id = p.id.trim();
      if (id.isEmpty) {
        continue;
      }
      if (!seen.contains(id)) {
        newly.add(p);
      }
    }

    final updated = <String>{...seen, ...currentIds};
    await _prefs.setDiscoverSeenPluginIds(updated);

    if (newly.isEmpty) {
      return;
    }

    final last = _prefs.discoverLastNotificationAtUtc;
    if (last != null &&
        nowUtc.difference(last) < _minIntervalBetweenNotifications) {
      return;
    }

    await _notifications.showDiscoverPromotedNotification(
      newCount: newly.length,
      exampleName: newly.first.name,
    );
    await _prefs.setDiscoverLastNotificationAtUtc(nowUtc);
  }
}
