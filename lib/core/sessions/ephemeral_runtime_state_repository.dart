/// Opaque per-launch JSON blob (not necessarily a [SessionStateEnvelope]).
class EphemeralRuntimeState {
  const EphemeralRuntimeState({
    required this.launchToken,
    required this.toolId,
    required this.toolSlug,
    required this.stateJson,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  final String launchToken;
  final String toolId;
  final String toolSlug;
  final String stateJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
}

abstract class EphemeralRuntimeStateRepository {
  Future<EphemeralRuntimeState?> get(String launchToken);

  Future<void> upsert(EphemeralRuntimeState state);

  Future<void> delete(String launchToken);

  /// Deletes rows whose [EphemeralRuntimeState.expiresAt] is non-null and before [now].
  Future<int> deleteExpiredBefore(DateTime now);

  /// Deletes rows with [EphemeralRuntimeState.updatedAt] strictly before [threshold].
  Future<int> deleteUpdatedBefore(DateTime threshold);
}
