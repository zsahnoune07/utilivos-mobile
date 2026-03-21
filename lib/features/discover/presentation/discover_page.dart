import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/networking/network_exception.dart';
import '../../../core/networking/models/cursor_page.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_skeletons.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/tool_thumbnail.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../../installs/application/installed_tools_controller.dart';
import '../../installs/data/installs_api.dart';
import '../../installs/data/models/install_models.dart';
import '../data/catalog_api.dart';
import '../data/models/catalog_models.dart';

String _installErrorUserMessage(NetworkException error, CatalogPlugin plugin) {
  final m = error.message.toLowerCase();
  if (m.contains('entitlement') ||
      m.contains('pro') ||
      m.contains('subscription') ||
      m.contains('pro')) {
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

class _DiscoverPageState extends State<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  AppViewState _viewState = AppViewState.loading;
  List<CatalogCategory> _categories = const <CatalogCategory>[];
  List<CatalogPlugin> _plugins = const <CatalogPlugin>[];
  String? _selectedCategory;
  final Set<String> _selectedFilterTags = <String>{};
  String? _nextCursor;
  String _errorMessage = 'Unable to load catalog.';
  bool _isLoadingMore = false;
  bool _disposed = false;
  int _queryGeneration = 0;
  bool _hasLoadedInitial = false;
  bool _didInstallDuringSession = false;

  final Map<String, _PluginInstallState> _installStates =
      <String, _PluginInstallState>{};
  final Set<String> _launchingSlugs = <String>{};

  @override
  void initState() {
    super.initState();
    widget.installedToolsController.bootstrap();
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
    _loadInitial();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  _PluginInstallState _installStateFor(String slug) {
    return _installStates[slug] ?? _PluginInstallState.idle;
  }

  List<CatalogPlugin> _filteredPluginsForActiveFilters() {
    if (_selectedFilterTags.isEmpty) {
      return _plugins;
    }
    return _plugins.where((CatalogPlugin plugin) {
      final lowerPricing = plugin.pricingType.toLowerCase();
      bool matches = false;
      if (_selectedFilterTags.contains('free') && lowerPricing == 'free') {
        matches = true;
      }
      if (_selectedFilterTags.contains('pro') &&
          (lowerPricing == 'pro' || lowerPricing == 'paid')) {
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
      await widget.installedToolsController.markToolLaunched(plugin.slug);
      unawaited(
        widget.proCapabilityService.recordToolEngagement(plugin.slug),
      );
      if (!mounted) {
        return;
      }
      final restore = widget.proCapabilityService.canRestoreSession;
      await context.push(
        AppRoutes.pluginRuntime(
          plugin.slug,
          toolName: plugin.name,
          restoreSession: restore,
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

  Future<void> _loadInitial() async {
    setState(() {
      _viewState = AppViewState.loading;
      _errorMessage = 'Loading catalog...';
      _nextCursor = null;
    });

    final requestToken = ++_queryGeneration;

    try {
      final categoriesFuture = widget.catalogApi.listCategories();
      final pluginsFuture = widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: _searchController.text.trim(),
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
        _plugins = plugins;
        _nextCursor = nextCursor;
        _viewState = _plugins.isEmpty
            ? AppViewState.empty
            : AppViewState.content;
      });
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

  Future<void> _reloadPlugins() async {
    setState(() {
      _viewState = AppViewState.loading;
      _errorMessage = 'Loading catalog...';
      _nextCursor = null;
    });

    final requestToken = ++_queryGeneration;

    try {
      final page = await widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: _searchController.text.trim(),
      );
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }

      setState(() {
        _plugins = page.items;
        _nextCursor = page.nextCursor;
        _viewState = _plugins.isEmpty
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
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      developer.log('Unexpected catalog reload error.', name: 'DiscoverPage');
      if (!mounted || _disposed || requestToken != _queryGeneration) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = 'Unexpected catalog load error.';
      });
    }
  }

  Future<void> _loadMore() async {
    final nextCursor = _nextCursor;
    if (_isLoadingMore || nextCursor == null || nextCursor.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await widget.catalogApi.listPlugins(
        category: _selectedCategory,
        search: _searchController.text.trim(),
        cursor: nextCursor,
      );
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _plugins = <CatalogPlugin>[..._plugins, ...page.items];
        _nextCursor = page.nextCursor;
      });
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

  void _onSearchSubmitted(String _) {
    _searchDebounce?.cancel();
    _reloadPlugins();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reloadPlugins);
  }

  void _onCategorySelected(String? slug) {
    setState(() {
      _selectedCategory = slug;
    });
    _reloadPlugins();
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
        ]),
          builder: (BuildContext context, Widget? child) {
            final hasProAccess =
                widget.entitlementController.hasProAccess;

            return CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _DiscoverHeader(
                      categories: _categories,
                      selectedCategory: _selectedCategory,
                      selectedFilterTags: _selectedFilterTags,
                      searchController: _searchController,
                      onCategorySelected: _onCategorySelected,
                      onSearchChanged: _onSearchChanged,
                      onSearchSubmitted: _onSearchSubmitted,
                      onClearSearch: () {
                        _searchController.clear();
                        _reloadPlugins();
                      },
                      onToggleFilterTag: _toggleFilterTag,
                    ),
                  ),
                ),
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
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCatalogSlivers(
    BuildContext context,
    bool hasProAccess,
  ) {
    final filteredPlugins = _viewState == AppViewState.content
        ? _filteredPluginsForActiveFilters()
        : const <CatalogPlugin>[];
    return switch (_viewState) {
      AppViewState.loading => <Widget>[
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: AppCardSkeletonList(items: 6, lines: 2),
          ),
        ),
      ],
      AppViewState.empty => <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyView(
            title: 'No tools found',
            message: 'Try a different category or search term to find tools.',
          ),
        ),
      ],
      AppViewState.error => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorView(
            title: 'Failed to load discover content',
            message: _errorMessage,
            onRetry: _loadInitial,
          ),
        ),
      ],
      AppViewState.content => <Widget>[
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
                    onOpen: () => context.push(
                      AppRoutes.discoverPluginDetail(plugin.slug),
                    ),
                    onInstall: () => _installPlugin(plugin),
                    onRun: () => _openInstalledTool(plugin),
                  ),
                ),
              );
            },
          ),
        ),
        if (_nextCursor != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: AppPrimaryButton(
                label: 'Load More',
                onPressed: _isLoadingMore ? null : _loadMore,
                isLoading: _isLoadingMore,
                expand: true,
              ),
            ),
          ),
      ],
    };
  }
}

String _normalizeTier(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'free') {
    return 'free';
  }
  return 'pro';
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.categories,
    required this.selectedCategory,
    required this.selectedFilterTags,
    required this.searchController,
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
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
    required this.onCategorySelected,
    required this.onToggleFilterTag,
  });

  final List<CatalogCategory> categories;
  final String? selectedCategory;
  final Set<String> selectedFilterTags;
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
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final Color? accentColor;

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
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
    final normalized = pricingType.trim().toLowerCase();
    if (normalized == 'free') {
      return 'Free';
    }
    if (normalized == 'pro' || normalized == 'paid') {
      return 'Pro';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLocked =
        plugin.isPro && !hasProAccess && !plugin.proPreview;
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
            ToolThumbnail(
              imageUrl: plugin.thumbnailUrl,
              localPath: localIconPath,
              baseUrl: iconBaseUrl,
              fallbackIcon: Icons.extension,
              size: 52,
              borderRadius: 12,
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
        message: isLocked
            ? 'Pro required — open tool for details'
            : 'Install',
        child: OutlinedButton(
          onPressed: isLocked ? null : onInstall,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            disabledForegroundColor:
                colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
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
