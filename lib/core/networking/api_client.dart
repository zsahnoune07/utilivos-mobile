import 'package:dio/dio.dart';

import 'api_extra_keys.dart';
import 'models/api_success_envelope.dart';
import 'network_exception.dart';
import 'network_exception_mapper.dart';

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    required ApiDataDecoder<T> decodeData,
    bool skipAuth = false,
    bool skipRefresh = false,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: _buildOptions(
          skipAuth: skipAuth,
          skipRefresh: skipRefresh,
          headers: headers,
        ),
      );
      return _decodeResponse(response.data, decodeData);
    } on DioException catch (error) {
      throw NetworkExceptionMapper.fromDioException(error);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    required ApiDataDecoder<T> decodeData,
    bool skipAuth = false,
    bool skipRefresh = false,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: _buildOptions(
          skipAuth: skipAuth,
          skipRefresh: skipRefresh,
          headers: headers,
        ),
      );
      return _decodeResponse(response.data, decodeData);
    } on DioException catch (error) {
      throw NetworkExceptionMapper.fromDioException(error);
    }
  }

  Future<void> postEmpty(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool skipAuth = false,
    bool skipRefresh = false,
  }) async {
    await post<Object?>(
      path,
      body: body,
      headers: headers,
      skipAuth: skipAuth,
      skipRefresh: skipRefresh,
      decodeData: (Object? _) => null,
    );
  }

  T _decodeResponse<T>(dynamic rawBody, ApiDataDecoder<T> decodeData) {
    if (rawBody is! Map<String, dynamic>) {
      throw const NetworkException(
        kind: NetworkExceptionKind.unexpected,
        message: 'Invalid response payload.',
      );
    }

    try {
      final envelope = ApiSuccessEnvelope<T>.fromJson(rawBody, decodeData);
      return envelope.data;
    } on FormatException catch (error) {
      throw NetworkException(
        kind: NetworkExceptionKind.unexpected,
        message: error.message,
      );
    }
  }

  Options _buildOptions({
    required bool skipAuth,
    required bool skipRefresh,
    Map<String, String>? headers,
  }) {
    return Options(
      headers: headers,
      extra: <String, dynamic>{
        if (skipAuth) ApiExtraKeys.skipAuth: true,
        if (skipRefresh) ApiExtraKeys.skipRefresh: true,
      },
    );
  }
}
