import 'dart:io';

import 'package:dio/dio.dart';

import '../../auth/session_manager.dart';
import '../api_extra_keys.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required Dio dio, required SessionManager sessionManager})
    : _dio = dio,
      _sessionManager = sessionManager;

  final Dio _dio;
  final SessionManager _sessionManager;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final skipAuth = options.extra[ApiExtraKeys.skipAuth] == true;
    if (!skipAuth) {
      final accessToken = _sessionManager.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers[HttpHeaders.authorizationHeader] =
            'Bearer $accessToken';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final statusCode = err.response?.statusCode;

    final shouldAttemptRefresh =
        statusCode == 401 &&
        requestOptions.extra[ApiExtraKeys.skipRefresh] != true &&
        requestOptions.extra[ApiExtraKeys.retryAttempted] != true;

    if (!shouldAttemptRefresh) {
      handler.next(err);
      return;
    }

    try {
      final refreshedAccessToken = await _sessionManager.refreshAccessToken();
      if (refreshedAccessToken == null || refreshedAccessToken.isEmpty) {
        handler.next(err);
        return;
      }

      final retryOptions = requestOptions.copyWith(
        headers: <String, dynamic>{
          ...requestOptions.headers,
          HttpHeaders.authorizationHeader: 'Bearer $refreshedAccessToken',
        },
        extra: <String, dynamic>{
          ...requestOptions.extra,
          ApiExtraKeys.retryAttempted: true,
        },
      );

      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}
