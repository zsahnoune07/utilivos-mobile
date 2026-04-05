import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utilivo_mobile/core/billing/billing_gateway.dart';
import 'package:utilivo_mobile/core/billing/models/billing_models.dart';
import 'package:utilivo_mobile/core/config/app_config.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/core/pro/free_tier_usage_store.dart';
import 'package:utilivo_mobile/core/pro/paywall_coordinator.dart';
import 'package:utilivo_mobile/core/pro/pro_analytics.dart';
import 'package:utilivo_mobile/core/pro/pro_capability_service.dart';
import 'package:utilivo_mobile/core/pro/pro_purchase_controller.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_api.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_verification_api.dart';
import 'package:utilivo_mobile/core/entitlement/models/pro_entitlement.dart';
import 'package:utilivo_mobile/features/downloads/application/tool_bundle_download_service.dart';
import 'package:utilivo_mobile/features/downloads/data/download_api.dart';
import 'package:utilivo_mobile/features/downloads/data/downloaded_tool_bundle_store.dart';
import 'package:utilivo_mobile/features/downloads/data/models/downloaded_tool_bundle.dart';
import 'package:utilivo_mobile/features/installs/application/installed_tools_controller.dart';
import 'package:utilivo_mobile/features/installs/data/installed_tools_read_result.dart';
import 'package:utilivo_mobile/features/installs/data/installed_tools_store.dart';
import 'package:utilivo_mobile/features/installs/data/installs_api.dart';
import 'package:utilivo_mobile/features/installs/data/installs_organization_store.dart';
import 'package:utilivo_mobile/features/installs/data/models/install_models.dart';
import 'package:utilivo_mobile/features/installs/data/models/installs_organization_models.dart';
import 'package:utilivo_mobile/features/installs/presentation/installs_page.dart';
import 'package:utilivo_mobile/features/installs/presentation/folder_detail_page.dart';
import 'package:utilivo_mobile/features/installs/presentation/widgets/folder_ui_catalog.dart';
import 'package:utilivo_mobile/features/installs/presentation/widgets/installed_tool_card.dart';
import 'package:utilivo_mobile/core/navigation/app_routes.dart';
import 'package:utilivo_mobile/l10n/app_localizations.dart';

import '../../support/pump_tool_thumbnail_ui.dart';

Widget _testMaterialApp({Widget? home, GoRouter? router}) {
  assert(home != null || router != null, 'home or router required');
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
  if (router != null) {
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: delegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
  return MaterialApp(
    localizationsDelegates: delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('home renders cached installed tools while offline', (
    WidgetTester tester,
  ) async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[
        DeviceInstallRecord(
          id: 'install_1',
          deviceId: 'device_1',
          pluginId: 'plugin_1',
          pluginSlug: 'tool-alpha',
          source: 'marketplace',
          installedAt: DateTime.parse('2026-03-06T10:00:00Z').toUtc(),
          installedVersionId: 'version_1',
          installedVersion: '1.0.0',
          updatedAt: DateTime.parse('2026-03-06T10:00:00Z').toUtc(),
        ),
      ],
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/installs') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404);
    });
    addTearDown(() => dio.close(force: true));

    final apiClient = ApiClient(dio);
    final controller = InstalledToolsController(
      installsApi: InstallsApi(apiClient),
      catalogApi: CatalogApi(apiClient),
      store: store,
      organizationStore: _InMemoryInstallsOrganizationStore(),
    );
    addTearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      controller.dispose();
    });

    await tester.runAsync(() async {
      await controller.bootstrap();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(controller.installedTools, hasLength(1));

    final downloadApi = DownloadApi(apiClient);
    final bundleStore = _InMemoryDownloadedToolBundleStore();
    final toolBundleDownloadService = ToolBundleDownloadService(
      dio: dio,
      store: bundleStore,
    );
    final installsApi = InstallsApi(apiClient);
    final entitlementStore = _InMemoryEntitlementStore();
    final entitlementVerificationApi = EntitlementVerificationApi(apiClient);
    final entitlementController = EntitlementController(
      store: entitlementStore,
      verificationApi: entitlementVerificationApi,
      packageName: 'com.test.app',
    );
    await entitlementController.bootstrap();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final pro = await _ProSidecar.create(entitlementController);
    addTearDown(pro.dispose);

    await tester.pumpWidget(
      _testMaterialApp(
        home: InstallsPage(
          appName: 'Utilivo',
          apiBaseUrl: 'https://api.example.test',
          installedToolsController: controller,
          downloadApi: downloadApi,
          toolBundleDownloadService: toolBundleDownloadService,
          installsApi: installsApi,
          entitlementController: entitlementController,
          proCapabilityService: pro.capability,
          paywallCoordinator: pro.paywall,
          proAnalytics: pro.analytics,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('tool-alpha'), findsOneWidget);
    expect(find.text('Browse Tool Library'), findsWidgets);
    expect(find.text('Could not load installed tools'), findsNothing);
    expect(find.text("Couldn't load installed tools"), findsNothing);
  });

  testWidgets('home shows unified load error when offline with no cached tools', (
    WidgetTester tester,
  ) async {
    final store = _InMemoryInstalledToolsStore(
      initial: const <DeviceInstallRecord>[],
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/installs') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404);
    });
    addTearDown(() => dio.close(force: true));

    final apiClient = ApiClient(dio);
    final controller = InstalledToolsController(
      installsApi: InstallsApi(apiClient),
      catalogApi: CatalogApi(apiClient),
      store: store,
      organizationStore: _InMemoryInstallsOrganizationStore(),
    );
    addTearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      controller.dispose();
    });

    await tester.runAsync(() async {
      await controller.bootstrap();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });

    final l10n = lookupAppLocalizations(const Locale('en'));

    final downloadApi = DownloadApi(apiClient);
    final bundleStore = _InMemoryDownloadedToolBundleStore();
    final toolBundleDownloadService = ToolBundleDownloadService(
      dio: dio,
      store: bundleStore,
    );
    final installsApi = InstallsApi(apiClient);
    final entitlementStore = _InMemoryEntitlementStore();
    final entitlementVerificationApi = EntitlementVerificationApi(apiClient);
    final entitlementController = EntitlementController(
      store: entitlementStore,
      verificationApi: entitlementVerificationApi,
      packageName: 'com.test.app',
    );
    await entitlementController.bootstrap();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final pro = await _ProSidecar.create(entitlementController);
    addTearDown(pro.dispose);

    await tester.pumpWidget(
      _testMaterialApp(
        home: InstallsPage(
          appName: 'Utilivo',
          apiBaseUrl: 'https://api.example.test',
          installedToolsController: controller,
          downloadApi: downloadApi,
          toolBundleDownloadService: toolBundleDownloadService,
          installsApi: installsApi,
          entitlementController: entitlementController,
          proCapabilityService: pro.capability,
          paywallCoordinator: pro.paywall,
          proAnalytics: pro.analytics,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.homeInstallsLoadFailedTitle), findsOneWidget);
    expect(find.text(l10n.homeInstallsOfflineDetail), findsOneWidget);
    expect(find.text(l10n.noInstalledTools), findsNothing);
  });

  testWidgets(
    'home search resets after returning from successful install flow',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) =>
                harness.page,
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => context.pop<bool>(true),
                    child: const Text('Install and return'),
                  ),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testMaterialApp(router: router));
      await pumpToolThumbnailUiSettled(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('No tools match your search'), findsOneWidget);

      await tester.tapAt(const Offset(20, 120));
      await pumpToolThumbnailUiSettled(tester);
      await tester.tap(find.text('Search in Tool Library'));
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Install and return'), findsOneWidget);

      await tester.tap(find.text('Install and return'));
      await pumpToolThumbnailUiSettled(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
      expect(find.text('No tools match your search'), findsNothing);
      expect(find.text('Tool Alpha'), findsOneWidget);
    },
  );

  testWidgets(
    'unfocusing home search restores grid; tapping tool opens runtime',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);

      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) =>
                harness.page,
          ),
          GoRoute(
            path: '${AppRoutes.pluginRuntimePrefix}/:slug',
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Center(child: Text('Runtime Page')));
            },
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testMaterialApp(router: router));
      await pumpToolThumbnailUiSettled(tester);

      final searchField = find.byKey(const Key('home_tool_search_field'));
      await tester.tap(searchField);
      await pumpToolThumbnailUiSettled(tester);
      expect(
        tester.widget<TextField>(searchField).focusNode?.hasFocus,
        isTrue,
      );

      await tester.enterText(searchField, 'Tool');
      await pumpToolThumbnailUiSettled(tester);
      expect(find.byType(InstalledToolCard), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await pumpToolThumbnailUiSettled(tester);
      expect(
        tester.widget<TextField>(searchField).focusNode?.hasFocus,
        isFalse,
      );
      expect(find.text('Runtime Page'), findsNothing);

      await tester.tap(find.byType(InstalledToolCard).first);
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Runtime Page'), findsOneWidget);
    },
  );

  testWidgets('tap on tool card opens immediately when search is not focused', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) => harness.page,
        ),
        GoRoute(
          path: '${AppRoutes.pluginRuntimePrefix}/:slug',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: Center(child: Text('Runtime Page')));
          },
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testMaterialApp(router: router));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.text('Tool Alpha'));
    await pumpToolThumbnailUiSettled(tester);
    expect(find.text('Runtime Page'), findsOneWidget);
  });

  testWidgets(
    'home keeps grouped sections for pinned, folders, and unpinned tools',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);
      await harness.controller.recordInstall(
        DeviceInstallRecord(
          id: 'install_2',
          deviceId: 'device_1',
          pluginId: 'plugin_2',
          pluginSlug: 'tool-beta',
          pluginName: 'Tool Beta',
          source: 'marketplace',
          installedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
          installedVersionId: 'version_2',
          installedVersion: '1.0.0',
          updatedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
          pluginDescription: 'Beta utility',
          categoryName: 'utilities',
        ),
      );
      await harness.controller.recordInstall(
        DeviceInstallRecord(
          id: 'install_3',
          deviceId: 'device_1',
          pluginId: 'plugin_3',
          pluginSlug: 'tool-gamma',
          pluginName: 'Tool Gamma',
          source: 'marketplace',
          installedAt: DateTime.parse('2026-03-08T10:00:00Z').toUtc(),
          installedVersionId: 'version_3',
          installedVersion: '1.0.0',
          updatedAt: DateTime.parse('2026-03-08T10:00:00Z').toUtc(),
          pluginDescription: 'Gamma utility',
          categoryName: 'utilities',
        ),
      );
      final folder = await harness.controller.createFolder(
        name: 'Work',
        iconKey: 'work',
        colorKey: 'blue',
      );
      await harness.controller.assignToolToFolder(
        pluginSlug: 'tool-beta',
        folderId: folder.id,
      );
      final alpha = harness.controller.installedTools.firstWhere(
        (tool) => tool.pluginSlug == 'tool-alpha',
      );
      await harness.controller.togglePin(alpha);
      final grouped = harness.controller.groupedHomeData;
      expect(
        grouped.pinnedTools.map((tool) => tool.pluginSlug),
        contains('tool-alpha'),
      );
      expect(
        grouped.folders.map((section) => section.folder.name),
        contains('Work'),
      );
      expect(
        grouped.unpinnedTools.map((tool) => tool.pluginSlug),
        contains('tool-gamma'),
      );

      await tester.pumpWidget(_testMaterialApp(home: harness.page));
      await pumpToolThumbnailUiSettled(tester);

      expect(find.text('Tool Alpha'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byType(InstalledToolCard), findsWidgets);
    },
  );

  testWidgets(
    'back on home with non-empty unfocused search clears search instead of closing',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);

      await tester.pumpWidget(_testMaterialApp(home: harness.page));
      await pumpToolThumbnailUiSettled(tester);

      await tester.enterText(_homeSearchField(), 'alpha');
      await pumpToolThumbnailUiSettled(tester);
      await tester.tapAt(const Offset(8, 8));
      await pumpToolThumbnailUiSettled(tester);

      await tester.binding.handlePopRoute();
      await pumpToolThumbnailUiSettled(tester);

      final textField = tester.widget<TextField>(_homeSearchField());
      expect(textField.controller?.text, isEmpty);
      expect(find.text('No tools match your search'), findsNothing);
      expect(find.text('Tool Alpha'), findsOneWidget);
    },
  );

  testWidgets('home back handling keeps initial state stable', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.binding.handlePopRoute();
    await pumpToolThumbnailUiSettled(tester);
    final initialField = tester.widget<TextField>(_homeSearchField());
    expect(initialField.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.enterText(_homeSearchField(), 'alpha');
    await pumpToolThumbnailUiSettled(tester);
    await tester.binding.handlePopRoute();
    await pumpToolThumbnailUiSettled(tester);
    final clearedField = tester.widget<TextField>(_homeSearchField());
    expect(clearedField.controller?.text, isEmpty);
  });

  testWidgets('home cards do not render category labels', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) => harness.page,
        ),
        GoRoute(
          path: '${AppRoutes.pluginRuntimePrefix}/:slug',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: Center(child: Text('Runtime Page')));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testMaterialApp(router: router));
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Tool Alpha'), findsOneWidget);
    expect(find.text('utilities'), findsNothing);
  });

  testWidgets('folder tile opens folder details and launches tool', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folderId,
    );

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) => harness.page,
        ),
        GoRoute(
          path: '${AppRoutes.folderDetailPrefix}/:folderId',
          builder: (BuildContext context, GoRouterState state) {
            final id = state.pathParameters['folderId']!;
            return FolderDetailPage(
              folderId: id,
              apiBaseUrl: 'https://api.example.test',
              controller: harness.controller,
              proCapabilityService: harness.pro.capability,
              paywallCoordinator: harness.pro.paywall,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.pluginRuntimePrefix}/:slug',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: Center(child: Text('Runtime Page')));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testMaterialApp(router: router));
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Work'), findsOneWidget);
    await tester.tap(find.text('Work'));
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Tool Alpha'), findsOneWidget);
    await tester.tap(find.text('Tool Alpha'));
    await pumpToolThumbnailUiSettled(tester);
    expect(find.text('Runtime Page'), findsOneWidget);
  });

  testWidgets('folder editor modal is keyboard-safe and selections persist', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Add folder'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('folder-color-carousel')), findsOneWidget);

    await tester.ensureVisible(find.byType(TextFormField));
    await tester.tap(find.byType(TextFormField), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField), 'Research');
    await tester.tap(find.byKey(const Key('folder-color-red')));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await pumpToolThumbnailUiSettled(tester);
    await tester.ensureVisible(find.byKey(const Key('folder-icon-education')));
    await tester.tap(find.byKey(const Key('folder-icon-education')));
    await tester.ensureVisible(find.text('Create folder'));
    await tester.tap(find.text('Create folder'));
    await tester.pump(const Duration(milliseconds: 260));

    final created = harness.controller.folders.firstWhere(
      (folder) => folder.name == 'Research',
    );
    expect(created.colorKey, 'red');
    expect(created.iconKey, 'education');
  });

  testWidgets(
    'folder details uses shared card and long-press removes only folder assignment',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);
      await harness.controller.createFolder(
        name: 'Work',
        iconKey: 'work',
        colorKey: 'blue',
      );
      final folderId = harness.controller.folders.first.id;
      await harness.controller.assignToolToFolder(
        pluginSlug: 'tool-alpha',
        folderId: folderId,
      );

      final router = GoRouter(
        initialLocation: AppRoutes.folderDetail(folderId),
        routes: <RouteBase>[
          GoRoute(
            path: '${AppRoutes.folderDetailPrefix}/:folderId',
            builder: (BuildContext context, GoRouterState state) =>
                FolderDetailPage(
                  folderId: state.pathParameters['folderId']!,
                  apiBaseUrl: 'https://api.example.test',
                  controller: harness.controller,
                  proCapabilityService: harness.pro.capability,
                  paywallCoordinator: harness.pro.paywall,
                ),
          ),
          GoRoute(
            path: '${AppRoutes.pluginRuntimePrefix}/:slug',
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testMaterialApp(router: router));
      await pumpToolThumbnailUiSettled(tester);
      expect(find.byType(InstalledToolCard), findsOneWidget);

      await tester.longPress(find.text('Tool Alpha'));
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Remove from folder'), findsOneWidget);
      await tester.tap(find.text('Remove from folder'));
      await pumpToolThumbnailUiSettled(tester);

      expect(
        harness.controller.installedTools
            .firstWhere((tool) => tool.pluginSlug == 'tool-alpha')
            .folderId,
        isNull,
      );
      expect(
        harness.controller.installedTools.where(
          (tool) => tool.pluginSlug == 'tool-alpha',
        ),
        isNotEmpty,
      );
    },
  );

  testWidgets('home search shows folder pill on folder-assigned tools', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folderId,
    );

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.enterText(find.byType(TextField), 'alpha');
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Tool Alpha'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folder detail app bar uses folder color with readable foreground',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);
      await harness.controller.createFolder(
        name: 'Urgent',
        iconKey: 'work',
        colorKey: 'red',
      );
      final folderId = harness.controller.folders.first.id;

      final router = GoRouter(
        initialLocation: AppRoutes.folderDetail(folderId),
        routes: <RouteBase>[
          GoRoute(
            path: '${AppRoutes.folderDetailPrefix}/:folderId',
            builder: (BuildContext context, GoRouterState state) =>
                FolderDetailPage(
                  folderId: state.pathParameters['folderId']!,
                  apiBaseUrl: 'https://api.example.test',
                  controller: harness.controller,
                  proCapabilityService: harness.pro.capability,
                  paywallCoordinator: harness.pro.paywall,
                ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testMaterialApp(router: router));
      await pumpToolThumbnailUiSettled(tester);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final appBarContext = tester.element(find.byType(AppBar));
      final expectedHeader = Color.alphaBlend(
        FolderUiCatalog.colorFor('red').withValues(alpha: 0.15),
        Theme.of(appBarContext).colorScheme.surface,
      );
      expect(appBar.backgroundColor, expectedHeader);
      expect(appBar.foregroundColor, isNotNull);
    },
  );

  testWidgets('home header renders icon-only add folder and sort controls', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    final secondInstall = DeviceInstallRecord(
      id: 'install_2',
      deviceId: 'device_1',
      pluginId: 'plugin_2',
      pluginSlug: 'tool-beta',
      pluginName: 'Tool Beta',
      source: 'marketplace',
      installedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
      installedVersionId: 'version_2',
      installedVersion: '1.0.0',
      updatedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
      pluginDescription: 'Beta utility',
      categoryName: 'utilities',
    );
    await harness.controller.recordInstall(secondInstall);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Add folder'), findsOneWidget);
    expect(find.text('Folder'), findsNothing);

    await tester.tap(find.byTooltip('Sort tools'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Name Z-A'));
    await pumpToolThumbnailUiSettled(tester);
    expect(harness.controller.homeSortMode, HomeSortMode.nameDesc);
  });

  testWidgets('folder modal icon grid has 28 curated icons', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.text('Add folder'));
    await pumpToolThumbnailUiSettled(tester);

    expect(FolderUiCatalog.iconKeys.length, 28);
    expect(FolderUiCatalog.iconKeys.length % 7, 0);
    for (final key in FolderUiCatalog.iconKeys) {
      expect(find.byKey(Key('folder-icon-$key')), findsOneWidget);
    }
  });

  testWidgets(
    'move-to-folder picker shows existing folders and create new folder',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);
      await harness.controller.createFolder(
        name: 'Work',
        iconKey: 'work',
        colorKey: 'blue',
      );

      await tester.pumpWidget(_testMaterialApp(home: harness.page));
      await pumpToolThumbnailUiSettled(tester);

      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await pumpToolThumbnailUiSettled(tester);
      await tester.longPress(
        find.byType(InstalledToolCard).first,
        warnIfMissed: false,
      );
      await pumpToolThumbnailUiSettled(tester);
      await tester.tap(find.text('Move to folder'));
      await pumpToolThumbnailUiSettled(tester);

      expect(find.text('Create new folder'), findsOneWidget);
      expect(find.text('Work'), findsWidgets);
    },
  );

  testWidgets(
    'nested modal flow keeps a single dim overlay and LIFO dismiss order',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);

      await tester.pumpWidget(_testMaterialApp(home: harness.page));
      await pumpToolThumbnailUiSettled(tester);

      await tester.longPress(find.byType(InstalledToolCard).first);
      await pumpToolThumbnailUiSettled(tester);
      await tester.tap(find.text('Move to folder'));
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Create new folder'), findsOneWidget);
      expect(_countDimmedBarriers(tester), 1);

      await tester.tap(find.text('Create new folder'));
      await pumpToolThumbnailUiSettled(tester);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(_countDimmedBarriers(tester), 1);

      await tester.binding.handlePopRoute();
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Move to folder'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Launch tool'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await pumpToolThumbnailUiSettled(tester);
      expect(find.text('Launch tool'), findsNothing);
    },
  );

  testWidgets('move-step transition keeps a single active content layer', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.longPress(find.byType(InstalledToolCard).first);
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Move to folder'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Launch tool'), findsNothing);
    expect(find.text('Move to folder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create new folder from move flow assigns tool immediately', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.ensureVisible(find.byType(InstalledToolCard).first);
    await tester.longPress(find.byType(InstalledToolCard).first);
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Move to folder'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Create new folder'));
    await pumpToolThumbnailUiSettled(tester);

    await tester.enterText(find.byType(TextFormField), 'Fresh');
    await tester.ensureVisible(find.text('Create folder'));
    await tester.tap(find.text('Create folder'));
    await pumpToolThumbnailUiSettled(tester);

    final createdFolder = harness.controller.folders.firstWhere(
      (folder) => folder.name == 'Fresh',
    );
    final tool = harness.controller.installedTools.firstWhere(
      (item) => item.pluginSlug == 'tool-alpha',
    );
    expect(tool.folderId, createdFolder.id);
  });

  testWidgets('cancel create new folder from move flow does not assign tool', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.ensureVisible(find.byType(InstalledToolCard).first);
    await tester.longPress(find.byType(InstalledToolCard).first);
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Move to folder'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Create new folder'));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tapAt(const Offset(8, 8));
    await pumpToolThumbnailUiSettled(tester);

    final tool = harness.controller.installedTools.firstWhere(
      (item) => item.pluginSlug == 'tool-alpha',
    );
    expect(tool.folderId, isNull);
  });

  testWidgets('create folder modal enforces max 16 characters while typing', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.text('Add folder'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.enterText(find.byType(TextFormField), 'ABCDEFGHIJKLMNOPQ');
    final nameField = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(nameField.controller?.text.length, 16);
  });

  testWidgets('create-from-move truncates over-limit name and assigns tool', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.longPress(find.byType(InstalledToolCard).first);
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Move to folder'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Create new folder'));
    await pumpToolThumbnailUiSettled(tester);

    await tester.enterText(find.byType(TextFormField), 'ABCDEFGHIJKLMNOPQ');
    await tester.ensureVisible(find.text('Create folder'));
    await tester.tap(find.text('Create folder'));
    await pumpToolThumbnailUiSettled(tester);

    final createdFolder = harness.controller.folders.firstWhere(
      (folder) => folder.name == 'ABCDEFGHIJKLMNOP',
    );
    final tool = harness.controller.installedTools.firstWhere(
      (item) => item.pluginSlug == 'tool-alpha',
    );
    expect(tool.folderId, createdFolder.id);
  });

  testWidgets('opened folder long-press flow still exposes move-to-folder', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'Source',
      iconKey: 'work',
      colorKey: 'blue',
    );
    final sourceId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: sourceId,
    );

    final router = GoRouter(
      initialLocation: AppRoutes.folderDetail(sourceId),
      routes: <RouteBase>[
        GoRoute(
          path: '${AppRoutes.folderDetailPrefix}/:folderId',
          builder: (BuildContext context, GoRouterState state) =>
              FolderDetailPage(
                folderId: state.pathParameters['folderId']!,
                apiBaseUrl: 'https://api.example.test',
                controller: harness.controller,
                proCapabilityService: harness.pro.capability,
                paywallCoordinator: harness.pro.paywall,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testMaterialApp(router: router));
    await pumpToolThumbnailUiSettled(tester);

    await tester.longPress(find.text('Tool Alpha'));
    await pumpToolThumbnailUiSettled(tester);
    expect(find.text('Move to folder'), findsOneWidget);
  });

  testWidgets('search card with folder pill does not overflow for long names', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'ResearchFolder',
      iconKey: 'documents',
      colorKey: 'blue',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.recordInstall(
      DeviceInstallRecord(
        id: 'install_long',
        deviceId: 'device_1',
        pluginId: 'plugin_long',
        pluginSlug: 'tool-long',
        pluginName: 'Very Long Tool Name For Overflow Verification',
        source: 'marketplace',
        installedAt: DateTime.parse('2026-03-07T11:00:00Z').toUtc(),
        installedVersionId: 'version_long',
        installedVersion: '1.0.0',
        updatedAt: DateTime.parse('2026-03-07T11:00:00Z').toUtc(),
        pluginDescription: 'Long description for overflow check',
        categoryName: 'utilities',
      ),
    );
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-long',
      folderId: folderId,
    );

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.enterText(find.byType(TextField), 'long');
    await pumpToolThumbnailUiSettled(tester);

    expect(find.textContaining('Very Long Tool Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folder badge overlay keeps search card proportions stable', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.recordInstall(
      DeviceInstallRecord(
        id: 'install_2',
        deviceId: 'device_1',
        pluginId: 'plugin_2',
        pluginSlug: 'tool-beta',
        pluginName: 'Tool Beta',
        source: 'marketplace',
        installedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
        installedVersionId: 'version_2',
        installedVersion: '1.0.0',
        updatedAt: DateTime.parse('2026-03-07T10:00:00Z').toUtc(),
        pluginDescription: 'Beta utility',
        categoryName: 'utilities',
      ),
    );
    await harness.controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folderId,
    );

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);
    await tester.enterText(find.byType(TextField), 'tool');
    await pumpToolThumbnailUiSettled(tester);

    final cards = find.byType(InstalledToolCard);
    expect(cards, findsNWidgets(2));
    final firstSize = tester.getSize(cards.at(0));
    final secondSize = tester.getSize(cards.at(1));
    expect(firstSize.height, secondSize.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folder badge uses referenced folder color tone', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'red',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folderId,
    );

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);
    await tester.enterText(find.byType(TextField), 'alpha');
    await pumpToolThumbnailUiSettled(tester);

    final badge = tester.widget<Container>(
      find.byKey(const Key('folder-badge-tool-alpha')),
    );
    final decoration = badge.decoration as BoxDecoration;
    final expectedColor = Color.alphaBlend(
      FolderUiCatalog.colorFor('red').withValues(alpha: 0.22),
      Theme.of(
        tester.element(find.byType(InstalledToolCard)),
      ).colorScheme.surface,
    );
    expect(decoration.color, expectedColor);
  });

  testWidgets('closing create-folder modal does not auto-focus home search', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.text('Add folder'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tapAt(const Offset(8, 8));
    await pumpToolThumbnailUiSettled(tester);

    final textField = tester.widget<TextField>(_homeSearchField());
    expect(textField.focusNode?.hasFocus ?? false, isFalse);
  });

  testWidgets('selecting sort does not auto-focus home search', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.byTooltip('Sort tools'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.tap(find.text('Last used'));
    await pumpToolThumbnailUiSettled(tester);

    final textField = tester.widget<TextField>(_homeSearchField());
    expect(textField.focusNode?.hasFocus ?? false, isFalse);
  });

  testWidgets('long-press anywhere on folder card opens editor modal', (
    WidgetTester tester,
  ) async {
    final harness = await _InstallsHarness.create();
    addTearDown(harness.dispose);
    await harness.controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    final folderId = harness.controller.folders.first.id;
    await harness.controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folderId,
    );

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.longPress(find.text('1 tools'));
    await pumpToolThumbnailUiSettled(tester);
    expect(find.text('Save folder'), findsOneWidget);
  });

  testWidgets(
    'folder icon Y-position stays consistent for one and two-line names',
    (WidgetTester tester) async {
      final harness = await _InstallsHarness.create();
      addTearDown(harness.dispose);
      final short = await harness.controller.createFolder(
        name: 'Work',
        iconKey: 'work',
        colorKey: 'blue',
      );
      final long = await harness.controller.createFolder(
        name: 'ResearchFolder16',
        iconKey: 'documents',
        colorKey: 'green',
      );

      await tester.pumpWidget(_testMaterialApp(home: harness.page));
      await pumpToolThumbnailUiSettled(tester);

      final shortCenter = tester.getCenter(
        find.byKey(Key('folder-tile-icon-${short.id}')),
      );
      final longCenter = tester.getCenter(
        find.byKey(Key('folder-tile-icon-${long.id}')),
      );
      expect(shortCenter.dy, moreOrLessEquals(longCenter.dy, epsilon: 0.1));
    },
  );

  testWidgets('legacy folder names longer than 16 chars are editable safely', (
    WidgetTester tester,
  ) async {
    final legacyFolder = ToolFolder(
      id: 'folder_legacy',
      name: 'Legacy Folder Name Too Long',
      iconKey: 'work',
      colorKey: 'blue',
      createdAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
      manualOrder: 0,
    );
    final harness = await _InstallsHarness.create(
      organizationStore: _InMemoryInstallsOrganizationStore(
        initial: InstallsOrganizationState(
          folders: <ToolFolder>[legacyFolder],
          homeSortMode: HomeSortMode.defaultManual,
        ),
      ),
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(_testMaterialApp(home: harness.page));
    await pumpToolThumbnailUiSettled(tester);

    await tester.longPress(find.text('Legacy Folder Name Too Long'));
    await pumpToolThumbnailUiSettled(tester);
    await tester.ensureVisible(find.text('Save folder'));
    await tester.tap(find.text('Save folder'));
    await pumpToolThumbnailUiSettled(tester);

    expect(tester.takeException(), isNull);
    expect(
      harness.controller.folders
          .firstWhere((f) => f.id == legacyFolder.id)
          .name,
      'Legacy Folder Name Too Long',
    );
  });
}

Finder _homeSearchField() {
  return find.byKey(const Key('home_tool_search_field'));
}

int _countDimmedBarriers(WidgetTester tester) {
  final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
  return barriers
      .where((ModalBarrier barrier) => (barrier.color?.a ?? 0) > 0)
      .length;
}

class _ProSidecar {
  _ProSidecar._({
    required this.capability,
    required this.paywall,
    required this.analytics,
    required this.purchaseController,
  });

  final ProCapabilityService capability;
  final PaywallCoordinator paywall;
  final ProAnalytics analytics;
  final ProPurchaseController purchaseController;

  static Future<_ProSidecar> create(
    EntitlementController entitlementController,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final usage = await FreeTierUsageStore.open();
    const config = AppConfig(
      appName: 'Utilivo',
      apiBaseUrl: 'https://api.example.test',
      androidPackageName: 'com.test.app',
      proOneTimeProductId: 'utilivo_pro_one_time',
      proSubscriptionProductId: '',
      proSubscriptionMonthlyProductId: '',
      proSubscriptionAnnualProductId: '',
    );
    final billing = _InstallsTestBillingGateway();
    final purchaseController = ProPurchaseController(
      config: config,
      billingGateway: billing,
      entitlementController: entitlementController,
    );
    await purchaseController.initialize();
    final capability = ProCapabilityService(
      entitlementController: entitlementController,
      usageStore: usage,
    );
    final analytics = DebugProAnalytics();
    final paywall = PaywallCoordinator(
      purchaseController: purchaseController,
      entitlementController: entitlementController,
      analytics: analytics,
    );
    return _ProSidecar._(
      capability: capability,
      paywall: paywall,
      analytics: analytics,
      purchaseController: purchaseController,
    );
  }

  void dispose() {
    capability.dispose();
    purchaseController.dispose();
  }
}

class _InstallsTestBillingGateway implements BillingGateway {
  final StreamController<BillingPurchaseUpdate> _updates =
      StreamController<BillingPurchaseUpdate>.broadcast();

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<void> buyNonConsumable(String productId) async {}

  @override
  Future<void> buyProduct(String productId) async {}

  @override
  void dispose() {
    _updates.close();
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async =>
      const <BillingProduct>[];

  @override
  Future<void> restorePurchases() async {}
}

class _InstallsHarness {
  _InstallsHarness({
    required this.page,
    required this.controller,
    required this.entitlementController,
    required this.dio,
    required this.bundleStoreDio,
    required this.pro,
  });

  final Widget page;
  final InstalledToolsController controller;
  final EntitlementController entitlementController;
  final Dio dio;
  final Dio bundleStoreDio;
  final _ProSidecar pro;

  static Future<_InstallsHarness> create({
    _InMemoryInstallsOrganizationStore? organizationStore,
  }) async {
    return createWithStore(
      organizationStore ?? _InMemoryInstallsOrganizationStore(),
    );
  }

  static Future<_InstallsHarness> createWithStore(
    _InMemoryInstallsOrganizationStore organizationStore,
  ) async {
    final install = DeviceInstallRecord(
      id: 'install_1',
      deviceId: 'device_1',
      pluginId: 'plugin_1',
      pluginSlug: 'tool-alpha',
      pluginName: 'Tool Alpha',
      source: 'marketplace',
      installedAt: DateTime.parse('2026-03-06T10:00:00Z').toUtc(),
      installedVersionId: 'version_1',
      installedVersion: '1.0.0',
      updatedAt: DateTime.parse('2026-03-06T10:00:00Z').toUtc(),
      pluginDescription: 'Alpha utility',
      categoryName: 'utilities',
    );

    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[install],
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/installs') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404);
    });

    final apiClient = ApiClient(dio);
    final controller = InstalledToolsController(
      installsApi: InstallsApi(apiClient),
      catalogApi: CatalogApi(apiClient),
      store: store,
      organizationStore: organizationStore,
    );
    await controller.bootstrap();

    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
      verificationApi: EntitlementVerificationApi(apiClient),
      packageName: 'com.test.app',
    );
    await entitlementController.bootstrap();

    final bundleStoreDio = Dio(
      BaseOptions(baseUrl: 'https://api.example.test'),
    );
    final pro = await _ProSidecar.create(entitlementController);
    final page = InstallsPage(
      appName: 'Utilivo',
      apiBaseUrl: 'https://api.example.test',
      installedToolsController: controller,
      downloadApi: DownloadApi(apiClient),
      toolBundleDownloadService: ToolBundleDownloadService(
        dio: bundleStoreDio,
        store: _InMemoryDownloadedToolBundleStore(),
      ),
      installsApi: InstallsApi(apiClient),
      entitlementController: entitlementController,
      proCapabilityService: pro.capability,
      paywallCoordinator: pro.paywall,
      proAnalytics: pro.analytics,
    );

    return _InstallsHarness(
      page: page,
      controller: controller,
      entitlementController: entitlementController,
      dio: dio,
      bundleStoreDio: bundleStoreDio,
      pro: pro,
    );
  }

  Future<void> dispose() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    pro.dispose();
    controller.dispose();
    entitlementController.dispose();
    dio.close(force: true);
    bundleStoreDio.close(force: true);
  }
}

class _InMemoryInstalledToolsStore implements InstalledToolsStore {
  _InMemoryInstalledToolsStore({List<DeviceInstallRecord>? initial})
    : _value = initial ?? const <DeviceInstallRecord>[];

  List<DeviceInstallRecord> _value;
  final StreamController<List<DeviceInstallRecord>> _watch =
      StreamController<List<DeviceInstallRecord>>.broadcast();

  @override
  Future<void> clear() async {
    _value = const <DeviceInstallRecord>[];
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_value));
  }

  @override
  Future<InstalledToolsStoreReadResult> read() async {
    return InstalledToolsStoreReadResult(installs: _value);
  }

  @override
  Future<void> write(List<DeviceInstallRecord> installs) async {
    _value = installs;
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_value));
  }

  @override
  Stream<List<DeviceInstallRecord>> watch() async* {
    yield List<DeviceInstallRecord>.unmodifiable(_value);
    yield* _watch.stream;
  }
}

ResponseBody _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _InMemoryDownloadedToolBundleStore implements DownloadedToolBundleStore {
  List<DownloadedToolBundle> _value = const <DownloadedToolBundle>[];

  @override
  Future<void> clear() async {
    _value = const <DownloadedToolBundle>[];
  }

  @override
  Future<List<DownloadedToolBundle>> read() async => _value;

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) async {
    _value = bundles;
  }
}

class _InMemoryEntitlementStore implements EntitlementStore {
  ProEntitlement? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<ProEntitlement?> read() async => _value;

  @override
  Future<void> write(ProEntitlement entitlement) async {
    _value = entitlement;
  }
}

class _InMemoryInstallsOrganizationStore implements InstallsOrganizationStore {
  _InMemoryInstallsOrganizationStore({InstallsOrganizationState? initial})
    : _value = initial ?? InstallsOrganizationState.empty;

  InstallsOrganizationState _value;

  @override
  Future<void> clear() async {
    _value = InstallsOrganizationState.empty;
  }

  @override
  Future<InstallsOrganizationState> read() async {
    return _value;
  }

  @override
  Future<void> write(InstallsOrganizationState state) async {
    _value = state;
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._responder);

  final Future<ResponseBody> Function(RequestOptions options) _responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _responder(options);
  }
}
