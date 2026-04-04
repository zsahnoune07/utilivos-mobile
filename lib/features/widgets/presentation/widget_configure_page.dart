import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/sessions/tool_widget_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/tool_thumbnail.dart';
import '../../installs/application/installed_tools_controller.dart';
import '../../installs/data/models/install_models.dart';

/// Picks an installed tool for an Android home screen widget.
///
/// Free tier: one widget; reconfiguring the same slot is allowed. Pro: unlimited.
class WidgetConfigurePage extends StatefulWidget {
  const WidgetConfigurePage({
    required this.androidAppWidgetId,
    required this.apiBaseUrl,
    required this.installedToolsController,
    required this.toolWidgetService,
    required this.proCapabilityService,
    required this.paywallCoordinator,
    super.key,
  });

  final int androidAppWidgetId;
  final String apiBaseUrl;
  final InstalledToolsController installedToolsController;
  final ToolWidgetService toolWidgetService;
  final ProCapabilityService proCapabilityService;
  final PaywallCoordinator paywallCoordinator;

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

  /// Local file path for the home widget [RemoteViews] bitmap, if available.
  String? _resolveLocalIconPath(DeviceInstallRecord install) {
    final p = install.iconPath?.trim();
    if (p == null || p.isEmpty) {
      return null;
    }
    return File(p).existsSync() ? p : null;
  }

  Future<void> _onPick(BuildContext context, DeviceInstallRecord install) async {
    final wid = widget.androidAppWidgetId;
    final existing = await widget.toolWidgetService.findWidget(
      platform: 'android',
      platformWidgetId: '$wid',
    );
    final all = await widget.toolWidgetService.listWidgets();
    final isReplacing = existing != null;
    if (!widget.proCapabilityService.canAddHomeScreenWidget(
      registeredWidgetCount: all.length,
      isReplacingExisting: isReplacing,
    )) {
      if (!context.mounted) {
        return;
      }
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('en'));
      await widget.paywallCoordinator.show(
        context,
        PaywallRequest(
          trigger: PaywallTrigger.limitReached,
          triggerSource: 'widget_configure',
          blockedFeatureId: 'home_widget',
          contextMessage: l10n.widgetConfigureSecondWidgetPaywall,
        ),
      );
      return;
    }

    final slug = install.pluginSlug;
    final name =
        install.pluginName?.trim().isNotEmpty == true
            ? install.pluginName!.trim()
            : slug;
    final iconPath = _resolveLocalIconPath(install);

    await HomeWidget.saveWidgetData<String>('tool_slug_$wid', slug);
    await HomeWidget.saveWidgetData<String>('tool_name_$wid', name);
    await HomeWidget.saveWidgetData<String?>('tool_icon_path_$wid', iconPath);
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
      iconSource: iconPath,
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
          title: Text(
            AppLocalizations.of(context)?.widgetConfigureTitle ??
                'Choose tool for widget',
          ),
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
                final preferLocalIcon =
                    t.iconPath?.trim().isNotEmpty == true;
                return ListTile(
                  leading: ToolThumbnail(
                    localPath: t.iconPath,
                    imageUrl: preferLocalIcon ? null : t.catalogListIconRef,
                    baseUrl: widget.apiBaseUrl,
                    size: 44,
                    borderRadius: 10,
                    transparentFallback: true,
                    debugToolSlug: t.pluginSlug,
                    debugThumbnailUrl: t.catalogThumbnailUrl,
                    debugIconUrl: t.catalogThumbnailUrl,
                  ),
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
