import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_category.dart';

class NotificationPreferences {
  NotificationPreferences._(this._prefs);

  final SharedPreferences _prefs;

  static Future<NotificationPreferences> open() async {
    final p = await SharedPreferences.getInstance();
    return NotificationPreferences._(p);
  }

  static const _kToolRuntime = 'notif_cat_tool_runtime';
  static const _kUpdates = 'notif_cat_updates';
  static const _kDiscover = 'notif_cat_discover';
  static const _kTimers = 'notif_cat_timers';
  static const _kWidgetOnlyUpdates = 'notif_updates_widget_only';
  static const _kDedupeUpdates = 'notif_dedupe_updates_v1';
  static const _kDiscoverSeen = 'notif_discover_seen_ids_v1';
  static const _kDiscoverLastAt = 'notif_discover_last_shown_utc_ms';

  bool isCategoryEnabled(UtilivosNotificationCategory c) {
    return switch (c) {
      UtilivosNotificationCategory.toolRuntime =>
        _prefs.getBool(_kToolRuntime) ?? true,
      UtilivosNotificationCategory.updates => _prefs.getBool(_kUpdates) ?? true,
      UtilivosNotificationCategory.discover =>
        _prefs.getBool(_kDiscover) ?? false,
      UtilivosNotificationCategory.timers => _prefs.getBool(_kTimers) ?? false,
    };
  }

  Future<void> setCategoryEnabled(
    UtilivosNotificationCategory c,
    bool value,
  ) async {
    final k = switch (c) {
      UtilivosNotificationCategory.toolRuntime => _kToolRuntime,
      UtilivosNotificationCategory.updates => _kUpdates,
      UtilivosNotificationCategory.discover => _kDiscover,
      UtilivosNotificationCategory.timers => _kTimers,
    };
    await _prefs.setBool(k, value);
  }

  bool get notifyUpdatesForWidgetToolsOnly {
    return _prefs.getBool(_kWidgetOnlyUpdates) ?? false;
  }

  Future<void> setNotifyUpdatesForWidgetToolsOnly(bool value) {
    return _prefs.setBool(_kWidgetOnlyUpdates, value);
  }

  /// Slug|latestVersion strings we have already raised an update notification for.
  Set<String> readUpdateNotificationDedupeKeys() {
    final raw = _prefs.getString(_kDedupeUpdates);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>{};
      }
      return decoded
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> addUpdateNotificationDedupeKeys(Iterable<String> keys) {
    final merged = readUpdateNotificationDedupeKeys()..addAll(keys);
    if (merged.length > 200) {
      final list = merged.toList()..sort();
      merged
        ..clear()
        ..addAll(list.sublist(list.length - 200));
    }
    return _prefs.setString(
      _kDedupeUpdates,
      jsonEncode(merged.toList()..sort()),
    );
  }

  Set<String> readDiscoverSeenPluginIds() {
    final raw = _prefs.getString(_kDiscoverSeen);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>{};
      }
      return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setDiscoverSeenPluginIds(Set<String> ids) {
    return _prefs.setString(
      _kDiscoverSeen,
      jsonEncode(ids.toList()..sort()),
    );
  }

  DateTime? get discoverLastNotificationAtUtc {
    final v = _prefs.getInt(_kDiscoverLastAt);
    if (v == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }

  Future<void> setDiscoverLastNotificationAtUtc(DateTime time) {
    return _prefs.setInt(
      _kDiscoverLastAt,
      time.toUtc().millisecondsSinceEpoch,
    );
  }
}
