import '../networking/api_client.dart';
import 'models/entitlement_verification_result.dart';

class EntitlementVerificationApi {
  const EntitlementVerificationApi(this._apiClient);

  final ApiClient _apiClient;

  Future<EntitlementVerificationResult> verify({
    required String platform,
    required String productId,
    required String storeToken,
    required String packageName,
    String? deviceId,
  }) {
    return _apiClient.post<EntitlementVerificationResult>(
      '/v1/entitlements/verify',
      body: <String, dynamic>{
        'platform': platform.trim(),
        'product_id': productId.trim(),
        'store_token': storeToken.trim(),
        'package_name': packageName.trim(),
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'device_id': deviceId.trim(),
      },
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException(
            'Entitlement verification payload must be an object.',
          );
        }
        return EntitlementVerificationResult.fromJson(rawData);
      },
    );
  }
}
