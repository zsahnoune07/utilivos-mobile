import 'dart:convert';

import 'session_exceptions.dart';

/// JSON envelope stored in [ToolSessions.stateJson] (see product plan).
class SessionStateEnvelope {
  SessionStateEnvelope({
    required this.schemaVersion,
    required this.toolSlug,
    this.toolVersion,
    required this.savedAt,
    required this.payload,
  });

  static const int currentSchemaVersion = 1;

  /// Maximum UTF-8 size for the serialized envelope (pathological payload guard).
  static const int maxSerializedUtf8Bytes = 2 * 1024 * 1024;

  final int schemaVersion;
  final String toolSlug;
  final String? toolVersion;
  final DateTime savedAt;
  final Map<String, dynamic> payload;

  factory SessionStateEnvelope.build({
    required String toolSlug,
    String? toolVersion,
    required Map<String, dynamic> payload,
  }) {
    return SessionStateEnvelope(
      schemaVersion: currentSchemaVersion,
      toolSlug: toolSlug,
      toolVersion: toolVersion,
      savedAt: DateTime.now().toUtc(),
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'toolSlug': toolSlug,
      'toolVersion': toolVersion,
      'savedAt': savedAt.toUtc().toIso8601String(),
      'payload': payload,
    };
  }

  String serialize() {
    final encoded = jsonEncode(toJson());
    enforceMaxUtf8Length(encoded);
    return encoded;
  }

  /// Best-effort parse for restore and migration paths. Never throws.
  /// Unknown fields are ignored except [payload], which is shallow-copied.
  static SessionStateEnvelope? tryParseRelaxed(String json) {
    try {
      enforceMaxUtf8Length(json);
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        return null;
      }
      final m = Map<String, dynamic>.from(decoded);
      try {
        return parse(json);
      } catch (_) {}
      final rawPayload = m['payload'];
      if (rawPayload is Map) {
        final payload = Map<String, dynamic>.from(rawPayload);
        final sv = m['schemaVersion'];
        int schema = currentSchemaVersion;
        if (sv is int) {
          schema = sv;
        } else if (sv is num) {
          schema = sv.toInt();
        }
        var slug = m['toolSlug']?.toString() ?? '';
        if (slug.isEmpty) {
          slug = 'unknown';
        }
        final savedRaw = m['savedAt']?.toString();
        final savedAt = savedRaw != null && savedRaw.isNotEmpty
            ? (DateTime.tryParse(savedRaw) ?? DateTime.now().toUtc())
            : DateTime.now().toUtc();
        return SessionStateEnvelope(
          schemaVersion: schema,
          toolSlug: slug,
          toolVersion: m['toolVersion']?.toString(),
          savedAt: savedAt,
          payload: payload,
        );
      }
      return SessionStateEnvelope(
        schemaVersion: 0,
        toolSlug: 'unknown',
        toolVersion: null,
        savedAt: DateTime.now().toUtc(),
        payload: m,
      );
    } catch (_) {
      return null;
    }
  }

  static SessionStateEnvelope parse(String json) {
    enforceMaxUtf8Length(json);
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Session envelope must be a JSON object.');
    }
    final schema = decoded['schemaVersion'];
    if (schema is! int) {
      throw const FormatException('schemaVersion must be an int.');
    }
    final slug = decoded['toolSlug']?.toString() ?? '';
    if (slug.isEmpty) {
      throw const FormatException('toolSlug is required.');
    }
    final savedRaw = decoded['savedAt']?.toString();
    if (savedRaw == null || savedRaw.isEmpty) {
      throw const FormatException('savedAt is required.');
    }
    final savedAt = DateTime.tryParse(savedRaw);
    if (savedAt == null) {
      throw FormatException('Invalid savedAt: $savedRaw');
    }
    final rawPayload = decoded['payload'];
    if (rawPayload is! Map<String, dynamic>) {
      throw const FormatException('payload must be a JSON object.');
    }
    return SessionStateEnvelope(
      schemaVersion: schema,
      toolSlug: slug,
      toolVersion: decoded['toolVersion']?.toString(),
      savedAt: savedAt,
      payload: rawPayload,
    );
  }

  static void enforceMaxUtf8Length(String value) {
    final bytes = utf8.encode(value).length;
    if (bytes > maxSerializedUtf8Bytes) {
      throw SessionStateTooLargeException(bytes, maxSerializedUtf8Bytes);
    }
  }
}
