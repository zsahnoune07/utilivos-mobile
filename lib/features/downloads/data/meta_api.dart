import '../../../core/networking/api_client.dart';
import 'models/signing_metadata.dart';

class MetaApi {
  const MetaApi(this._apiClient);

  final ApiClient _apiClient;

  Future<SigningMetadata> fetchSigningMetadata() {
    return _apiClient.get<SigningMetadata>(
      '/v1/meta',
      skipAuth: true,
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException('Meta payload must be an object.');
        }
        return SigningMetadata.fromJson(rawData);
      },
    );
  }
}
