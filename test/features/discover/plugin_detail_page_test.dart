import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utilivos_mobile/core/billing/billing_gateway.dart';
import 'package:utilivos_mobile/core/billing/models/billing_models.dart';
import 'package:utilivos_mobile/core/config/app_config.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_controller.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivos_mobile/core/entitlement/models/pro_entitlement.dart';
import 'package:utilivos_mobile/core/pro/free_tier_usage_store.dart';
import 'package:utilivos_mobile/core/pro/paywall_coordinator.dart';
import 'package:utilivos_mobile/core/pro/pro_analytics.dart';
import 'package:utilivos_mobile/core/pro/pro_capability_service.dart';
import 'package:utilivos_mobile/core/networking/api_client.dart';
import 'package:utilivos_mobile/core/pro/pro_purchase_controller.dart';
import 'package:utilivos_mobile/features/discover/data/catalog_api.dart';
import 'package:utilivos_mobile/features/discover/data/models/catalog_models.dart';
import 'package:utilivos_mobile/features/discover/presentation/plugin_detail_page.dart';
import 'package:utilivos_mobile/features/downloads/application/tool_bundle_download_service.dart';
import 'package:utilivos_mobile/features/downloads/data/download_api.dart';
import 'package:utilivos_mobile/features/downloads/data/downloaded_tool_bundle_store.dart';
import 'package:utilivos_mobile/features/downloads/data/meta_api.dart';
import 'package:utilivos_mobile/features/downloads/data/models/downloaded_tool_bundle.dart';
import 'package:utilivos_mobile/features/installs/application/installed_tools_controller.dart';
import 'package:utilivos_mobile/features/installs/data/installed_tools_read_result.dart';
import 'package:utilivos_mobile/features/installs/data/installed_tools_store.dart';
import 'package:utilivos_mobile/features/installs/data/installs_api.dart';
import 'package:utilivos_mobile/features/installs/data/installs_organization_store.dart';
import 'package:utilivos_mobile/features/installs/data/models/install_models.dart';
import 'package:utilivos_mobile/features/installs/data/models/installs_organization_models.dart';

import '../../support/pump_tool_thumbnail_ui.dart';

void main() {
  testWidgets(
    'Pro-locked detail shows upgrade CTA and disabled Open Tool when purchase is unavailable',
    (WidgetTester tester) async {
      final harness = await _PluginDetailHarness.create(
        pricingType: 'pro',
        entitlementActive: false,
        initializeBilling: false,
        proPreview: false,
      );
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.widget);
      await pumpToolThumbnailUiSettled(tester);

      expect(find.text('Pro required'), findsOneWidget);
      expect(find.text('Go Pro'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);

      final upgradeButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Go Pro'),
      );
      // Hard-locked Pro opens the paywall sheet (not direct IAP); enabled even
      // when the billing store is unavailable.
      expect(upgradeButton.onPressed, isNotNull);

      final openToolButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Open Tool'),
      );
      expect(openToolButton.onPressed, isNull);
    },
  );

  testWidgets(
    'API pricing_type premium shows Go Pro when locked (no preview)',
    (WidgetTester tester) async {
      final harness = await _PluginDetailHarness.create(
        pricingType: 'premium',
        entitlementActive: false,
        initializeBilling: false,
        proPreview: false,
      );
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.widget);
      await pumpToolThumbnailUiSettled(tester);

      expect(find.text('Go Pro'), findsOneWidget);
      expect(find.text('Install'), findsNothing);
    },
  );

  testWidgets(
    'Pro-locked detail enables upgrade CTA when billing products are available',
    (WidgetTester tester) async {
      final harness = await _PluginDetailHarness.create(
        pricingType: 'pro',
        entitlementActive: false,
        initializeBilling: true,
        proPreview: false,
      );
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.widget);
      await pumpToolThumbnailUiSettled(tester);

      final upgradeButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Go Pro'),
      );
      expect(upgradeButton.onPressed, isNotNull);
    },
  );

  testWidgets('Pro unlocked detail shows install CTA', (
    WidgetTester tester,
  ) async {
    final harness = await _PluginDetailHarness.create(
      pricingType: 'pro',
      entitlementActive: true,
      initializeBilling: false,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await pumpToolThumbnailUiSettled(tester);

    expect(find.text('Pro active'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Restore purchases'), findsNothing);

    final installButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Install'),
    );
    expect(installButton.onPressed, isNotNull);
  });

  testWidgets('install does not auto-open runtime after completion', (
    WidgetTester tester,
  ) async {
    final harness = await _PluginDetailHarness.create(
      pricingType: 'free',
      entitlementActive: true,
      initializeBilling: false,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.widget);
    await pumpToolThumbnailUiSettled(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Install'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Launching tool'), findsNothing);
    expect(find.text('Tool Details'), findsOneWidget);
  });
}

class _PluginDetailHarness {
  _PluginDetailHarness({
    required this.widget,
    required this.dio,
    required this.entitlementController,
    required this.proPurchaseController,
    required this.installedToolsController,
    required this.proCapabilityService,
  });

  final Widget widget;
  final Dio dio;
  final EntitlementController entitlementController;
  final ProPurchaseController proPurchaseController;
  final InstalledToolsController installedToolsController;
  final ProCapabilityService proCapabilityService;

  static const _slug = 'pro-tool';
  static const _config = AppConfig(
    appName: 'Utilivos',
    apiBaseUrl: 'https://api.example.test',
    androidPackageName: 'com.utilivos.app',
    proOneTimeProductId: 'utilivos_pro_one_time',
    proSubscriptionProductId: 'utilivos_pro_subscription',
    proSubscriptionMonthlyBasePlanId: 'monthly',
    proSubscriptionAnnualBasePlanId: 'annual',
  );

  static Future<_PluginDetailHarness> create({
    required String pricingType,
    required bool entitlementActive,
    required bool initializeBilling,
    bool proPreview = false,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: _config.apiBaseUrl));
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: _slug,
      pluginName: 'Pro Tool',
      version: '1.0.0',
    );
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/plugins/$_slug') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'ID': 'plugin_1',
            'Slug': _slug,
            'Name': 'Pro Tool',
            'CategorySlug': 'productivity',
            'CategoryName': 'Productivity',
            'PricingType': pricingType,
            'ShortDescription': 'Short description',
            if (CatalogPlugin.tierIsPro(pricingType)) 'pro_preview': proPreview,
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$_slug/versions') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'ID': 'version_1',
                'Version': '1.0.0',
                'Changelog': 'Initial',
              },
            ],
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$_slug/install' &&
          options.method == 'POST') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'ID': 'install_1',
            'DeviceID': 'device_1',
            'PluginID': 'plugin_1',
            'PluginSlug': _slug,
            'InstalledVersionID': 'version_1',
            'InstalledVersion': '1.0.0',
            'Source': 'marketplace',
            'InstalledAt': '2026-03-06T10:00:00Z',
            'UpdatedAt': '2026-03-06T10:00:00Z',
          },
        }, 200);
      }

      if (options.path == '/v1/plugins/$_slug/download') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'url': 'https://cdn.example.test/pro-tool.bundle',
            'version': '1.0.0',
            'checksum_sha256': null,
          },
        }, 200);
      }

      if (options.path == '/v1/installs') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{'items': <dynamic>[]},
        }, 200);
      }

      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404);
    });

    final apiClient = ApiClient(dio);
    final entitlementStore = _InMemoryEntitlementStore(
      initialValue: entitlementActive ? _activeEntitlement() : null,
    );
    final entitlementController = EntitlementController(
      store: entitlementStore,
    );
    await entitlementController.bootstrap();

    final billingGateway = _FakeBillingGateway(
      storeAvailable: initializeBilling,
      products: initializeBilling
          ? const <BillingProduct>[
              BillingProduct(
                id: 'utilivos_pro_one_time',
                title: 'Utilivos Pro',
                description: 'Unlock Pro tools',
                price: '\$9.99',
              ),
            ]
          : const <BillingProduct>[],
    );
    final proPurchaseController = ProPurchaseController(
      config: _config,
      billingGateway: billingGateway,
      entitlementController: entitlementController,
    );
    if (initializeBilling) {
      await proPurchaseController.initialize();
    }

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final usageStore = await FreeTierUsageStore.open();
    final proCapabilityService = ProCapabilityService(
      entitlementController: entitlementController,
      usageStore: usageStore,
    );
    final paywallCoordinator = PaywallCoordinator(
      purchaseController: proPurchaseController,
      entitlementController: entitlementController,
      analytics: DebugProAnalytics(),
    );

    final catalogApi = CatalogApi(apiClient);
    final installsApi = InstallsApi(apiClient);
    final installedToolsController = InstalledToolsController(
      installsApi: installsApi,
      catalogApi: catalogApi,
      store: _InMemoryInstalledToolsStore(),
      organizationStore: _InMemoryInstallsOrganizationStore(),
    );

    final widget = MaterialApp(
      home: PluginDetailPage(
        slug: _slug,
        config: _config,
        catalogApi: catalogApi,
        downloadApi: DownloadApi(apiClient),
        toolBundleDownloadService: ToolBundleDownloadService(
          dio: dio,
          store: _InMemoryDownloadedToolBundleStore(),
          metaApi: MetaApi(apiClient),
          baseDirectoryProvider: () async => Directory.systemTemp,
          downloadFile:
              (
                Uri uri,
                String savePath,
                void Function(int received, int total)? onReceiveProgress,
              ) async {
                await File(savePath).writeAsBytes(bundleBytes, flush: true);
                onReceiveProgress?.call(bundleBytes.length, bundleBytes.length);
              },
        ),
        installsApi: installsApi,
        installedToolsController: installedToolsController,
        entitlementController: entitlementController,
        proPurchaseController: proPurchaseController,
        proCapabilityService: proCapabilityService,
        paywallCoordinator: paywallCoordinator,
      ),
    );

    return _PluginDetailHarness(
      widget: widget,
      dio: dio,
      entitlementController: entitlementController,
      proPurchaseController: proPurchaseController,
      installedToolsController: installedToolsController,
      proCapabilityService: proCapabilityService,
    );
  }

  Future<void> dispose() async {
    proCapabilityService.dispose();
    installedToolsController.dispose();
    proPurchaseController.dispose();
    entitlementController.dispose();
    dio.close(force: true);
  }

  static ProEntitlement _activeEntitlement() {
    final now = DateTime.now().toUtc();
    return ProEntitlement(
      proActive: true,
      updatedAt: now,
      entitlementType: 'one_time',
      productId: _config.proOneTimeProductId,
      purchaseToken: 'purchase-token-1',
      graceExpiresAt: now.add(const Duration(days: 1)),
      lastVerificationAt: now,
      verificationSource: 'test_fixture',
    );
  }
}

class _InMemoryEntitlementStore implements EntitlementStore {
  _InMemoryEntitlementStore({ProEntitlement? initialValue})
    : _value = initialValue;

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

class _InMemoryInstalledToolsStore implements InstalledToolsStore {
  List<DeviceInstallRecord> _value = const <DeviceInstallRecord>[];
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

class _InMemoryDownloadedToolBundleStore implements DownloadedToolBundleStore {
  List<DownloadedToolBundle> _value = const <DownloadedToolBundle>[];

  @override
  Future<void> clear() async {
    _value = const <DownloadedToolBundle>[];
  }

  @override
  Future<List<DownloadedToolBundle>> read() async {
    return _value;
  }

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) async {
    _value = bundles;
  }
}

class _FakeBillingGateway implements BillingGateway {
  _FakeBillingGateway({required this.storeAvailable, required this.products});

  final bool storeAvailable;
  final List<BillingProduct> products;
  final StreamController<BillingPurchaseUpdate> _updates =
      StreamController<BillingPurchaseUpdate>.broadcast();

  @override
  Stream<BillingPurchaseUpdate> get purchaseUpdates => _updates.stream;

  @override
  Future<void> buyNonConsumable(String productId) async {}

  @override
  Future<void> buyProduct(String productId) async {}

  @override
  Future<void> buySubscriptionPlan(ProSubscriptionPlan plan) async {}

  @override
  void dispose() {
    _updates.close();
  }

  @override
  Future<bool> isAvailable() async {
    return storeAvailable;
  }

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    return products
        .where((BillingProduct product) => productIds.contains(product.id))
        .toList(growable: false);
  }

  @override
  Future<void> restorePurchases() async {}
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

List<int> _buildBundleArchiveBytes({
  required String pluginSlug,
  required String pluginName,
  required String version,
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('manifest.json', '''
{
  "id": "com.utilivos.plugin.$pluginSlug",
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
