/// Thrown when serialized session state exceeds [SessionStateEnvelope.maxSerializedUtf8Bytes].
class SessionStateTooLargeException implements Exception {
  SessionStateTooLargeException(this.byteLength, this.maxBytes);

  final int byteLength;
  final int maxBytes;

  @override
  String toString() =>
      'SessionStateTooLargeException: $byteLength bytes (max $maxBytes)';
}

/// Another session for the same tool already uses this name.
class SessionNameConflictException implements Exception {
  SessionNameConflictException(this.toolId, this.name);

  final String toolId;
  final String name;

  @override
  String toString() =>
      'SessionNameConflictException: name "$name" already exists for tool $toolId';
}
