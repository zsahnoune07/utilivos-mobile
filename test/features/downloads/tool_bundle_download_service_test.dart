import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:utilivo_mobile/features/downloads/application/tool_bundle_download_service.dart';
import 'package:utilivo_mobile/features/downloads/data/downloaded_tool_bundle_store.dart';
import 'package:utilivo_mobile/features/downloads/data/models/downloaded_tool_bundle.dart';
import 'package:utilivo_mobile/features/downloads/data/models/plugin_download_grant.dart';

void main() {
  test(
    'downloadBundle persists metadata and hash when checksum matches',
    () async {
      final tmpDir = await Directory.systemTemp.createTemp(
        'utilivo-download-test-',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });

      final store = _InMemoryDownloadedToolBundleStore();
      final bundleBytes = _buildBundleArchiveBytes(
        pluginSlug: 'tool-alpha',
        pluginName: 'Tool Alpha',
        version: '1.0.0',
      );
      final bundleChecksum = sha256.convert(bundleBytes).toString();
      final service = ToolBundleDownloadService(
        dio: Dio(),
        store: store,
        baseDirectoryProvider: () async => tmpDir,
        downloadFile:
            (
              Uri uri,
              String savePath,
              void Function(int received, int total)? onReceiveProgress,
            ) async {
              await File(savePath).writeAsBytes(bundleBytes, flush: true);
              onReceiveProgress?.call(bundleBytes.length, bundleBytes.length);
            },
      );

      final result = await service.downloadBundle(
        pluginSlug: 'tool-alpha',
        grant: PluginDownloadGrant(
          url: 'https://example.test/bundle',
          version: '1.0.0',
          checksumSha256: bundleChecksum,
        ),
      );

      expect(result.isRunnable, true);
      expect(result.entryFilePath, isNotNull);
      expect(await File(result.entryFilePath!).exists(), true);
      expect(result.pluginSlug, 'tool-alpha');
      expect(await File(result.localPath).exists(), true);
      expect((await store.read()), hasLength(1));
    },
  );

  test('downloadBundle extracts icon metadata and accent color once', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'utilivo-download-test-',
    );
    addTearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    final store = _InMemoryDownloadedToolBundleStore();
    final iconBytes = _buildSolidPngBytes(220, 32, 32);
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: 'tool-colored',
      pluginName: 'Tool Colored',
      version: '1.0.0',
      iconPathInManifest: 'assets/icon.png',
      iconFileBytes: iconBytes,
    );
    final service = ToolBundleDownloadService(
      dio: Dio(),
      store: store,
      baseDirectoryProvider: () async => tmpDir,
      downloadFile:
          (
            Uri uri,
            String savePath,
            void Function(int received, int total)? onReceiveProgress,
          ) async {
            await File(savePath).writeAsBytes(bundleBytes, flush: true);
          },
    );

    final result = await service.downloadBundle(
      pluginSlug: 'tool-colored',
      grant: const PluginDownloadGrant(
        url: 'https://example.test/bundle',
        version: '1.0.0',
      ),
    );

    expect(result.iconPath, isNotNull);
    expect(result.iconAccentColor, isNotNull);
    expect(result.iconAccentColor!.startsWith('#'), isTrue);
    expect((await store.read()).first.iconAccentColor, result.iconAccentColor);
  });

  test('downloadBundle throws integrity exception on hash mismatch', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'utilivo-download-test-',
    );
    addTearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    final store = _InMemoryDownloadedToolBundleStore();
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: 'tool-alpha',
      pluginName: 'Tool Alpha',
      version: '1.0.0',
    );
    final service = ToolBundleDownloadService(
      dio: Dio(),
      store: store,
      baseDirectoryProvider: () async => tmpDir,
      downloadFile:
          (
            Uri uri,
            String savePath,
            void Function(int received, int total)? onReceiveProgress,
          ) async {
            await File(savePath).writeAsBytes(bundleBytes, flush: true);
          },
    );

    await expectLater(
      () => service.downloadBundle(
        pluginSlug: 'tool-alpha',
        grant: const PluginDownloadGrant(
          url: 'https://example.test/bundle',
          version: '1.0.0',
          checksumSha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ),
      throwsA(isA<ToolBundleIntegrityException>()),
    );
    expect((await store.read()), isEmpty);
  });

  test('downloadBundle rejects unsupported tier values', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'utilivo-download-test-',
    );
    addTearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    final store = _InMemoryDownloadedToolBundleStore();
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: 'tool-alpha',
      pluginName: 'Tool Alpha',
      version: '1.0.0',
    );
    final service = ToolBundleDownloadService(
      dio: Dio(),
      store: store,
      baseDirectoryProvider: () async => tmpDir,
      downloadFile:
          (
            Uri uri,
            String savePath,
            void Function(int received, int total)? onReceiveProgress,
          ) async {
            await File(savePath).writeAsBytes(bundleBytes, flush: true);
          },
    );

    await expectLater(
      () => service.downloadBundle(
        pluginSlug: 'tool-alpha',
        grant: const PluginDownloadGrant(
          url: 'https://example.test/bundle',
          version: '1.0.0',
          tier: 'standard',
        ),
      ),
      throwsA(isA<ToolBundleFormatException>()),
    );
  });

  test(
    'downloadBundle rejects Pro-tier grants without signature metadata',
    () async {
      final tmpDir = await Directory.systemTemp.createTemp(
        'utilivo-download-test-',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });

      final store = _InMemoryDownloadedToolBundleStore();
      final bundleBytes = _buildBundleArchiveBytes(
        pluginSlug: 'tool-premium',
        pluginName: 'Tool Pro',
        version: '1.0.0',
      );
      final service = ToolBundleDownloadService(
        dio: Dio(),
        store: store,
        baseDirectoryProvider: () async => tmpDir,
        downloadFile:
            (
              Uri uri,
              String savePath,
              void Function(int received, int total)? onReceiveProgress,
            ) async {
              await File(savePath).writeAsBytes(bundleBytes, flush: true);
            },
      );

      await expectLater(
        () => service.downloadBundle(
          pluginSlug: 'tool-premium',
          grant: const PluginDownloadGrant(
            url: 'https://example.test/bundle',
            version: '1.0.0',
            tier: 'premium',
          ),
        ),
        throwsA(isA<ToolBundleFormatException>()),
      );
    },
  );

  test('verifyBundleIntegrity detects tampered bundle archive', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'utilivo-download-test-',
    );
    addTearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    final store = _InMemoryDownloadedToolBundleStore();
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: 'tool-alpha',
      pluginName: 'Tool Alpha',
      version: '1.0.0',
    );
    final service = ToolBundleDownloadService(
      dio: Dio(),
      store: store,
      baseDirectoryProvider: () async => tmpDir,
      downloadFile:
          (
            Uri uri,
            String savePath,
            void Function(int received, int total)? onReceiveProgress,
          ) async {
            await File(savePath).writeAsBytes(bundleBytes, flush: true);
          },
    );

    final result = await service.downloadBundle(
      pluginSlug: 'tool-alpha',
      grant: const PluginDownloadGrant(
        url: 'https://example.test/bundle',
        version: '1.0.0',
      ),
    );
    expect(await service.verifyBundleIntegrity(result), isTrue);

    await File(result.localPath).writeAsBytes(<int>[1, 2, 3, 4], flush: true);
    expect(await service.verifyBundleIntegrity(result), isFalse);
  });

  test(
    'findRunnableBundle upgrades legacy stored metadata from local archive',
    () async {
      final tmpDir = await Directory.systemTemp.createTemp(
        'utilivo-download-test-',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });

      final archivePath = '${tmpDir.path}/tool-alpha-1.0.0.bundle';
      final bundleBytes = _buildBundleArchiveBytes(
        pluginSlug: 'tool-alpha',
        pluginName: 'Tool Alpha',
        version: '1.0.0',
      );
      await File(archivePath).writeAsBytes(bundleBytes, flush: true);

      final legacyBundle = DownloadedToolBundle(
        pluginSlug: 'tool-alpha',
        version: '1.0.0',
        localPath: archivePath,
        sha256: sha256.convert(bundleBytes).toString(),
        downloadedAt: DateTime.now().toUtc(),
      );
      final store = _InMemoryDownloadedToolBundleStore();
      await store.write(<DownloadedToolBundle>[legacyBundle]);
      final service = ToolBundleDownloadService(
        dio: Dio(),
        store: store,
        baseDirectoryProvider: () async => tmpDir,
      );

      final runnable = await service.findRunnableBundle('tool-alpha');
      expect(runnable, isNotNull);
      expect(runnable!.isRunnable, true);
      expect(await File(runnable.entryFilePath!).exists(), true);

      final persisted = await store.read();
      expect(persisted, hasLength(1));
      expect(persisted.first.entryFilePath, isNotNull);
    },
  );

  test(
    'importBundleFromFile persists runnable metadata from local .ubb',
    () async {
      final tmpDir = await Directory.systemTemp.createTemp(
        'utilivo-import-test-',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });

      final sourceArchivePath = '${tmpDir.path}/btc-util-1.0.0.ubb';
      final bundleBytes = _buildBundleArchiveBytes(
        pluginSlug: 'btc-util',
        pluginName: 'BTC Util',
        version: '1.0.0',
      );
      await File(sourceArchivePath).writeAsBytes(bundleBytes, flush: true);

      final store = _InMemoryDownloadedToolBundleStore();
      final service = ToolBundleDownloadService(
        dio: Dio(),
        store: store,
        baseDirectoryProvider: () async => tmpDir,
      );

      final result = await service.importBundleFromFile(
        localArchivePath: sourceArchivePath,
      );

      expect(result.pluginSlug, 'btc-util');
      expect(result.version, '1.0.0');
      expect(result.localPath, endsWith('.ubb'));
      expect(result.isRunnable, true);
      expect(await File(result.entryFilePath!).exists(), true);
      expect((await store.read()), hasLength(1));
    },
  );

  test('importBundleFromFile rejects mismatched configured slug', () async {
    final tmpDir = await Directory.systemTemp.createTemp(
      'utilivo-import-test-',
    );
    addTearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    final sourceArchivePath = '${tmpDir.path}/btc-util-1.0.0.ubb';
    final bundleBytes = _buildBundleArchiveBytes(
      pluginSlug: 'btc-util',
      pluginName: 'BTC Util',
      version: '1.0.0',
    );
    await File(sourceArchivePath).writeAsBytes(bundleBytes, flush: true);

    final service = ToolBundleDownloadService(
      dio: Dio(),
      store: _InMemoryDownloadedToolBundleStore(),
      baseDirectoryProvider: () async => tmpDir,
    );

    await expectLater(
      () => service.importBundleFromFile(
        localArchivePath: sourceArchivePath,
        pluginSlug: 'wrong-slug',
      ),
      throwsA(isA<ToolBundleFormatException>()),
    );
  });
}

List<int> _buildBundleArchiveBytes({
  required String pluginSlug,
  required String pluginName,
  required String version,
  String? iconPathInManifest,
  List<int>? iconFileBytes,
}) {
  final iconManifestPart = iconPathInManifest == null
      ? ''
      : ',\n  "icon": "$iconPathInManifest"';
  final archive = Archive()
    ..addFile(
      ArchiveFile.string('manifest.json', '''
{
  "id": "com.utilivo.plugin.$pluginSlug",
  "name": "$pluginName",
  "slug": "$pluginSlug",
  "version": "$version",
  "entry": "src/index.html"$iconManifestPart
}
'''),
    )
    ..addFile(
      ArchiveFile.string(
        'src/index.html',
        '<!doctype html><html><body><h1>$pluginName</h1></body></html>',
      ),
    );
  if (iconPathInManifest != null && iconFileBytes != null) {
    archive.addFile(
      ArchiveFile(iconPathInManifest, iconFileBytes.length, iconFileBytes),
    );
  }
  return ZipEncoder().encode(archive);
}

List<int> _buildSolidPngBytes(int r, int g, int b) {
  final image = img.Image(width: 24, height: 24);
  final color = img.ColorRgba8(r, g, b, 255);
  img.fill(image, color: color);
  return img.encodePng(image);
}

class _InMemoryDownloadedToolBundleStore implements DownloadedToolBundleStore {
  List<DownloadedToolBundle> _bundles = const <DownloadedToolBundle>[];

  @override
  Future<void> clear() async {
    _bundles = const <DownloadedToolBundle>[];
  }

  @override
  Future<List<DownloadedToolBundle>> read() async {
    return _bundles;
  }

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) async {
    _bundles = bundles;
  }
}
