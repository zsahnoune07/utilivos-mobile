import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/core/networking/network_exception.dart';

void main() {
  test('maps 5xx envelope errors to server NetworkException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((RequestOptions _) async {
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'service_unavailable',
          'message': 'database unavailable',
        },
      }, 503);
    });
    addTearDown(() => dio.close(force: true));

    final client = ApiClient(dio);

    try {
      await client.get<Map<String, dynamic>>(
        '/v1/health',
        decodeData: (Object? rawData) => rawData as Map<String, dynamic>,
      );
      fail('Expected a NetworkException.');
    } on NetworkException catch (error) {
      expect(error.kind, NetworkExceptionKind.server);
      expect(error.statusCode, 503);
      expect(error.code, 'service_unavailable');
      expect(error.message, 'database unavailable');
    }
  });

  test('maps 401 responses to unauthorized NetworkException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((RequestOptions _) async {
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'authentication required',
        },
      }, 401);
    });
    addTearDown(() => dio.close(force: true));

    final client = ApiClient(dio);

    try {
      await client.get<Map<String, dynamic>>(
        '/v1/me',
        decodeData: (Object? rawData) => rawData as Map<String, dynamic>,
      );
      fail('Expected a NetworkException.');
    } on NetworkException catch (error) {
      expect(error.kind, NetworkExceptionKind.unauthorized);
      expect(error.statusCode, 401);
      expect(error.code, 'unauthorized');
    }
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
