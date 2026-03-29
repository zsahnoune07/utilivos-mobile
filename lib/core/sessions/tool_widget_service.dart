import 'tool_home_widget_record.dart';
import 'tool_widget_repository.dart';

class ToolWidgetService {
  ToolWidgetService(this._repository);

  final ToolWidgetRepository _repository;

  Future<List<ToolHomeWidgetRecord>> listWidgets() {
    return _repository.listAll();
  }

  Future<ToolHomeWidgetRecord?> getWidget(String id) {
    return _repository.getById(id);
  }

  Future<ToolHomeWidgetRecord?> findWidget({
    required String platform,
    required String platformWidgetId,
  }) {
    return _repository.findByPlatformWidget(
      platform: platform,
      platformWidgetId: platformWidgetId,
    );
  }

  Future<void> registerOrUpdateWidget({
    required String id,
    required String platform,
    required String platformWidgetId,
    required String toolId,
    required String toolSlug,
    required String toolName,
    String? iconSource,
    String? configurationJson,
    DateTime? lastLaunchedAt,
  }) async {
    _requireNonEmpty('id', id);
    _requireNonEmpty('platform', platform);
    _requireNonEmpty('platformWidgetId', platformWidgetId);
    _requireNonEmpty('toolId', toolId);
    _requireNonEmpty('toolSlug', toolSlug);
    _requireNonEmpty('toolName', toolName);

    final now = DateTime.now().toUtc();
    final existing = await _repository.findByPlatformWidget(
      platform: platform,
      platformWidgetId: platformWidgetId,
    );
    final createdAt = existing?.createdAt ?? now;
    await _repository.upsert(
      ToolHomeWidgetRecord(
        id: id,
        platform: platform,
        platformWidgetId: platformWidgetId,
        toolId: toolId,
        toolSlug: toolSlug,
        toolName: toolName,
        iconSource: iconSource,
        createdAt: createdAt,
        updatedAt: now,
        lastLaunchedAt: lastLaunchedAt ?? existing?.lastLaunchedAt,
        configurationJson: configurationJson ?? existing?.configurationJson,
      ),
    );
  }

  Future<void> removeWidget(String id) {
    return _repository.delete(id);
  }

  Future<void> touchLaunched({
    required String platform,
    required String platformWidgetId,
  }) async {
    final row = await _repository.findByPlatformWidget(
      platform: platform,
      platformWidgetId: platformWidgetId,
    );
    if (row == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    await _repository.upsert(
      ToolHomeWidgetRecord(
        id: row.id,
        platform: row.platform,
        platformWidgetId: row.platformWidgetId,
        toolId: row.toolId,
        toolSlug: row.toolSlug,
        toolName: row.toolName,
        iconSource: row.iconSource,
        createdAt: row.createdAt,
        updatedAt: now,
        lastLaunchedAt: now,
        configurationJson: row.configurationJson,
      ),
    );
  }

  void _requireNonEmpty(String field, String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'must be non-empty');
    }
  }
}
