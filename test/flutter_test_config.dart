import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports — need [createMockImageHttpClient] (not exported).
import 'package:network_image_mock/src/network_image_mock.dart';

/// Stabilizes widget tests: plugin channels + HTTP used by [Image.network] and
/// `package:http` / [flutter_cache_manager] must not leave infinite placeholders
/// (repeating skeletons) that prevent [WidgetTester.pumpAndSettle] from finishing.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = _UtilivosTestHttpOverrides();

  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(permissions, (MethodCall call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return 1;
      case 'checkServiceStatus':
        return 1;
      case 'requestPermissions':
        final raw = call.arguments;
        if (raw is List) {
          return <int, int>{
            for (final Object? code in raw) (code as int): 1,
          };
        }
        return <int, int>{};
      case 'shouldShowRequestPermissionRationale':
        return false;
      case 'openAppSettings':
        return true;
    }
    return null;
  });

  const packageInfo = MethodChannel('dev.fluttercommunity.plus/package_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(packageInfo, (MethodCall call) async {
    return <String, dynamic>{
      'appName': 'Utilivos',
      'packageName': 'com.utilivos.utilivos_mobile',
      'version': '1.0.0',
      'buildNumber': '1',
      'buildSignature': '',
      'installerStore': '',
    };
  });

  const urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(urlLauncher, (MethodCall call) async {
    switch (call.method) {
      case 'canLaunch':
        return true;
      case 'launch':
        return true;
      case 'closeWebView':
        return null;
    }
    return null;
  });

  await testMain();
}

/// [IOClient] uses [HttpClient.openUrl]; [Image.network] uses [HttpClient.getUrl].
class _UtilivosTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner = createMockImageHttpClient();
    return _OpenUrlForwardsToGetUrl(inner);
  }
}

class _OpenUrlForwardsToGetUrl extends Fake implements HttpClient {
  _OpenUrlForwardsToGetUrl(this._inner);

  final HttpClient _inner;

  @override
  Future<HttpClientRequest> getUrl(Uri? url) {
    return _inner.getUrl(url!);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _inner.getUrl(url);
  }
}
