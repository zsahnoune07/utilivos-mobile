import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/networking/network_exception.dart';
import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/pro/pro_purchase_controller.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_info_tile.dart';
import '../../../shared/widgets/app_skeletons.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/tool_thumbnail.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../../installs/application/installed_tools_controller.dart';
import '../../installs/data/installs_api.dart';
import '../data/catalog_api.dart';
import '../data/models/catalog_models.dart';

class PluginDetailPage extends StatefulWidget {
  const PluginDetailPage({
    required this.slug,
    required this.config,
    required this.catalogApi,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.installsApi,
    required this.installedToolsController,
    required this.entitlementController,
    required this.proPurchaseController,
    required this.proCapabilityService,
    required this.paywallCoordinator,
    super.key,
  });

  final String slug;
  final AppConfig config;
  final CatalogApi catalogApi;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final InstallsApi installsApi;
  final InstalledToolsController installedToolsController;
  final EntitlementController entitlementController;
  final ProPurchaseController proPurchaseController;
  final ProCapabilityService proCapabilityService;
  final PaywallCoordinator paywallCoordinator;

  @override
  State<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends State<PluginDetailPage> {
  AppViewState _viewState = AppViewState.loading;
  CatalogPlugin? _plugin;
  List<PluginVersionSummary> _versions = const <PluginVersionSummary>[];
  String _errorMessage = 'Failed to load tool details.';
  bool _hasRunnableBundle = false;
  bool _isInstalling = false;
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _downloadStatusMessage;
  String? _downloadErrorMessage;
  String? _localIconPath;

  @override
  void initState() {
    super.initState();
    widget.installedToolsController.bootstrap();
    _load();
    _loadLocalIcon();
  }

  Future<void> _loadLocalIcon() async {
    for (final install in widget.installedToolsController.installedTools) {
      if (install.pluginSlug == widget.slug && install.iconPath != null) {
        _localIconPath = install.iconPath;
        break;
      }
    }
    if (_localIconPath != null && mounted) {
      setState(() {});
      return;
    }
    final bundle = await widget.toolBundleDownloadService.findRunnableBundle(
      widget.slug,
    );
    if (bundle == null || !mounted) return;
    final icon = bundle.iconPath;
    if (icon != null && icon.isNotEmpty && await File(icon).exists()) {
      setState(() => _localIconPath = icon);
    }
  }

  Future<void> _load() async {
    setState(() {
      _viewState = AppViewState.loading;
      _errorMessage = 'Loading tool details...';
    });

    try {
      final pluginFuture = widget.catalogApi.getPluginBySlug(widget.slug);
      final versionsFuture = widget.catalogApi.listPluginVersions(widget.slug);
      final results = await Future.wait<Object>(<Future<Object>>[
        pluginFuture,
        versionsFuture,
      ]);
      if (!mounted) {
        return;
      }

      final plugin = results[0] as CatalogPlugin;
      final versions = results[1] as List<PluginVersionSummary>;
      final runnableBundle = await widget.toolBundleDownloadService
          .findRunnableBundle(plugin.slug);
      if (!mounted) {
        return;
      }

      setState(() {
        _plugin = plugin;
        _versions = versions;
        _hasRunnableBundle = runnableBundle != null;
        if (runnableBundle != null) {
          _downloadStatusMessage =
              'Bundle ready to run: ${runnableBundle.version}';
        }
        _viewState = AppViewState.content;
      });
    } on NetworkException catch (error) {
      developer.log(
        'Plugin detail load failed.',
        name: 'PluginDetailPage',
        error:
            'slug=${widget.slug} status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      developer.log(
        'Unexpected plugin detail load error.',
        name: 'PluginDetailPage',
        error: 'slug=${widget.slug}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = 'Unexpected tool detail error.';
      });
    }
  }

  Future<void> _trackInstall() async {
    final plugin = _plugin;
    final hasProAccess = widget.entitlementController.hasProAccess;
    final canInstall =
        plugin != null && plugin.canFreeUserAttemptInstall(hasProAccess);
    if (!canInstall) {
      return;
    }

    setState(() {
      _isInstalling = true;
    });

    try {
      // Download and prepare bundle first; only then record install so the tool
      // only appears on Home when it is actually runnable.
      final runtimePrepared = await _downloadAndPrepareBundle(
        plugin: plugin,
        showSuccessSnackBar: false,
        requestReason: 'install',
      );
      if (!mounted) {
        return;
      }
      if (!runtimePrepared) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Install incomplete: bundle could not be prepared. Try again when online.',
            ),
          ),
        );
        return;
      }
      final installedBundle = await widget.toolBundleDownloadService
          .findRunnableBundle(plugin.slug);
      final install = await widget.installsApi.trackInstall(
        pluginSlug: plugin.slug,
        version: _versions.isEmpty ? null : _versions.first.version,
      );
      await widget.installedToolsController.recordInstall(
        install.copyWith(
          pluginName: plugin.name,
          categoryName: installedBundle?.category ?? plugin.categoryName,
          pluginDescription: plugin.longDescription ?? plugin.shortDescription,
          categoryColor: plugin.categoryColor,
          iconPath: installedBundle?.iconPath,
          cardAccentColor: installedBundle?.iconAccentColor,
          pricingTier: _displayTier(plugin.pricingType).toLowerCase(),
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Installed ${plugin.name}.')));
      await _loadLocalIcon();
    } on NetworkException catch (error) {
      developer.log(
        'Plugin install failed from details.',
        name: 'PluginDetailPage',
        error:
            'slug=${plugin.slug} status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Install failed: ${error.message}')),
      );
    } catch (_) {
      developer.log(
        'Unexpected plugin install error from details.',
        name: 'PluginDetailPage',
        error: 'slug=${plugin.slug}',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Install failed due to unexpected error.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }

  Future<bool> _downloadAndPrepareBundle({
    required CatalogPlugin plugin,
    required bool showSuccessSnackBar,
    required String requestReason,
  }) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadErrorMessage = null;
      _downloadStatusMessage = 'Requesting download grant...';
    });

    String? assertionToken;
    final hasProAccess = widget.entitlementController.hasProAccess;
    if (plugin.isPro) {
      if (hasProAccess) {
        assertionToken = widget.entitlementController.activeAssertionToken;
        if (assertionToken == null || assertionToken.trim().isEmpty) {
          await widget.entitlementController.backgroundReverify(
            reason: requestReason,
          );
          assertionToken = widget.entitlementController.activeAssertionToken;
        }
        if (assertionToken == null || assertionToken.trim().isEmpty) {
          if (!mounted) {
            return false;
          }
          setState(() {
            _isDownloading = false;
            _downloadProgress = null;
            _downloadErrorMessage =
                'No valid Pro verification. Connect online to refresh entitlement.';
          });
          return false;
        }
      } else if (!plugin.proPreview) {
        if (!mounted) {
          return false;
        }
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
          _downloadErrorMessage = 'This tool requires Pro to install.';
        });
        return false;
      }
    }

    try {
      final grant = await widget.downloadApi.requestDownload(
        pluginSlug: plugin.slug,
        entitlementAssertionToken: assertionToken,
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        _downloadStatusMessage = 'Downloading bundle...';
      });

      final result = await widget.toolBundleDownloadService.downloadBundle(
        pluginSlug: plugin.slug,
        grant: grant,
        onProgress: (double progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = progress.clamp(0, 1);
          });
        },
      );

      if (!mounted) {
        return false;
      }
      setState(() {
        _hasRunnableBundle = result.isRunnable;
        _downloadStatusMessage = result.isRunnable
            ? 'Bundle ready to run: ${result.version}'
            : 'Bundle downloaded: ${result.version}';
      });
      if (showSuccessSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${plugin.name} bundle.')),
        );
      }
      return result.isRunnable;
    } on ToolBundleIntegrityException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _downloadErrorMessage =
            'Bundle integrity failed (expected ${error.expectedSha256}, got ${error.actualSha256}).';
      });
      return false;
    } on ToolBundleFormatException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _downloadErrorMessage = 'Bundle format is invalid: ${error.message}';
      });
      return false;
    } on NetworkException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _downloadErrorMessage = 'Download request failed: ${error.message}';
      });
      return false;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _downloadErrorMessage = 'Bundle download failed: $error';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _openRuntime(String slug) async {
    await widget.installedToolsController.markToolLaunched(slug);
    unawaited(widget.proCapabilityService.recordToolEngagement(slug));
    if (!mounted) {
      return;
    }
    final restore = widget.proCapabilityService.canRestoreSession;
    context.push(
      AppRoutes.pluginRuntime(
        slug,
        toolName: _plugin?.name,
        restoreSession: restore,
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugin = _plugin;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tool Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          widget.entitlementController,
          widget.proPurchaseController,
          widget.installedToolsController,
          widget.proCapabilityService,
        ]),
        builder: (BuildContext context, Widget? child) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AppStateBody(
              state: _viewState,
              loadingMessage: 'Loading tool details...',
              loadingBuilder: (BuildContext context) =>
                  const _PluginDetailLoadingView(),
              errorTitle: 'Could not load tool details',
              errorMessage: _errorMessage,
              onRetry: _load,
              emptyTitle: 'Tool missing',
              emptyMessage: 'No tool details are available.',
              content: plugin == null
                  ? const AppEmptyView(
                      title: 'Tool missing',
                      message: 'No tool details are available.',
                    )
                  : _buildContent(context, plugin),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, CatalogPlugin plugin) {
    final latestVersion = _versions.isEmpty ? null : _versions.first.version;
    final hasProAccess = widget.entitlementController.hasProAccess;
    final hardProLock =
        plugin.isPro && !hasProAccess && !plugin.proPreview;
    final previewInstallable =
        plugin.isPro && !hasProAccess && plugin.proPreview;
    final purchaseController = widget.proPurchaseController;
    final isInstalled = widget.installedToolsController.installedTools.any(
      (install) => install.pluginSlug == plugin.slug,
    );

    return ListView(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ToolThumbnail(
              imageUrl: plugin.thumbnailUrl,
              localPath: _localIconPath,
              baseUrl: widget.config.apiBaseUrl,
              size: 58,
              borderRadius: 12,
              fallbackIcon: hardProLock
                  ? Icons.lock_outline
                  : Icons.extension_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          plugin.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (plugin.isPro) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 22,
                          semanticLabel: 'Pro tool',
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plugin.categoryName} · ${_displayTier(plugin.pricingType)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          plugin.longDescription ??
              plugin.shortDescription ??
              'No description provided.',
        ),
        if (latestVersion != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Latest version: $latestVersion',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (plugin.isPro) ...<Widget>[
          const SizedBox(height: 16),
          AppInfoTile(
            leading: hasProAccess
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            title: hasProAccess
                ? 'Pro active'
                : previewInstallable
                    ? 'Pro tool · Preview install'
                    : 'Pro required',
            subtitle: hasProAccess
                ? 'Full access to Pro tools and workflows.'
                : previewInstallable
                    ? 'Install and explore; upgrade for full output, exports, and saved sessions.'
                    : 'Subscribe to install and unlock the full tool.',
          ),
        ],
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: hardProLock
              ? 'Go Pro'
              : (isInstalled ? 'Installed' : 'Install'),
          onPressed: hardProLock
              ? () => widget.paywallCoordinator.show(
                    context,
                    const PaywallRequest(
                      trigger: PaywallTrigger.contextualFeature,
                      triggerSource: 'plugin_detail_install',
                      contextMessage:
                          'Unlock full Pro tools, saved workflows, and unlimited organization.',
                    ),
                  )
              : (isInstalled ? null : _trackInstall),
          isLoading:
              hardProLock ? false : _isInstalling,
        ),
        if (hardProLock) ...<Widget>[
          const SizedBox(height: 8),
          AppSecondaryButton(
            label: 'Restore purchases',
            onPressed: purchaseController.isRestoreInProgress
                ? null
                : purchaseController.restorePurchases,
            expand: true,
          ),
        ],
        const SizedBox(height: 8),
        AppSecondaryButton(
          label: 'Open Tool',
          onPressed: _hasRunnableBundle
              ? () => _openRuntime(plugin.slug)
              : null,
          expand: true,
        ),
        if (_isDownloading && _downloadProgress != null) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _downloadProgress),
        ],
        if (_downloadStatusMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_downloadStatusMessage!),
        ],
        if (_downloadErrorMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _downloadErrorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        AppSecondaryButton(
          label: 'Open Home',
          onPressed: () => context.go(AppRoutes.home),
          expand: true,
        ),
        if (purchaseController.statusMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(purchaseController.statusMessage!),
        ],
        if (purchaseController.errorMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            purchaseController.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_versions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Version History',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final version in _versions.take(5)) ...<Widget>[
            AppInfoTile(
              leading: Icons.history_toggle_off,
              title: version.version,
              subtitle:
                  (version.changelog == null ||
                      version.changelog!.trim().isEmpty)
                  ? 'No changelog notes.'
                  : version.changelog!,
            ),
          ],
        ],
      ],
    );
  }
}

class _PluginDetailLoadingView extends StatelessWidget {
  const _PluginDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        AppCardSkeleton(lines: 3),
        SizedBox(height: 12),
        AppCardSkeleton(lines: 2),
        SizedBox(height: 12),
        AppCardSkeleton(lines: 2),
      ],
    );
  }
}

String _displayTier(String pricingType) {
  final normalized = pricingType.trim().toLowerCase();
  if (normalized == 'free') {
    return 'Free';
  }
  if (normalized == 'pro' || normalized == 'paid') {
    return 'Pro';
  }
  return 'Free';
}
