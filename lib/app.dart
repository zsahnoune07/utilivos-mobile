import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/bootstrap/app_bootstrap_controller.dart';
import 'core/di/app_dependencies.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/installs/data/models/install_models.dart';

class UtilivoApp extends StatefulWidget {
  const UtilivoApp({super.key, this.dependencies, this.initialLocation});

  final AppDependencies? dependencies;
  final String? initialLocation;

  @override
  State<UtilivoApp> createState() => _UtilivoAppState();
}

class _UtilivoAppState extends State<UtilivoApp> {
  late final AppDependencies _dependencies =
      widget.dependencies ?? AppDependencies.create();
  late final bool _ownsDependencies = widget.dependencies == null;
  late final AppBootstrapController _bootstrapController =
      AppBootstrapController(
        deviceIdentityManager: _dependencies.deviceIdentityManager,
        entitlementController: _dependencies.entitlementController,
      );
  late final GoRouter _router = createAppRouter(
    dependencies: _dependencies,
    bootstrapController: _bootstrapController,
    initialLocation: widget.initialLocation ?? '/splash',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    unawaited(_bootstrapController.bootstrap());
    unawaited(_dependencies.premiumPurchaseController.initialize());
    unawaited(_seedLocalToolBundleIfConfigured());
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _UtilivoLifecycleObserver(
        onResumed: () => _dependencies.entitlementController.onAppResumed(),
      );

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
    return MaterialApp.router(
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
