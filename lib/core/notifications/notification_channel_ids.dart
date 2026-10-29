import 'package:flutter/foundation.dart';

import 'notification_category.dart';

/// Android notification channel ids (iOS uses these as thread identifiers / grouping hints).
@immutable
class UtilivosNotificationChannelIds {
  const UtilivosNotificationChannelIds._();

  static const String toolRuntime = 'utilivos_tool_runtime';
  static const String updates = 'utilivos_updates';
  static const String discover = 'utilivos_discover';
  static const String timers = 'utilivos_timers';

  static String channelIdFor(UtilivosNotificationCategory category) {
    return switch (category) {
      UtilivosNotificationCategory.toolRuntime => toolRuntime,
      UtilivosNotificationCategory.updates => updates,
      UtilivosNotificationCategory.discover => discover,
      UtilivosNotificationCategory.timers => timers,
    };
  }
}
