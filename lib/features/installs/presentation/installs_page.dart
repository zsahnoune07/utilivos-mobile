import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/search/recent_search_store.dart';
import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_analytics.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/networking/network_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_skeletons.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/tool_thumbnail.dart';
import '../../discover/data/models/catalog_models.dart';
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
    required this.apiBaseUrl,
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
  final String apiBaseUrl;
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
  List<HomeSearchHistoryEntry> _homeRecentHistory = <HomeSearchHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.installedToolsController.bootstrap();
      unawaited(_reloadHomeRecentQueries());
    });
    _searchController.addListener(() => setState(() {}));
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    setState(() {});
  }

  Future<void> _reloadHomeRecentQueries() async {
    final store = await RecentSearchStore.open();
    if (!mounted) {
      return;
    }
    setState(() {
      _homeRecentHistory = store.loadHomeSync();
    });
  }

  Future<void> _persistHomeSearchSubmission(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final store = await RecentSearchStore.open();
    await store.addHomeQuery(trimmed);
    await _reloadHomeRecentQueries();
  }

  Future<void> _persistHomeToolHistoryEntry(DeviceInstallRecord install) async {
    final store = await RecentSearchStore.open();
    await store.addHomeTool(
      slug: install.pluginSlug,
      name: install.displayName,
    );
    if (!mounted) {
      return;
    }
    await _reloadHomeRecentQueries();
  }

  bool _isHomeSearchMode(InstalledToolsController controller) {
    final phase = controller.homePresentationPhase;
    return _searchFocusNode.hasFocus &&
        (phase == HomeInstallsPresentationPhase.content ||
            phase == HomeInstallsPresentationPhase.emptyLibrary);
  }

  String _homeLoadFailureDetail(
    InstalledToolsController controller,
    AppLocalizations l10n,
  ) {
    switch (controller.homeLoadFailureKind) {
      case HomeInstallsLoadFailureKind.offline:
        return l10n.homeInstallsOfflineDetail;
      case HomeInstallsLoadFailureKind.bootstrap:
        return l10n.homeInstallsBootstrapFailedDetail;
      case HomeInstallsLoadFailureKind.corruptLocalData:
        return l10n.homeInstallsCorruptLocalDetail;
      case HomeInstallsLoadFailureKind.sync:
        final message = controller.errorMessage?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        return l10n.homeInstallsSyncFailedDetail;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  DeviceInstallRecord? _homeInstallForSlug(String slug) {
    final normalized = slug.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final DeviceInstallRecord tool
        in widget.installedToolsController.installedTools) {
      if (tool.pluginSlug.trim().toLowerCase() == normalized) {
        return tool;
      }
    }
    return null;
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

  Future<void> _openToolRuntime(
    BuildContext context,
    DeviceInstallRecord install,
  ) async {
    final prepared = await widget.installedToolsController.prepareToolLaunch(
      install.pluginSlug,
    );
    if (!context.mounted) {
      return;
    }
    switch (prepared) {
      case ToolLaunchPrepared.notInstalled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This tool is no longer installed.')),
        );
        return;
      case ToolLaunchPrepared.missingBundle:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tool files were removed. Reinstall from the Tool Library.',
            ),
          ),
        );
        return;
      case ToolLaunchPrepared.mandatoryUpdateRequired:
        _showUpdateModal(context, install: install);
        return;
      case ToolLaunchPrepared.ok:
        break;
    }
    widget.installedToolsController.markToolLaunched(install.pluginSlug);
    unawaited(
      widget.proCapabilityService.recordToolEngagement(install.pluginSlug),
    );
    context
        .push(
          AppRoutes.pluginRuntime(
            install.pluginSlug,
            toolName: install.displayName,
            restoreSession: false,
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

  bool get _hasActiveSearchState =>
      _searchFocusNode.hasFocus || _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasActiveSearchState,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (_hasActiveSearchState) {
          _resetSearchState();
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
            final grouped = _filteredGroupedData(controller);
            return SafeArea(
              top: false,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RefreshIndicator(
                      onRefresh: () =>
                          controller.syncFromRepository(trigger: 'pull'),
                      child: _buildBody(
                        context,
                        controller,
                        grouped,
                      ),
                    ),
                  ),
                  _FloatingControlsBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onClear: () => _searchController.clear(),
                    onOpenMarketplace: () => _openMarketplace(context),
                    onSearchSubmitted: (String value) {
                      unawaited(_persistHomeSearchSubmission(value));
                    },
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
    HomeGroupedInstalls grouped,
  ) {
    final foldersById = _foldersById(controller);
    final phase = controller.homePresentationPhase;
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

    if (phase == HomeInstallsPresentationPhase.loading) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverToBoxAdapter(
              child: AppHomeToolGridSkeleton(
                cells: MediaQuery.sizeOf(context).width >= 600 ? 12 : 9,
              ),
            ),
          ),
        ],
      );
    }

    if (phase == HomeInstallsPresentationPhase.recoverableLoadFailure) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorView(
              title: l10n.homeInstallsLoadFailedTitle,
              message: _homeLoadFailureDetail(controller, l10n),
              onRetry: () => unawaited(controller.retryHomeLoad()),
            ),
          ),
        ],
      );
    }

    if (phase == HomeInstallsPresentationPhase.emptyLibrary &&
        !_searchFocusNode.hasFocus) {
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
                    AppEmptyView(
                      title: l10n.noInstalledTools,
                      message: l10n.noInstalledToolsMessage,
                    ),
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: l10n.browseMarketplace,
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

    if (_isHomeSearchMode(controller)) {
      return _buildHomeFocusedSearchBody(
        context,
        controller,
        grouped,
        foldersById,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        if (controller.isSyncing) ...<Widget>[
          Text(
            'Updating tools...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
              return RepaintBoundary(
                child: InstalledToolCard(
                  install: install,
                  iconPath: install.iconPath,
                  iconBaseUrl: widget.apiBaseUrl,
                  dominantColorHex: install.cardAccentColor,
                  folderBadgeLabel: null,
                  folderBadgeColor: null,
                  onTap: () {
                    if (install.updateAvailable) {
                      _showUpdateModal(context, install: install);
                    } else {
                      unawaited(_openToolRuntime(context, install));
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
            return RepaintBoundary(
              child: InstalledToolCard(
                install: install,
                iconPath: install.iconPath,
                iconBaseUrl: widget.apiBaseUrl,
                dominantColorHex: install.cardAccentColor,
                folderBadgeLabel: null,
                folderBadgeColor: null,
                onTap: () {
                  if (install.updateAvailable) {
                    _showUpdateModal(context, install: install);
                  } else {
                    unawaited(_openToolRuntime(context, install));
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

  Widget _buildHomeFocusedSearchBody(
    BuildContext context,
    InstalledToolsController controller,
    HomeGroupedInstalls grouped,
    Map<String, ToolFolder> foldersById,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    final query = _searchController.text.trim();
    final flat = <DeviceInstallRecord>[
      ...grouped.pinnedTools,
      ...grouped.unpinnedTools,
    ];

    if (query.isNotEmpty && flat.isNotEmpty) {
      return GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.86,
        ),
        itemCount: flat.length,
        itemBuilder: (BuildContext context, int index) {
          final install = flat[index];
          final folder =
              install.folderId != null && install.folderId!.isNotEmpty
              ? foldersById[install.folderId!]
              : null;
          return RepaintBoundary(
            child: InstalledToolCard(
              install: install,
              iconPath: install.iconPath,
              iconBaseUrl: widget.apiBaseUrl,
              dominantColorHex: install.cardAccentColor,
              folderBadgeLabel: folder?.name,
              folderBadgeColor: folder != null
                  ? FolderUiCatalog.colorFor(folder.colorKey)
                  : null,
              onTap: () {
                unawaited(_persistHomeToolHistoryEntry(install));
                if (install.updateAvailable) {
                  _showUpdateModal(context, install: install);
                } else {
                  unawaited(_openToolRuntime(context, install));
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
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        if (query.isEmpty) ...<Widget>[
          Icon(
            Icons.search_rounded,
            size: 44,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchStartTypingTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.searchStartTypingMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (_homeRecentHistory.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.recentActivitySection,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final store = await RecentSearchStore.open();
                    await store.clearHome();
                    await _reloadHomeRecentQueries();
                  },
                  child: Text(l10n.clearSearchHistory),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._homeRecentHistory.map(
              (HomeSearchHistoryEntry e) => switch (e) {
                final HomeSearchHistoryQuery q => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.history,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(q.text),
                  onTap: () {
                    _searchController.text = q.text;
                    _searchController.selection = TextSelection.collapsed(
                      offset: q.text.length,
                    );
                    unawaited(_persistHomeSearchSubmission(q.text));
                  },
                ),
                final HomeSearchHistoryTool t => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ToolThumbnail(
                    imageUrl:
                        '/v1/plugins/${Uri.encodeComponent(t.slug)}/icon',
                    baseUrl: widget.apiBaseUrl,
                    size: 40,
                    borderRadius: 10,
                    fallbackIcon: Icons.extension_outlined,
                  ),
                  title: Text(t.name),
                  onTap: () {
                    final install = _homeInstallForSlug(t.slug);
                    if (install == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.recentToolNoLongerInstalled)),
                      );
                      return;
                    }
                    if (install.updateAvailable) {
                      _showUpdateModal(context, install: install);
                    } else {
                      unawaited(_openToolRuntime(context, install));
                    }
                  },
                ),
              },
            ),
          ],
        ] else ...<Widget>[
          AppEmptyView(
            title: l10n.noToolsMatchSearch,
            message: l10n.noToolsMatchSearchMessage,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AppPrimaryButton(
              label: l10n.searchInToolLibrary,
              onPressed: () => _openMarketplaceWithSearch(context),
              expand: true,
            ),
          ),
        ],
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
          onOpenAnyway: install.updateMandatory
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_openToolRuntime(context, install));
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
      final isPro = CatalogPlugin.tierIsPro(install.pricingTier ?? '');
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
            unawaited(_openToolRuntime(context, install));
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
    required this.onSearchSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onOpenMarketplace;
  final ValueChanged<String> onSearchSubmitted;

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
                    key: const Key('home_tool_search_field'),
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    onSubmitted: onSearchSubmitted,
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
    const iconSize = 28.0;
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
    this.onOpenAnyway,
  });

  final DeviceInstallRecord install;
  final VoidCallback onUpdate;
  final VoidCallback? onOpenAnyway;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mandatory = install.updateMandatory;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Icon(Icons.system_update_alt, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mandatory ? 'Update required' : 'Update available'),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            mandatory
                ? 'You must update ${install.displayName} before you can open it.'
                : '${install.displayName} has a newer version.',
          ),
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
        if (onOpenAnyway != null)
          TextButton(
            onPressed: onOpenAnyway,
            child: const Text('Open Anyway'),
          ),
        FilledButton.icon(
          onPressed: onUpdate,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update'),
        ),
      ],
    );
  }
}
