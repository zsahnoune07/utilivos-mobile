class AppConfig {
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.androidPackageName,
    required this.proOneTimeProductId,
    required this.proSubscriptionProductId,
    required this.proSubscriptionMonthlyProductId,
    required this.proSubscriptionAnnualProductId,
    this.localToolBundlePath,
    this.localToolBundleSlug,
    this.localToolBundleVersion,
    this.toolReportSubmitUrl,
    this.iosAppStoreId,
  });

  final String appName;
  final String apiBaseUrl;
  final String androidPackageName;
  final String proOneTimeProductId;

  /// Legacy single subscription id; used as fallback when monthly/annual are empty.
  final String proSubscriptionProductId;
  final String proSubscriptionMonthlyProductId;
  final String proSubscriptionAnnualProductId;
  final String? localToolBundlePath;
  final String? localToolBundleSlug;
  final String? localToolBundleVersion;

  /// Future HTTP endpoint for tool issue reports (optional until backend exists).
  final String? toolReportSubmitUrl;

  /// Numeric App Store id for "Update app" links (e.g. `123456789`). Optional.
  final String? iosAppStoreId;

  factory AppConfig.fromEnvironment() {
    const appName = String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'Utilivo',
    );
    const configuredBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    );
    const androidPackageName = String.fromEnvironment(
      'ANDROID_PACKAGE_NAME',
      defaultValue: 'com.utilivo.utilivo_mobile',
    );
    const proOneTimeProductId = String.fromEnvironment(
      'PREMIUM_ONE_TIME_PRODUCT_ID',
      defaultValue: 'utilivo_pro_one_time',
    );
    const proSubscriptionProductId = String.fromEnvironment(
      'PREMIUM_SUBSCRIPTION_PRODUCT_ID',
      defaultValue: 'utilivo_pro_subscription',
    );
    const proSubscriptionMonthlyProductId = String.fromEnvironment(
      'PREMIUM_SUBSCRIPTION_MONTHLY_PRODUCT_ID',
      defaultValue: '',
    );
    const proSubscriptionAnnualProductId = String.fromEnvironment(
      'PREMIUM_SUBSCRIPTION_ANNUAL_PRODUCT_ID',
      defaultValue: '',
    );
    const localToolBundlePath = String.fromEnvironment(
      'LOCAL_TOOL_BUNDLE_PATH',
    );
    const localToolBundleSlug = String.fromEnvironment(
      'LOCAL_TOOL_BUNDLE_SLUG',
    );
    const localToolBundleVersion = String.fromEnvironment(
      'LOCAL_TOOL_BUNDLE_VERSION',
    );
    const toolReportSubmitUrl = String.fromEnvironment(
      'TOOL_REPORT_SUBMIT_URL',
    );
    const iosAppStoreId = String.fromEnvironment(
      'IOS_APP_STORE_ID',
    );

    return AppConfig(
      appName: appName.trim().isEmpty ? 'Utilivo' : appName.trim(),
      apiBaseUrl: _normalizeBaseUrl(configuredBaseUrl),
      androidPackageName: _normalizeNonEmpty(
        androidPackageName,
        fallback: 'com.utilivo.utilivo_mobile',
      ),
      proOneTimeProductId: _normalizeNonEmpty(
        proOneTimeProductId,
        fallback: 'utilivo_pro_one_time',
      ),
      proSubscriptionProductId: proSubscriptionProductId.trim(),
      proSubscriptionMonthlyProductId:
          proSubscriptionMonthlyProductId.trim(),
      proSubscriptionAnnualProductId:
          proSubscriptionAnnualProductId.trim(),
      localToolBundlePath: _normalizeOptional(localToolBundlePath),
      localToolBundleSlug: _normalizeOptional(localToolBundleSlug),
      localToolBundleVersion: _normalizeOptional(localToolBundleVersion),
      toolReportSubmitUrl: _normalizeOptional(toolReportSubmitUrl),
      iosAppStoreId: _normalizeOptional(iosAppStoreId),
    );
  }

  /// Google Play deep link for this app.
  Uri get androidPlayStoreListingUri {
    return Uri.parse(
      'https://play.google.com/store/apps/details?id=${Uri.encodeComponent(androidPackageName)}',
    );
  }

  /// App Store HTTPS link when [iosAppStoreId] is configured.
  Uri? get iosAppStoreListingUri {
    final id = iosAppStoreId?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    return Uri.parse('https://apps.apple.com/app/id$id');
  }

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'http://10.0.2.2:8080';
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static String _normalizeNonEmpty(String value, {required String fallback}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  static String? _normalizeOptional(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
