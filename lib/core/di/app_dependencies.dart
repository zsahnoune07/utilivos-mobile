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
import '../networking/api_client.dart';
import '../networking/interceptors/device_id_interceptor.dart';
import '../networking/interceptors/request_id_interceptor.dart';
import '../premium/folder_creation_policy.dart';
import '../premium/free_tier_usage_store.dart';
import '../premium/paywall_coordinator.dart';
import '../premium/pinning_policy.dart';
import '../premium/premium_analytics.dart';
import '../premium/premium_capability_service.dart';
import '../premium/premium_purchase_controller.dart';
import '../premium/tool_session_store.dart';
import '../../features/discover/data/catalog_api.dart';
import '../../features/discover/data/catalog_cache_store.dart';
import '../../features/discover/data/secure_catalog_cache_store.dart';
import '../../features/downloads/application/tool_bundle_download_service.dart';
import '../../features/downloads/data/download_api.dart';
import '../../features/downloads/data/downloaded_tool_bundle_store.dart';
import '../../features/home/data/health_api.dart';
import '../../features/installs/application/installed_tools_controller.dart';
import '../../features/installs/data/installed_tools_store.dart';
import '../../features/installs/data/installs_api.dart';
import '../../features/installs/data/installs_organization_store.dart';
import '../../features/installs/data/secure_installed_tools_store.dart';
import '../../features/installs/data/secure_installs_organization_store.dart';
import '../../features/downloads/data/secure_downloaded_tool_bundle_store.dart';

class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.dio,
    required this.apiClient,
    required this.deviceIdentityManager,
    required this.entitlementController,
    required this.premiumPurchaseController,
    required this.freeTierUsageStore,
    required this.premiumCapabilityService,
    required this.premiumAnalytics,
    required this.paywallCoordinator,
    required this.toolSessionStore,
    required this.installedToolsController,
    required this.healthApi,
    required this.catalogApi,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.installsApi,
  });

  final AppConfig config;
  final Dio dio;
  final ApiClient apiClient;
  final DeviceIdentityManager deviceIdentityManager;
  final EntitlementController entitlementController;
  final PremiumPurchaseController premiumPurchaseController;
  final FreeTierUsageStore freeTierUsageStore;
  final PremiumCapabilityService premiumCapabilityService;
  final PremiumAnalytics premiumAnalytics;
  final PaywallCoordinator paywallCoordinator;
  final ToolSessionStore toolSessionStore;
  final InstalledToolsController installedToolsController;
  final HealthApi healthApi;
  final CatalogApi catalogApi;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final InstallsApi installsApi;

  factory AppDependencies.create({
    AppConfig? config,
    DeviceIdStore? deviceIdStore,
    EntitlementStore? entitlementStore,
    CatalogCacheStore? catalogCacheStore,
    InstalledToolsStore? installedToolsStore,
    InstallsOrganizationStore? installsOrganizationStore,
    DownloadedToolBundleStore? downloadedToolBundleStore,
    BillingGateway? billingGateway,
    Dio? dio,
    required FreeTierUsageStore freeTierUsageStore,
    PremiumAnalytics? premiumAnalytics,
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
    final premiumPurchaseController = PremiumPurchaseController(
      config: resolvedConfig,
      billingGateway: resolvedBillingGateway,
      entitlementController: entitlementController,
    );

    final resolvedAnalytics = premiumAnalytics ?? DebugPremiumAnalytics();
    final premiumCapabilityService = PremiumCapabilityService(
      entitlementController: entitlementController,
      usageStore: freeTierUsageStore,
    );
    final paywallCoordinator = PaywallCoordinator(
      purchaseController: premiumPurchaseController,
      entitlementController: entitlementController,
      analytics: resolvedAnalytics,
    );
    final toolSessionStore = ToolSessionStore(premiumCapabilityService);

    resolvedDio.interceptors.add(RequestIdInterceptor());
    resolvedDio.interceptors.add(
      DeviceIdInterceptor(
        getDeviceId: () => deviceIdentityManager.currentDeviceId,
      ),
    );

    final healthApi = HealthApi(apiClient);
    final resolvedCatalogCacheStore =
        catalogCacheStore ?? SecureCatalogCacheStore();
    final catalogApi = CatalogApi(
      apiClient,
      cacheStore: resolvedCatalogCacheStore,
    );
    final downloadApi = DownloadApi(apiClient);
    final resolvedDownloadedToolBundleStore =
        downloadedToolBundleStore ?? SecureDownloadedToolBundleStore();
    final toolBundleDownloadService = ToolBundleDownloadService(
      dio: resolvedDio,
      store: resolvedDownloadedToolBundleStore,
    );
    final installsApi = InstallsApi(apiClient);
    final resolvedInstalledToolsStore =
        installedToolsStore ?? SecureInstalledToolsStore();
    final resolvedInstallsOrganizationStore =
        installsOrganizationStore ?? SecureInstallsOrganizationStore();
    final installedToolsController = InstalledToolsController(
      installsApi: installsApi,
      catalogApi: catalogApi,
      store: resolvedInstalledToolsStore,
      organizationStore: resolvedInstallsOrganizationStore,
      toolBundleDownloadService: toolBundleDownloadService,
      pinningPolicy: FreemiumPinningPolicy(entitlementController),
      folderCreationPolicy: FreemiumFolderCreationPolicy(entitlementController),
    );

    return AppDependencies._(
      config: resolvedConfig,
      dio: resolvedDio,
      apiClient: apiClient,
      deviceIdentityManager: deviceIdentityManager,
      entitlementController: entitlementController,
      premiumPurchaseController: premiumPurchaseController,
      freeTierUsageStore: freeTierUsageStore,
      premiumCapabilityService: premiumCapabilityService,
      premiumAnalytics: resolvedAnalytics,
      paywallCoordinator: paywallCoordinator,
      toolSessionStore: toolSessionStore,
      installedToolsController: installedToolsController,
      healthApi: healthApi,
      catalogApi: catalogApi,
      downloadApi: downloadApi,
      toolBundleDownloadService: toolBundleDownloadService,
      installsApi: installsApi,
    );
  }

  void dispose() {
    installedToolsController.dispose();
    premiumCapabilityService.dispose();
    premiumPurchaseController.dispose();
    entitlementController.dispose();
    dio.close(force: true);
  }
}
