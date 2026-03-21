import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_analytics.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/networking/network_exception.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_skeletons.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../application/folder_quota_exception.dart';
import '../application/installed_tools_controller.dart';
import '../data/installs_api.dart';
import '../data/models/install_models.dart';
import '../data/models/installs_organization_models.dart';
import 'widgets/folder_editor_modal.dart';
import 'widgets/folder_ui_catalog.dart';
import 'widgets/installed_tool_card.dart';
import 'widgets/tool_actions_sheet.dart';

class InstallsPage extends StatefulWidget {
  const InstallsPage({
    required this.appName,
    required this.installedToolsController,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.installsApi,
    required this.entitlementController,
    required this.proCapabilityService,
    required this.paywallCoordinator,
    required this.proAnalytics,
    super.key,
  });

  final String appName;
  final InstalledToolsController installedToolsController;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final InstallsApi installsApi;
  final EntitlementController entitlementController;
  final ProCapabilityService proCapabilityService;
  final PaywallCoordinator paywallCoordinator;
  final ProAnalytics proAnalytics;

  @override
  State<InstallsPage> createState() => _InstallsPageState();
}

class _InstallsPageState extends State<InstallsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isResettingSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.installedToolsController.bootstrap();
    });
    _searchController.addListener(() => setState(() {}));
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<DeviceInstallRecord> _filteredTools(
    InstalledToolsController controller,
  ) {
    final tools = controller.installedTools;

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return tools;
    }
    return tools
        .where(
          (DeviceInstallRecord t) =>
              t.displayName.toLowerCase().contains(query) ||
              t.pluginSlug.toLowerCase().contains(query) ||
              (t.pluginDescription?.toLowerCase().contains(query) ?? false) ||
              (t.categoryName?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  HomeGroupedInstalls _filteredGroupedData(
    InstalledToolsController controller,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final grouped = controller.groupedHomeData;
    if (query.isEmpty) {
      return grouped;
    }
    final matches = controller.installedTools
        .where(
          (tool) =>
              tool.displayName.toLowerCase().contains(query) ||
              tool.pluginSlug.toLowerCase().contains(query) ||
              (tool.pluginDescription?.toLowerCase().contains(query) ??
                  false) ||
              (tool.categoryName?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);

    final pinnedMatches = matches
        .where((DeviceInstallRecord tool) => tool.pinned)
        .toList(growable: false);
    final unpinnedMatches = matches
        .where((DeviceInstallRecord tool) => !tool.pinned)
        .toList(growable: false);

    return HomeGroupedInstalls(
      pinnedTools: pinnedMatches,
      folders: const <HomeFolderSection>[],
      unpinnedTools: unpinnedMatches,
    );
  }

  Map<String, ToolFolder> _foldersById(InstalledToolsController controller) {
    return <String, ToolFolder>{
      for (final folder in controller.folders) folder.id: folder,
    };
  }

  Future<void> _addTestTools() async {
    await widget.installedToolsController.addDebugTools(count: 10);
  }

  void _resetSearchState() {
    if (_isResettingSearch) {
      return;
    }
    _isResettingSearch = true;
    try {
      _searchFocusNode.unfocus();
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      } else {
        // Keep derived UI state in sync even when text is already empty.
        setState(() {});
      }
    } finally {
      _isResettingSearch = false;
    }
  }

  void _dismissSearchFocus() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _openToolRuntime(BuildContext context, DeviceInstallRecord install) {
    widget.installedToolsController.markToolLaunched(install.pluginSlug);
    unawaited(
      widget.proCapabilityService.recordToolEngagement(install.pluginSlug),
    );
    final restore = widget.proCapabilityService.canRestoreSession;
    context
        .push(
          AppRoutes.pluginRuntime(
            install.pluginSlug,
            toolName: install.displayName,
            restoreSession: restore,
          ),
        )
        .then((_) {
          if (!context.mounted) {
            return;
          }
          unawaited(_maybeOfferSoftPaywall(context));
        });
  }

  Future<void> _maybeOfferSoftPaywall(BuildContext context) async {
    if (!widget.proCapabilityService.shouldOfferSoftPaywall) {
      return;
    }
    final result = await widget.paywallCoordinator.show(
      context,
      const PaywallRequest(
        trigger: PaywallTrigger.softEngagement,
        triggerSource: 'post_tool_session',
        fullScreen: false,
      ),
    );
    if (result == PaywallResult.dismissed) {
      await widget.proCapabilityService.markSoftPaywallDismissed();
    }
  }

  Future<void> _showPinLimitPaywall(BuildContext context) async {
    await widget.paywallCoordinator.show(
      context,
      const PaywallRequest(
        trigger: PaywallTrigger.limitReached,
        triggerSource: 'pins',
        contextMessage:
            'Pro includes unlimited pins so your essentials stay one tap away.',
      ),
    );
  }

  Future<void> _showFolderLimitPaywall(BuildContext context) async {
    await widget.paywallCoordinator.show(
      context,
      const PaywallRequest(
        trigger: PaywallTrigger.limitReached,
        triggerSource: 'folders',
        contextMessage:
            'Organize without limits: Pro unlocks unlimited folders and power-user layouts.',
      ),
    );
  }

  Future<void> _openMarketplace(BuildContext context, {String? search}) async {
    final trimmedSearch = search?.trim() ?? '';
    final uri = Uri(
      path: AppRoutes.discover,
      queryParameters: <String, String>{
        if (trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      },
    );
    final didInstall = await context.push<bool>(uri.toString());
    if (!mounted) {
      return;
    }
    if (didInstall == true) {
      _resetSearchState();
    }
  }

  Future<void> _openMarketplaceWithSearch(BuildContext context) async {
    await _openMarketplace(context, search: _searchController.text);
  }

  bool get _hasActiveSearchState => _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasActiveSearchState && !_searchFocusNode.hasFocus,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (_hasActiveSearchState) {
          _resetSearchState();
          return;
        }
        if (_searchFocusNode.hasFocus) {
          _dismissSearchFocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: SvgPicture.asset(
            'assets/wordmark.svg',
            height: 24,
            fit: BoxFit.contain,
            semanticsLabel: widget.appName,
            alignment: Alignment.centerLeft,
          ),
          centerTitle: false,
          automaticallyImplyLeading: false,
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
          animation: widget.installedToolsController,
          builder: (BuildContext context, Widget? child) {
            final controller = widget.installedToolsController;
            final viewState = _resolveViewState(controller);
            final filtered = _filteredTools(controller);
            final grouped = _filteredGroupedData(controller);
            return SafeArea(
              top: false,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RefreshIndicator(
                      onRefresh: controller.syncFromRepository,
                      child: _buildBody(
                        context,
                        controller,
                        viewState,
                        filtered,
                        grouped,
                      ),
                    ),
                  ),
                  if (_searchFocusNode.hasFocus)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _searchFocusNode.unfocus,
                      ),
                    ),
                  _FloatingControlsBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onClear: () => _searchController.clear(),
                    onOpenMarketplace: () => _openMarketplace(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    InstalledToolsController controller,
    AppViewState viewState,
    List<DeviceInstallRecord> filtered,
    HomeGroupedInstalls grouped,
  ) {
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final showFilteredEmpty =
        viewState == AppViewState.content && filtered.isEmpty && hasSearchQuery;
    final foldersById = _foldersById(controller);

    if (viewState == AppViewState.loading) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverToBoxAdapter(
              child: AppCardSkeletonList(items: 5, lines: 2),
            ),
          ),
        ],
      );
    }

    if (viewState == AppViewState.error) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorView(
              title: 'Could not load installed tools',
              message:
                  controller.errorMessage ??
                  'Unexpected installed-tools loading error.',
              onRetry: controller.retryBootstrap,
            ),
          ),
        ],
      );
    }

    if (viewState == AppViewState.empty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const AppEmptyView(
                      title: 'No installed tools',
                      message:
                          'Browse the Tool Library to install your first tool.',
                    ),
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: 'Browse Tool Library',
                      onPressed: () => _openMarketplace(context),
                      expand: true,
                    ),
                    const SizedBox(height: 12),
                    AppSecondaryButton(
                      label: 'Add 10 Test Tools',
                      onPressed: _addTestTools,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (showFilteredEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const AppEmptyView(
                  title: 'No tools match your search',
                  message: 'Try a different search term or category.',
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppPrimaryButton(
                        label: 'Search in Tool Library',
                        onPressed: () => _openMarketplaceWithSearch(context),
                        expand: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        _HomeHeaderRow(
          selectedSortMode: controller.homeSortMode,
          onSortSelected: (mode) async {
            _dismissSearchFocus();
            await controller.setHomeSortMode(mode);
            if (!mounted) {
              return;
            }
            _dismissSearchFocus();
          },
          onCreateFolder: () {
            _dismissSearchFocus();
            _showFolderEditor(context);
          },
        ),
        const SizedBox(height: 12),
        if (grouped.pinnedTools.isNotEmpty) ...<Widget>[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: grouped.pinnedTools.length,
            itemBuilder: (BuildContext context, int index) {
              final install = grouped.pinnedTools[index];
              final folder =
                  install.folderId != null && install.folderId!.isNotEmpty
                  ? foldersById[install.folderId!]
                  : null;
              return RepaintBoundary(
                child: InstalledToolCard(
                  install: install,
                  iconPath: install.iconPath,
                  dominantColorHex: install.cardAccentColor,
                  folderBadgeLabel: hasSearchQuery && folder != null
                      ? folder.name
                      : null,
                  folderBadgeColor: hasSearchQuery && folder != null
                      ? FolderUiCatalog.colorFor(folder.colorKey)
                      : null,
                  onTap: () {
                    if (install.updateAvailable) {
                      _showUpdateModal(context, install: install);
                    } else {
                      _openToolRuntime(context, install);
                    }
                  },
                  onLongPress: () => _showToolDetailsModal(
                    context,
                    install: install,
                    controller: widget.installedToolsController,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        if (grouped.folders.isNotEmpty) ...<Widget>[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: grouped.folders.length,
            itemBuilder: (context, index) {
              final section = grouped.folders[index];
              return _FolderTile(
                folder: section.folder,
                toolCount: controller.toolsForFolder(section.folder.id).length,
                onTap: () =>
                    context.push(AppRoutes.folderDetail(section.folder.id)),
                onLongPress: () =>
                    _showFolderEditor(context, folder: section.folder),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemCount: grouped.unpinnedTools.length,
          itemBuilder: (BuildContext context, int index) {
            final install = grouped.unpinnedTools[index];
            final folder =
                install.folderId != null && install.folderId!.isNotEmpty
                ? foldersById[install.folderId!]
                : null;
            return RepaintBoundary(
              child: InstalledToolCard(
                install: install,
                iconPath: install.iconPath,
                dominantColorHex: install.cardAccentColor,
                folderBadgeLabel: hasSearchQuery && folder != null
                    ? folder.name
                    : null,
                folderBadgeColor: hasSearchQuery && folder != null
                    ? FolderUiCatalog.colorFor(folder.colorKey)
                    : null,
                onTap: () {
                  if (install.updateAvailable) {
                    _showUpdateModal(context, install: install);
                  } else {
                    _openToolRuntime(context, install);
                  }
                },
                onLongPress: () => _showToolDetailsModal(
                  context,
                  install: install,
                  controller: widget.installedToolsController,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        AppSecondaryButton(
          label: 'Browse Tool Library',
          onPressed: () => _openMarketplace(context),
          expand: true,
        ),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: 'Add 10 Test Tools',
          onPressed: _addTestTools,
          expand: true,
        ),
      ],
    );
  }

  void _showUpdateModal(
    BuildContext context, {
    required DeviceInstallRecord install,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _UpdateDialog(
          install: install,
          onUpdate: () {
            Navigator.of(dialogContext).pop();
            _updateTool(context, install: install);
          },
          onOpenAnyway: () {
            Navigator.of(dialogContext).pop();
            _openToolRuntime(context, install);
          },
        );
      },
    );
  }

  Future<void> _updateTool(
    BuildContext context, {
    required DeviceInstallRecord install,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Updating ${install.displayName}...')),
    );
    try {
      String? assertionToken;
      final isPro = install.pricingTier == 'pro';
      if (isPro) {
        assertionToken = widget.entitlementController.activeAssertionToken;
        if (assertionToken == null || assertionToken.trim().isEmpty) {
          await widget.entitlementController.backgroundReverify(
            reason: 'update',
          );
          assertionToken = widget.entitlementController.activeAssertionToken;
        }
      }

      final grant = await widget.downloadApi.requestDownload(
        pluginSlug: install.pluginSlug,
        entitlementAssertionToken: assertionToken,
      );
      final bundle = await widget.toolBundleDownloadService.downloadBundle(
        pluginSlug: install.pluginSlug,
        grant: grant,
      );
      if (!bundle.isRunnable) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Update failed: bundle is not runnable.'),
          ),
        );
        return;
      }
      final tracked = await widget.installsApi.trackInstall(
        pluginSlug: install.pluginSlug,
        version: grant.version,
      );
      await widget.installedToolsController.recordInstall(
        tracked.copyWith(
          pluginName: install.pluginName,
          categoryName: bundle.category ?? install.categoryName,
          pluginDescription: install.pluginDescription,
          installedVersion: grant.version,
          categoryColor: install.categoryColor,
          iconPath: bundle.iconPath ?? install.iconPath,
          cardAccentColor: bundle.iconAccentColor ?? install.cardAccentColor,
          pricingTier: install.pricingTier,
          pinned: install.pinned,
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${install.displayName} updated to ${grant.version}.'),
        ),
      );
    } on NetworkException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: ${error.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Update failed unexpectedly.')),
      );
    }
  }

  void _showToolDetailsModal(
    BuildContext context, {
    required DeviceInstallRecord install,
    required InstalledToolsController controller,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return ToolActionsSheet(
          install: install,
          controller: controller,
          canPinMore: widget.proCapabilityService.canPinMoreTools(
            controller.pinnedCount,
          ),
          onLaunch: () {
            Navigator.of(sheetContext).pop();
            _openToolRuntime(context, install);
          },
          onUpdate: install.updateAvailable
              ? () {
                  Navigator.of(sheetContext).pop();
                  _updateTool(context, install: install);
                }
              : null,
          onDelete: () async {
            await controller.removeInstall(install);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          onPinBlocked: () {
            Navigator.of(sheetContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                unawaited(_showPinLimitPaywall(context));
              }
            });
          },
          onTogglePin: () async {
            final changed = await controller.togglePin(install);
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
            if (!changed && context.mounted) {
              await _showPinLimitPaywall(context);
            }
          },
          folders: controller.folders,
          onAssignFolder: (folderId) async {
            await controller.assignToolToFolder(
              pluginSlug: install.pluginSlug,
              folderId: folderId,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          onCreateFolderInFlow: () async {
            _dismissSearchFocus();
            final result = await showFolderEditorModal(
              context,
              barrierColor: Colors.transparent,
            );
            _dismissSearchFocus();
            if (result == null || result.type != FolderEditorResultType.save) {
              return null;
            }
            try {
              final createdFolder = await controller.createFolder(
                name: result.name,
                iconKey: result.iconKey,
                colorKey: result.colorKey,
              );
              return createdFolder.id;
            } on FolderQuotaExceededException {
              if (context.mounted) {
                await _showFolderLimitPaywall(context);
              }
              return null;
            }
          },
          onRemoveFromFolder: () async {
            await controller.removeToolFromFolder(
              pluginSlug: install.pluginSlug,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
        );
      },
    );
  }

  Future<void> _showFolderEditor(
    BuildContext context, {
    ToolFolder? folder,
  }) async {
    _dismissSearchFocus();
    final controller = widget.installedToolsController;
    final result = await showFolderEditorModal(
      context,
      folder: folder,
      validateFolderName: (name) =>
          controller.hasFolderWithName(name, excludeFolderId: folder?.id)
              ? 'A folder with this name already exists.'
              : null,
    );
    _dismissSearchFocus();
    if (result == null) {
      return;
    }

    if (result.type == FolderEditorResultType.delete && folder != null) {
      await widget.installedToolsController.deleteFolder(folder.id);
      return;
    }

    if (result.type == FolderEditorResultType.save) {
      if (folder == null) {
        try {
          await widget.installedToolsController.createFolder(
            name: result.name,
            iconKey: result.iconKey,
            colorKey: result.colorKey,
          );
        } on FolderQuotaExceededException {
          if (context.mounted) {
            await _showFolderLimitPaywall(context);
          }
        }
      } else {
        await widget.installedToolsController.updateFolder(
          folderId: folder.id,
          name: result.name,
          iconKey: result.iconKey,
          colorKey: result.colorKey,
        );
      }
    }
  }

  AppViewState _resolveViewState(InstalledToolsController controller) {
    if (controller.state == InstalledToolsState.initializing &&
        controller.installedTools.isEmpty) {
      return AppViewState.loading;
    }
    if (controller.installedTools.isNotEmpty) {
      return AppViewState.content;
    }
    if (controller.state == InstalledToolsState.failed) {
      return AppViewState.error;
    }
    return AppViewState.empty;
  }
}

class _BlurredFloatingSurface extends StatelessWidget {
  const _BlurredFloatingSurface({
    required this.child,
    required this.borderRadius,
    required this.color,
    this.border,
    this.showShadow = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final BoxBorder? border;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FloatingControlsBar extends StatelessWidget {
  const _FloatingControlsBar({
    required this.controller,
    required this.focusNode,
    required this.onClear,
    required this.onOpenMarketplace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onOpenMarketplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isFocused = focusNode.hasFocus;

    final bool showFullWidthSearch =
        isFocused || controller.text.trim().isNotEmpty;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SizedBox(
        height: 56,
        child: Row(
          children: <Widget>[
            ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: showFullWidthSearch ? 0 : 56,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: showFullWidthSearch ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: showFullWidthSearch,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      scale: showFullWidthSearch ? 0.86 : 1,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _BlurredFloatingSurface(
                          borderRadius: BorderRadius.circular(28),
                          color: colorScheme.primary.withValues(alpha: 0.88),
                          showShadow: false,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: onOpenMarketplace,
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 24,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: showFullWidthSearch ? 0 : 12,
            ),
            Expanded(
              child: _BlurredFloatingSurface(
                borderRadius: BorderRadius.circular(28),
                color: isDark
                    ? Colors.black.withValues(alpha: isFocused ? 0.38 : 0.28)
                    : Colors.white.withValues(alpha: isFocused ? 0.82 : 0.72),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search tools',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 18,
                      ),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClear,
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeaderRow extends StatelessWidget {
  const _HomeHeaderRow({
    required this.selectedSortMode,
    required this.onSortSelected,
    required this.onCreateFolder,
  });

  final HomeSortMode selectedSortMode;
  final Future<void> Function(HomeSortMode mode) onSortSelected;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        FilledButton.tonalIcon(
          onPressed: onCreateFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 22),
          label: const Text('Add folder'),
        ),
        PopupMenuButton<HomeSortMode>(
          tooltip: 'Sort tools',
          initialValue: selectedSortMode,
          onSelected: (mode) {
            onSortSelected(mode);
          },
          itemBuilder: (context) => const <PopupMenuEntry<HomeSortMode>>[
            PopupMenuItem(
              value: HomeSortMode.defaultManual,
              child: Text('Default order'),
            ),
            PopupMenuItem(value: HomeSortMode.nameAsc, child: Text('Name A-Z')),
            PopupMenuItem(
              value: HomeSortMode.nameDesc,
              child: Text('Name Z-A'),
            ),
            PopupMenuItem(
              value: HomeSortMode.installDateNewest,
              child: Text('Install date newest'),
            ),
            PopupMenuItem(
              value: HomeSortMode.installDateOldest,
              child: Text('Install date oldest'),
            ),
            PopupMenuItem(
              value: HomeSortMode.lastUsed,
              child: Text('Last used'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.sort_rounded, size: 18),
                const SizedBox(width: 6),
                Text(_sortLabel(selectedSortMode)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _sortLabel(HomeSortMode mode) {
    switch (mode) {
      case HomeSortMode.defaultManual:
        return 'Sort';
      case HomeSortMode.nameAsc:
        return 'A-Z';
      case HomeSortMode.nameDesc:
        return 'Z-A';
      case HomeSortMode.installDateNewest:
        return 'Newest';
      case HomeSortMode.installDateOldest:
        return 'Oldest';
      case HomeSortMode.lastUsed:
        return 'Last used';
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.toolCount,
    required this.onTap,
    required this.onLongPress,
  });

  final ToolFolder folder;
  final int toolCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final iconSize = 28.0;
    final color = FolderUiCatalog.colorFor(folder.colorKey);
    final titleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final titleLineHeight =
        (titleStyle?.fontSize ?? 12) * (titleStyle?.height ?? 1.35);
    final twoLineTitleHeight = titleLineHeight * 2;
    return Material(
      color: color.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.15,
      ),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                key: Key('folder-tile-icon-${folder.id}'),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FolderUiCatalog.iconFor(folder.iconKey),
                  color: color,
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: twoLineTitleHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$toolCount tools',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.install,
    required this.onUpdate,
    required this.onOpenAnyway,
  });

  final DeviceInstallRecord install;
  final VoidCallback onUpdate;
  final VoidCallback onOpenAnyway;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.system_update_alt, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Update Available')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${install.displayName} has a newer version.'),
          const SizedBox(height: 8),
          Text(
            'Installed: ${install.installedVersion ?? "unknown"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Latest: ${install.latestAvailableVersion ?? "unknown"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: onOpenAnyway, child: const Text('Open Anyway')),
        FilledButton.icon(
          onPressed: onUpdate,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update'),
        ),
      ],
    );
  }
}
