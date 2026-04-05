/// Single permission entry from `manifest.json` (`permissions` array).
class ToolManifestPermission {
  const ToolManifestPermission({
    required this.type,
    this.rationale,
  });

  /// Normalized lowercase type (e.g. `storage`, `camera`).
  final String type;
  final String? rationale;
}

/// Parsed host-relevant fields from a tool `manifest.json`.
class ParsedToolManifest {
  const ParsedToolManifest({
    this.minAppVersion,
    this.maxAppVersion,
    this.permissions = const <ToolManifestPermission>[],
  });

  final String? minAppVersion;
  final String? maxAppVersion;
  final List<ToolManifestPermission> permissions;

  /// Types that the host satisfies without an OS prompt.
  static const Set<String> hostOnlyTypes = <String>{
    'storage',
    'clipboard',
    'local_persistence',
    'localpersistence',
    'persistence',
  };

  /// Types that map to OS permission requests.
  static const Set<String> systemTypes = <String>{
    'camera',
    'microphone',
    'location',
  };

  static bool isHostOnlyType(String type) {
    final t = type.trim().toLowerCase();
    return hostOnlyTypes.contains(t);
  }

  static bool isSystemType(String type) {
    final t = type.trim().toLowerCase();
    return systemTypes.contains(t);
  }

  Iterable<ToolManifestPermission> get systemPermissions sync* {
    for (final p in permissions) {
      if (isSystemType(p.type)) {
        yield p;
      }
    }
  }
}
