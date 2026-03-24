import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utilivo_mobile/core/config/app_config.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivo_mobile/core/entitlement/models/pro_entitlement.dart';
import 'package:utilivo_mobile/core/billing/billing_gateway.dart';
import 'package:utilivo_mobile/core/billing/models/billing_models.dart';
import 'package:utilivo_mobile/core/pro/free_tier_usage_store.dart';
import 'package:utilivo_mobile/core/pro/pro_capability_service.dart';
import 'package:utilivo_mobile/core/pro/pro_purchase_controller.dart';
import 'package:utilivo_mobile/core/navigation/app_routes.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_api.dart';
import 'package:utilivo_mobile/features/discover/presentation/discover_page.dart';
import 'package:utilivo_mobile/features/downloads/application/tool_bundle_download_service.dart';
import 'package:utilivo_mobile/features/downloads/data/download_api.dart';
import 'package:utilivo_mobile/features/downloads/data/downloaded_tool_bundle_store.dart';
import 'package:utilivo_mobile/features/downloads/data/models/downloaded_tool_bundle.dart';
import 'package:utilivo_mobile/features/installs/application/installed_tools_controller.dart';
import 'package:utilivo_mobile/features/installs/data/installed_tools_store.dart';
import 'package:utilivo_mobile/features/installs/data/installs_api.dart';
import 'package:utilivo_mobile/features/installs/data/installs_organization_store.dart';
import 'package:utilivo_mobile/features/installs/data/models/install_models.dart';
import 'package:utilivo_mobile/features/installs/data/models/installs_organization_models.dart';

const String _kSlug = 'json-toolkit';
const String _kPluginName = 'JSON Toolkit';
const String _kVersion = '1.0.0';

void main() {
  testWidgets('not installed tool shows Install action', (
    WidgetTester tester,
  ) async {
    final harness = await _DiscoverHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    await _pumpUntilVisible(tester, find.text('JSON Toolkit'));

    expect(find.text('JSON Toolkit'), findsOneWidget);
    expect(find.byTooltip('Install'), findsOneWidget);
    expect(find.text('Run'), findsNothing);
  });

  testWidgets('installed tool shows Run in Tool Library listing', (
    WidgetTester tester,
  ) async {
    final harness = await _DiscoverHarness.create(initiallyInstalled: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    await _pumpUntilVisible(tester, find.text('JSON Toolkit'));

    expect(find.text('JSON Toolkit'), findsOneWidget);
    expect(find.byTooltip('Run'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byTooltip('Install'), findsNothing);
  });

  testWidgets('tapping Run from Tool Library launches runtime', (
    WidgetTester tester,
  ) async {
    final harness = await _DiscoverHarness.create(initiallyInstalled: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    await _pumpUntilVisible(tester, find.text('JSON Toolkit'));

    await tester.tap(find.byTooltip('Run'));
    await _pumpUntilVisible(tester, find.text('Runtime: json-toolkit'));

    expect(find.text('Runtime: json-toolkit'), findsOneWidget);
  });

  testWidgets('post-install action switches from Install to Run immediately', (
    WidgetTester tester,
  ) async {
    final harness = await _DiscoverHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    await _pumpUntilVisible(tester, find.text('JSON Toolkit'));

    expect(find.byTooltip('Install'), findsOneWidget);
    await harness.controller.recordInstall(
      DeviceInstallRecord.fromJson(
        _installPayload(
          slug: _kSlug,
          pluginName: _kPluginName,
          version: _kVersion,
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilVisible(tester, find.byTooltip('Run'));

    expect(find.byTooltip('Run'), findsOneWidget);
    expect(find.byTooltip('Install'), findsNothing);
  });

  testWidgets('quick repeated taps on Run do not duplicate launch', (
    WidgetTester tester,
  ) async {
    final harness = await _DiscoverHarness.create(initiallyInstalled: true);
    addTearDown(harness.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    await _pumpUntilVisible(tester, find.text('JSON Toolkit'));

    await tester.tap(find.byTooltip('Run'));
    await tester.tap(find.byTooltip('Run'), warnIfMissed: false);
    await _pumpUntilVisible(tester, find.text('Runtime: json-toolkit'));

    expect(harness.runtimeOpenCount, 1);
  });
}

class _DiscoverHarness {
  _DiscoverHarness({
    required this.router,
    required this.controller,
    required this.entitlementController,
    required this.apiDio,
    required this.bundleDio,
    required this.baseDir,
    required this.runtimeOpenCounter,
    required this.proCapabilityService,
    required this.proPurchaseController,
  });

  final GoRouter router;
  final InstalledToolsController controller;
  final EntitlementController entitlementController;
  final Dio apiDio;
  final Dio bundleDio;
  final Directory baseDir;
  final ValueNotifier<int> runtimeOpenCounter;
  final ProCapabilityService proCapabilityService;
  final ProPurchaseController proPurchaseController;

  int get runtimeOpenCount => runtimeOpenCounter.value;

  static Future<_DiscoverHarness> create({
    bool initiallyInstalled = false,
  }) async {
    const slug = _kSlug;
    const pluginName = _kPluginName;
    const version = _kVersion;

    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: slug,
      pluginName: pluginName,
      version: version,
    );
    final checksum = sha256.convert(bundleBytes).toString();
    var installTracked = initiallyInstalled;

    final apiDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    apiDio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/categories') {
        return _jsonResponse(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'cat_1',
              'slug': 'dev-tools',
              'name': 'Dev Tools',
            },
          ],
        }, 200);
      }

      if (options.path == '/v1/plugins') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'plugin_1',
                'slug': slug,
                'name': pluginName,
                'category_slug': 'dev-tools',
                'category_name': 'Dev Tools',
                'pricing_type': 'free',
                'short_description': 'Parse and validate JSON',
              },
            ],
            'next_cursor': null,
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$slug') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'id': 'plugin_1',
            'slug': slug,
            'name': pluginName,
            'category_slug': 'dev-tools',
            'category_name': 'Dev Tools',
            'pricing_type': 'free',
            'short_description': 'Parse and validate JSON',
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$slug/versions') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'ver_1', 'version': version},
            ],
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$slug/download') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'url': 'https://download.example.test/$slug-$version.ubb',
            'expires_at': '2026-03-10T00:00:00Z',
            'version': version,
            'checksum_sha256': checksum,
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$slug/install') {
        installTracked = true;
        return _jsonResponse(<String, dynamic>{
          'data': _installPayload(
            slug: slug,
            pluginName: pluginName,
            version: version,
          ),
        }, 200);
      }

      if (options.path == '/v1/installs') {
        final items = installTracked
            ? <Map<String, dynamic>>[
                _installPayload(
                  slug: slug,
                  pluginName: pluginName,
                  version: version,
                ),
              ]
            : <Map<String, dynamic>>[];
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{'items': items},
        }, 200);
      }

      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404);
    });

    final apiClient = ApiClient(apiDio);
    final initialStoreData = initiallyInstalled
        ? <DeviceInstallRecord>[
            DeviceInstallRecord.fromJson(
              _installPayload(
                slug: slug,
                pluginName: pluginName,
                version: version,
              ),
            ),
          ]
        : const <DeviceInstallRecord>[];
    final controller = InstalledToolsController(
      installsApi: InstallsApi(apiClient),
      catalogApi: CatalogApi(apiClient),
      store: _InMemoryInstalledToolsStore(initial: initialStoreData),
      organizationStore: _InMemoryInstallsOrganizationStore(),
    );

    final baseDir = Directory.systemTemp;
    final bundleDio = Dio();
    final toolBundleDownloadService = ToolBundleDownloadService(
      dio: bundleDio,
      store: _InMemoryDownloadedToolBundleStore(),
      baseDirectoryProvider: () async => baseDir,
      downloadFile:
          (
            Uri uri,
            String savePath,
            void Function(int received, int total)? onReceiveProgress,
          ) async {
            final file = File(savePath);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bundleBytes);
            onReceiveProgress?.call(bundleBytes.length, bundleBytes.length);
          },
    );

    final entitlementController = EntitlementController(
      store: _InMemoryEntitlementStore(),
    );
    await entitlementController.bootstrap();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final usageStore = await FreeTierUsageStore.open();
    final proCapabilityService = ProCapabilityService(
      entitlementController: entitlementController,
      usageStore: usageStore,
    );
    const billingConfig = AppConfig(
      appName: 'Utilivo',
      apiBaseUrl: 'https://api.example.test',
      androidPackageName: 'com.utilivo.utilivo_mobile',
      proOneTimeProductId: 'utilivo_pro_one_time',
      proSubscriptionProductId: '',
      proSubscriptionMonthlyProductId: '',
      proSubscriptionAnnualProductId: '',
    );
    final discoverBilling = _DiscoverTestBillingGateway();
    final proPurchaseController = ProPurchaseController(
      config: billingConfig,
      billingGateway: discoverBilling,
      entitlementController: entitlementController,
    );
    await proPurchaseController.initialize();
    final runtimeOpenCounter = ValueNotifier<int>(0);
    final router = GoRouter(
      initialLocation: AppRoutes.discover,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.discover,
          builder: (BuildContext context, GoRouterState state) {
            return DiscoverPage(
              config: const AppConfig(
                appName: 'Utilivo',
                apiBaseUrl: 'https://api.example.test',
                androidPackageName: 'com.utilivo.utilivo_mobile',
                proOneTimeProductId: 'utilivo_pro_one_time',
                proSubscriptionProductId: 'utilivo_pro_subscription',
                proSubscriptionMonthlyProductId: '',
                proSubscriptionAnnualProductId: '',
              ),
              catalogApi: CatalogApi(apiClient),
              entitlementController: entitlementController,
              downloadApi: DownloadApi(apiClient),
              toolBundleDownloadService: toolBundleDownloadService,
              installsApi: InstallsApi(apiClient),
              installedToolsController: controller,
              proCapabilityService: proCapabilityService,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.pluginRuntimePrefix}/:slug',
          builder: (BuildContext context, GoRouterState state) {
            runtimeOpenCounter.value = runtimeOpenCounter.value + 1;
            final slug = state.pathParameters['slug'] ?? '';
            return Scaffold(body: Center(child: Text('Runtime: $slug')));
          },
        ),
      ],
    );

    return _DiscoverHarness(
      router: router,
      controller: controller,
      entitlementController: entitlementController,
      apiDio: apiDio,
      bundleDio: bundleDio,
      baseDir: baseDir,
      runtimeOpenCounter: runtimeOpenCounter,
      proCapabilityService: proCapabilityService,
      proPurchaseController: proPurchaseController,
    );
  }

  Future<void> dispose() async {
    router.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    proCapabilityService.dispose();
    proPurchaseController.dispose();
    controller.dispose();
    entitlementController.dispose();
    apiDio.close(force: true);
    bundleDio.close(force: true);
  }
}

class _DiscoverTestBillingGateway implements BillingGateway {
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

Map<String, dynamic> _installPayload({
  required String slug,
  required String pluginName,
  required String version,
}) {
  return <String, dynamic>{
    'id': 'install_$slug',
    'device_id': 'device_1',
    'plugin_id': 'plugin_1',
    'plugin_slug': slug,
    'source': 'marketplace',
    'installed_at': '2026-03-10T10:00:00Z',
    'installed_version_id': 'ver_1',
    'installed_version': version,
    'updated_at': '2026-03-10T10:00:00Z',
    'plugin_name': pluginName,
    'category_name': 'Dev Tools',
    'plugin_description': 'Parse and validate JSON',
  };
}

class _InMemoryInstalledToolsStore implements InstalledToolsStore {
  _InMemoryInstalledToolsStore({List<DeviceInstallRecord>? initial})
    : _data = initial ?? <DeviceInstallRecord>[];

  List<DeviceInstallRecord> _data;
  final StreamController<List<DeviceInstallRecord>> _watch =
      StreamController<List<DeviceInstallRecord>>.broadcast();

  @override
  Future<List<DeviceInstallRecord>> read() async => _data;

  @override
  Future<void> write(List<DeviceInstallRecord> installs) async {
    _data = installs;
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_data));
  }

  @override
  Future<void> clear() async {
    _data = <DeviceInstallRecord>[];
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_data));
  }

  @override
  Stream<List<DeviceInstallRecord>> watch() async* {
    yield List<DeviceInstallRecord>.unmodifiable(_data);
    yield* _watch.stream;
  }
}

class _InMemoryDownloadedToolBundleStore implements DownloadedToolBundleStore {
  List<DownloadedToolBundle> _data = const <DownloadedToolBundle>[];

  @override
  Future<List<DownloadedToolBundle>> read() async => _data;

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) async {
    _data = bundles;
  }

  @override
  Future<void> clear() async {
    _data = const <DownloadedToolBundle>[];
  }
}

class _InMemoryEntitlementStore implements EntitlementStore {
  ProEntitlement? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<ProEntitlement?> read() async {
    return _value;
  }

  @override
  Future<void> write(ProEntitlement entitlement) async {
    _value = entitlement;
  }
}

class _InMemoryInstallsOrganizationStore implements InstallsOrganizationStore {
  InstallsOrganizationState _value = InstallsOrganizationState.empty;

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

ResponseBody _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
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

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 40,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

List<int> _buildBundleArchiveBytes({
  required String pluginSlug,
  required String pluginName,
  required String version,
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('manifest.json', '''
{
  "id": "com.utilivo.plugin.$pluginSlug",
  "name": "$pluginName",
  "slug": "$pluginSlug",
  "version": "$version",
  "entry": "src/index.html"
}
'''),
    )
    ..addFile(
      ArchiveFile.string(
        'src/index.html',
        '<!doctype html><html><body><h1>$pluginName</h1></body></html>',
      ),
    );
  return ZipEncoder().encode(archive);
}
