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
    );
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
