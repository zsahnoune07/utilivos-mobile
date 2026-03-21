import '../../../core/networking/api_client.dart';
import '../../../core/networking/network_exception.dart';
import 'models/plugin_download_grant.dart';

class DownloadApi {
  const DownloadApi(this._apiClient);

  final ApiClient _apiClient;

  Future<PluginDownloadGrant> requestDownload({
    required String pluginSlug,
    String? entitlementAssertionToken,
  }) {
    final normalizedSlug = pluginSlug.trim();
    if (normalizedSlug.isEmpty) {
      throw const NetworkException(
        kind: NetworkExceptionKind.client,
        message: 'Cannot request download for an empty plugin slug.',
      );
    }
    final assertionToken = entitlementAssertionToken?.trim();
    return _apiClient.get<PluginDownloadGrant>(
      '/v1/plugins/${Uri.encodeComponent(normalizedSlug)}/download',
      headers: assertionToken == null || assertionToken.isEmpty
          ? null
          : <String, String>{'X-Entitlement-Assertion': assertionToken},
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException('Download payload must be an object.');
        }
        return PluginDownloadGrant.fromJson(rawData);
      },
    );
  }
}
