import 'named_tool_session.dart';

abstract class ToolSessionRepository {
  Future<List<NamedToolSession>> listForTool(String toolId);

  Future<NamedToolSession?> getById(String id);

  Future<NamedToolSession?> findByToolAndName({
    required String toolId,
    required String name,
  });

  /// Replaces any row with the same [NamedToolSession.toolId] and [NamedToolSession.name].
  Future<void> putReplacingName(NamedToolSession session);

  Future<void> delete(String id);

  /// Renames session [id] to [newName] if no other session for the same tool uses it.
  Future<void> rename({
    required String id,
    required String newName,
  });

  Future<void> touchLastOpened(String id);
}
