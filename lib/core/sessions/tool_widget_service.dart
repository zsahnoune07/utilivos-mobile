import 'dart:io';

import 'package:home_widget/home_widget.dart';

import 'tool_home_widget_record.dart';
import 'tool_widget_repository.dart';

class ToolWidgetService {
  ToolWidgetService(this._repository);

  final ToolWidgetRepository _repository;

  static const String _androidWidgetProvider =
      'com.utilivo.utilivo_mobile.ToolHomeWidgetProvider';

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

  /// Drops metadata for widgets bound to this install and clears Android
  /// [HomeWidget] prefs so tiles return to the unconfigured state.
  Future<void> removeWidgetsForTool({
    required String installId,
    required String toolSlug,
  }) async {
    final normalizedSlug = _normalizeSlug(toolSlug);
    final all = await _repository.listAll();
    final targets = all
        .where(
          (ToolHomeWidgetRecord w) =>
              w.toolId == installId || _normalizeSlug(w.toolSlug) == normalizedSlug,
        )
        .toList(growable: false);
    var clearedAndroidPrefs = false;
    for (final w in targets) {
      await _repository.delete(w.id);
      if (w.platform.toLowerCase() == 'android') {
        final wid = int.tryParse(w.platformWidgetId);
        if (wid != null) {
          await HomeWidget.saveWidgetData<String?>('tool_slug_$wid', null);
          await HomeWidget.saveWidgetData<String?>('tool_name_$wid', null);
          await HomeWidget.saveWidgetData<String?>('tool_icon_path_$wid', null);
          await HomeWidget.saveWidgetData<String?>('widget_layout_mode_$wid', null);
          clearedAndroidPrefs = true;
        }
      }
    }
    if (clearedAndroidPrefs && Platform.isAndroid) {
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidWidgetProvider);
    }
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

  String _normalizeSlug(String slug) => slug.trim().toLowerCase();
}
