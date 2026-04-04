import 'dart:convert';
import 'dart:math';

import 'named_tool_session.dart';
import 'session_state_envelope.dart';
import 'tool_session_repository.dart';

class ToolSessionService {
  ToolSessionService(this._repository);

  final ToolSessionRepository _repository;
  final Random _random = Random.secure();

  String _newSessionId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = _random.nextInt(1 << 30);
    return 'sess_${t}_$r';
  }

  Future<List<NamedToolSession>> listSessions(String toolId) {
    return _repository.listForTool(toolId);
  }

  Future<NamedToolSession?> getSession(String id) {
    return _repository.getById(id);
  }

  /// Persists a named session, overwriting any row with the same [toolId] + [name].
  Future<String> saveNamedSession({
    required String toolId,
    required String toolSlug,
    required String name,
    required Map<String, dynamic> payload,
    String? installId,
    String? toolVersion,
    String? toolManifestVersion,
    String? previewText,
    bool isFavorite = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must be non-empty');
    }
    final envelope = SessionStateEnvelope.build(
      toolSlug: toolSlug,
      toolVersion: toolVersion,
      payload: payload,
    );
    final stateJson = envelope.serialize();
    final byteLen = utf8.encode(stateJson).length;
    final now = DateTime.now().toUtc();
    final existing = await _repository.findByToolAndName(
      toolId: toolId,
      name: trimmedName,
    );
    final id = existing?.id ?? _newSessionId();
    final createdAt = existing?.createdAt ?? now;
    await _repository.putReplacingName(
      NamedToolSession(
        id: id,
        toolId: toolId,
        toolSlug: toolSlug,
        installId: installId,
        toolVersion: toolVersion,
        name: trimmedName,
        stateJson: stateJson,
        stateSchemaVersion: SessionStateEnvelope.currentSchemaVersion,
        toolManifestVersion: toolManifestVersion,
        createdAt: createdAt,
        updatedAt: now,
        lastOpenedAt: existing?.lastOpenedAt,
        isFavorite: isFavorite,
        previewText: previewText,
        stateSizeBytes: byteLen,
      ),
    );
    return id;
  }

  Future<void> deleteSession(String id) {
    return _repository.delete(id);
  }

  /// Deletes named sessions for an install removed from the device ([toolId]
  /// is usually the install id; legacy rows may key only by [pluginSlug]).
  Future<void> deleteAllSessionsForRemovedInstall({
    required String installId,
    required String pluginSlug,
  }) async {
    final ids = <String>{};
    for (final s in await _repository.listForTool(installId)) {
      ids.add(s.id);
    }
    for (final s in await _repository.listForTool(pluginSlug)) {
      ids.add(s.id);
    }
    for (final id in ids) {
      await _repository.delete(id);
    }
  }

  Future<void> renameSession({
    required String id,
    required String newName,
  }) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(newName, 'newName', 'must be non-empty');
    }
    return _repository.rename(id: id, newName: trimmed);
  }

  Future<SessionStateEnvelope?> loadEnvelopeForSession(String id) async {
    final row = await _repository.getById(id);
    if (row == null) {
      return null;
    }
    try {
      return SessionStateEnvelope.parse(row.stateJson);
    } on FormatException {
      return null;
    }
  }

  Future<void> markSessionOpened(String id) {
    return _repository.touchLastOpened(id);
  }

  /// Overwrites stored state for an existing named session (same row id).
  Future<void> updateNamedSessionState({
    required String id,
    required Map<String, dynamic> payload,
    String? toolVersion,
    String? toolManifestVersion,
  }) async {
    final row = await _repository.getById(id);
    if (row == null) {
      throw StateError('Named session not found: $id');
    }
    final envelope = SessionStateEnvelope.build(
      toolSlug: row.toolSlug,
      toolVersion: toolVersion ?? row.toolVersion,
      payload: payload,
    );
    final stateJson = envelope.serialize();
    final byteLen = utf8.encode(stateJson).length;
    await _repository.updateStatePayload(
      id: id,
      stateJson: stateJson,
      stateSchemaVersion: SessionStateEnvelope.currentSchemaVersion,
      toolVersion: toolVersion ?? row.toolVersion,
      toolManifestVersion: toolManifestVersion ?? row.toolManifestVersion,
      stateSizeBytes: byteLen,
    );
  }
}
