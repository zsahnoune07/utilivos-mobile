import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'freemium_limits.dart';

/// Persisted counters for free-tier quotas and soft-paywall engagement.
class FreeTierUsageStore {
  FreeTierUsageStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _keyStorageDay = 'utilivo_ft_storage_day';
  static const _keyStorageCount = 'utilivo_ft_storage_count';
  static const _keyLaunchedTools = 'utilivo_ft_distinct_launches';
  static const _keySoftDismissedAt = 'utilivo_ft_soft_paywall_dismissed_ms';

  static Future<FreeTierUsageStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return FreeTierUsageStore._(prefs);
  }

  String _todayKey() {
    final n = DateTime.now().toUtc();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _rollStorageDayIfNeeded() {
    final today = _todayKey();
    final stored = _prefs.getString(_keyStorageDay);
    if (stored != today) {
      _prefs.setString(_keyStorageDay, today);
      _prefs.setInt(_keyStorageCount, 0);
    }
  }

  int get storageActionsToday {
    _rollStorageDayIfNeeded();
    return _prefs.getInt(_keyStorageCount) ?? 0;
  }

  Future<void> recordStorageAction() async {
    _rollStorageDayIfNeeded();
    final next = storageActionsToday + 1;
    await _prefs.setInt(_keyStorageCount, next);
  }

  int get remainingFreeStorageActionsToday {
    final used = storageActionsToday;
    const cap = FreemiumLimits.maxStorageActionsPerDay;
    final left = cap - used;
    return left < 0 ? 0 : left;
  }

  /// Slugs the user has launched at least once (lifetime set, capped size).
  Future<void> recordToolLaunch(String pluginSlug) async {
    final slug = pluginSlug.trim();
    if (slug.isEmpty) {
      return;
    }
    final raw = _prefs.getStringList(_keyLaunchedTools) ?? <String>[];
    if (raw.contains(slug)) {
      return;
    }
    const maxTracked = 64;
    final next = <String>[slug, ...raw];
    if (next.length > maxTracked) {
      next.removeRange(maxTracked, next.length);
    }
    await _prefs.setStringList(_keyLaunchedTools, next);
  }

  int get distinctToolLaunchCount {
    return _prefs.getStringList(_keyLaunchedTools)?.length ?? 0;
  }

  DateTime? get lastSoftPaywallDismissedAt {
    final ms = _prefs.getInt(_keySoftDismissedAt);
    if (ms == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> markSoftPaywallDismissed() async {
    await _prefs.setInt(
      _keySoftDismissedAt,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  /// Whether a soft upsell may be shown (not on cold open — caller must gate).
  bool get shouldOfferSoftPaywall {
    if (distinctToolLaunchCount < FreemiumLimits.softPaywallMinDistinctToolLaunches) {
      return false;
    }
    final last = lastSoftPaywallDismissedAt;
    if (last == null) {
      return true;
    }
    const cooldown = Duration(hours: FreemiumLimits.softPaywallCooldownHours);
    return DateTime.now().toUtc().isAfter(last.add(cooldown));
  }

  /// Debug: reset quotas and soft-paywall engagement counters.
  Future<void> debugResetAll() async {
    if (!kDebugMode) {
      return;
    }
    await _prefs.remove(_keyStorageDay);
    await _prefs.remove(_keyStorageCount);
    await _prefs.remove(_keyLaunchedTools);
    await _prefs.remove(_keySoftDismissedAt);
  }
}
