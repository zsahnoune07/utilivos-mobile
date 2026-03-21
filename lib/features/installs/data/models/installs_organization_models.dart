enum HomeSortMode {
  defaultManual('default_manual'),
  nameAsc('name_asc'),
  nameDesc('name_desc'),
  installDateNewest('installed_newest'),
  installDateOldest('installed_oldest'),
  lastUsed('last_used');

  const HomeSortMode(this.storageKey);
  final String storageKey;

  static HomeSortMode fromStorageKey(String? key) {
    for (final mode in HomeSortMode.values) {
      if (mode.storageKey == key) {
        return mode;
      }
    }
    return HomeSortMode.defaultManual;
  }
}

class ToolFolder {
  const ToolFolder({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorKey,
    required this.createdAt,
    required this.updatedAt,
    this.manualOrder,
  });

  final String id;
  final String name;
  final String iconKey;
  final String colorKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? manualOrder;

  factory ToolFolder.fromJson(Map<String, dynamic> json) {
    return ToolFolder(
      id: _readRequiredString(json, 'id'),
      name: _readRequiredString(json, 'name'),
      iconKey: _readRequiredString(json, 'icon_key'),
      colorKey: _readRequiredString(json, 'color_key'),
      createdAt: DateTime.parse(
        _readRequiredString(json, 'created_at'),
      ).toUtc(),
      updatedAt: DateTime.parse(
        _readRequiredString(json, 'updated_at'),
      ).toUtc(),
      manualOrder: _readOptionalInt(json, 'manual_order'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'icon_key': iconKey,
      'color_key': colorKey,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'manual_order': manualOrder,
    };
  }

  ToolFolder copyWith({
    String? id,
    String? name,
    String? iconKey,
    String? colorKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? manualOrder = _unset,
  }) {
    return ToolFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      manualOrder: identical(manualOrder, _unset)
          ? this.manualOrder
          : manualOrder as int?,
    );
  }

  static const Object _unset = Object();
}

class InstallsOrganizationState {
  const InstallsOrganizationState({
    required this.folders,
    required this.homeSortMode,
  });

  final List<ToolFolder> folders;
  final HomeSortMode homeSortMode;

  static const empty = InstallsOrganizationState(
    folders: <ToolFolder>[],
    homeSortMode: HomeSortMode.defaultManual,
  );

  factory InstallsOrganizationState.fromJson(Map<String, dynamic> json) {
    final rawFolders = json['folders'];
    final folders = rawFolders is List
        ? rawFolders
              .whereType<Map<String, dynamic>>()
              .map(ToolFolder.fromJson)
              .toList(growable: false)
        : const <ToolFolder>[];
    final sortMode = HomeSortMode.fromStorageKey(
      json['home_sort_mode'] as String?,
    );
    return InstallsOrganizationState(folders: folders, homeSortMode: sortMode);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'folders': folders
          .map((folder) => folder.toJson())
          .toList(growable: false),
      'home_sort_mode': homeSortMode.storageKey,
    };
  }

  InstallsOrganizationState copyWith({
    List<ToolFolder>? folders,
    HomeSortMode? homeSortMode,
  }) {
    return InstallsOrganizationState(
      folders: folders ?? this.folders,
      homeSortMode: homeSortMode ?? this.homeSortMode,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Missing required "$key" in installs organization.');
  }
  return raw.trim();
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw is int) {
    return raw;
  }
  return null;
}
