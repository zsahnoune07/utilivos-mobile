import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:utilivo_mobile/app.dart';
import 'package:utilivo_mobile/core/billing/billing_gateway.dart';
import 'package:utilivo_mobile/core/billing/models/billing_models.dart';
import 'package:utilivo_mobile/core/device/device_id_store.dart';
import 'package:utilivo_mobile/core/di/app_dependencies.dart';
import 'package:utilivo_mobile/core/entitlement/entitlement_store.dart';
import 'package:utilivo_mobile/core/premium/free_tier_usage_store.dart';
import 'package:utilivo_mobile/core/entitlement/models/premium_entitlement.dart';
import 'package:utilivo_mobile/core/navigation/app_routes.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_cache_store.dart';
import 'package:utilivo_mobile/features/discover/data/models/catalog_cache_snapshot.dart';
import 'package:utilivo_mobile/features/installs/data/installed_tools_store.dart';
import 'package:utilivo_mobile/features/installs/data/models/install_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boots through splash to home shell', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(UtilivoApp(dependencies: dependencies));

    expect(find.text('Preparing Utilivo...'), findsOneWidget);
    await _pumpUtilivoReady(tester);

    // Home app bar uses a wordmark SVG; app name is exposed via semantics only.
    expect(find.bySemanticsLabel('Utilivo'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('app configures light and dark themes', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(UtilivoApp(dependencies: dependencies));
    await _pumpUtilivoReady(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('deep link to settings shows persisted anonymous device id', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies(
      initialDeviceId: 'dev-widget-settings',
    );
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      UtilivoApp(
        dependencies: dependencies,
        initialLocation: AppRoutes.settings,
      ),
    );

    await _pumpUtilivoReady(tester);
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Anonymous Device ID'), findsOneWidget);
    expect(find.textContaining('dev-widget-settings'), findsOneWidget);
  });

  testWidgets('system back from settings returns to home', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      UtilivoApp(
        dependencies: dependencies,
        initialLocation: AppRoutes.settings,
      ),
    );
    await _pumpUtilivoReady(tester);

    expect(find.text('Settings'), findsAtLeastNWidgets(1));

    await tester.binding.handlePopRoute();
    await _pumpUtilivoReady(tester);

    expect(find.bySemanticsLabel('Utilivo'), findsOneWidget);
  });

  testWidgets('settings opened from home returns to home on back', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(UtilivoApp(dependencies: dependencies));
    await _pumpUtilivoReady(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await _pumpUtilivoReady(tester);

    expect(find.text('Settings'), findsAtLeastNWidgets(1));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await _pumpUtilivoReady(tester);

    expect(find.bySemanticsLabel('Utilivo'), findsOneWidget);
  });

  testWidgets('system back from discover returns to home', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      UtilivoApp(
        dependencies: dependencies,
        initialLocation: AppRoutes.discover,
      ),
    );
    await _pumpUtilivoReady(tester);

    expect(find.text('Tool Library'), findsAtLeastNWidgets(1));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await _pumpUtilivoReady(tester);

    expect(find.bySemanticsLabel('Utilivo'), findsOneWidget);
  });

  testWidgets('discover debug route keeps Android back-stack behavior', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      UtilivoApp(
        dependencies: dependencies,
        initialLocation: AppRoutes.discoverDebug,
      ),
    );

    await _pumpUtilivoReady(tester);
    expect(find.text('Phase 1 Debug Console'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await _pumpUtilivoReady(tester);
    expect(find.text('Search tools'), findsOneWidget);
  });

  testWidgets('discover shows empty state with fallback messaging', (
    WidgetTester tester,
  ) async {
    final dependencies = await _createDependencies();
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      UtilivoApp(
        dependencies: dependencies,
        initialLocation: AppRoutes.discover,
      ),
    );
    await _pumpUtilivoReady(tester);

    expect(find.text('No tools found'), findsOneWidget);
    expect(
      find.text('Try a different category or search term to find tools.'),
      findsOneWidget,
    );
  });
}

/// Splash uses a repeating [CircularProgressIndicator], so [pumpAndSettle]
/// never completes there; advance time until bootstrap navigates away.
Future<void> _pumpPastIndeterminateSplash(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Preparing Utilivo...').evaluate().isEmpty) {
      break;
    }
  }
  await tester.pump();
}

/// Home ([InstallsPage]) SVG assets keep the frame pipeline busy, so avoid
/// [pumpAndSettle] after bootstrap; pump until the shell is recognizable.
Future<void> _pumpUtilivoReady(WidgetTester tester) async {
  await _pumpPastIndeterminateSplash(tester);
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.bySemanticsLabel('Utilivo').evaluate().isNotEmpty) {
      return;
    }
    if (find.text('Settings').evaluate().isNotEmpty) {
      return;
    }
    if (find.text('Tool Library').evaluate().isNotEmpty) {
      return;
    }
    if (find.text('Phase 1 Debug Console').evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<AppDependencies> _createDependencies({
  Future<ResponseBody> Function(RequestOptions options)? responder,
  String initialDeviceId = 'dev-widget-default',
}) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test',
      headers: const <String, String>{'Content-Type': 'application/json'},
    ),
  );
  dio.httpClientAdapter = _FakeHttpClientAdapter(responder ?? _defaultResponse);

  final usage = await FreeTierUsageStore.open();
  return AppDependencies.create(
    dio: dio,
    deviceIdStore: _InMemoryDeviceIdStore(initialValue: initialDeviceId),
    entitlementStore: _InMemoryEntitlementStore(),
    catalogCacheStore: _InMemoryCatalogCacheStore(),
    installedToolsStore: _InMemoryInstalledToolsStore(),
    billingGateway: _FakeBillingGateway(),
    freeTierUsageStore: usage,
  );
}

Future<ResponseBody> _defaultResponse(RequestOptions options) async {
  if (options.path == '/v1/categories') {
    return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
  }

  if (options.path == '/v1/plugins') {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{'items': <dynamic>[], 'next_cursor': null},
    }, 200);
  }

  if (options.path == '/v1/installs') {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{'items': <dynamic>[]},
    }, 200);
  }

  if (options.path == '/v1/health') {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{'status': 'ok'},
    }, 200);
  }

  if (options.path.endsWith('/versions')) {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{'items': <dynamic>[]},
    }, 200);
  }

  if (options.path.endsWith('/install') && options.method == 'POST') {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{
        'ID': 'install_1',
        'DeviceID': 'dev-widget-default',
        'PluginID': 'plugin_1',
        'PluginSlug': 'plugin-slug',
        'InstalledVersionID': 'version_1',
        'InstalledVersion': '1.0.0',
        'Source': 'marketplace',
        'InstalledAt': '2026-03-03T10:00:00Z',
        'UpdatedAt': '2026-03-03T10:00:00Z',
      },
    }, 200);
  }

  if (options.path.startsWith('/v1/plugins/')) {
    return _jsonResponse(<String, dynamic>{
      'data': <String, dynamic>{
        'ID': 'plugin_1',
        'Slug': 'plugin-slug',
        'Name': 'Plugin One',
        'CategorySlug': 'dev-tools',
        'CategoryName': 'Dev Tools',
        'PricingType': 'free',
        'ShortDescription': 'Short',
      },
    }, 200);
  }

  return _jsonResponse(<String, dynamic>{
    'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
  }, 404);
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

class _InMemoryDeviceIdStore implements DeviceIdStore {
  _InMemoryDeviceIdStore({String? initialValue}) : _value = initialValue;

  String? _value;

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<String?> read() async {
    return _value;
  }

  @override
  Future<void> write(String deviceId) async {
    _value = deviceId;
  }
}

class _InMemoryEntitlementStore implements EntitlementStore {
  PremiumEntitlement? _entitlement;

  @override
  Future<void> clear() async {
    _entitlement = null;
  }

  @override
  Future<PremiumEntitlement?> read() async {
    return _entitlement;
  }

  @override
  Future<void> write(PremiumEntitlement entitlement) async {
    _entitlement = entitlement;
  }
}

class _FakeBillingGateway implements BillingGateway {
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
  Future<bool> isAvailable() async {
    return false;
  }

  @override
  Future<List<BillingProduct>> queryProducts(Set<String> productIds) async {
    return const <BillingProduct>[];
  }

  @override
  Future<void> restorePurchases() async {}
}

class _InMemoryInstalledToolsStore implements InstalledToolsStore {
  List<DeviceInstallRecord> _value = const <DeviceInstallRecord>[];

  @override
  Future<void> clear() async {
    _value = const <DeviceInstallRecord>[];
  }

  @override
  Future<List<DeviceInstallRecord>> read() async {
    return _value;
  }

  @override
  Future<void> write(List<DeviceInstallRecord> installs) async {
    _value = installs;
  }
}

class _InMemoryCatalogCacheStore implements CatalogCacheStore {
  CatalogCacheSnapshot _snapshot = CatalogCacheSnapshot.empty;

  @override
  Future<void> clear() async {
    _snapshot = CatalogCacheSnapshot.empty;
  }

  @override
  Future<CatalogCacheSnapshot> read() async {
    return _snapshot;
  }

  @override
  Future<void> write(CatalogCacheSnapshot snapshot) async {
    _snapshot = snapshot;
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
