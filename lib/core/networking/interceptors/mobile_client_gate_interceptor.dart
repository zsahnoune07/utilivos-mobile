import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Builds the same path + normalized query string the API uses for HMAC payloads
/// (`url.ParseQuery(RawQuery).Encode()` in Go).
String canonicalPathForMobileGateSignature(Uri uri) {
  final path = uri.path;
  if (!uri.hasQuery) {
    return path;
  }
  final all = uri.queryParametersAll;
  if (all.isEmpty) {
    return path;
  }
  final keys = all.keys.toList()..sort();
  final buf = StringBuffer(path)..write('?');
  var first = true;
  for (final k in keys) {
    for (final v in all[k]!) {
      if (!first) {
        buf.write('&');
      }
      first = false;
      buf.write(Uri.encodeQueryComponent(k));
      buf.write('=');
      buf.write(Uri.encodeQueryComponent(v));
    }
  }
  return buf.toString();
}

String mobileClientSignPayload(String method, String canonicalPath, String ts) {
  return '${method.toUpperCase()}\n$canonicalPath\n$ts';
}

String hmacSha256Hex(String secret, String payload) {
  final key = utf8.encode(secret);
  final bytes = utf8.encode(payload);
  final digest = Hmac(sha256, key).convert(bytes);
  return digest.toString();
}

/// Adds [X-Client], [X-Client-Ts], and [X-Client-Signature] when both [sharedSecret]
/// and [signatureSecret] are non-empty (typically from `--dart-define`).
class MobileClientGateInterceptor extends Interceptor {
  MobileClientGateInterceptor({
    required Dio dio,
    required String? sharedSecret,
    required String? signatureSecret,
  }) : _dio = dio,
       _shared = _trimOrNull(sharedSecret),
       _sig = _trimOrNull(signatureSecret);

  static const String _retryExtraKey = 'utilivos.mobile_client_gate_retry';

  final Dio _dio;
  final String? _shared;
  final String? _sig;

  bool get _enabled => _shared != null && _sig != null;

  static String? _trimOrNull(String? s) {
    if (s == null) {
      return null;
    }
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _applyGateHeaders(RequestOptions options) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tsStr = ts.toString();
    final canonical = canonicalPathForMobileGateSignature(options.uri);
    final payload = mobileClientSignPayload(options.method, canonical, tsStr);
    final sig = hmacSha256Hex(_sig!, payload);
    options.headers['X-Client'] = _shared;
    options.headers['X-Client-Ts'] = tsStr;
    options.headers['X-Client-Signature'] = sig;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_enabled) {
      handler.next(options);
      return;
    }
    _applyGateHeaders(options);
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_enabled) {
      handler.next(err);
      return;
    }
    if (err.requestOptions.extra[_retryExtraKey] == true) {
      handler.next(err);
      return;
    }
    final resp = err.response;
    if (resp?.statusCode != 403) {
      handler.next(err);
      return;
    }
    final data = resp?.data;
    if (data is! Map<String, dynamic>) {
      handler.next(err);
      return;
    }
    final errMap = data['error'];
    if (errMap is! Map<String, dynamic>) {
      handler.next(err);
      return;
    }
    if (errMap['code'] != 'client_verification_failed') {
      handler.next(err);
      return;
    }
    try {
      final opts = err.requestOptions.copyWith(
        extra: <String, dynamic>{
          ...err.requestOptions.extra,
          _retryExtraKey: true,
        },
      );
      _applyGateHeaders(opts);
      final response = await _dio.fetch<dynamic>(opts);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}
