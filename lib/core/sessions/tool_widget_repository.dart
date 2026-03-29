import 'tool_home_widget_record.dart';

abstract class ToolWidgetRepository {
  Future<List<ToolHomeWidgetRecord>> listAll();

  Future<ToolHomeWidgetRecord?> getById(String id);

  Future<ToolHomeWidgetRecord?> findByPlatformWidget({
    required String platform,
    required String platformWidgetId,
  });

  Future<void> upsert(ToolHomeWidgetRecord record);

  Future<void> delete(String id);
}
