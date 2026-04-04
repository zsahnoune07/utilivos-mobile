import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/plugin_detail_page.dart';
import '../../features/discover/presentation/discover_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/installs/presentation/installs_page.dart';
import '../../features/installs/presentation/folder_detail_page.dart';
import '../../features/installs/data/models/install_models.dart';
import '../../features/runtime/presentation/plugin_runtime_page.dart';
import '../sessions/tool_launch_context.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/widgets/presentation/widget_configure_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../bootstrap/app_bootstrap_controller.dart';
import '../di/app_dependencies.dart';
import 'app_routes.dart';
import 'deep_link_parser.dart';

GoRouter createAppRouter({
  required AppDependencies dependencies,
  required AppBootstrapController bootstrapController,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: bootstrapController,
    redirect: (BuildContext context, GoRouterState state) {
      // Home-screen widget / some Android intents deliver utilivo://tool/... as the
      // route location; GoRouter only knows /runtime/... paths.
      if (state.uri.scheme == 'utilivo' && state.uri.host == 'tool') {
        final String? target = parseAppDeepLink(state.uri);
        if (target != null) {
          return target;
        }
      }

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
        path: AppRoutes.widgetConfigure,
        builder: (BuildContext context, GoRouterState state) {
          final raw = state.uri.queryParameters['androidAppWidgetId'];
          final id = int.tryParse(raw ?? '');
          if (id == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid widget configuration.')),
            );
          }
          return WidgetConfigurePage(
            androidAppWidgetId: id,
            apiBaseUrl: dependencies.config.apiBaseUrl,
            installedToolsController: dependencies.installedToolsController,
            toolWidgetService: dependencies.toolWidgetService,
            proCapabilityService: dependencies.proCapabilityService,
            paywallCoordinator: dependencies.paywallCoordinator,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.pluginRuntimePrefix}/:slug',
        builder: (BuildContext context, GoRouterState state) {
          final slug = state.pathParameters['slug'] ?? '';
          final initialToolName = state.uri.queryParameters['name'];
          final restoreSession =
              state.uri.queryParameters['restore'] == '1';
          final widgetInstanceId =
              state.uri.queryParameters['widget']?.trim() ?? '';
          final sessionParam =
              state.uri.queryParameters['session']?.trim() ?? '';
          DeviceInstallRecord? install;
          for (final i in dependencies.installedToolsController.installedTools) {
            if (i.pluginSlug == slug) {
              install = i;
              break;
            }
          }
          final toolId = install?.id ?? slug;
          final ToolLaunchContext launchContext;
          if (widgetInstanceId.isNotEmpty) {
            launchContext = ToolLaunchContext.widgetLaunch(
              toolId: toolId,
              toolSlug: slug,
              widgetInstanceId: widgetInstanceId,
              installId: install?.id,
              installedVersion: install?.installedVersion,
            );
          } else if (sessionParam.isNotEmpty) {
            launchContext = ToolLaunchContext.namedSessionLaunch(
              toolId: toolId,
              toolSlug: slug,
              sessionId: sessionParam,
              installId: install?.id,
              installedVersion: install?.installedVersion,
            );
          } else if (restoreSession) {
            launchContext = ToolLaunchContext.legacyFileRestore(
              toolId: toolId,
              toolSlug: slug,
              installId: install?.id,
              installedVersion: install?.installedVersion,
            );
          } else {
            launchContext = ToolLaunchContext.ephemeral(
              toolId: toolId,
              toolSlug: slug,
              installId: install?.id,
              installedVersion: install?.installedVersion,
            );
          }
          return PluginRuntimePage(
            key: ValueKey<String>('plugin_runtime_$slug'),
            pluginSlug: slug,
            initialToolName: initialToolName,
            launchContext: launchContext,
            config: dependencies.config,
            catalogApi: dependencies.catalogApi,
            downloadApi: dependencies.downloadApi,
            toolBundleDownloadService: dependencies.toolBundleDownloadService,
            entitlementController: dependencies.entitlementController,
            proCapabilityService: dependencies.proCapabilityService,
            paywallCoordinator: dependencies.paywallCoordinator,
            toolSessionStore: dependencies.toolSessionStore,
            runtimeStateScopeService: dependencies.runtimeStateScopeService,
            toolSessionService: dependencies.toolSessionService,
            toolWidgetService: dependencies.toolWidgetService,
            proAnalytics: dependencies.proAnalytics,
            installedToolsController: dependencies.installedToolsController,
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
                apiBaseUrl: dependencies.config.apiBaseUrl,
                installedToolsController: dependencies.installedToolsController,
                downloadApi: dependencies.downloadApi,
                toolBundleDownloadService:
                    dependencies.toolBundleDownloadService,
                installsApi: dependencies.installsApi,
                entitlementController: dependencies.entitlementController,
                proCapabilityService: dependencies.proCapabilityService,
                paywallCoordinator: dependencies.paywallCoordinator,
                proAnalytics: dependencies.proAnalytics,
              );
            },
          ),
          GoRoute(
            path: '${AppRoutes.folderDetailPrefix}/:folderId',
            builder: (BuildContext context, GoRouterState state) {
              final folderId = state.pathParameters['folderId'] ?? '';
              return FolderDetailPage(
                folderId: folderId,
                apiBaseUrl: dependencies.config.apiBaseUrl,
                controller: dependencies.installedToolsController,
                proCapabilityService: dependencies.proCapabilityService,
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
                proCapabilityService: dependencies.proCapabilityService,
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
                    proPurchaseController:
                        dependencies.proPurchaseController,
                    proCapabilityService: dependencies.proCapabilityService,
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
                proPurchaseController:
                    dependencies.proPurchaseController,
                paywallCoordinator: dependencies.paywallCoordinator,
                freeTierUsageStore: dependencies.freeTierUsageStore,
                proCapabilityService: dependencies.proCapabilityService,
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
