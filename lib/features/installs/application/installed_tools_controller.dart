import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/networking/network_exception.dart';
import '../../../core/pro/folder_creation_policy.dart';
import '../../../core/pro/freemium_limits.dart';
import '../../../core/pro/pinning_policy.dart';
import '../../../core/pro/tool_session_store.dart';
import '../../../core/sessions/tool_session_service.dart';
import '../../../core/sessions/tool_widget_service.dart';
import '../../../core/versioning/plugin_version_compare.dart';
import '../../discover/data/catalog_api.dart';
import 'folder_quota_exception.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/models/downloaded_tool_bundle.dart';
import '../data/installed_tools_read_result.dart';
import '../data/installed_tools_store.dart';
import '../data/local_install_removals_store.dart';
import '../data/installs_sync_meta_store.dart';
import '../data/installs_organization_store.dart';
import '../data/installs_api.dart';
import '../data/models/install_models.dart';
import '../data/models/installs_organization_models.dart';

enum InstalledToolsState { initializing, ready, failed }

/// Home tab (Installs) presentation phase for empty/error/loading orchestration.
enum HomeInstallsPresentationPhase { loading, content, emptyLibrary, recoverableLoadFailure }

/// Why [HomeInstallsPresentationPhase.recoverableLoadFailure] is shown.
enum HomeInstallsLoadFailureKind { offline, bootstrap, sync, corruptLocalData }

/// Result of [InstalledToolsController.prepareToolLaunch] before navigating to runtime.
enum ToolLaunchPrepared {
  ok,
  notInstalled,
  missingBundle,
  mandatoryUpdateRequired,
}

class InstalledToolsController extends ChangeNotifier {
  InstalledToolsController({
    required InstallsApi installsApi,
    required CatalogApi catalogApi,
    required InstalledToolsStore store,
    required InstallsOrganizationStore organizationStore,
    InstallsSyncMetaStore? syncMetaStore,
    LocalInstallRemovalsStore? removalsStore,
    ToolBundleDownloadService? toolBundleDownloadService,
    ToolWidgetService? toolWidgetService,
    ToolSessionService? toolSessionService,
    ToolSessionStore? toolSessionStore,
    PinningPolicy pinningPolicy = const UnlimitedPinningPolicy(),
    FolderCreationPolicy folderCreationPolicy =
        const UnlimitedFolderCreationPolicy(),
  }) : _installsApi = installsApi,
       _catalogApi = catalogApi,
       _store = store,
       _organizationStore = organizationStore,
       _syncMetaStore = syncMetaStore ?? const NoopInstallsSyncMetaStore(),
       _removalsStore = removalsStore ?? const NoopLocalInstallRemovalsStore(),
       _toolBundleDownloadService = toolBundleDownloadService,
       _toolWidgetService = toolWidgetService,
       _toolSessionService = toolSessionService,
       _toolSessionStore = toolSessionStore,
       _pinningPolicy = pinningPolicy,
       _folderCreationPolicy = folderCreationPolicy;

  /// Free-tier pin cap (Pro bypasses via [PinningPolicy]).
  static int get maxPinnedTools => FreemiumLimits.maxPinnedTools;
  static const int maxFolderNameLength = 16;

  final InstallsApi _installsApi;
  final CatalogApi _catalogApi;
  final InstalledToolsStore _store;
  final InstallsOrganizationStore _organizationStore;
  final InstallsSyncMetaStore _syncMetaStore;
  final LocalInstallRemovalsStore _removalsStore;
  final ToolBundleDownloadService? _toolBundleDownloadService;
  final ToolWidgetService? _toolWidgetService;
  final ToolSessionService? _toolSessionService;
  final ToolSessionStore? _toolSessionStore;
  final PinningPolicy _pinningPolicy;
  final FolderCreationPolicy _folderCreationPolicy;

  bool _disposed = false;

  bool _bootstrapStarted = false;
  InstalledToolsState _state = InstalledToolsState.initializing;
  List<DeviceInstallRecord> _installedTools = const <DeviceInstallRecord>[];
  bool _isSyncing = false;
  bool _isCheckingUpdates = false;
  bool _isFirstRunOffline = false;
  String? _statusMessage;
  String? _errorMessage;
  DateTime? _lastSyncedAt;
  List<ToolFolder> _folders = const <ToolFolder>[];
  HomeSortMode _homeSortMode = HomeSortMode.defaultManual;
  Set<String> _removedInstallSlugs = <String>{};

  bool _initialRepositorySyncSettled = false;
  bool _bootstrapFailed = false;
  int _skippedInvalidRowsOnLastStoreRead = 0;

  InstalledToolsState get state => _state;
  bool get isSyncing => _isSyncing;
  bool get isCheckingUpdates => _isCheckingUpdates;
  bool get isFirstRunOffline => _isFirstRunOffline;
  bool get isBusy => _isSyncing || _isCheckingUpdates;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasFailed => _state == InstalledToolsState.failed;
  bool get hasCachedTools => _installedTools.isNotEmpty;
  HomeSortMode get homeSortMode => _homeSortMode;
  List<ToolFolder> get folders => _sortedFolders(_folders);

  List<DeviceInstallRecord> get installedTools => _sortedTools(_installedTools);

  /// Single source of truth for Installs home body state (loading / content / empty / error).
  HomeInstallsPresentationPhase get homePresentationPhase {
    if (_installedTools.isNotEmpty) {
      return HomeInstallsPresentationPhase.content;
    }
    if (_state == InstalledToolsState.initializing) {
      return HomeInstallsPresentationPhase.loading;
    }
    if (!_initialRepositorySyncSettled) {
      return HomeInstallsPresentationPhase.loading;
    }
    if (_state == InstalledToolsState.failed) {
      return HomeInstallsPresentationPhase.recoverableLoadFailure;
    }
    if (_skippedInvalidRowsOnLastStoreRead > 0) {
      return HomeInstallsPresentationPhase.recoverableLoadFailure;
    }
    return HomeInstallsPresentationPhase.emptyLibrary;
  }

  /// Meaningful when [homePresentationPhase] is [HomeInstallsPresentationPhase.recoverableLoadFailure].
  HomeInstallsLoadFailureKind get homeLoadFailureKind {
    if (_skippedInvalidRowsOnLastStoreRead > 0 &&
        _state == InstalledToolsState.ready &&
        _installedTools.isEmpty) {
      return HomeInstallsLoadFailureKind.corruptLocalData;
    }
    if (_state == InstalledToolsState.failed) {
      if (_isFirstRunOffline) {
        return HomeInstallsLoadFailureKind.offline;
      }
      if (_bootstrapFailed) {
        return HomeInstallsLoadFailureKind.bootstrap;
      }
      return HomeInstallsLoadFailureKind.sync;
    }
    return HomeInstallsLoadFailureKind.sync;
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  HomeGroupedInstalls get groupedHomeData {
    final pinnedTools = _sortByMode(
      _installedTools
          .where((DeviceInstallRecord tool) => tool.pinned)
          .toList(growable: false),
    );
    final folders = _sortedFolders(_folders);
    final folderSections = folders
        .map((folder) {
          return HomeFolderSection(
            folder: folder,
            tools: _sortByMode(
              _installedTools
                  .where(
                    (tool) =>
                        !tool.pinned &&
                        tool.folderId != null &&
                        tool.folderId == folder.id,
                  )
                  .toList(growable: false),
            ),
          );
        })
        .toList(growable: false);
    final unpinnedTools = _sortByMode(
      _installedTools
          .where(
            (tool) =>
                !tool.pinned &&
                (tool.folderId == null || tool.folderId!.isEmpty),
          )
          .toList(growable: false),
    );
    return HomeGroupedInstalls(
      pinnedTools: pinnedTools,
      folders: folderSections,
      unpinnedTools: unpinnedTools,
    );
  }

  List<DeviceInstallRecord> _sortedTools(List<DeviceInstallRecord> tools) {
    final pinned = _sortByMode(
      tools.where((DeviceInstallRecord t) => t.pinned).toList(growable: false),
    );
    final unpinned = _sortByMode(
      tools.where((DeviceInstallRecord t) => !t.pinned).toList(growable: false),
    );
    return <DeviceInstallRecord>[...pinned, ...unpinned];
  }

  Future<void> bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;

    _state = InstalledToolsState.initializing;
    _statusMessage = null;
    _errorMessage = null;
    _isFirstRunOffline = false;
    _bootstrapFailed = false;
    _notify();

    try {
      final organization = await _organizationStore.read();
      final InstalledToolsStoreReadResult readResult = await _store.read();
      final cached = readResult.installs;
      _skippedInvalidRowsOnLastStoreRead = readResult.skippedInvalidRowCount;
      _removedInstallSlugs = await _removalsStore.read();
      _lastSyncedAt = await _syncMetaStore.readLastSyncedAt();
      final hydrated = await _hydrateLocalBundleMetadata(cached);
      _folders = organization.folders;
      _homeSortMode = organization.homeSortMode;
      _installedTools = _reconcileFolderAssignments(hydrated.installs);
      if (hydrated.didMutate) {
        await _persistState();
      }
      _state = InstalledToolsState.ready;
      _initialRepositorySyncSettled = _installedTools.isNotEmpty;
      _statusMessage = _installedTools.isEmpty
          ? 'No installed tools found yet.'
          : 'Loaded installed tools from device cache.';
    } catch (error) {
      developer.log(
        'Failed to bootstrap installed tools cache.',
        name: 'InstalledToolsController',
        error: error,
      );
      _installedTools = const <DeviceInstallRecord>[];
      _folders = const <ToolFolder>[];
      _homeSortMode = HomeSortMode.defaultManual;
      _state = InstalledToolsState.failed;
      _bootstrapFailed = true;
      _initialRepositorySyncSettled = true;
      _errorMessage = 'Failed to load installed tools cache: $error';
      _notify();
      return;
    }

    _notify();
    unawaited(syncFromRepository(trigger: 'launch'));
  }

  Future<void> retryBootstrap() async {
    _bootstrapStarted = false;
    await bootstrap();
  }

  /// Single preferred retry for the Installs home recoverable failure states.
  Future<void> retryHomeLoad() async {
    switch (homeLoadFailureKind) {
      case HomeInstallsLoadFailureKind.corruptLocalData:
        await _store.clear();
        await retryBootstrap();
        return;
      case HomeInstallsLoadFailureKind.bootstrap:
        await retryBootstrap();
        return;
      case HomeInstallsLoadFailureKind.offline:
      case HomeInstallsLoadFailureKind.sync:
        await syncFromRepository(trigger: 'retry');
        return;
    }
  }

  Future<void> syncFromRepository({String trigger = 'manual'}) async {
    if (_isSyncing) {
      return;
    }

    developer.log(
      'Starting installed-tools sync.',
      name: 'InstalledToolsController',
      error: 'trigger=$trigger localCount=${_installedTools.length}',
    );
    _isSyncing = true;
    _errorMessage = null;
    _isFirstRunOffline = false;
    _notify();

    try {
      final remoteInstalls = await _installsApi.listInstalls();
      final slugsBeforeSync = <String>{
        for (final t in _installedTools) t.pluginSlug,
      };
      _installedTools = _mergeRemoteWithCached(remoteInstalls, _installedTools);
      final newRemoteSlugs = <String>{
        for (final t in _installedTools)
          if (!slugsBeforeSync.contains(t.pluginSlug)) t.pluginSlug,
      };
      _installedTools = await _hydrateCatalogMetadata(
        _installedTools,
        forceRefreshSlugs: newRemoteSlugs,
      );
      final hydrated = await _hydrateLocalBundleMetadata(_installedTools);
      _installedTools = _reconcileFolderAssignments(hydrated.installs);
      _lastSyncedAt = DateTime.now().toUtc();
      _state = InstalledToolsState.ready;
      _isFirstRunOffline = false;
      _statusMessage = remoteInstalls.isEmpty
          ? 'No installed tools found for this device yet.'
          : 'Installed tools synced from online repository.';
      developer.log(
        'Installed-tools sync succeeded.',
        name: 'InstalledToolsController',
        error:
            'trigger=$trigger remoteCount=${remoteInstalls.length} localCount=${_installedTools.length}',
      );
      await _persistState();
      await _syncMetaStore.writeLastSyncedAt(_lastSyncedAt!);
      _notify();
    } on NetworkException {
      if (_installedTools.isEmpty) {
        _state = InstalledToolsState.failed;
        _isFirstRunOffline = true;
        _errorMessage =
            'Could not reach online repository to load installed tools.';
        developer.log(
          'Installed-tools sync failed with offline first-run state.',
          name: 'InstalledToolsController',
          error: 'trigger=$trigger',
        );
      } else {
        _state = InstalledToolsState.ready;
        _isFirstRunOffline = false;
        _statusMessage =
            'Offline mode: showing installed tools from local cache.';
        developer.log(
          'Installed-tools sync offline fallback used.',
          name: 'InstalledToolsController',
          error: 'trigger=$trigger localCount=${_installedTools.length}',
        );
      }
    } catch (error) {
      developer.log(
        'Unexpected installed-tools sync error.',
        name: 'InstalledToolsController',
        error: error,
      );
      if (_installedTools.isEmpty) {
        _state = InstalledToolsState.failed;
        _isFirstRunOffline = false;
        _errorMessage = 'Unexpected installed-tools sync error: $error';
      } else {
        _state = InstalledToolsState.ready;
        _isFirstRunOffline = false;
        _statusMessage =
            'Unable to refresh right now. Showing cached installed tools.';
      }
    } finally {
      _isSyncing = false;
      _initialRepositorySyncSettled = true;
      _notify();
    }
    unawaited(checkForUpdates());
  }

  Future<void> checkForUpdates() async {
    if (_disposed || _isCheckingUpdates || _installedTools.isEmpty) {
      return;
    }

    _isCheckingUpdates = true;
    _notify();

    try {
      final now = DateTime.now().toUtc();
      final updatedTools = <DeviceInstallRecord>[];
      for (final install in _installedTools) {
        updatedTools.add(await _withLatestVersion(install, checkedAt: now));
      }
      _installedTools = updatedTools;
      final updatesFound = updatedTools.any(
        (DeviceInstallRecord t) => t.updateAvailable,
      );
      if (updatesFound) {
        _statusMessage = 'Updates available for some tools.';
      }
      await _store.write(_installedTools);
    } finally {
      _isCheckingUpdates = false;
      _notify();
    }
  }

  Future<void> removeInstall(DeviceInstallRecord install) async {
    _removedInstallSlugs.add(_normalizeInstallSlug(install.pluginSlug));
    await _persistRemovals();
    _installedTools = _installedTools
        .where(
          (DeviceInstallRecord t) =>
              _normalizeInstallSlug(t.pluginSlug) !=
              _normalizeInstallSlug(install.pluginSlug),
        )
        .toList(growable: false);
    _installedTools = _reconcileFolderAssignments(_installedTools);
    _state = InstalledToolsState.ready;
    _errorMessage = null;
    _statusMessage = _installedTools.isEmpty
        ? 'No installed tools.'
        : 'Tool removed from this device.';
    await _persistState();
    _notify();
    try {
      await _toolBundleDownloadService?.deleteBundle(install.pluginSlug);
    } catch (_) {
      // Best-effort bundle cleanup.
    }
    try {
      await _toolWidgetService?.removeWidgetsForTool(
        installId: install.id,
        toolSlug: install.pluginSlug,
      );
    } catch (_) {
      // Best-effort widget metadata + launcher tile reset.
    }
    try {
      await _toolSessionService?.deleteAllSessionsForRemovedInstall(
        installId: install.id,
        pluginSlug: install.pluginSlug,
      );
    } catch (_) {
      // Best-effort named session cleanup.
    }
    try {
      await _toolSessionStore?.removeLegacyDiskSnapshotIfExists(
        install.pluginSlug,
      );
    } catch (_) {
      // Best-effort legacy file snapshot cleanup.
    }
  }

  /// Returns `true` if pin state changed.
  Future<bool> togglePin(DeviceInstallRecord install) async {
    final newPinned = !install.pinned;
    final currentPinnedCount = _installedTools
        .where((DeviceInstallRecord t) => t.pinned)
        .length;
    if (!_pinningPolicy.allowPinChange(
      currentPinnedCount: currentPinnedCount,
      targetPinned: newPinned,
    )) {
      return false;
    }
    _installedTools = _installedTools
        .map((DeviceInstallRecord t) {
          if (t.pluginSlug == install.pluginSlug) {
            return t.copyWith(pinned: newPinned);
          }
          return t;
        })
        .toList(growable: false);
    await _persistState();
    _notify();
    return true;
  }

  int get pinnedCount =>
      _installedTools.where((DeviceInstallRecord t) => t.pinned).length;

  Future<void> recordInstall(DeviceInstallRecord installation) async {
    _removedInstallSlugs.remove(_normalizeInstallSlug(installation.pluginSlug));
    await _persistRemovals();
    final existingIndex = _installedTools.indexWhere(
      (DeviceInstallRecord current) =>
          _normalizeInstallSlug(current.pluginSlug) ==
          _normalizeInstallSlug(installation.pluginSlug),
    );

    final existing = existingIndex >= 0 ? _installedTools[existingIndex] : null;
    final normalized = installation.copyWith(
      updateAvailable: false,
      updateMandatory: false,
      latestAvailableVersion:
          installation.installedVersion ?? installation.latestAvailableVersion,
      lastUpdateCheckAt: DateTime.now().toUtc(),
      pluginName: installation.pluginName ?? existing?.pluginName,
      categoryName: installation.categoryName ?? existing?.categoryName,
      pluginDescription:
          installation.pluginDescription ?? existing?.pluginDescription,
      categoryColor: installation.categoryColor ?? existing?.categoryColor,
      iconPath: installation.iconPath ?? existing?.iconPath,
      catalogThumbnailUrl:
          installation.catalogThumbnailUrl ?? existing?.catalogThumbnailUrl,
      cardAccentColor:
          installation.cardAccentColor ?? existing?.cardAccentColor,
      pricingTier: installation.pricingTier ?? existing?.pricingTier,
      pinned: existing?.pinned ?? false,
      folderId: existing?.folderId,
      lastLaunchedAt: existing?.lastLaunchedAt,
    );

    if (existingIndex >= 0) {
      final mutableTools = _installedTools.toList(growable: true);
      mutableTools[existingIndex] = normalized;
      _installedTools = mutableTools;
    } else {
      _installedTools = <DeviceInstallRecord>[normalized, ..._installedTools];
    }

    _state = InstalledToolsState.ready;
    _errorMessage = null;
    _statusMessage = 'Installed tools updated locally.';
    _installedTools = _reconcileFolderAssignments(_installedTools);
    await _persistState();
    _notify();

    unawaited(checkForUpdates());
  }

  List<DeviceInstallRecord> _mergeRemoteWithCached(
    List<DeviceInstallRecord> remoteInstalls,
    List<DeviceInstallRecord> cachedInstalls,
  ) {
    final cachedBySlug = <String, DeviceInstallRecord>{
      for (final install in cachedInstalls)
        _normalizeInstallSlug(install.pluginSlug): install,
    };
    final mergedSlugs = <String>{};
    final merged = <DeviceInstallRecord>[];

    for (final remote in remoteInstalls) {
      final slug = _normalizeInstallSlug(remote.pluginSlug);
      if (_removedInstallSlugs.contains(slug)) {
        continue;
      }
      final cached = cachedBySlug[slug];
      if (cached != null) {
        merged.add(
          remote.copyWith(
            latestAvailableVersion: cached.latestAvailableVersion,
            updateAvailable: cached.updateAvailable,
            lastUpdateCheckAt: cached.lastUpdateCheckAt,
            pluginName: cached.pluginName ?? remote.pluginName,
            categoryName: cached.categoryName ?? remote.categoryName,
            pluginDescription:
                cached.pluginDescription ?? remote.pluginDescription,
            categoryColor: cached.categoryColor ?? remote.categoryColor,
            iconPath: cached.iconPath ?? remote.iconPath,
            catalogThumbnailUrl:
                cached.catalogThumbnailUrl ?? remote.catalogThumbnailUrl,
            cardAccentColor: cached.cardAccentColor ?? remote.cardAccentColor,
            pricingTier: cached.pricingTier ?? remote.pricingTier,
            pinned: cached.pinned,
            folderId: cached.folderId,
            lastLaunchedAt: cached.lastLaunchedAt,
          ),
        );
      } else {
        merged.add(remote);
      }
      mergedSlugs.add(slug);
    }

    for (final cached in cachedInstalls) {
      final slug = _normalizeInstallSlug(cached.pluginSlug);
      if (mergedSlugs.contains(slug)) {
        continue;
      }
      if (_removedInstallSlugs.contains(slug)) {
        continue;
      }
      merged.add(cached);
    }

    return merged;
  }

  Future<void> _persistRemovals() async {
    await _removalsStore.write(_removedInstallSlugs);
  }

  /// Validates install list + local bundle before opening the tool runtime.
  Future<ToolLaunchPrepared> prepareToolLaunch(String pluginSlug) async {
    final normalized = _normalizeInstallSlug(pluginSlug);
    DeviceInstallRecord? record;
    for (final t in _installedTools) {
      if (_normalizeInstallSlug(t.pluginSlug) == normalized) {
        record = t;
        break;
      }
    }
    if (record == null) {
      return ToolLaunchPrepared.notInstalled;
    }
    if (record.updateMandatory && record.updateAvailable) {
      return ToolLaunchPrepared.mandatoryUpdateRequired;
    }
    final service = _toolBundleDownloadService;
    if (service == null) {
      return ToolLaunchPrepared.ok;
    }
    final bundle = await service.findRunnableBundle(pluginSlug);
    if (bundle == null) {
      await removeInstall(record);
      return ToolLaunchPrepared.missingBundle;
    }
    return ToolLaunchPrepared.ok;
  }

  Future<List<DeviceInstallRecord>> _hydrateCatalogMetadata(
    List<DeviceInstallRecord> installs, {
    Set<String> forceRefreshSlugs = const <String>{},
  }) async {
    final updatedInstalls = <DeviceInstallRecord>[];
    for (final install in installs) {
      final forceRefresh = forceRefreshSlugs.contains(install.pluginSlug);
      final shouldFetch = forceRefresh || _needsCatalogMetadata(install);
      if (!shouldFetch) {
        updatedInstalls.add(install);
        continue;
      }
      try {
        final plugin = await _catalogApi.getPluginBySlug(
          install.pluginSlug,
          forceRefresh: forceRefresh,
        );
        final iconRef = plugin.catalogListIconRef.trim();
        updatedInstalls.add(
          install.copyWith(
            pluginName: plugin.name,
            categoryName: plugin.categoryName,
            categoryColor: plugin.categoryColor,
            pluginDescription:
                plugin.longDescription ?? plugin.shortDescription,
            pricingTier: _normalizeTier(plugin.pricingType),
            catalogThumbnailUrl: iconRef.isNotEmpty
                ? iconRef
                : install.catalogThumbnailUrl,
          ),
        );
      } on NetworkException {
        updatedInstalls.add(install);
      } catch (_) {
        developer.log(
          'Failed to hydrate catalog metadata for install.',
          name: 'InstalledToolsController',
          error: 'slug=${install.pluginSlug}',
        );
        updatedInstalls.add(install);
      }
    }
    return updatedInstalls;
  }

  bool _needsCatalogMetadata(DeviceInstallRecord install) {
    return (install.pluginName?.trim().isEmpty ?? true) ||
        (install.categoryName?.trim().isEmpty ?? true) ||
        (install.categoryColor?.trim().isEmpty ?? true) ||
        (install.pluginDescription?.trim().isEmpty ?? true) ||
        (install.pricingTier?.trim().isEmpty ?? true) ||
        (install.catalogThumbnailUrl?.trim().isEmpty ?? true);
  }

  Future<_InstallHydrationResult> _hydrateLocalBundleMetadata(
    List<DeviceInstallRecord> installs,
  ) async {
    final service = _toolBundleDownloadService;
    if (service == null || installs.isEmpty) {
      return _InstallHydrationResult(installs: installs, didMutate: false);
    }

    final bundles = await service.listDownloadedBundles();
    if (bundles.isEmpty) {
      return _InstallHydrationResult(installs: installs, didMutate: false);
    }
    final bundlesBySlug = <String, DownloadedToolBundle>{
      for (final bundle in bundles) bundle.pluginSlug: bundle,
    };

    var didMutate = false;
    final hydrated = installs
        .map((DeviceInstallRecord install) {
          final bundle = bundlesBySlug[install.pluginSlug];
          if (bundle == null) {
            return install;
          }
          final iconPath = bundle.iconPath;
          final iconAccentColor = bundle.iconAccentColor;
          final category = bundle.category;
          final pluginName = bundle.pluginName;
          final updated = install.copyWith(
            pluginName: install.pluginName ?? pluginName,
            categoryName: install.categoryName ?? category,
            iconPath: install.iconPath ?? iconPath,
            cardAccentColor: install.cardAccentColor ?? iconAccentColor,
            pricingTier:
                install.pricingTier ?? _normalizeTier(bundle.verifiedTier),
          );
          if (!identical(updated, install) &&
              (updated.pluginName != install.pluginName ||
                  updated.categoryName != install.categoryName ||
                  updated.iconPath != install.iconPath ||
                  updated.cardAccentColor != install.cardAccentColor)) {
            didMutate = true;
          }
          return updated;
        })
        .toList(growable: false);
    return _InstallHydrationResult(installs: hydrated, didMutate: didMutate);
  }

  String? _normalizeTier(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized == 'free') {
      return 'free';
    }
    if (normalized == 'pro' ||
        normalized == 'paid' ||
        normalized == 'premium') {
      return 'pro';
    }
    return null;
  }

  Future<void> addDebugTools({int count = 10}) async {
    const names = <String>[
      'Key Utility',
      'Address Explorer',
      'Seed Converter',
      'Node Monitor',
      'Transaction Inspector',
      'UTXO Viewer',
      'Lightning Helper',
      'Fee Estimator',
      'Wallet Toolkit',
      'Script Decoder',
    ];
    const categories = <String>[
      'Utilities',
      'Security',
      'Marketplace',
      'Finance',
      'Networking',
    ];
    const descriptions = <String>[
      'Calculate public keys from private keys and export results quickly.',
      'Inspect wallet addresses, balances, and chain metadata in one place.',
      'Convert seed phrases between formats and verify checksums safely.',
      'Monitor peer status, mempool health, and node responsiveness.',
      'Decode transactions, signatures, and raw payloads for debugging.',
      'Review UTXOs, filter spendable outputs, and estimate consolidation.',
      'Estimate routing conditions and inspect Lightning network details.',
      'Compare fee targets and suggest optimal confirmation windows.',
      'Bundle common wallet maintenance tools for daily usage.',
      'Decode script templates and explain opcode usage clearly.',
    ];

    final random = Random();
    final now = DateTime.now().toUtc();
    final deviceId = _installedTools.isNotEmpty
        ? _installedTools.first.deviceId
        : 'debug-device';

    final generated = List<DeviceInstallRecord>.generate(count, (int index) {
      final seed = now.microsecondsSinceEpoch + index;
      final name = names[random.nextInt(names.length)];
      return DeviceInstallRecord(
        id: 'debug-$seed',
        deviceId: deviceId,
        pluginId: 'debug.plugin.$seed',
        pluginSlug: 'debug-tool-$seed',
        source: 'debug_seed',
        installedAt: now.add(Duration(seconds: index)),
        installedVersionId: '1.0.${index + 1}',
        installedVersion: '1.0.${index + 1}',
        updatedAt: now.add(Duration(seconds: index)),
        latestAvailableVersion: '1.0.${index + 1}',
        updateAvailable: false,
        lastUpdateCheckAt: now,
        pluginName: '$name ${100 + index}',
        categoryName: categories[random.nextInt(categories.length)],
        pluginDescription: descriptions[random.nextInt(descriptions.length)],
      );
    });

    _installedTools = <DeviceInstallRecord>[...generated, ..._installedTools];
    _state = InstalledToolsState.ready;
    _errorMessage = null;
    _statusMessage = 'Added $count test tools.';
    _installedTools = _reconcileFolderAssignments(_installedTools);
    await _persistState();
    _notify();
  }

  Future<void> setHomeSortMode(HomeSortMode mode) async {
    if (_homeSortMode == mode) {
      return;
    }
    _homeSortMode = mode;
    await _persistState();
    _notify();
  }

  ToolFolder? folderById(String folderId) {
    final normalized = folderId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final folder in _folders) {
      if (folder.id == normalized) {
        return folder;
      }
    }
    return null;
  }

  List<DeviceInstallRecord> toolsForFolder(
    String folderId, {
    bool includePinned = true,
  }) {
    final normalized = folderId.trim();
    if (normalized.isEmpty) {
      return const <DeviceInstallRecord>[];
    }
    return _sortByMode(
      _installedTools
          .where(
            (DeviceInstallRecord tool) =>
                tool.folderId == normalized && (includePinned || !tool.pinned),
          )
          .toList(growable: false),
    );
  }

  bool hasFolderWithName(String name, {String? excludeFolderId}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    for (final folder in _folders) {
      if (folder.id == excludeFolderId) {
        continue;
      }
      if (folder.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  Future<ToolFolder> createFolder({
    required String name,
    required String iconKey,
    required String colorKey,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name is required.');
    }
    if (trimmedName.length > maxFolderNameLength) {
      throw ArgumentError(
        'Folder name must be $maxFolderNameLength characters or less.',
      );
    }
    if (hasFolderWithName(trimmedName)) {
      throw ArgumentError('A folder with this name already exists.');
    }
    if (!_folderCreationPolicy.allowCreateFolder(_folders.length)) {
      throw const FolderQuotaExceededException();
    }
    final now = DateTime.now().toUtc();
    final folder = ToolFolder(
      id: 'folder_${now.microsecondsSinceEpoch}',
      name: trimmedName,
      iconKey: iconKey.trim(),
      colorKey: colorKey.trim(),
      createdAt: now,
      updatedAt: now,
      manualOrder: _folders.length,
    );
    _folders = <ToolFolder>[..._folders, folder];
    await _persistState();
    _notify();
    return folder;
  }

  Future<void> updateFolder({
    required String folderId,
    required String name,
    required String iconKey,
    required String colorKey,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Folder name is required.');
    }
    final existing = folderById(folderId);
    final isLegacyUnchangedLongName =
        existing != null &&
        existing.name.trim().length > maxFolderNameLength &&
        existing.name.trim() == trimmedName;
    if (trimmedName.length > maxFolderNameLength &&
        !isLegacyUnchangedLongName) {
      throw ArgumentError(
        'Folder name must be $maxFolderNameLength characters or less.',
      );
    }
    if (hasFolderWithName(trimmedName, excludeFolderId: folderId)) {
      throw ArgumentError('A folder with this name already exists.');
    }
    _folders = _folders
        .map((folder) {
          if (folder.id != folderId) {
            return folder;
          }
          return folder.copyWith(
            name: trimmedName,
            iconKey: iconKey.trim(),
            colorKey: colorKey.trim(),
            updatedAt: DateTime.now().toUtc(),
          );
        })
        .toList(growable: false);
    await _persistState();
    _notify();
  }

  Future<void> deleteFolder(String folderId) async {
    _folders = _folders
        .where((folder) => folder.id != folderId)
        .toList(growable: false);
    _installedTools = _installedTools
        .map((tool) {
          if (tool.folderId != folderId) {
            return tool;
          }
          return tool.copyWith(folderId: null);
        })
        .toList(growable: false);
    await _persistState();
    _notify();
  }

  Future<void> assignToolToFolder({
    required String pluginSlug,
    required String folderId,
  }) async {
    if (folderById(folderId) == null) {
      throw ArgumentError('Folder does not exist.');
    }
    _installedTools = _installedTools
        .map((tool) {
          if (tool.pluginSlug != pluginSlug) {
            return tool;
          }
          return tool.copyWith(folderId: folderId);
        })
        .toList(growable: false);
    await _persistState();
    _notify();
  }

  Future<void> removeToolFromFolder({required String pluginSlug}) async {
    _installedTools = _installedTools
        .map((tool) {
          if (tool.pluginSlug != pluginSlug) {
            return tool;
          }
          return tool.copyWith(folderId: null);
        })
        .toList(growable: false);
    await _persistState();
    _notify();
  }

  Future<void> markToolLaunched(String pluginSlug) async {
    final launchedAt = DateTime.now().toUtc();
    var didMutate = false;
    _installedTools = _installedTools
        .map((tool) {
          if (tool.pluginSlug != pluginSlug) {
            return tool;
          }
          didMutate = true;
          return tool.copyWith(lastLaunchedAt: launchedAt);
        })
        .toList(growable: false);
    if (!didMutate) {
      return;
    }
    await _persistState();
    _notify();
  }

  List<ToolFolder> _sortedFolders(List<ToolFolder> folders) {
    final copy = folders.toList(growable: true);
    switch (_homeSortMode) {
      case HomeSortMode.nameAsc:
        copy.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case HomeSortMode.nameDesc:
        copy.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case HomeSortMode.installDateNewest:
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case HomeSortMode.installDateOldest:
        copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case HomeSortMode.lastUsed:
      case HomeSortMode.defaultManual:
        copy.sort((a, b) {
          final aOrder = a.manualOrder ?? 0;
          final bOrder = b.manualOrder ?? 0;
          return aOrder.compareTo(bOrder);
        });
        break;
    }
    return copy;
  }

  List<DeviceInstallRecord> _sortByMode(List<DeviceInstallRecord> tools) {
    final copy = tools.toList(growable: true);
    switch (_homeSortMode) {
      case HomeSortMode.nameAsc:
        copy.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        break;
      case HomeSortMode.nameDesc:
        copy.sort(
          (a, b) => b.displayName.toLowerCase().compareTo(
            a.displayName.toLowerCase(),
          ),
        );
        break;
      case HomeSortMode.installDateNewest:
        copy.sort((a, b) => b.installedAt.compareTo(a.installedAt));
        break;
      case HomeSortMode.installDateOldest:
        copy.sort((a, b) => a.installedAt.compareTo(b.installedAt));
        break;
      case HomeSortMode.lastUsed:
        copy.sort((a, b) {
          final aTime = a.lastLaunchedAt ?? a.installedAt;
          final bTime = b.lastLaunchedAt ?? b.installedAt;
          return bTime.compareTo(aTime);
        });
        break;
      case HomeSortMode.defaultManual:
        break;
    }
    return copy;
  }

  List<DeviceInstallRecord> _reconcileFolderAssignments(
    List<DeviceInstallRecord> tools,
  ) {
    if (_folders.isEmpty) {
      return tools
          .map((tool) => tool.copyWith(folderId: null))
          .toList(growable: false);
    }
    final validFolderIds = _folders.map((f) => f.id).toSet();
    var didMutate = false;
    final reconciled = tools
        .map((tool) {
          final folderId = tool.folderId;
          if (folderId == null || folderId.isEmpty) {
            return tool;
          }
          if (validFolderIds.contains(folderId)) {
            return tool;
          }
          didMutate = true;
          return tool.copyWith(folderId: null);
        })
        .toList(growable: false);
    return didMutate ? reconciled : tools;
  }

  Future<void> _persistState() async {
    await _store.write(_installedTools);
    await _organizationStore.write(
      InstallsOrganizationState(folders: _folders, homeSortMode: _homeSortMode),
    );
  }

  Future<DeviceInstallRecord> _withLatestVersion(
    DeviceInstallRecord install, {
    required DateTime checkedAt,
  }) async {
    try {
      final versions = await _catalogApi.listPluginVersions(
        install.pluginSlug,
        forceRefresh: true,
      );
      final latest = versions.isEmpty ? null : versions.first;
      final latestVersion = latest?.version;
      final hasUpdate = isPluginUpdateAvailable(
        installedVersion: install.installedVersion,
        latestVersion: latestVersion,
      );
      return install.copyWith(
        latestAvailableVersion: latestVersion,
        updateAvailable: hasUpdate,
        updateMandatory: hasUpdate && (latest?.updateMandatory ?? false),
        lastUpdateCheckAt: checkedAt,
      );
    } on NetworkException {
      return install.copyWith(lastUpdateCheckAt: checkedAt);
    } catch (_) {
      return install.copyWith(lastUpdateCheckAt: checkedAt);
    }
  }

}

String _normalizeInstallSlug(String slug) => slug.trim().toLowerCase();

class _InstallHydrationResult {
  const _InstallHydrationResult({
    required this.installs,
    required this.didMutate,
  });

  final List<DeviceInstallRecord> installs;
  final bool didMutate;
}

class HomeFolderSection {
  const HomeFolderSection({required this.folder, required this.tools});

  final ToolFolder folder;
  final List<DeviceInstallRecord> tools;
}

class HomeGroupedInstalls {
  const HomeGroupedInstalls({
    required this.pinnedTools,
    required this.folders,
    required this.unpinnedTools,
  });

  final List<DeviceInstallRecord> pinnedTools;
  final List<HomeFolderSection> folders;
  final List<DeviceInstallRecord> unpinnedTools;
}
