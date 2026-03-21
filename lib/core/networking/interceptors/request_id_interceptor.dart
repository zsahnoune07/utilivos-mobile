import 'package:dio/dio.dart';

import '../request_id_generator.dart';

class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({this.headerName = 'X-Request-Id'});

  final String headerName;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(headerName, RequestIdGenerator.next);
    handler.next(options);
  }
}
