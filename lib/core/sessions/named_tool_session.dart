/// Durable named session row, independent of persistence backend.
class NamedToolSession {
  const NamedToolSession({
    required this.id,
    required this.toolId,
    required this.toolSlug,
    this.installId,
    this.toolVersion,
    required this.name,
    required this.stateJson,
    this.stateSchemaVersion = 1,
    this.toolManifestVersion,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    this.isFavorite = false,
    this.previewText,
    this.stateSizeBytes,
  });

  final String id;
  final String toolId;
  final String toolSlug;
  final String? installId;
  final String? toolVersion;
  final String name;
  final String stateJson;
  final int stateSchemaVersion;
  final String? toolManifestVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  final bool isFavorite;
  final String? previewText;
  final int? stateSizeBytes;

  NamedToolSession copyWith({
    String? id,
    String? toolId,
    String? toolSlug,
    String? installId,
    String? toolVersion,
    String? name,
    String? stateJson,
    int? stateSchemaVersion,
    String? toolManifestVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool? isFavorite,
    String? previewText,
    int? stateSizeBytes,
  }) {
    return NamedToolSession(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      toolSlug: toolSlug ?? this.toolSlug,
      installId: installId ?? this.installId,
      toolVersion: toolVersion ?? this.toolVersion,
      name: name ?? this.name,
      stateJson: stateJson ?? this.stateJson,
      stateSchemaVersion: stateSchemaVersion ?? this.stateSchemaVersion,
      toolManifestVersion: toolManifestVersion ?? this.toolManifestVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      previewText: previewText ?? this.previewText,
      stateSizeBytes: stateSizeBytes ?? this.stateSizeBytes,
    );
  }
}
