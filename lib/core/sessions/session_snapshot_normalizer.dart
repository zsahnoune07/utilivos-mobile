import 'dart:convert';

import 'session_state_envelope.dart';

/// Shared rules for turning persisted named-session rows into the JSON string
/// stored in ephemeral runtime state and delivered to the tool via [loadState] /
/// in-place restore.
class SessionSnapshotNormalizer {
  SessionSnapshotNormalizer._();

  /// JSON string suitable for [RuntimeStateScopeService.persistEphemeral] and
  /// tool hydration: envelope payloads are flattened to raw tool state JSON.
  static String ephemeralStateJsonFromNamedSessionRow(String rowStateJson) {
    final trimmed = rowStateJson.trim();
    if (trimmed.isEmpty) {
      return '{}';
    }
    final env = SessionStateEnvelope.tryParseRelaxed(trimmed);
    if (env != null) {
      return jsonEncode(env.payload);
    }
    return trimmed;
  }

  /// Extracts a payload map for persisting named sessions (save / update).
  static Map<String, dynamic> payloadMapFromEphemeralStateJson(
    String stateJson,
  ) {
    final env = SessionStateEnvelope.tryParseRelaxed(stateJson);
    if (env != null) {
      return Map<String, dynamic>.from(env.payload);
    }
    try {
      final decoded = jsonDecode(stateJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{'_raw': stateJson};
  }
}
