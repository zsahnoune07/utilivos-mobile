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
}
