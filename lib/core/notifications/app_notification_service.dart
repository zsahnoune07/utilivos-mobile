import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_category.dart';
import 'notification_channel_ids.dart';
import 'notification_payload.dart';
import 'notification_preferences.dart';

export 'notification_category.dart' show UtilivosNotificationCategory;

class AppNotificationService {
  AppNotificationService({required NotificationPreferences notificationPreferences})
    : _prefs = notificationPreferences;

  final NotificationPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Random _random = Random();

  /// Set from [UtilivosApp] when [GoRouter] is ready. Cold-start tap is handled via
  /// [consumePendingLaunchRoute].
  void Function(String location)? onNavigate;

  static const int _notificationIdUpdates = 901001;
  static const int _notificationIdDiscover = 901002;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _createAndroidChannels();
    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }
    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        UtilivosNotificationChannelIds.toolRuntime,
        'Tool runtime alerts',
        description: 'Notifications raised by running tools.',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        UtilivosNotificationChannelIds.updates,
        'Tool updates',
        description: 'When installed tools have new versions on the server.',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        UtilivosNotificationChannelIds.discover,
        'Tool Library highlights',
        description: 'New and featured tools in the catalog.',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        UtilivosNotificationChannelIds.timers,
        'Focus and timers',
        description: 'Ongoing focus timers (reserved for future use).',
        importance: Importance.low,
      ),
    ];
    for (final c in channels) {
      await android.createNotificationChannel(c);
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final loc = notificationPayloadToRoute(response.payload);
    if (loc != null) {
      onNavigate?.call(loc);
    }
  }

  /// If the app was opened from a notification tap, returns the target route (once).
  Future<String?> consumePendingLaunchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null) {
      return null;
    }
    if (details.didNotificationLaunchApp != true) {
      return null;
    }
    return notificationPayloadToRoute(
      details.notificationResponse?.payload,
    );
  }

  int _nextRuntimeNotificationId() {
    return 10000 + _random.nextInt(1 << 20);
  }

  Future<bool> showToolRuntimeAlert({
    required String title,
    required String body,
    String? toolSlug,
  }) async {
    if (!_prefs.isCategoryEnabled(UtilivosNotificationCategory.toolRuntime)) {
      return false;
    }
    if (!_initialized) {
      return false;
    }
    final payload = toolSlug != null
        ? encodeRuntimeToolPayload(toolSlug)
        : null;
    try {
      final style = body.length > 80
          ? BigTextStyleInformation(body)
          : null;
      await _plugin.show(
        _nextRuntimeNotificationId(),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            UtilivosNotificationChannelIds.toolRuntime,
            'Tool runtime alerts',
            channelDescription: 'Notifications raised by running tools.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: style,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            threadIdentifier: UtilivosNotificationChannelIds.toolRuntime,
          ),
        ),
        payload: payload,
      );
      return true;
    } catch (e, st) {
      assert(() {
        debugPrint('showToolRuntimeAlert failed: $e $st');
        return true;
      }());
      return false;
    }
  }

  Future<void> showBatchedUpdateNotification({
    required List<String> toolNames,
  }) async {
    if (toolNames.isEmpty) {
      return;
    }
    if (!_prefs.isCategoryEnabled(UtilivosNotificationCategory.updates)) {
      return;
    }
    if (!_initialized) {
      return;
    }
    final title = toolNames.length == 1
        ? 'Update available'
        : 'Updates available';
    final body = toolNames.length == 1
        ? '${toolNames.first} has a new version.'
        : '${toolNames.length} tools have updates: ${toolNames.join(', ')}.';
    try {
      final big = toolNames.length > 1
          ? BigTextStyleInformation(body)
          : null;
      await _plugin.show(
        _notificationIdUpdates,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            UtilivosNotificationChannelIds.updates,
            'Tool updates',
            channelDescription:
                'When installed tools have new versions on the server.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: big,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            threadIdentifier: UtilivosNotificationChannelIds.updates,
          ),
        ),
        payload: encodeUpdatesNotificationPayload(),
      );
    } catch (e, st) {
      assert(() {
        debugPrint('showBatchedUpdateNotification failed: $e $st');
        return true;
      }());
    }
  }

  Future<void> showDiscoverPromotedNotification({
    required int newCount,
    String? exampleName,
  }) async {
    if (newCount <= 0) {
      return;
    }
    if (!_prefs.isCategoryEnabled(UtilivosNotificationCategory.discover)) {
      return;
    }
    if (!_initialized) {
      return;
    }
    const title = 'New in the Tool Library';
    final body = exampleName != null && exampleName.trim().isNotEmpty
        ? '$newCount new featured tool${newCount == 1 ? '' : 's'} (e.g. $exampleName).'
        : '$newCount new featured tool${newCount == 1 ? '' : 's'}.';
    try {
      await _plugin.show(
        _notificationIdDiscover,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            UtilivosNotificationChannelIds.discover,
            'Tool Library highlights',
            channelDescription: 'New and featured tools in the catalog.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: body.length > 100
                ? BigTextStyleInformation(body)
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
            threadIdentifier: UtilivosNotificationChannelIds.discover,
          ),
        ),
        payload: encodeDiscoverPromotedPayload(),
      );
    } catch (e, st) {
      assert(() {
        debugPrint('showDiscoverPromotedNotification failed: $e $st');
        return true;
      }());
    }
  }
}
