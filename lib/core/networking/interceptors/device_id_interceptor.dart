import 'package:dio/dio.dart';

class DeviceIdInterceptor extends Interceptor {
  DeviceIdInterceptor({
    required String? Function() getDeviceId,
    this.headerName = 'X-Device-ID',
  }) : _getDeviceId = getDeviceId;

  final String? Function() _getDeviceId;
  final String headerName;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final deviceId = _getDeviceId()?.trim();
    if (deviceId != null && deviceId.isNotEmpty) {
      options.headers[headerName] = deviceId;
    }
    handler.next(options);
  }
}
