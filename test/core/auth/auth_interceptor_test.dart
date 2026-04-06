import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/auth/access_token_store.dart';
import 'package:utilivos_mobile/core/auth/auth_api.dart';
import 'package:utilivos_mobile/core/auth/models/auth_tokens.dart';
import 'package:utilivos_mobile/core/auth/refresh_token_store.dart';
import 'package:utilivos_mobile/core/auth/session_manager.dart';
import 'package:utilivos_mobile/core/networking/api_client.dart';
import 'package:utilivos_mobile/core/networking/interceptors/auth_interceptor.dart';
import 'package:utilivos_mobile/core/networking/interceptors/request_id_interceptor.dart';

void main() {
  test('attaches bearer token and request-id header', () async {
    String? seenAuthorizationHeader;
    String? seenRequestIdHeader;

    final harness = _createHarness((RequestOptions options) async {
      seenAuthorizationHeader =
          options.headers[HttpHeaders.authorizationHeader] as String?;
      seenRequestIdHeader = options.headers['X-Request-Id'] as String?;

      return _jsonResponse(<String, dynamic>{
        'data': <String, dynamic>{'ok': true},
      }, 200);
    });
    addTearDown(harness.dispose);

    await harness.sessionManager.saveTokens(
      const AuthTokens(
        tokenType: 'Bearer',
        accessToken: 'existing_access',
        refreshToken: 'existing_refresh',
        expiresIn: 900,
      ),
    );

    final response = await harness.dio.get<Map<String, dynamic>>('/protected');
    final data = response.data?['data'] as Map<String, dynamic>;

    expect(data['ok'], true);
    expect(seenAuthorizationHeader, 'Bearer existing_access');
    expect(seenRequestIdHeader, isNotNull);
    expect(seenRequestIdHeader, isNotEmpty);
  });

  test('refreshes on 401 and retries original request', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;

    final harness = _createHarness((RequestOptions options) async {
      if (options.path == '/v1/auth/refresh') {
        refreshCalls += 1;
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'token_type': 'Bearer',
            'access_token': 'fresh_access',
            'refresh_token': 'fresh_refresh',
            'expires_in': 900,
          },
        }, 200);
      }

      if (options.path == '/protected') {
        protectedCalls += 1;
        final authorization =
            options.headers[HttpHeaders.authorizationHeader] as String?;

        if (authorization == 'Bearer expired_access') {
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'unauthorized',
              'message': 'token expired',
            },
          }, 401);
        }

        if (authorization == 'Bearer fresh_access') {
          return _jsonResponse(<String, dynamic>{
            'data': <String, dynamic>{'ok': true},
          }, 200);
        }
      }

      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unexpected',
          'message': 'Unexpected path',
        },
      }, 500);
    });
    addTearDown(harness.dispose);

    await harness.sessionManager.saveTokens(
      const AuthTokens(
        tokenType: 'Bearer',
        accessToken: 'expired_access',
        refreshToken: 'refresh_seed',
        expiresIn: 0,
      ),
    );

    final response = await harness.dio.get<Map<String, dynamic>>('/protected');
    final data = response.data?['data'] as Map<String, dynamic>;

    expect(data['ok'], true);
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
    expect(harness.accessTokenStore.token, 'fresh_access');
    expect(await harness.refreshTokenStore.read(), 'fresh_refresh');
  });

  test('uses single-flight refresh for concurrent 401 responses', () async {
    var refreshCalls = 0;

    final harness = _createHarness((RequestOptions options) async {
      if (options.path == '/v1/auth/refresh') {
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'token_type': 'Bearer',
            'access_token': 'new_access',
            'refresh_token': 'new_refresh',
            'expires_in': 900,
          },
        }, 200);
      }

      if (options.path == '/protected') {
        final authorization =
            options.headers[HttpHeaders.authorizationHeader] as String?;

        if (authorization == 'Bearer old_access') {
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'unauthorized',
              'message': 'expired',
            },
          }, 401);
        }

        if (authorization == 'Bearer new_access') {
          return _jsonResponse(<String, dynamic>{
            'data': <String, dynamic>{'ok': true},
          }, 200);
        }
      }

      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unexpected',
          'message': 'Unexpected path',
        },
      }, 500);
    });
    addTearDown(harness.dispose);

    await harness.sessionManager.saveTokens(
      const AuthTokens(
        tokenType: 'Bearer',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
        expiresIn: 0,
      ),
    );

    final responses =
        await Future.wait(<Future<Response<Map<String, dynamic>>>>[
          harness.dio.get<Map<String, dynamic>>('/protected'),
          harness.dio.get<Map<String, dynamic>>('/protected'),
        ]);

    expect(responses, hasLength(2));
    expect(refreshCalls, 1);
    expect(harness.accessTokenStore.token, 'new_access');
    expect(await harness.refreshTokenStore.read(), 'new_refresh');
  });

  test('logout clears access and refresh tokens', () async {
    var logoutCalls = 0;
    String? logoutAuthorization;

    final harness = _createHarness((RequestOptions options) async {
      if (options.path == '/v1/auth/logout') {
        logoutCalls += 1;
        logoutAuthorization =
            options.headers[HttpHeaders.authorizationHeader] as String?;
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{'logged_out': true},
        }, 200);
      }

      return _jsonResponse(<String, dynamic>{
        'data': <String, dynamic>{'ok': true},
      }, 200);
    });
    addTearDown(harness.dispose);

    await harness.sessionManager.saveTokens(
      const AuthTokens(
        tokenType: 'Bearer',
        accessToken: 'to_be_cleared',
        refreshToken: 'refresh_to_be_cleared',
        expiresIn: 900,
      ),
    );

    await harness.sessionManager.logout();

    expect(harness.accessTokenStore.token, isNull);
    expect(await harness.refreshTokenStore.read(), isNull);
    expect(logoutCalls, 1);
    expect(logoutAuthorization, 'Bearer to_be_cleared');
  });
}

_TestHarness _createHarness(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test',
      headers: const <String, String>{'Content-Type': 'application/json'},
    ),
  );
  dio.httpClientAdapter = _FakeHttpClientAdapter(responder);

  final apiClient = ApiClient(dio);
  final accessTokenStore = AccessTokenStore();
  final refreshTokenStore = _InMemoryRefreshTokenStore();
  final sessionManager = SessionManager(
    accessTokenStore: accessTokenStore,
    refreshTokenStore: refreshTokenStore,
    authApi: AuthApi(apiClient),
  );

  dio.interceptors.add(RequestIdInterceptor());
  dio.interceptors.add(
    AuthInterceptor(dio: dio, sessionManager: sessionManager),
  );

  return _TestHarness(
    dio: dio,
    sessionManager: sessionManager,
    accessTokenStore: accessTokenStore,
    refreshTokenStore: refreshTokenStore,
  );
}

ResponseBody _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _TestHarness {
  _TestHarness({
    required this.dio,
    required this.sessionManager,
    required this.accessTokenStore,
    required this.refreshTokenStore,
  });

  final Dio dio;
  final SessionManager sessionManager;
  final AccessTokenStore accessTokenStore;
  final _InMemoryRefreshTokenStore refreshTokenStore;

  void dispose() {
    dio.close(force: true);
  }
}

class _InMemoryRefreshTokenStore implements RefreshTokenStore {
  String? _token;

  @override
  Future<void> clear() async {
    _token = null;
  }

  @override
  Future<String?> read() async {
    return _token;
  }

  @override
  Future<void> write(String token) async {
    _token = token;
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._responder);

  final Future<ResponseBody> Function(RequestOptions options) _responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _responder(options);
  }
}
