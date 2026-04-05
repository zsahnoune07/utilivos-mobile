import 'plugin_version_compare.dart';

/// Strips Flutter/Android build suffix (`1.0.0+42` → `1.0.0`).
String normalizeAppVersionLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return t;
  }
  final plus = t.indexOf('+');
  if (plus >= 0) {
    return t.substring(0, plus).trim();
  }
  return t;
}

/// Returns `true` when the running app is **strictly older** than [minimumVersion].
///
/// * Missing or blank [minimumVersion] → `false` (no gate).
/// * Unparseable [minimumVersion] → `false` (do not lock users out).
/// * Unparseable [currentAppVersion] but parseable minimum → `true` (fail closed).
bool isHostAppBelowMinimum({
  required String currentAppVersion,
  required String? minimumVersion,
}) {
  final minRaw = minimumVersion?.trim();
  if (minRaw == null || minRaw.isEmpty) {
    return false;
  }

  final current = normalizeAppVersionLabel(currentAppVersion);
  final min = normalizeAppVersionLabel(minRaw);
  if (current.isEmpty) {
    return _hasParseableMinimum(min);
  }

  final currentParts = parsePluginVersionParts(current);
  final minParts = parsePluginVersionParts(min);
  if (minParts == null) {
    return false;
  }
  if (currentParts == null) {
    return true;
  }

  final maxLen = currentParts.length > minParts.length
      ? currentParts.length
      : minParts.length;
  for (var i = 0; i < maxLen; i++) {
    final c = i < currentParts.length ? currentParts[i] : 0;
    final m = i < minParts.length ? minParts[i] : 0;
    if (c < m) {
      return true;
    }
    if (c > m) {
      return false;
    }
  }
  return false;
}

bool _hasParseableMinimum(String min) {
  return parsePluginVersionParts(min) != null;
}

/// Compares two app version labels for ordering: negative if [a] < [b], etc.
int compareAppVersionLabels(String a, String b) {
  final ap = parsePluginVersionParts(normalizeAppVersionLabel(a));
  final bp = parsePluginVersionParts(normalizeAppVersionLabel(b));
  if (ap == null && bp == null) {
    return normalizeAppVersionLabel(a).compareTo(normalizeAppVersionLabel(b));
  }
  if (ap == null) {
    return -1;
  }
  if (bp == null) {
    return 1;
  }
  final maxLen = ap.length > bp.length ? ap.length : bp.length;
  for (var i = 0; i < maxLen; i++) {
    final av = i < ap.length ? ap[i] : 0;
    final bv = i < bp.length ? bp[i] : 0;
    if (av < bv) {
      return -1;
    }
    if (av > bv) {
      return 1;
    }
  }
  return 0;
}
