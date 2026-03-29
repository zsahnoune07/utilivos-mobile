/// Local mapping for a home-screen widget instance (Android/iOS).
class ToolHomeWidgetRecord {
  const ToolHomeWidgetRecord({
    required this.id,
    required this.platform,
    required this.platformWidgetId,
    required this.toolId,
    required this.toolSlug,
    required this.toolName,
    this.iconSource,
    required this.createdAt,
    required this.updatedAt,
    this.lastLaunchedAt,
    this.configurationJson,
  });

  final String id;
  final String platform;
  final String platformWidgetId;
  final String toolId;
  final String toolSlug;
  final String toolName;
  final String? iconSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLaunchedAt;
  final String? configurationJson;
}
