import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/sessions/tool_widget_service.dart';
import '../../installs/application/installed_tools_controller.dart';
import '../../installs/data/models/install_models.dart';

/// Picks an installed tool for an Android home screen widget.
///
/// Uses explicit [InstalledToolsController] / [ToolWidgetService] instead of
/// Riverpod here: this route can be built under a different [ProviderScope]
/// ancestry than [installedToolsStreamProvider] expects, which triggers
/// Riverpod's cross-scope listener assertion.
class WidgetConfigurePage extends StatefulWidget {
  const WidgetConfigurePage({
    required this.androidAppWidgetId,
    required this.installedToolsController,
    required this.toolWidgetService,
    super.key,
  });

  final int androidAppWidgetId;
  final InstalledToolsController installedToolsController;
  final ToolWidgetService toolWidgetService;

  static const MethodChannel _channel = MethodChannel(
    'com.utilivo.utilivo_mobile/runtime',
  );

  @override
  State<WidgetConfigurePage> createState() => _WidgetConfigurePageState();
}

class _WidgetConfigurePageState extends State<WidgetConfigurePage> {
  Future<void> _finish(BuildContext context, bool success) async {
    if (!Platform.isAndroid) {
      if (context.mounted) {
        context.pop();
      }
      return;
    }
    try {
      await WidgetConfigurePage._channel.invokeMethod<void>(
        'completeWidgetConfigure',
        <String, Object?>{'success': success},
      );
    } catch (_) {}
  }

  Future<void> _onPick(BuildContext context, DeviceInstallRecord install) async {
    final slug = install.pluginSlug;
    final name =
        install.pluginName?.trim().isNotEmpty == true
            ? install.pluginName!.trim()
            : slug;
    final wid = widget.androidAppWidgetId;
    await HomeWidget.saveWidgetData<String>('tool_slug_$wid', slug);
    await HomeWidget.saveWidgetData<String>('tool_name_$wid', name);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.utilivo.utilivo_mobile.ToolHomeWidgetProvider',
    );
    await widget.toolWidgetService.registerOrUpdateWidget(
      id: 'android_home_$wid',
      platform: 'android',
      platformWidgetId: '$wid',
      toolId: install.id,
      toolSlug: slug,
      toolName: name,
    );
    if (!context.mounted) {
      return;
    }
    await _finish(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_finish(context, false));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose tool for widget'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => unawaited(_finish(context, false)),
          ),
        ),
        body: ListenableBuilder(
          listenable: widget.installedToolsController,
          builder: (BuildContext context, Widget? child) {
            final c = widget.installedToolsController;
            if (c.state == InstalledToolsState.initializing) {
              return const Center(child: CircularProgressIndicator());
            }
            if (c.state == InstalledToolsState.failed) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load your tools. Try again after opening the app from the launcher.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            final tools = c.installedTools;
            if (tools.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Install a tool from the Tool Library first.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: tools.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int i) {
                final t = tools[i];
                final title =
                    t.pluginName?.trim().isNotEmpty == true
                        ? t.pluginName!
                        : t.pluginSlug;
                return ListTile(
                  title: Text(title),
                  subtitle: Text(t.pluginSlug),
                  onTap: () => unawaited(_onPick(context, t)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
