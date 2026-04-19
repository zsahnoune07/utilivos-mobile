import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/entitlement/entitlement_verification_api.dart';
import 'package:utilivos_mobile/core/networking/api_client.dart';
import 'package:utilivos_mobile/features/downloads/data/download_api.dart';

/// Phase-8 style smoke: server verify → Pro download GET carries assertion header.
void main() {
  test(
    'verify entitlement then download sends X-Entitlement-Assertion',
    () async {
      String? assertionHeader;

      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.smoke.test',
          headers: const <String, String>{'Content-Type': 'application/json'},
        ),
      );
      dio.httpClientAdapter = _SmokeAdapter(
        onDownload: (RequestOptions o) {
          final raw = o.headers['X-Entitlement-Assertion'];
          assertionHeader = raw is String ? raw : raw?.toString();
        },
      );

      final api = ApiClient(dio);
      final verify = EntitlementVerificationApi(api);
      final download = DownloadApi(api);

      final verification = await verify.verify(
        platform: 'android',
        productId: 'pro_sku',
        storeToken: 'store-token',
        packageName: 'com.utilivos.app',
        deviceId: 'device-1',
      );
      expect(verification.proActive, isTrue);
      expect(verification.assertionToken, 'assertion-from-server');

      final grant = await download.requestDownload(
        pluginSlug: 'demo-tool',
        entitlementAssertionToken: verification.assertionToken,
      );
      expect(grant.url, isNotEmpty);
      expect(assertionHeader, 'assertion-from-server');
    },
  );
}

class _SmokeAdapter implements HttpClientAdapter {
  _SmokeAdapter({required this.onDownload});

  final void Function(RequestOptions options) onDownload;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/v1/entitlements/verify' && options.method == 'POST') {
      return _json(<String, dynamic>{
        'data': <String, dynamic>{
          'pro_active': true,
          'assertion_token': 'assertion-from-server',
          'assertion_expires_at': '2099-01-01T00:00:00Z',
        },
      });
    }
    if (options.path == '/v1/plugins/demo-tool/download' &&
        options.method == 'GET') {
      onDownload(options);
      return _json(<String, dynamic>{
        'data': <String, dynamic>{
          'url': 'https://cdn.example/bundle.zip',
          'version': '1.0.0',
        },
      });
    }
    return _json(<String, dynamic>{
      'error': <String, dynamic>{'code': 'not_found', 'message': 'unexpected'},
    }, 404);
  }
}

ResponseBody _json(Map<String, dynamic> body, [int status = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
