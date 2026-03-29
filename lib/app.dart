import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/bootstrap/app_bootstrap_controller.dart';
import 'core/di/app_dependencies.dart';
import 'core/persistence/app_database.dart';
import 'core/riverpod/app_providers.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_routes.dart';
import 'core/navigation/deep_link_parser.dart';
import 'core/pro/free_tier_usage_store.dart';
import 'core/theme/app_theme.dart';
import 'features/installs/data/models/install_models.dart';

class UtilivoApp extends StatefulWidget {
  const UtilivoApp({
    super.key,
    this.dependencies,
    this.freeTierUsageStore,
    this.appDatabase,
    this.initialLocation,
    this.initialDeepLinkRoute,
  }) : assert(
         dependencies != null ||
             (freeTierUsageStore != null && appDatabase != null),
         'Provide dependencies or (freeTierUsageStore and appDatabase)',
       );

  final AppDependencies? dependencies;
  final FreeTierUsageStore? freeTierUsageStore;

  /// Drift database for catalog, installs, and sync metadata (required with [freeTierUsageStore]).
  final AppDatabase? appDatabase;

  final String? initialLocation;
  final String? initialDeepLinkRoute;

  @override
  State<UtilivoApp> createState() => _UtilivoAppState();
}

class _UtilivoAppState extends State<UtilivoApp> {
  late final AppDependencies _dependencies =
      widget.dependencies ??
      AppDependencies.create(
        freeTierUsageStore: widget.freeTierUsageStore!,
        appDatabase: widget.appDatabase,
      );
  late final bool _ownsDependencies = widget.dependencies == null;
  late final AppBootstrapController _bootstrapController =
      AppBootstrapController(
        deviceIdentityManager: _dependencies.deviceIdentityManager,
        entitlementController: _dependencies.entitlementController,
      );
  late final GoRouter _router = createAppRouter(
    dependencies: _dependencies,
    bootstrapController: _bootstrapController,
    initialLocation: _resolveInitialRouterLocation(),
  );

  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription<Uri?>? _homeWidgetUriSubscription;
  DateTime? _lastResumeSyncAt;

  String _resolveInitialRouterLocation() {
    if (widget.initialLocation != null) {
      return widget.initialLocation!;
    }
    final deep = widget.initialDeepLinkRoute?.trim();
    if (deep != null && deep.isNotEmpty) {
      return '${AppRoutes.splash}?from=${Uri.encodeComponent(deep)}';
    }
    return AppRoutes.splash;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    unawaited(_bootstrapController.bootstrap());
    unawaited(_dependencies.proPurchaseController.initialize());
    unawaited(_dependencies.installedToolsController.bootstrap());
    unawaited(_seedLocalToolBundleIfConfigured());
    _listenAppLinks();
    _listenHomeWidgetLaunches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeInitialHomeWidgetLaunch());
    });
  }

  void _listenAppLinks() {
    try {
      final appLinks = AppLinks();
      _appLinkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
        final loc = parseAppDeepLink(uri);
        if (loc != null && mounted) {
          _router.go(loc);
        }
      });
    } catch (error) {
      debugPrint('App links stream unavailable: $error');
    }
  }

  void _listenHomeWidgetLaunches() {
    try {
      _homeWidgetUriSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri == null || !mounted) {
          return;
        }
        final String? loc = parseAppDeepLink(uri);
        if (loc != null) {
          _router.go(loc);
        }
      });
    } catch (error) {
      debugPrint('Home widget link stream unavailable: $error');
    }
  }

  Future<void> _consumeInitialHomeWidgetLaunch() async {
    try {
      final Uri? uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (!mounted || uri == null) {
        return;
      }
      final String? loc = parseAppDeepLink(uri);
      if (loc != null) {
        _router.go(loc);
      }
    } catch (error) {
      debugPrint('Home widget initial launch check failed: $error');
    }
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _UtilivoLifecycleObserver(onResumed: _onAppResumed);

  void _onAppResumed() {
    _dependencies.entitlementController.onAppResumed();
    final now = DateTime.now().toUtc();
    final lastSyncAt = _lastResumeSyncAt;
    if (lastSyncAt != null &&
        now.difference(lastSyncAt) < const Duration(seconds: 45)) {
      return;
    }
    _lastResumeSyncAt = now;
    unawaited(
      _dependencies.installedToolsController.syncFromRepository(
        trigger: 'resume',
      ),
    );
  }

  Future<void> _seedLocalToolBundleIfConfigured() async {
    final localBundlePath = _dependencies.config.localToolBundlePath;
    if (localBundlePath == null) {
      return;
    }

    try {
      final imported = await _dependencies.toolBundleDownloadService
          .importBundleFromFile(
            localArchivePath: localBundlePath,
            pluginSlug: _dependencies.config.localToolBundleSlug,
            version: _dependencies.config.localToolBundleVersion,
          );
      final installedVersion =
          imported.manifestVersion?.trim().isNotEmpty == true
          ? imported.manifestVersion!.trim()
          : imported.version;
      final deviceId = await _dependencies.deviceIdentityManager
          .ensureDeviceId();
      await _dependencies.installedToolsController.recordInstall(
        DeviceInstallRecord(
          id: 'local-${imported.pluginSlug}-$installedVersion',
          deviceId: deviceId,
          pluginId: 'local.${imported.pluginSlug}',
          pluginSlug: imported.pluginSlug,
          source: 'local_bundle_seed',
          installedAt: DateTime.now().toUtc(),
          installedVersionId: installedVersion,
          installedVersion: installedVersion,
          latestAvailableVersion: installedVersion,
          updateAvailable: false,
          lastUpdateCheckAt: DateTime.now().toUtc(),
          pluginName: imported.pluginName,
          categoryName: imported.category,
          iconPath: imported.iconPath,
          cardAccentColor: imported.iconAccentColor,
          pricingTier: imported.verifiedTier,
          pluginDescription: null,
        ),
      );
    } catch (error) {
      debugPrint('Local bundle seed skipped: $error');
    }
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    _homeWidgetUriSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _router.dispose();
    _bootstrapController.dispose();
    if (_ownsDependencies) {
      _dependencies.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget app = MaterialApp.router(
      title: _dependencies.config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en')],
    );
    return ProviderScope(
      overrides: <Override>[
        appDependenciesProvider.overrideWithValue(_dependencies),
      ],
      child: app,
    );
  }
}

class _UtilivoLifecycleObserver extends WidgetsBindingObserver {
  _UtilivoLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
