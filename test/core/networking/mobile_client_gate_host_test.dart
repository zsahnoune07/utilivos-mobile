import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/networking/interceptors/mobile_client_gate_interceptor.dart';

void main() {
  const shared = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const sigSecret = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('gate headers apply for same host as Dio baseUrl', () async {
    String? xClient;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      MobileClientGateInterceptor(
        dio: dio,
        sharedSecret: shared,
        signatureSecret: sigSecret,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          xClient = options.headers['X-Client'] as String?;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
            ),
          );
        },
      ),
    );
    dio.httpClientAdapter = _ThrowAdapter();

    await expectLater(
      dio.get<dynamic>('/v1/health'),
      throwsA(isA<DioException>()),
    );
    expect(xClient, shared);
  });

  test('gate headers apply for absolute URL on different host (no host filter)', () async {
    String? xClient;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    dio.interceptors.add(
      MobileClientGateInterceptor(
        dio: dio,
        sharedSecret: shared,
        signatureSecret: sigSecret,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          xClient = options.headers['X-Client'] as String?;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
            ),
          );
        },
      ),
    );
    dio.httpClientAdapter = _ThrowAdapter();

    await expectLater(
      dio.get<dynamic>('https://cdn.example.net/file.bin'),
      throwsA(isA<DioException>()),
    );
    expect(xClient, shared);
  });
}

class _ThrowAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw StateError('adapter should not be reached');
  }
}
