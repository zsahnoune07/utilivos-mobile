import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/search/recent_search_store.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/networking/network_exception.dart';
import '../../../core/networking/models/cursor_page.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_skeletons.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/tool_thumbnail.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../../installs/application/installed_tools_controller.dart';
import '../../installs/presentation/folder_detail_page.dart';
import '../../installs/data/installs_api.dart';
import '../../installs/data/models/install_models.dart';
import '../application/catalog_search_ranker.dart';
import '../data/catalog_api.dart';
import '../data/models/catalog_models.dart';

String _installErrorUserMessage(NetworkException error, CatalogPlugin plugin) {
  final m = error.message.toLowerCase();
  if (m.contains('entitlement') ||
      m.contains('pro') ||
      m.contains('premium') ||
      m.contains('subscription')) {
    if (plugin.isPro && !plugin.proPreview) {
      return 'This Pro tool requires a subscription to install.';
    }
    return 'This download needs Pro verification. Open tool details to subscribe or reconnect.';
  }
  return 'Install failed: ${error.message}';
}

Color _fallbackCategoryColor(String seed) {
  final hash = seed.toLowerCase().codeUnits.fold<int>(
    0,
    (int acc, int c) => (acc * 31 + c) & 0x7FFFFFFF,
  );
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.62, 0.56).toColor();
}

Color _categoryAccent(CatalogCategory category) {
  final raw = category.color?.trim();
  if (raw != null && raw.isNotEmpty) {
    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(withAlpha, radix: 16);
    if (parsed != null) {
      return Color(parsed);
    }
  }
  return _fallbackCategoryColor(
    category.slug.isNotEmpty ? category.slug : category.name,
  );
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    required this.config,
    required this.catalogApi,
    required this.entitlementController,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.installsApi,
    required this.installedToolsController,
    required this.proCapabilityService,
    super.key,
  });

  final AppConfig config;
  final CatalogApi catalogApi;
  final EntitlementController entitlementController;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final InstallsApi installsApi;
  final InstalledToolsController installedToolsController;
  final ProCapabilityService proCapabilityService;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

enum _PluginInstallState { idle, installing, installed }

class _DiscoverPageState extends State<DiscoverPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  AppViewState _viewState = AppViewState.loading;
  List<CatalogCategory> _categories = const <CatalogCategory>[];
  List<CatalogPlugin> _browsePlugins = const <CatalogPlugin>[];
  List<CatalogPlugin> _searchPlugins = const <CatalogPlugin>[];
  /// All search API pages merged for the active query (used with client-side ranking).
  List<CatalogPlugin> _searchApiAccumulated = const <CatalogPlugin>[];
  String? _selectedCategory;
  final Set<String> _selectedFilterTags = <String>{};
  String? _browseNextCursor;
  String? _searchNextCursor;
  String _errorMessage = 'Unable to load catalog.';
  bool _isLoadingMore = false;
  bool _searchLoading = false;
  int _searchRequestGeneration = 0;
  List<DiscoverSearchHistoryEntry> _discoverRecentHistory =
      <DiscoverSearchHistoryEntry>[];
  bool _disposed = false;
  int _queryGeneration = 0;
  bool _hasLoadedInitial = false;
  bool _didInstallDuringSession = false;
  DateTime? _lastResumeRefreshAt;
  bool _isCatalogReloading = false;

  final Map<String, _PluginInstallState> _installStates =
      <String, _PluginInstallState>{};
  final Set<String> _launchingSlugs = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.installedToolsController.bootstrap();
    _searchFocusNode.addListener(_onDiscoverSearchFocusChanged);
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onDiscoverSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      unawaited(_reloadDiscoverRecentQueries());
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _searchPlugins = const <CatalogPlugin>[];
          _searchNextCursor = null;
          _searchLoading = false;
        });
      } else {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(
          const Duration(milliseconds: 350),
          () => _reloadSearchPlugins(forceRefresh: true),
        );
      }
    } else {
      _searchDebounce?.cancel();
      setState(() {
        _searchLoading = false;
      });
    }
    setState(() {});
  }

  Future<void> _reloadDiscoverRecentQueries() async {
    final store = await RecentSearchStore.open();
    if (!mounted || _disposed) {
      return;
    }
    setState(() {
      _discoverRecentHistory = store.loadDiscoverSync();
    });
  }

  Future<void> _persistDiscoverSearchSubmission(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final store = await RecentSearchStore.open();
    await store.addDiscoverQuery(trimmed);
    await _reloadDiscoverRecentQueries();
  }

  Future<void> _persistDiscoverToolHistoryEntry({
    required String slug,
    required String name,
  }) async {
    final store = await RecentSearchStore.open();
    await store.addDiscoverTool(slug: slug, name: name);
    await _reloadDiscoverRecentQueries();
  }

  Future<void> _openDiscoverHistoryTool(
    BuildContext context,
    DiscoverSearchHistoryTool item,
  ) async {
    await _persistDiscoverToolHistoryEntry(slug: item.slug, name: item.name);
    if (!context.mounted) {
      return;
    }
    context.push(AppRoutes.discoverPluginDetail(item.slug));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedInitial) return;
    _hasLoadedInitial = true;
    try {
      final uri = GoRouterState.of(context).uri;
      _searchController.text = uri.queryParameters['search'] ?? '';
    } catch (_) {
      // No GoRouter in tree (e.g. in tests).
    }
    _loadInitial(forceRefresh: true);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchFocusNode.removeListener(_onDiscoverSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _disposed) {
      return;
    }
    final now = DateTime.now().toUtc();
    final last = _lastResumeRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 45)) {
      return;
    }
    _lastResumeRefreshAt = now;
    if (_viewState == AppViewState.content && _browsePlugins.isNotEmpty) {
      unawaited(_reloadBrowsePlugins(forceRefresh: true));
    } else {
      unawaited(_loadInitial(forceRefresh: true));
    }
  }

  _PluginInstallState _installStateFor(String slug) {
    return _installStates[slug] ?? _PluginInstallState.idle;
  }

  List<CatalogPlugin> _sourcePluginsForFilters() {
    if (_searchFocusNode.hasFocus) {
      return _searchPlugins;
    }
    return _browsePlugins;
  }

  List<CatalogPlugin> _filteredPluginsForActiveFilters() {
    final source = _sourcePluginsForFilters();
    if (_selectedFilterTags.isEmpty) {
      return source;
    }
    return source.where((CatalogPlugin plugin) {
      final lowerPricing = plugin.pricingType.toLowerCase();
      bool matches = false;
      if (_selectedFilterTags.contains('free') && lowerPricing == 'free') {
        matches = true;
      }
      if (_selectedFilterTags.contains('pro') &&
          CatalogPlugin.tierIsPro(plugin.pricingType)) {
        matches = true;
      }
      return matches;
    }).toList();
  }

  bool _isAlreadyInstalled(String slug) {
    return widget.installedToolsController.installedTools.any(
      (DeviceInstallRecord t) => t.pluginSlug == slug,
    );
  }

  DeviceInstallRecord? _installedRecordFor(String slug) {
    for (final install in widget.installedToolsController.installedTools) {
      if (install.pluginSlug == slug) {
        return install;
      }
    }
    return null;
  }

  bool _hasUpdateAvailable(String slug) {
    return widget.installedToolsController.installedTools.any(
      (DeviceInstallRecord t) => t.pluginSlug == slug && t.updateAvailable,
    );
  }

  bool _isLaunching(String slug) => _launchingSlugs.contains(slug);

  Future<void> _openInstalledTool(CatalogPlugin plugin) async {
    if (_isLaunching(plugin.slug)) {
      return;
    }
    setState(() {
      _launchingSlugs.add(plugin.slug);
    });

    try {
      final prepared =
          await widget.installedToolsController.prepareToolLaunch(plugin.slug);
      if (!mounted) {
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
          await showMandatoryUpdateRequiredDialog(context, plugin.slug);
          return;
        case ToolLaunchPrepared.ok:
          break;
      }
      await widget.installedToolsController.markToolLaunched(plugin.slug);
      unawaited(widget.proCapabilityService.recordToolEngagement(plugin.slug));
      if (!mounted) {
        return;
      }
      await context.push(
        AppRoutes.pluginRuntime(
          plugin.slug,
          toolName: plugin.name,
          restoreSession: false,
        ),
      );
    } finally {
      if (mounted && !_disposed) {
        setState(() {
          _launchingSlugs.remove(plugin.slug);
        });
      }
    }
  }

  Future<void> _installPlugin(CatalogPlugin plugin) async {
    if (_installStates[plugin.slug] == _PluginInstallState.installing) {
      return;
    }
    setState(() {
      _installStates[plugin.slug] = _PluginInstallState.installing;
    });

    try {
      String? assertionToken;
      final hasProAccess = widget.entitlementController.hasProAccess;
      if (plugin.isPro) {
        if (hasProAccess) {
          assertionToken = widget.entitlementController.activeAssertionToken;
          if (assertionToken == null || assertionToken.trim().isEmpty) {
            await widget.entitlementController.backgroundReverify(
              reason: 'install',
            );
            assertionToken = widget.entitlementController.activeAssertionToken;
          }
          if (assertionToken == null || assertionToken.trim().isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pro verification failed. Cannot install.'),
              ),
            );
            setState(() {
              _installStates[plugin.slug] = _PluginInstallState.idle;
            });
            return;
          }
        } else if (!plugin.proPreview) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This tool requires Pro to install.')),
          );
          setState(() {
            _installStates[plugin.slug] = _PluginInstallState.idle;
          });
          return;
        }
      }

      final grant = await widget.downloadApi.requestDownload(
        pluginSlug: plugin.slug,
        entitlementAssertionToken: assertionToken,
      );

      final bundle = await widget.toolBundleDownloadService.downloadBundle(
        pluginSlug: plugin.slug,
        grant: grant,
        refetchGrant: () => widget.downloadApi.requestDownload(
          pluginSlug: plugin.slug,
          entitlementAssertionToken: assertionToken,
        ),
      );

      if (!bundle.isRunnable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Install incomplete: bundle is not runnable.'),
          ),
        );
        setState(() {
          _installStates[plugin.slug] = _PluginInstallState.idle;
        });
        return;
      }

      final install = await widget.installsApi.trackInstall(
        pluginSlug: plugin.slug,
        version: grant.version,
      );
      await widget.installedToolsController.recordInstall(
        install.copyWith(
          pluginName: plugin.name,
          categoryName: bundle.category ?? plugin.categoryName,
          pluginDescription: plugin.longDescription ?? plugin.shortDescription,
          installedVersion: grant.version,
          categoryColor: plugin.categoryColor,
          iconPath: bundle.iconPath,
          cardAccentColor: bundle.iconAccentColor,
          pricingTier: _normalizeTier(plugin.pricingType),
        ),
      );

      if (!mounted) return;
      setState(() {
        _installStates[plugin.slug] = _PluginInstallState.installed;
        _didInstallDuringSession = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plugin.name} installed successfully.')),
      );
    } on NetworkException catch (error) {
      developer.log(
        'Install request failed.',
        name: 'DiscoverPage',
        error:
            'slug=${plugin.slug} status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted) return;
      setState(() {
        _installStates[plugin.slug] = _PluginInstallState.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_installErrorUserMessage(error, plugin))),
      );
    } catch (_) {
      developer.log(
        'Unexpected install error.',
        name: 'DiscoverPage',
        error: 'slug=${plugin.slug}',
      );
      if (!mounted) return;
      setState(() {
        _installStates[plugin.slug] = _PluginInstallState.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Install failed unexpectedly.')),
      );
    }
  }

  Future<void> _loadInitial({bool forceRefresh = false}) async {
    setState(() {
      _viewState = AppViewState.loading;
      _errorMessage = 'Loading catalog...';
      _browseNextCursor = null;
      _searchNextCursor = null;
    });

    final requestToken = ++_queryGeneration;

    try {
      final categoriesFuture = widget.catalogApi.listCategories(
        forceRefresh: forceRefresh,
      );
      final pluginsFuture = widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: null,
        forceRefresh: forceRefresh,
      );

      final results = await Future.wait<Object>(<Future<Object>>[
        categoriesFuture,
        pluginsFuture,
      ]);
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }

      final categories = results[0] as List<CatalogCategory>;
      final page = results[1] as CursorPage<CatalogPlugin>;
      final plugins = page.items;
      final nextCursor = page.nextCursor;

      setState(() {
        _categories = categories;
        _browsePlugins = plugins;
        _browseNextCursor = nextCursor;
        _viewState = _browsePlugins.isEmpty
            ? AppViewState.empty
            : AppViewState.content;
      });
      final pendingSearch = _searchController.text.trim();
      if (pendingSearch.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _disposed) {
            return;
          }
          _searchFocusNode.requestFocus();
          unawaited(_reloadSearchPlugins(forceRefresh: true));
        });
      }
    } on NetworkException catch (error) {
      developer.log(
        'Catalog initial load failed.',
        name: 'DiscoverPage',
        error:
            'status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      developer.log(
        'Unexpected catalog initial load error.',
        name: 'DiscoverPage',
      );
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = 'Unexpected catalog load error.';
      });
    }
  }

  Future<void> _reloadBrowsePlugins({bool forceRefresh = false}) async {
    final softReload =
        forceRefresh &&
        _viewState == AppViewState.content &&
        _browsePlugins.isNotEmpty;

    if (softReload) {
      setState(() {
        _isCatalogReloading = true;
      });
    } else {
      setState(() {
        _viewState = AppViewState.loading;
        _errorMessage = 'Loading catalog...';
        _browseNextCursor = null;
      });
    }

    final requestToken = ++_queryGeneration;

    try {
      final page = await widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: null,
        forceRefresh: forceRefresh,
      );
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }

      setState(() {
        _browsePlugins = page.items;
        _browseNextCursor = page.nextCursor;
        _viewState = _browsePlugins.isEmpty
            ? AppViewState.empty
            : AppViewState.content;
      });
    } on NetworkException catch (error) {
      developer.log(
        'Catalog reload failed.',
        name: 'DiscoverPage',
        error:
            'status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }
      if (softReload) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh: ${error.message}')),
        );
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      developer.log('Unexpected catalog reload error.', name: 'DiscoverPage');
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }
      if (softReload) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh catalog.')),
        );
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = 'Unexpected catalog load error.';
      });
    } finally {
      if (softReload && mounted && !_disposed) {
        setState(() {
          _isCatalogReloading = false;
        });
      }
    }
  }

  Future<void> _reloadSearchPlugins({bool forceRefresh = false}) async {
    if (!_searchFocusNode.hasFocus) {
      return;
    }
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        _searchPlugins = const <CatalogPlugin>[];
        _searchApiAccumulated = const <CatalogPlugin>[];
        _searchNextCursor = null;
        _searchLoading = false;
      });
      return;
    }

    final requestToken = ++_searchRequestGeneration;
    setState(() {
      _searchLoading = true;
    });

    try {
      final page = await widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: q,
        forceRefresh: forceRefresh,
      );
      if (!mounted || _disposed || requestToken != _searchRequestGeneration) {
        return;
      }
      final cacheUnion = await widget.catalogApi.collectCachedPluginsUnion();
      if (!mounted || _disposed || requestToken != _searchRequestGeneration) {
        return;
      }
      final ranked = buildDiscoverSearchResults(
        query: q,
        apiAccumulatedPageItems: page.items,
        cacheUnion: cacheUnion,
      );
      if (!mounted || _disposed || requestToken != _searchRequestGeneration) {
        return;
      }
      setState(() {
        _searchApiAccumulated = List<CatalogPlugin>.from(page.items);
        _searchPlugins = ranked;
        _searchNextCursor = page.nextCursor;
        _searchLoading = false;
      });
    } on NetworkException catch (error) {
      if (!mounted || _disposed || requestToken != _searchRequestGeneration) {
        return;
      }
      setState(() {
        _searchLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: ${error.message}')),
      );
    } catch (_) {
      if (!mounted || _disposed || requestToken != _searchRequestGeneration) {
        return;
      }
      setState(() {
        _searchLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed unexpectedly.')),
      );
    }
  }

  Future<void> _loadMore() async {
    final isSearch =
        _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;
    final nextCursor = isSearch ? _searchNextCursor : _browseNextCursor;
    if (_isLoadingMore || nextCursor == null || nextCursor.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: isSearch ? _searchController.text.trim() : null,
        cursor: nextCursor,
      );
      if (!mounted || _disposed) {
        return;
      }
      if (isSearch) {
        final q = _searchController.text.trim();
        final nextAccumulated = <CatalogPlugin>[
          ..._searchApiAccumulated,
          ...page.items,
        ];
        final cacheUnion = await widget.catalogApi.collectCachedPluginsUnion();
        if (!mounted || _disposed) {
          return;
        }
        final ranked = buildDiscoverSearchResults(
          query: q,
          apiAccumulatedPageItems: nextAccumulated,
          cacheUnion: cacheUnion,
        );
        if (!mounted || _disposed) {
          return;
        }
        setState(() {
          _searchApiAccumulated = nextAccumulated;
          _searchPlugins = ranked;
          _searchNextCursor = page.nextCursor;
        });
      } else {
        setState(() {
          _browsePlugins = <CatalogPlugin>[..._browsePlugins, ...page.items];
          _browseNextCursor = page.nextCursor;
        });
      }
    } on NetworkException catch (error) {
      developer.log(
        'Catalog load more failed.',
        name: 'DiscoverPage',
        error:
            'status=${error.statusCode} code=${error.code} kind=${error.kind}',
      );
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load more failed: ${error.message}')),
      );
    } catch (_) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _errorMessage = 'Unexpected load-more error.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load more failed unexpectedly.')),
      );
    } finally {
      if (mounted && !_disposed) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();
    unawaited(_persistDiscoverSearchSubmission(value));
    if (_searchFocusNode.hasFocus) {
      unawaited(_reloadSearchPlugins(forceRefresh: true));
    } else {
      unawaited(_reloadBrowsePlugins(forceRefresh: true));
    }
  }

  void _onSearchChanged(String _) {
    if (!_searchFocusNode.hasFocus) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _reloadSearchPlugins(forceRefresh: true),
    );
  }

  void _onCategorySelected(String? slug) {
    setState(() {
      _selectedCategory = slug;
    });
    unawaited(_reloadBrowsePlugins(forceRefresh: true));
    if (_searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty) {
      unawaited(_reloadSearchPlugins(forceRefresh: true));
    }
  }

  void _toggleFilterTag(String tag) {
    setState(() {
      if (_selectedFilterTags.contains(tag)) {
        _selectedFilterTags.remove(tag);
      } else {
        _selectedFilterTags.add(tag);
      }
    });
  }

  void _goBack(BuildContext context) {
    final didInstall = _didInstallDuringSession;
    if (GoRouter.of(context).canPop()) {
      context.pop<bool>(didInstall);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goBack(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Tool Library',
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
            widget.installedToolsController,
            widget.proCapabilityService,
            _searchFocusNode,
          ]),
          builder: (BuildContext context, Widget? child) {
            final hasProAccess = widget.entitlementController.hasProAccess;

            return RefreshIndicator(
              onRefresh: () => _loadInitial(forceRefresh: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _DiscoverHeader(
                        categories: _categories,
                        selectedCategory: _selectedCategory,
                        selectedFilterTags: _selectedFilterTags,
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        iconBaseUrl: widget.config.apiBaseUrl,
                        onCategorySelected: _onCategorySelected,
                        onSearchChanged: _onSearchChanged,
                        onSearchSubmitted: _onSearchSubmitted,
                        onClearSearch: () {
                          _searchController.clear();
                          unawaited(_reloadBrowsePlugins(forceRefresh: true));
                          if (_searchFocusNode.hasFocus) {
                            unawaited(_reloadSearchPlugins(forceRefresh: true));
                          }
                        },
                        onToggleFilterTag: _toggleFilterTag,
                      ),
                    ),
                  ),
                  if (_isCatalogReloading ||
                      widget.installedToolsController.isSyncing) ...<Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              _isCatalogReloading
                                  ? 'Updating catalog...'
                                  : 'Updating tools...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ..._buildCatalogSlivers(context, hasProAccess),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: <Widget>[
                          AppSecondaryButton(
                            label: 'Open Debug Console',
                            onPressed: () =>
                                context.push(AppRoutes.discoverDebug),
                            expand: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'API base URL: ${widget.config.apiBaseUrl}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCatalogSlivers(BuildContext context, bool hasProAccess) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    if (_viewState == AppViewState.loading) {
      return <Widget>[
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: AppCardSkeletonList(items: 6, lines: 2),
          ),
        ),
      ];
    }
    if (_viewState == AppViewState.error) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            title: 'Failed to load discover content',
            message: _errorMessage,
            onRetry: _loadInitial,
          ),
        ),
      ];
    }

    if (_searchFocusNode.hasFocus) {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        return _buildDiscoverSearchIdleSlivers(context, l10n);
      }
      if (_searchLoading && _searchPlugins.isEmpty) {
        return <Widget>[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: AppCardSkeletonList(items: 4, lines: 2),
            ),
          ),
        ];
      }
      final filtered = _filteredPluginsForActiveFilters();
      if (filtered.isEmpty) {
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyView(
              title: l10n.catalogSearchEmptyTitle,
              message: l10n.catalogSearchEmptyMessage,
            ),
          ),
        ];
      }
      return _buildPluginListSlivers(
        context,
        hasProAccess,
        filtered,
        _searchNextCursor,
        true,
      );
    }

    if (_browsePlugins.isEmpty) {
      return <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyView(
            title: 'No tools found',
            message: 'Try a different category or search term to find tools.',
          ),
        ),
      ];
    }

    final filteredBrowse = _filteredPluginsForActiveFilters();
    return _buildPluginListSlivers(
      context,
      hasProAccess,
      filteredBrowse,
      _browseNextCursor,
      false,
    );
  }

  List<Widget> _buildDiscoverSearchIdleSlivers(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(Icons.search_rounded, size: 44, color: colorScheme.outline),
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
              if (_discoverRecentHistory.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.recentSearchesSection,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final store = await RecentSearchStore.open();
                        await store.clearDiscover();
                        await _reloadDiscoverRecentQueries();
                      },
                      child: Text(l10n.clearSearchHistory),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ..._discoverRecentHistory.map((
                  DiscoverSearchHistoryEntry item,
                ) {
                  if (item is DiscoverSearchHistoryQuery) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.history,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      title: Text(item.text),
                      onTap: () {
                        _searchController.text = item.text;
                        _searchController.selection = TextSelection.collapsed(
                          offset: item.text.length,
                        );
                        unawaited(_persistDiscoverSearchSubmission(item.text));
                        unawaited(_reloadSearchPlugins(forceRefresh: true));
                      },
                    );
                  }
                  final tool = item as DiscoverSearchHistoryTool;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ToolThumbnail(
                      imageUrl:
                          '/v1/plugins/${Uri.encodeComponent(tool.slug)}/icon',
                      baseUrl: widget.config.apiBaseUrl,
                      size: 40,
                      borderRadius: 10,
                      fallbackIcon: Icons.extension_outlined,
                    ),
                    title: Text(tool.name),
                    onTap: () {
                      unawaited(_openDiscoverHistoryTool(context, tool));
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildPluginListSlivers(
    BuildContext context,
    bool hasProAccess,
    List<CatalogPlugin> filteredPlugins,
    String? nextCursor,
    bool isSearchResults,
  ) {
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: filteredPlugins.length,
          itemBuilder: (BuildContext context, int index) {
            final plugin = filteredPlugins[index];
            final installedRecord = _installedRecordFor(plugin.slug);
            final isInstalled = _isAlreadyInstalled(plugin.slug);
            final hasUpdate = _hasUpdateAvailable(plugin.slug);
            final installState = _installStateFor(plugin.slug);
            final isLaunching = _isLaunching(plugin.slug);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == filteredPlugins.length - 1 ? 0 : 10,
              ),
              child: RepaintBoundary(
                child: _PluginListTile(
                  plugin: plugin,
                  hasProAccess: hasProAccess,
                  isInstalled: isInstalled,
                  hasUpdate: hasUpdate,
                  isLaunching: isLaunching,
                  installState: installState,
                  localIconPath: installedRecord?.iconPath,
                  iconBaseUrl: widget.config.apiBaseUrl,
                  onOpen: () {
                    if (isSearchResults) {
                      unawaited(
                        _persistDiscoverToolHistoryEntry(
                          slug: plugin.slug,
                          name: plugin.name,
                        ),
                      );
                    }
                    context.push(AppRoutes.discoverPluginDetail(plugin.slug));
                  },
                  onInstall: () => _installPlugin(plugin),
                  onRun: () {
                    if (isSearchResults) {
                      unawaited(
                        _persistDiscoverToolHistoryEntry(
                          slug: plugin.slug,
                          name: plugin.name,
                        ),
                      );
                    }
                    unawaited(_openInstalledTool(plugin));
                  },
                ),
              ),
            );
          },
        ),
      ),
      if (nextCursor != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: AppPrimaryButton(
              label: AppLocalizations.of(context)!.loadMore,
              onPressed: _isLoadingMore ? null : _loadMore,
              isLoading: _isLoadingMore,
              expand: true,
            ),
          ),
        ),
    ];
  }
}

String _normalizeTier(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'free') {
    return 'free';
  }
  if (CatalogPlugin.tierIsPro(raw)) {
    return 'pro';
  }
  return 'free';
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.categories,
    required this.selectedCategory,
    required this.selectedFilterTags,
    required this.searchController,
    required this.searchFocusNode,
    required this.iconBaseUrl,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onToggleFilterTag,
  });

  final List<CatalogCategory> categories;
  final String? selectedCategory;
  final Set<String> selectedFilterTags;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String? iconBaseUrl;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onToggleFilterTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // const SizedBox(height: 8),
        // const Text('Browse categories and install tools.'),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          focusNode: searchFocusNode,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search tools',

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),

            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _DiscoverFilterRow(
          categories: categories,
          selectedCategory: selectedCategory,
          selectedFilterTags: selectedFilterTags,
          iconBaseUrl: iconBaseUrl,
          onCategorySelected: onCategorySelected,
          onToggleFilterTag: onToggleFilterTag,
        ),
      ],
    );
  }
}

class _DiscoverFilterRow extends StatelessWidget {
  const _DiscoverFilterRow({
    required this.categories,
    required this.selectedCategory,
    required this.selectedFilterTags,
    required this.iconBaseUrl,
    required this.onCategorySelected,
    required this.onToggleFilterTag,
  });

  final List<CatalogCategory> categories;
  final String? selectedCategory;
  final Set<String> selectedFilterTags;
  final String? iconBaseUrl;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onToggleFilterTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _DiscoverFilterPill(
                label: 'Free',
                isSelected: selectedFilterTags.contains('free'),
                onTap: () => onToggleFilterTag('free'),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _DiscoverFilterPill(
                label: 'Pro',
                isSelected: selectedFilterTags.contains('pro'),
                onTap: () => onToggleFilterTag('pro'),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _DiscoverFilterPill(
                label: 'All',
                isSelected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
                colorScheme: colorScheme,
              ),
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _DiscoverFilterPill(
                    label: category.name,
                    isSelected: category.slug == selectedCategory,
                    onTap: () => onCategorySelected(category.slug),
                    colorScheme: colorScheme,
                    accentColor: _categoryAccent(category),
                    categoryIconUrl: category.icon?.trim(),
                    iconBaseUrl: iconBaseUrl,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverFilterPill extends StatelessWidget {
  const _DiscoverFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    this.accentColor,
    this.categoryIconUrl,
    this.iconBaseUrl,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final Color? accentColor;
  final String? categoryIconUrl;
  final String? iconBaseUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor;
    final Color backgroundColor;
    final Color borderColor;
    final Color textColor;

    if (accent != null) {
      backgroundColor = accent.withValues(
        alpha: isSelected ? (isDark ? 0.28 : 0.18) : (isDark ? 0.16 : 0.10),
      );
      borderColor = accent.withValues(alpha: isSelected ? 0.95 : 0.42);
      textColor = accent;
    } else {
      backgroundColor = isSelected
          ? (isDark
                ? colorScheme.primary.withValues(alpha: 0.22)
                : const Color(0xFFF3E8FD).withValues(alpha: 0.72))
          : (isDark
                ? colorScheme.surface.withValues(alpha: 0.45)
                : const Color(0xFFF1F5F9).withValues(alpha: 0.62));
      borderColor = isSelected
          ? (isDark ? colorScheme.primary : const Color(0xFF7C3AED))
          : (isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0));
      textColor = isSelected
          ? (isDark ? colorScheme.onPrimary : const Color(0xFF6D28D9))
          : colorScheme.onSurfaceVariant;
    }

    final iconRef = categoryIconUrl;
    final showCategoryIcon = iconRef != null && iconRef.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showCategoryIcon) ...<Widget>[
              ToolThumbnail(
                imageUrl: iconRef,
                baseUrl: iconBaseUrl,
                size: 20,
                borderRadius: 6,
                fallbackIcon: Icons.category_outlined,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginListTile extends StatelessWidget {
  const _PluginListTile({
    required this.plugin,
    required this.hasProAccess,
    required this.isInstalled,
    required this.hasUpdate,
    required this.isLaunching,
    required this.installState,
    required this.onOpen,
    required this.onInstall,
    required this.onRun,
    this.localIconPath,
    this.iconBaseUrl,
  });

  final CatalogPlugin plugin;
  final bool hasProAccess;
  final bool isInstalled;
  final bool hasUpdate;
  final bool isLaunching;
  final _PluginInstallState installState;
  final VoidCallback onOpen;
  final VoidCallback onInstall;
  final VoidCallback onRun;
  final String? localIconPath;
  final String? iconBaseUrl;

  static String _formatTier(String pricingType) {
    if (pricingType.trim().toLowerCase() == 'free') {
      return 'Free';
    }
    if (CatalogPlugin.tierIsPro(pricingType)) {
      return 'Pro';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconFrameColor = colorScheme.surfaceContainerHigh;
    final iconRef = plugin.catalogListIconRef.trim();
    final localRef = localIconPath?.trim();
    final hasCustomIcon =
        iconRef.isNotEmpty || (localRef != null && localRef.isNotEmpty);
    final isLocked = plugin.isPro && !hasProAccess && !plugin.proPreview;
    final alreadyInstalled =
        (isInstalled || installState == _PluginInstallState.installed) &&
        !hasUpdate;
    final isInstalling = installState == _PluginInstallState.installing;
    final tier = _formatTier(plugin.pricingType);
    final meta = <String>[
      if (plugin.categoryName.isNotEmpty) plugin.categoryName,
      if (tier.isNotEmpty) tier,
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconFrameColor,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: hasCustomIcon
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ToolThumbnail(
                        imageUrl: plugin.catalogListIconRef,
                        localPath: localIconPath,
                        baseUrl: iconBaseUrl,
                        fallbackIcon: Icons.extension,
                        size: 52,
                        borderRadius: 12,
                        transparentFallback: true,
                      ),
                    )
                  : Icon(Icons.extension, color: colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          plugin.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (plugin.isPro) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 17,
                          semanticLabel: 'Pro tool',
                          color: colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                  if (meta.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    plugin.shortDescription ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _InstallActionButton(
              isInstalled: alreadyInstalled,
              isInstalling: isInstalling,
              isLaunching: isLaunching,
              isLocked: isLocked,
              hasUpdate: hasUpdate,
              onInstall: onInstall,
              onRun: onRun,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallActionButton extends StatelessWidget {
  const _InstallActionButton({
    required this.isInstalled,
    required this.isInstalling,
    required this.isLaunching,
    required this.isLocked,
    required this.hasUpdate,
    required this.onInstall,
    required this.onRun,
  });

  final bool isInstalled;
  final bool isInstalling;
  final bool isLaunching;
  final bool isLocked;
  final bool hasUpdate;
  final VoidCallback onInstall;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isInstalling) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Tooltip(
          message: 'Installing',
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (hasUpdate) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Tooltip(
          message: 'Update',
          child: FilledButton(
            onPressed: onInstall,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Icon(
              Icons.system_update_alt,
              size: 20,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
      );
    }

    if (isInstalled) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Tooltip(
          message: 'Run',
          child: FilledButton(
            onPressed: isLaunching ? null : onRun,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLaunching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
          ),
        ),
      );
    }

    return SizedBox(
      width: 42,
      height: 42,
      child: Tooltip(
        message: isLocked ? 'Pro required — open tool for details' : 'Install',
        child: OutlinedButton(
          onPressed: isLocked ? null : onInstall,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
              alpha: 0.38,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.download_rounded,
            size: 20,
            color: isLocked ? null : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
