import 'package:dio/dio.dart';

import 'models/api_error_envelope.dart';
import 'network_exception.dart';

class NetworkExceptionMapper {
  const NetworkExceptionMapper._();

  static NetworkException fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          kind: NetworkExceptionKind.timeout,
          message: 'Request timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          kind: NetworkExceptionKind.noConnection,
          message: 'No network connection available.',
        );
      case DioExceptionType.cancel:
        return const NetworkException(
          kind: NetworkExceptionKind.cancelled,
          message: 'Request was cancelled.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException(
          kind: NetworkExceptionKind.unexpected,
          message: 'TLS certificate validation failed.',
        );
      case DioExceptionType.badResponse:
        return _fromBadResponse(error);
      case DioExceptionType.unknown:
        return NetworkException(
          kind: NetworkExceptionKind.unexpected,
          message: error.message ?? 'Unexpected networking error.',
          details: <String, Object?>{
            'method': error.requestOptions.method,
            'path': error.requestOptions.path,
            'error': error.error,
          },
        );
    }
  }

  static NetworkException _fromBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final rawData = error.response?.data;

    String? code;
    String message = 'Request failed.';
    Object? details;

    if (rawData is Map<String, dynamic>) {
      try {
        final envelope = ApiErrorEnvelope.fromJson(rawData);
        code = envelope.error.code;
        message = envelope.error.message;
        details = <String, Object?>{
          'method': error.requestOptions.method,
          'path': error.requestOptions.path,
          'response_details': envelope.error.details,
        };
      } on FormatException {
        // Keep default fallback message when the error body shape is unexpected.
      }
    } else {
      details = <String, Object?>{
        'method': error.requestOptions.method,
        'path': error.requestOptions.path,
      };
    }

    final kind = switch (statusCode) {
      401 => NetworkExceptionKind.unauthorized,
      final int value when value >= 500 => NetworkExceptionKind.server,
      final int value when value >= 400 => NetworkExceptionKind.client,
      _ => NetworkExceptionKind.unexpected,
    };

    return NetworkException(
      kind: kind,
      statusCode: statusCode,
      code: code,
      message: message,
      details: details,
    );
  }
}
