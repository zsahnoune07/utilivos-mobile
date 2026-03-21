import '../networking/api_client.dart';
import 'models/auth_tokens.dart';
import 'models/auth_user.dart';

class AuthApi {
  const AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _apiClient.post<AuthTokens>(
      '/v1/auth/register',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'display_name': displayName,
      },
      skipAuth: true,
      skipRefresh: true,
      decodeData: _decodeAuthTokens,
    );
  }

  Future<AuthTokens> login({required String email, required String password}) {
    return _apiClient.post<AuthTokens>(
      '/v1/auth/login',
      body: <String, dynamic>{'email': email, 'password': password},
      skipAuth: true,
      skipRefresh: true,
      decodeData: _decodeAuthTokens,
    );
  }

  Future<AuthTokens> refresh({required String refreshToken}) {
    return _apiClient.post<AuthTokens>(
      '/v1/auth/refresh',
      body: <String, dynamic>{'refresh_token': refreshToken},
      skipAuth: true,
      skipRefresh: true,
      decodeData: _decodeAuthTokens,
    );
  }

  Future<void> logout({required String refreshToken}) {
    return _apiClient.postEmpty(
      '/v1/auth/logout',
      body: <String, dynamic>{'refresh_token': refreshToken},
      skipRefresh: true,
    );
  }

  Future<AuthUser> me() {
    return _apiClient.get<AuthUser>(
      '/v1/me',
      decodeData: (Object? rawData) {
        if (rawData is! Map<String, dynamic>) {
          throw const FormatException(
            'User profile payload must be an object.',
          );
        }
        return AuthUser.fromJson(rawData);
      },
    );
  }

  AuthTokens _decodeAuthTokens(Object? rawData) {
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Auth payload must be an object.');
    }
    return AuthTokens.fromJson(rawData);
  }
}
