import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/plugin_detail_page.dart';
import '../../features/discover/presentation/discover_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/installs/presentation/installs_page.dart';
import '../../features/installs/presentation/folder_detail_page.dart';
import '../../features/runtime/presentation/plugin_runtime_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../bootstrap/app_bootstrap_controller.dart';
import '../di/app_dependencies.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required AppDependencies dependencies,
  required AppBootstrapController bootstrapController,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: bootstrapController,
    redirect: (BuildContext context, GoRouterState state) {
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isInitializing = bootstrapController.isInitializing;
      final hasBootstrapFailed = bootstrapController.hasFailed;
      final requestedLocation = state.uri.toString();
      final fromLocation = _normalizeGuardRedirectTarget(
        state.uri.queryParameters['from'],
      );

      if (isInitializing) {
        if (isSplash) {
          return null;
        }
        return Uri(
          path: AppRoutes.splash,
          queryParameters: <String, String>{'from': requestedLocation},
        ).toString();
      }

      if (hasBootstrapFailed) {
        if (isSplash) {
          return null;
        }
        return AppRoutes.splash;
      }

      if (isSplash) {
        final targetAfterSplash = fromLocation ?? AppRoutes.home;
        return targetAfterSplash;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) {
          return SplashPage(bootstrapController: bootstrapController);
        },
      ),
      GoRoute(
        path: '${AppRoutes.pluginRuntimePrefix}/:slug',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final slug = state.pathParameters['slug'] ?? '';
          final initialToolName = state.uri.queryParameters['name'];
          final restoreSession =
              state.uri.queryParameters['restore'] == '1';
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            child: PluginRuntimePage(
              pluginSlug: slug,
              initialToolName: initialToolName,
              restoreSessionRequested: restoreSession,
              catalogApi: dependencies.catalogApi,
              downloadApi: dependencies.downloadApi,
              toolBundleDownloadService: dependencies.toolBundleDownloadService,
              entitlementController: dependencies.entitlementController,
              premiumCapabilityService: dependencies.premiumCapabilityService,
              paywallCoordinator: dependencies.paywallCoordinator,
              toolSessionStore: dependencies.toolSessionStore,
              premiumAnalytics: dependencies.premiumAnalytics,
            ),
            transitionsBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                  Widget child,
                ) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.92,
                        end: 1.0,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          );
        },
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          final isHome =
              state.matchedLocation == AppRoutes.home ||
              state.matchedLocation == AppRoutes.installs;
          final canPop = GoRouter.of(context).canPop();
          return PopScope(
            canPop: isHome || canPop,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (!didPop) {
                context.go(AppRoutes.home);
              }
            },
            child: child,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) {
              return InstallsPage(
                appName: dependencies.config.appName,
                installedToolsController: dependencies.installedToolsController,
                downloadApi: dependencies.downloadApi,
                toolBundleDownloadService:
                    dependencies.toolBundleDownloadService,
                installsApi: dependencies.installsApi,
                entitlementController: dependencies.entitlementController,
                premiumCapabilityService: dependencies.premiumCapabilityService,
                paywallCoordinator: dependencies.paywallCoordinator,
                premiumAnalytics: dependencies.premiumAnalytics,
              );
            },
          ),
          GoRoute(
            path: '${AppRoutes.folderDetailPrefix}/:folderId',
            builder: (BuildContext context, GoRouterState state) {
              final folderId = state.pathParameters['folderId'] ?? '';
              return FolderDetailPage(
                folderId: folderId,
                controller: dependencies.installedToolsController,
                premiumCapabilityService: dependencies.premiumCapabilityService,
                paywallCoordinator: dependencies.paywallCoordinator,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.installs,
            redirect: (BuildContext context, GoRouterState state) {
              return AppRoutes.home;
            },
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (BuildContext context, GoRouterState state) {
              return DiscoverPage(
                config: dependencies.config,
                catalogApi: dependencies.catalogApi,
                entitlementController: dependencies.entitlementController,
                downloadApi: dependencies.downloadApi,
                toolBundleDownloadService:
                    dependencies.toolBundleDownloadService,
                installsApi: dependencies.installsApi,
                installedToolsController: dependencies.installedToolsController,
                premiumCapabilityService: dependencies.premiumCapabilityService,
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'plugin/:slug',
                builder: (BuildContext context, GoRouterState state) {
                  final slug = state.pathParameters['slug'] ?? '';
                  return PluginDetailPage(
                    slug: slug,
                    config: dependencies.config,
                    catalogApi: dependencies.catalogApi,
                    downloadApi: dependencies.downloadApi,
                    toolBundleDownloadService:
                        dependencies.toolBundleDownloadService,
                    installsApi: dependencies.installsApi,
                    installedToolsController:
                        dependencies.installedToolsController,
                    entitlementController: dependencies.entitlementController,
                    premiumPurchaseController:
                        dependencies.premiumPurchaseController,
                    premiumCapabilityService: dependencies.premiumCapabilityService,
                    paywallCoordinator: dependencies.paywallCoordinator,
                  );
                },
              ),
              GoRoute(
                path: 'debug',
                builder: (BuildContext context, GoRouterState state) {
                  return HomePage(
                    config: dependencies.config,
                    healthApi: dependencies.healthApi,
                    bootstrapController: bootstrapController,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (BuildContext context, GoRouterState state) {
              return SettingsPage(
                bootstrapController: bootstrapController,
                entitlementController: dependencies.entitlementController,
                premiumPurchaseController:
                    dependencies.premiumPurchaseController,
                paywallCoordinator: dependencies.paywallCoordinator,
                freeTierUsageStore: dependencies.freeTierUsageStore,
                premiumCapabilityService: dependencies.premiumCapabilityService,
              );
            },
          ),
        ],
      ),
    ],
  );
}

String? _normalizeGuardRedirectTarget(String? rawTarget) {
  if (rawTarget == null || rawTarget.trim().isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(rawTarget);
  if (parsed == null) {
    return null;
  }
  if (!parsed.path.startsWith('/')) {
    return null;
  }
  if (parsed.path == AppRoutes.splash) {
    return null;
  }
  return parsed.toString();
}
