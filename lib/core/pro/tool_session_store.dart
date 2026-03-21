import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../pro/pro_capability_service.dart';

/// Persists opaque JSON tool state on disk for pro users only.
class ToolSessionStore {
  ToolSessionStore(this._capability);

  final ProCapabilityService _capability;

  Future<Directory> _sessionDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'tool_sessions'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileName(String pluginSlug) {
    final safe = pluginSlug.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$safe.json';
  }

  Future<String?> readStateJson(String pluginSlug) async {
    if (!_capability.canPersistToolState) {
      return null;
    }
    final slug = pluginSlug.trim();
    if (slug.isEmpty) {
      return null;
    }
    try {
      final dir = await _sessionDir();
      final file = File(p.join(dir.path, _fileName(slug)));
      if (!await file.exists()) {
        return null;
      }
      return file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeStateJson(String pluginSlug, String jsonPayload) async {
    if (!_capability.canPersistToolState) {
      return;
    }
    final slug = pluginSlug.trim();
    if (slug.isEmpty) {
      return;
    }
    try {
      jsonDecode(jsonPayload);
    } catch (_) {
      return;
    }
    try {
      final dir = await _sessionDir();
      final file = File(p.join(dir.path, _fileName(slug)));
      await file.writeAsString(jsonPayload, flush: true);
    } catch (_) {}
  }

  Future<void> clearState(String pluginSlug) async {
    if (!_capability.canPersistToolState) {
      return;
    }
    try {
      final dir = await _sessionDir();
      final file = File(p.join(dir.path, _fileName(pluginSlug)));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
