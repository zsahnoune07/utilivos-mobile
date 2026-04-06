import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/networking/interceptors/device_id_interceptor.dart';

void main() {
  test('attaches X-Device-ID header when id exists', () async {
    String? seenDeviceIdHeader;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      seenDeviceIdHeader = options.headers['X-Device-ID'] as String?;
      return _jsonResponse(<String, dynamic>{
        'data': <String, dynamic>{'ok': true},
      }, 200);
    });
    addTearDown(() => dio.close(force: true));

    dio.interceptors.add(DeviceIdInterceptor(getDeviceId: () => 'dev-12345'));
    await dio.get<dynamic>('/v1/health');

    expect(seenDeviceIdHeader, 'dev-12345');
  });

  test('does not attach X-Device-ID header when id is absent', () async {
    String? seenDeviceIdHeader;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      seenDeviceIdHeader = options.headers['X-Device-ID'] as String?;
      return _jsonResponse(<String, dynamic>{
        'data': <String, dynamic>{'ok': true},
      }, 200);
    });
    addTearDown(() => dio.close(force: true));

    dio.interceptors.add(DeviceIdInterceptor(getDeviceId: () => null));
    await dio.get<dynamic>('/v1/health');

    expect(seenDeviceIdHeader, isNull);
  });
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
