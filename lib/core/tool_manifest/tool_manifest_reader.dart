import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../features/downloads/data/models/downloaded_tool_bundle.dart';
import 'tool_manifest_models.dart';

/// Reads and parses tool `manifest.json` from disk (offline-safe).
class ToolManifestReader {
  const ToolManifestReader();

  /// Resolves manifest path from [bundle] and parses JSON.
  Future<ParsedToolManifest> readForBundle(DownloadedToolBundle bundle) async {
    final path = _resolveManifestPath(bundle);
    if (path == null) {
      return const ParsedToolManifest();
    }
    final file = File(path);
    if (!await file.exists()) {
      return const ParsedToolManifest();
    }
    final text = await file.readAsString();
    final dynamic decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      return const ParsedToolManifest();
    }
    return parseManifestMap(decoded);
  }

  String? _resolveManifestPath(DownloadedToolBundle bundle) {
    final explicit = bundle.manifestPath?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final root = bundle.extractedPath?.trim();
    if (root != null && root.isNotEmpty) {
      return p.join(root, 'manifest.json');
    }
    return null;
  }
}

ParsedToolManifest parseManifestMap(Map<String, dynamic> raw) {
  final min = _readOptionalString(raw, const <String>['min_app_version', 'minAppVersion']);
  final max = _readOptionalString(raw, const <String>['max_app_version', 'maxAppVersion']);
  final perms = _parsePermissions(raw['permissions']);
  return ParsedToolManifest(
    minAppVersion: min,
    maxAppVersion: max,
    permissions: perms,
  );
}

List<ToolManifestPermission> _parsePermissions(Object? raw) {
  if (raw == null) {
    return const <ToolManifestPermission>[];
  }
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) {
      return const <ToolManifestPermission>[];
    }
    return <ToolManifestPermission>[
      ToolManifestPermission(type: _normalizeType(t)),
    ];
  }
  if (raw is! List) {
    return const <ToolManifestPermission>[];
  }
  final out = <ToolManifestPermission>[];
  for (final entry in raw) {
    if (entry is String) {
      final s = entry.trim();
      if (s.isEmpty) {
        continue;
      }
      out.add(ToolManifestPermission(type: _normalizeType(s)));
      continue;
    }
    if (entry is Map) {
      final m = entry.cast<String, dynamic>();
      final typeRaw = m['type'] ?? m['Type'];
      if (typeRaw is! String || typeRaw.trim().isEmpty) {
        continue;
      }
      final rationaleRaw = m['rationale'] ?? m['Rationale'];
      final rationale = rationaleRaw is String && rationaleRaw.trim().isNotEmpty
          ? rationaleRaw.trim()
          : null;
      out.add(
        ToolManifestPermission(
          type: _normalizeType(typeRaw),
          rationale: rationale,
        ),
      );
    }
  }
  return out;
}

String _normalizeType(String raw) => raw.trim().toLowerCase();

String? _readOptionalString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) {
      final t = value.trim();
      if (t.isEmpty) {
        continue;
      }
      return t;
    }
  }
  return null;
}
