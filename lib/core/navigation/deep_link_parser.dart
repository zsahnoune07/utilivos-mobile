import 'app_routes.dart';

/// Maps incoming URIs to in-app locations. Used for cold start and [AppLinks] stream.
String? parseAppDeepLink(Uri? uri) {
  if (uri == null) {
    return null;
  }
  if (uri.scheme == 'utilivos' && uri.host == 'tool') {
    final segments = uri.pathSegments;
    final slug = segments.isNotEmpty ? segments.first.trim() : '';
    if (slug.isEmpty) {
      return null;
    }
    final restore = uri.queryParameters['restore'] == '1';
    final widget = uri.queryParameters['widget']?.trim();
    final session = uri.queryParameters['session']?.trim();
    final toolName = uri.queryParameters['name']?.trim();
    return AppRoutes.pluginRuntime(
      slug,
      toolName: toolName != null && toolName.isNotEmpty ? toolName : null,
      restoreSession: restore,
      widgetInstanceId:
          widget != null && widget.isNotEmpty ? widget : null,
      sessionId: session != null && session.isNotEmpty ? session : null,
    );
  }
  if (uri.scheme == 'https' &&
      (uri.host == 'app.utilivos.com' || uri.host == 'www.app.utilivos.com')) {
    final parts = uri.pathSegments;
    if (parts.length >= 2 && parts[0] == 'tool') {
      final slug = parts[1].trim();
      if (slug.isEmpty) {
        return null;
      }
      final restore = uri.queryParameters['restore'] == '1';
      final widget = uri.queryParameters['widget']?.trim();
      final session = uri.queryParameters['session']?.trim();
      final toolName = uri.queryParameters['name']?.trim();
      return AppRoutes.pluginRuntime(
        slug,
        toolName: toolName != null && toolName.isNotEmpty ? toolName : null,
        restoreSession: restore,
        widgetInstanceId:
            widget != null && widget.isNotEmpty ? widget : null,
        sessionId: session != null && session.isNotEmpty ? session : null,
      );
    }
  }
  return null;
}
