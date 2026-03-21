import '../../../core/networking/api_client.dart';

class HealthStatus {
  const HealthStatus({required this.status});

  final String status;
}

class HealthApi {
  const HealthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<HealthStatus> fetchHealthStatus() {
    return _apiClient.get<HealthStatus>(
      '/v1/health',
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException('Health payload must be an object.');
        }
        final status = rawData['status'] as String?;
        if (status == null || status.trim().isEmpty) {
          throw const FormatException('Health payload must contain status.');
        }
        return HealthStatus(status: status);
      },
    );
  }
}
