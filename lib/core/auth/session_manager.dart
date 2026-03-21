import 'dart:async';

import 'access_token_store.dart';
import 'auth_api.dart';
import 'models/auth_tokens.dart';
import 'models/auth_user.dart';
import 'refresh_token_store.dart';

class SessionManager {
  SessionManager({
    required AccessTokenStore accessTokenStore,
    required RefreshTokenStore refreshTokenStore,
    required AuthApi authApi,
  }) : _accessTokenStore = accessTokenStore,
       _refreshTokenStore = refreshTokenStore,
       _authApi = authApi;

  final AccessTokenStore _accessTokenStore;
  final RefreshTokenStore _refreshTokenStore;
  final AuthApi _authApi;

  Completer<String?>? _refreshInFlight;

  String? get accessToken => _accessTokenStore.token;
  bool get hasAccessToken => _accessTokenStore.hasToken;

  Future<void> saveTokens(AuthTokens tokens) async {
    _accessTokenStore.write(tokens.accessToken);
    await _refreshTokenStore.write(tokens.refreshToken);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final tokens = await _authApi.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await saveTokens(tokens);
  }

  Future<void> login({required String email, required String password}) async {
    final tokens = await _authApi.login(email: email, password: password);
    await saveTokens(tokens);
  }

  Future<AuthUser> me() {
    return _authApi.me();
  }

  Future<void> clearTokens() async {
    _accessTokenStore.clear();
    await _refreshTokenStore.clear();
  }

  Future<void> logout() async {
    final refreshToken = await _refreshTokenStore.read();
    try {
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await _authApi.logout(refreshToken: refreshToken);
      }
    } finally {
      await clearTokens();
    }
  }

  Future<String?> refreshAccessToken() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String?>();
    _refreshInFlight = completer;
    _runRefresh(completer);
    return completer.future;
  }

  Future<void> _runRefresh(Completer<String?> completer) async {
    try {
      final refreshToken = await _refreshTokenStore.read();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        await clearTokens();
        completer.complete(null);
        return;
      }

      final refreshedTokens = await _authApi.refresh(
        refreshToken: refreshToken,
      );
      await saveTokens(refreshedTokens);
      completer.complete(refreshedTokens.accessToken);
    } catch (error, stackTrace) {
      await clearTokens();
      completer.completeError(error, stackTrace);
    } finally {
      _refreshInFlight = null;
    }
  }
}
