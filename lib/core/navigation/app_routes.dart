class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';

  static const home = '/home';
  static const pluginRuntimePrefix = '/runtime';
  static const discover = '/discover';
  static const discoverDebug = '/discover/debug';
  static const discoverPluginDetailPrefix = '/discover/plugin';
  static const folderDetailPrefix = '/home/folder';
  // Backward-compatible alias for older deep links.
  static const installs = '/installs';
  static const settings = '/settings';

  static String discoverPluginDetail(String slug) {
    return '$discoverPluginDetailPrefix/$slug';
  }

  static String pluginRuntime(
    String slug, {
    String? toolName,
    bool restoreSession = false,
  }) {
    final params = <String, String>{};
    if (toolName != null && toolName.trim().isNotEmpty) {
      params['name'] = toolName.trim();
    }
    if (restoreSession) {
      params['restore'] = '1';
    }
    return Uri(
      path: '$pluginRuntimePrefix/$slug',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  static String folderDetail(String folderId) {
    return '$folderDetailPrefix/$folderId';
  }
}
