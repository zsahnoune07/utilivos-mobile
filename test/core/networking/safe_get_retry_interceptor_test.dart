import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/networking/interceptors/safe_get_retry_interceptor.dart';

void main() {
  test('retries GET on connection failure then succeeds', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _FailThenOkAdapter(failuresBeforeOk: 2);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(SafeGetRetryInterceptor(dio: dio, maxAttempts: 3));

    final response = await dio.get<dynamic>('/v1/health');
    expect(response.statusCode, 200);
    expect(adapter.fetchCount, 3);
  });

  test('does not retry POST', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = _FailThenOkAdapter(failuresBeforeOk: 99);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(SafeGetRetryInterceptor(dio: dio, maxAttempts: 3));

    await expectLater(dio.post<dynamic>('/v1/x'), throwsA(isA<DioException>()));
    expect(adapter.fetchCount, 1);
  });
}

class _FailThenOkAdapter implements HttpClientAdapter {
  _FailThenOkAdapter({required this.failuresBeforeOk});

  final int failuresBeforeOk;
  int fetchCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    if (fetchCount <= failuresBeforeOk) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'simulated',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
