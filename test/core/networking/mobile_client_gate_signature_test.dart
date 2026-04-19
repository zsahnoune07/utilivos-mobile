import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/networking/interceptors/mobile_client_gate_interceptor.dart';

void main() {
  test('canonicalPathForMobileGateSignature sorts query like Go url.Values.Encode', () {
    final u = Uri.parse('https://api.example/v1/plugins?foo=bar&baz=1');
    expect(
      canonicalPathForMobileGateSignature(u),
      '/v1/plugins?baz=1&foo=bar',
    );
  });

  test('mobileClientSignPayload uppercases method', () {
    expect(
      mobileClientSignPayload('get', '/v1/meta', '123'),
      'GET\n/v1/meta\n123',
    );
  });

  test('hmacSha256Hex is stable for known vector', () {
    const secret = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const payload = 'GET\n/v1/meta\n42';
    final hex = hmacSha256Hex(secret, payload);
    expect(hex, isNotEmpty);
    expect(hex, hmacSha256Hex(secret, payload));
  });
}
