import 'package:dio/dio.dart';

/// Retries **GET** requests on transient failures (connection issues, 502/503/504).
/// POST/PUT/PATCH/DELETE are never retried here to avoid duplicate side effects.
class SafeGetRetryInterceptor extends Interceptor {
  SafeGetRetryInterceptor({
    required Dio dio,
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
  }) : _dio = dio;

  final Dio _dio;
  final int maxAttempts;
  final Duration initialDelay;

  static const String _attemptKey = 'safe_get_retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (req.method.toUpperCase() != 'GET') {
      handler.next(err);
      return;
    }

    final attempt = (req.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxAttempts - 1 || !_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final delay = initialDelay * (1 << attempt);
    await Future<void>.delayed(delay);

    final mergedExtra = Map<String, dynamic>.from(req.extra);
    mergedExtra[_attemptKey] = attempt + 1;
    final nextOptions = req.copyWith(extra: mergedExtra);

    try {
      final response = await _dio.fetch<dynamic>(nextOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (e, st) {
      handler.next(
        DioException(
          requestOptions: nextOptions,
          error: e,
          stackTrace: st,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  bool _shouldRetry(DioException err) {
    final type = err.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.connectionError) {
      return true;
    }
    if (type == DioExceptionType.sendTimeout) {
      return true;
    }
    final code = err.response?.statusCode;
    if (code == 502 || code == 503 || code == 504) {
      return true;
    }
    return false;
  }
}
