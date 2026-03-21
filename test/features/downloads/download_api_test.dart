import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/features/downloads/data/download_api.dart';

void main() {
  test(
    'requestDownload sends entitlement assertion header when provided',
    () async {
      RequestOptions? capturedOptions;
      final api = _createDownloadApi((RequestOptions options) async {
        capturedOptions = options;
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'url': 'https://example.test/tool.zip',
            'version': '1.0.0',
          },
        }, 200);
      });

      await api.requestDownload(
        pluginSlug: 'tool-alpha',
        entitlementAssertionToken: 'assertion-abc',
      );

      expect(
        capturedOptions?.headers['X-Entitlement-Assertion'],
        'assertion-abc',
      );
    },
  );
}

DownloadApi _createDownloadApi(
  Future<ResponseBody> Function(RequestOptions options) responder,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = _FakeHttpClientAdapter(responder);
  final apiClient = ApiClient(dio);
  return DownloadApi(apiClient);
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
