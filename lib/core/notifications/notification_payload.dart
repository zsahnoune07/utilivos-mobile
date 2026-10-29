import 'dart:convert';

import '../navigation/app_routes.dart';
import 'catalog_promotion_constants.dart';

/// Compact JSON payloads for [flutter_local_notifications] tap handling.
class NotificationPayloadKind {
  const NotificationPayloadKind._();

  static const String updates = 'u';
  static const String discover = 'd';
  static const String runtime = 'r';
}

String? encodeUpdatesNotificationPayload() {
  return jsonEncode(<String, String>{'k': NotificationPayloadKind.updates});
}

String? encodeDiscoverPromotedPayload() {
  return jsonEncode(<String, String>{
    'k': NotificationPayloadKind.discover,
    't': CatalogPromotionConstants.promotionTag,
  });
}

String? encodeRuntimeToolPayload(String slug) {
  final s = slug.trim();
  if (s.isEmpty) {
    return null;
  }
  return jsonEncode(<String, String>{
    'k': NotificationPayloadKind.runtime,
    's': s,
  });
}

/// Resolves a GoRouter location for in-app navigation, or null.
String? notificationPayloadToRoute(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );
    final k = map['k']?.toString();
    return switch (k) {
      NotificationPayloadKind.updates => AppRoutes.home,
      NotificationPayloadKind.discover => _routeDiscover(map),
      NotificationPayloadKind.runtime => _routeRuntime(map),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

String? _routeDiscover(Map<String, Object?> map) {
  final tag = map['t']?.toString().trim();
  if (tag != null && tag.isNotEmpty) {
    return '${AppRoutes.discover}?tag=${Uri.encodeComponent(tag)}';
  }
  return AppRoutes.discover;
}

String? _routeRuntime(Map<String, Object?> map) {
  final slug = map['s']?.toString().trim() ?? '';
  if (slug.isEmpty) {
    return null;
  }
  return AppRoutes.pluginRuntime(slug);
}
