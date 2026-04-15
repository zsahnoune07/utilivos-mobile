import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/features/downloads/data/models/plugin_download_grant.dart';

void main() {
  test('PluginDownloadGrant.fromJson reads expires_in_seconds and method', () {
    final grant = PluginDownloadGrant.fromJson(<String, dynamic>{
      'url': 'https://cdn.example/bundle.ubb?token=x',
      'version': '2.0.0',
      'expires_at': '2026-01-01T00:00:00.000Z',
      'expires_in_seconds': 300,
      'method': 'GET',
      'checksum_sha256': 'a' * 64,
    });

    expect(grant.expiresInSeconds, 300);
    expect(grant.method, 'GET');
    expect(grant.expiresAt?.toUtc().year, 2026);
  });
}
