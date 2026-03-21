import 'app_routes.dart';

/// Maps incoming URIs to in-app locations. Used for cold start and [AppLinks] stream.
String? parseAppDeepLink(Uri? uri) {
  if (uri == null) {
    return null;
  }
  if (uri.scheme == 'utilivo' && uri.host == 'tool') {
    final segments = uri.pathSegments;
    final slug = segments.isNotEmpty ? segments.first.trim() : '';
    if (slug.isEmpty) {
      return null;
    }
    final restore = uri.queryParameters['restore'] == '1';
    return AppRoutes.pluginRuntime(slug, restoreSession: restore);
  }
  if (uri.scheme == 'https' &&
      (uri.host == 'app.utilivo.com' || uri.host == 'www.app.utilivo.com')) {
    final parts = uri.pathSegments;
    if (parts.length >= 2 && parts[0] == 'tool') {
      final slug = parts[1].trim();
      if (slug.isEmpty) {
        return null;
      }
      final restore = uri.queryParameters['restore'] == '1';
      return AppRoutes.pluginRuntime(slug, restoreSession: restore);
    }
  }
  return null;
}
