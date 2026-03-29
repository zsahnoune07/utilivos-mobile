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
