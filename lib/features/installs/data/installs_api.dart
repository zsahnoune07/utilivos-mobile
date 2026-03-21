import '../../../core/networking/api_client.dart';
import '../../../core/networking/network_exception.dart';
import 'models/install_models.dart';

class InstallsApi {
  const InstallsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<DeviceInstallRecord> trackInstall({
    required String pluginSlug,
    String? version,
    String source = 'marketplace',
  }) {
    final normalizedSlug = pluginSlug.trim();
    if (normalizedSlug.isEmpty) {
      throw const NetworkException(
        kind: NetworkExceptionKind.client,
        message: 'Cannot track install for an empty plugin slug.',
      );
    }
    final normalizedVersion = version?.trim();
    final normalizedSource = switch (source.trim().toLowerCase()) {
      'marketplace' => 'marketplace',
      'grant' => 'grant',
      'external' => 'external',
      _ => 'marketplace',
    };
    return _apiClient.post<DeviceInstallRecord>(
      '/v1/plugins/${Uri.encodeComponent(normalizedSlug)}/install',
      body: <String, dynamic>{
        if (normalizedVersion != null && normalizedVersion.isNotEmpty)
          'version': normalizedVersion,
        'source': normalizedSource,
      },
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException(
            'Install tracking payload must be an object.',
          );
        }
        return DeviceInstallRecord.fromJson(rawData);
      },
    );
  }

  Future<List<DeviceInstallRecord>> listInstalls() {
    return _apiClient.get<List<DeviceInstallRecord>>(
      '/v1/installs',
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException('Installs payload must be an object.');
        }
        final rawItems = rawData['items'];
        if (rawItems is! List) {
          throw const FormatException(
            'Installs payload must include an items list.',
          );
        }

        return rawItems
            .map((Object? entry) {
              if (entry is! Map<String, dynamic>) {
                throw const FormatException(
                  'Each install record item must be an object.',
                );
              }
              return DeviceInstallRecord.fromJson(entry);
            })
            .toList(growable: false);
      },
    );
  }
}
