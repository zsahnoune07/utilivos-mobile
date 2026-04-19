import 'package:dio/dio.dart';

import '../billing/billing_gateway.dart';
import '../billing/in_app_purchase_billing_gateway.dart';
import '../device/device_id_store.dart';
import '../device/device_identity_manager.dart';
import '../device/secure_device_id_store.dart';
import '../entitlement/entitlement_controller.dart';
import '../entitlement/entitlement_store.dart';
import '../entitlement/entitlement_verification_api.dart';
import '../entitlement/secure_entitlement_store.dart';
import '../config/app_config.dart';
import '../persistence/app_database.dart';
import '../networking/api_client.dart';
import '../networking/interceptors/device_id_interceptor.dart';
import '../networking/interceptors/mobile_client_gate_interceptor.dart';
import '../networking/interceptors/request_id_interceptor.dart';
import '../pro/folder_creation_policy.dart';
import '../pro/free_tier_usage_store.dart';
import '../pro/paywall_coordinator.dart';
import '../pro/pinning_policy.dart';
import '../pro/pro_analytics.dart';
import '../pro/pro_capability_service.dart';
import '../pro/pro_purchase_controller.dart';
import '../pro/tool_session_store.dart';
import '../sessions/drift_ephemeral_runtime_state_repository.dart';
import '../sessions/drift_tool_session_repository.dart';
import '../sessions/drift_tool_widget_repository.dart';
import '../sessions/runtime_state_scope_service.dart';
import '../sessions/tool_session_service.dart';
import '../sessions/tool_widget_service.dart';
import '../../features/discover/data/catalog_api.dart';
import '../../features/discover/data/catalog_cache_store.dart';
import '../../features/discover/data/drift_catalog_cache_store.dart';
import '../../features/downloads/application/tool_bundle_download_service.dart';
import '../../features/downloads/data/download_api.dart';
import '../../features/downloads/data/downloaded_tool_bundle_store.dart';
import '../../features/downloads/data/meta_api.dart';
import '../../features/home/data/health_api.dart';
import '../../features/installs/application/installed_tools_controller.dart';
import '../../features/installs/data/drift_installed_tools_store.dart';
import '../../features/installs/data/drift_local_install_removals_store.dart';
import '../../features/installs/data/installed_tools_store.dart';
import '../../features/installs/data/drift_installs_sync_meta_store.dart';
import '../../features/installs/data/installs_api.dart';
import '../../features/installs/data/installs_organization_store.dart';
import '../../features/installs/data/installs_sync_meta_store.dart';
import '../../features/installs/data/secure_installs_organization_store.dart';
import '../../features/downloads/data/secure_downloaded_tool_bundle_store.dart';

class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.dio,
    required this.apiClient,
    required this.deviceIdentityManager,
    required this.entitlementController,
    required this.proPurchaseController,
    required this.freeTierUsageStore,
    required this.proCapabilityService,
    required this.proAnalytics,
    required this.paywallCoordinator,
    required this.toolSessionStore,
    required this.installedToolsController,
    required this.installedToolsStore,
    required this.healthApi,
    required this.catalogApi,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.installsApi,
    required this.appDatabase,
    required this.toolSessionService,
    required this.runtimeStateScopeService,
    required this.toolWidgetService,
  });

  final AppConfig config;
  final Dio dio;
  final ApiClient apiClient;
  final DeviceIdentityManager deviceIdentityManager;
  final EntitlementController entitlementController;
  final ProPurchaseController proPurchaseController;
  final FreeTierUsageStore freeTierUsageStore;
  final ProCapabilityService proCapabilityService;
  final ProAnalytics proAnalytics;
  final PaywallCoordinator paywallCoordinator;
  final ToolSessionStore toolSessionStore;
  final InstalledToolsController installedToolsController;
  final InstalledToolsStore installedToolsStore;
  final HealthApi healthApi;
  final CatalogApi catalogApi;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final InstallsApi installsApi;

  /// Drift database (persistent on device; tests may inject [AppDatabase.memory]). [dispose] closes it.
  final AppDatabase appDatabase;

  /// Named tool sessions (Drift). UI and bridge wiring land in later phases.
  final ToolSessionService toolSessionService;

  /// Ephemeral per-launch state + cleanup helpers.
  final RuntimeStateScopeService runtimeStateScopeService;

  /// Home widget metadata (platform integration in Phase 4).
  final ToolWidgetService toolWidgetService;

  factory AppDependencies.create({
    AppConfig? config,
    DeviceIdStore? deviceIdStore,
    EntitlementStore? entitlementStore,
    CatalogCacheStore? catalogCacheStore,
    AppDatabase? appDatabase,
    InstallsSyncMetaStore? installsSyncMetaStore,
    InstalledToolsStore? installedToolsStore,
    InstallsOrganizationStore? installsOrganizationStore,
    DownloadedToolBundleStore? downloadedToolBundleStore,
    BillingGateway? billingGateway,
    Dio? dio,
    required FreeTierUsageStore freeTierUsageStore,
    ProAnalytics? proAnalytics,
  }) {
    final resolvedConfig = config ?? AppConfig.fromEnvironment();
    final resolvedDio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: resolvedConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        );

    final apiClient = ApiClient(resolvedDio);
    final resolvedDeviceIdStore = deviceIdStore ?? SecureDeviceIdStore();
    final deviceIdentityManager = DeviceIdentityManager(
      store: resolvedDeviceIdStore,
    );
    final resolvedEntitlementStore =
        entitlementStore ?? SecureEntitlementStore();
    final entitlementVerificationApi = EntitlementVerificationApi(apiClient);
    final entitlementController = EntitlementController(
      store: resolvedEntitlementStore,
      verificationApi: entitlementVerificationApi,
      packageName: resolvedConfig.androidPackageName,
    );
    final resolvedBillingGateway =
        billingGateway ?? InAppPurchaseBillingGateway();
    final proPurchaseController = ProPurchaseController(
      config: resolvedConfig,
      billingGateway: resolvedBillingGateway,
      entitlementController: entitlementController,
    );

    final resolvedAnalytics = proAnalytics ?? DebugProAnalytics();
    final proCapabilityService = ProCapabilityService(
      entitlementController: entitlementController,
      usageStore: freeTierUsageStore,
    );
    final paywallCoordinator = PaywallCoordinator(
      purchaseController: proPurchaseController,
      entitlementController: entitlementController,
      analytics: resolvedAnalytics,
    );
    final toolSessionStore = ToolSessionStore(proCapabilityService);

    resolvedDio.interceptors.add(RequestIdInterceptor());
    resolvedDio.interceptors.add(
      DeviceIdInterceptor(
        getDeviceId: () => deviceIdentityManager.currentDeviceId,
      ),
    );
    resolvedDio.interceptors.add(
      MobileClientGateInterceptor(
        dio: resolvedDio,
        sharedSecret: resolvedConfig.mobileClientSharedSecret,
        signatureSecret: resolvedConfig.mobileClientSignatureSecret,
      ),
    );

    final healthApi = HealthApi(apiClient);
    final AppDatabase resolvedDb = appDatabase ?? AppDatabase.memory();
    final CatalogCacheStore resolvedCatalogCacheStore =
        catalogCacheStore ?? DriftCatalogCacheStore(resolvedDb);
    final catalogApi = CatalogApi(
      apiClient,
      cacheStore: resolvedCatalogCacheStore,
    );
    final downloadApi = DownloadApi(apiClient);
    final metaApi = MetaApi(apiClient);
    final resolvedDownloadedToolBundleStore =
        downloadedToolBundleStore ?? SecureDownloadedToolBundleStore();
    final toolBundleDownloadService = ToolBundleDownloadService(
      dio: resolvedDio,
      store: resolvedDownloadedToolBundleStore,
      metaApi: metaApi,
      pinnedSigningRootPublicKey: resolvedConfig.pinnedSigningRootPublicKey,
    );
    final installsApi = InstallsApi(apiClient);
    final InstalledToolsStore resolvedInstalledToolsStore =
        installedToolsStore ?? DriftInstalledToolsStore(resolvedDb);
    final resolvedInstallsOrganizationStore =
        installsOrganizationStore ?? SecureInstallsOrganizationStore();
    final InstallsSyncMetaStore resolvedInstallsSyncMetaStore =
        installsSyncMetaStore ?? DriftInstallsSyncMetaStore(resolvedDb);
    final localInstallRemovalsStore = DriftLocalInstallRemovalsStore(
      resolvedDb,
    );
    final toolSessionService = ToolSessionService(
      DriftToolSessionRepository(resolvedDb),
    );
    final toolWidgetService = ToolWidgetService(
      DriftToolWidgetRepository(resolvedDb),
    );
    final installedToolsController = InstalledToolsController(
      installsApi: installsApi,
      catalogApi: catalogApi,
      store: resolvedInstalledToolsStore,
      organizationStore: resolvedInstallsOrganizationStore,
      syncMetaStore: resolvedInstallsSyncMetaStore,
      removalsStore: localInstallRemovalsStore,
      toolBundleDownloadService: toolBundleDownloadService,
      toolWidgetService: toolWidgetService,
      toolSessionService: toolSessionService,
      toolSessionStore: toolSessionStore,
      pinningPolicy: FreemiumPinningPolicy(entitlementController),
      folderCreationPolicy: FreemiumFolderCreationPolicy(entitlementController),
    );

    final runtimeStateScopeService = RuntimeStateScopeService(
      DriftEphemeralRuntimeStateRepository(resolvedDb),
    );

    return AppDependencies._(
      config: resolvedConfig,
      dio: resolvedDio,
      apiClient: apiClient,
      deviceIdentityManager: deviceIdentityManager,
      entitlementController: entitlementController,
      proPurchaseController: proPurchaseController,
      freeTierUsageStore: freeTierUsageStore,
      proCapabilityService: proCapabilityService,
      proAnalytics: resolvedAnalytics,
      paywallCoordinator: paywallCoordinator,
      toolSessionStore: toolSessionStore,
      installedToolsController: installedToolsController,
      installedToolsStore: resolvedInstalledToolsStore,
      healthApi: healthApi,
      catalogApi: catalogApi,
      downloadApi: downloadApi,
      toolBundleDownloadService: toolBundleDownloadService,
      installsApi: installsApi,
      appDatabase: resolvedDb,
      toolSessionService: toolSessionService,
      runtimeStateScopeService: runtimeStateScopeService,
      toolWidgetService: toolWidgetService,
    );
  }

  void dispose() {
    installedToolsController.dispose();
    proCapabilityService.dispose();
    proPurchaseController.dispose();
    entitlementController.dispose();
    dio.close(force: true);
    appDatabase.close();
  }
}
