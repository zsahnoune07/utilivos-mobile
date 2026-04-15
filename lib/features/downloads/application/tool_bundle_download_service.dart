import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/meta_api.dart';
import '../data/downloaded_tool_bundle_store.dart';
import '../data/models/downloaded_tool_bundle.dart';
import '../data/models/plugin_download_grant.dart';
import '../data/models/signing_metadata.dart';

typedef BundleDownloadProgress = void Function(double progress);
typedef BundleFileDownloader =
    Future<void> Function(
      Uri uri,
      String savePath,
      void Function(int received, int total)? onReceiveProgress,
    );
typedef BundleBaseDirectoryProvider = Future<Directory> Function();

class ToolBundleIntegrityException implements Exception {
  const ToolBundleIntegrityException({
    required this.expectedSha256,
    required this.actualSha256,
  });

  final String expectedSha256;
  final String actualSha256;

  @override
  String toString() {
    return 'ToolBundleIntegrityException(expected=$expectedSha256, actual=$actualSha256)';
  }
}

class ToolBundleFormatException implements Exception {
  const ToolBundleFormatException(this.message);

  final String message;

  @override
  String toString() {
    return 'ToolBundleFormatException($message)';
  }
}

class ToolBundleDownloadService {
  ToolBundleDownloadService({
    required Dio dio,
    required DownloadedToolBundleStore store,
    required MetaApi metaApi,
    String? pinnedSigningRootPublicKey,
    BundleFileDownloader? downloadFile,
    BundleBaseDirectoryProvider? baseDirectoryProvider,
  }) : _dio = dio,
       _store = store,
       _metaApi = metaApi,
       _pinnedSigningRootPublicKey = pinnedSigningRootPublicKey,
       _downloadFile = downloadFile,
       _baseDirectoryProvider = baseDirectoryProvider;

  final Dio _dio;
  final DownloadedToolBundleStore _store;
  final MetaApi _metaApi;
  final String? _pinnedSigningRootPublicKey;
  final BundleFileDownloader? _downloadFile;
  final BundleBaseDirectoryProvider? _baseDirectoryProvider;
  List<DownloadedToolBundle>? _cachedBundles;

  Future<DownloadedToolBundle> downloadBundle({
    required String pluginSlug,
    required PluginDownloadGrant grant,
    Future<PluginDownloadGrant> Function()? refetchGrant,
    BundleDownloadProgress? onProgress,
  }) async {
    final normalizedSlug = pluginSlug.trim();
    final safeSlug = _safeFilePart(normalizedSlug);
    final safeVersion = _safeFilePart(grant.version);
    final baseDir = await _resolveBaseDirectory();
    final bundlesDir = Directory('${baseDir.path}/tool_bundles');
    if (!await bundlesDir.exists()) {
      await bundlesDir.create(recursive: true);
    }

    final filePath = '${bundlesDir.path}/$safeSlug-$safeVersion.utilivos.zip';
    final downloader = _downloadFile ?? _downloadWithDio;
    var activeGrant = grant;
    var retriedGrant = false;
    while (true) {
      try {
        await downloader(Uri.parse(activeGrant.url), filePath, (
          int received,
          int total,
        ) {
          if (onProgress == null || total <= 0) {
            return;
          }
          onProgress(received / total);
        });
        break;
      } on DioException catch (e) {
        if (!retriedGrant &&
            refetchGrant != null &&
            e.response?.statusCode == 403) {
          retriedGrant = true;
          activeGrant = await refetchGrant();
          continue;
        }
        rethrow;
      }
    }

    final archiveBytes = await File(filePath).readAsBytes();
    return _prepareAndPersistBundle(
      pluginSlug: normalizedSlug,
      version: activeGrant.version.trim(),
      archivePath: filePath,
      archiveBytes: archiveBytes,
      expectedSha256: activeGrant.checksumSha256,
      grant: activeGrant,
    );
  }

  Future<DownloadedToolBundle> importBundleFromFile({
    required String localArchivePath,
    String? pluginSlug,
    String? version,
  }) async {
    if (kReleaseMode) {
      throw const ToolBundleFormatException(
        'Local bundle import is disabled in production builds.',
      );
    }
    final sourcePath = localArchivePath.trim();
    if (sourcePath.isEmpty) {
      throw const ToolBundleFormatException(
        'Local bundle path must not be empty.',
      );
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw ToolBundleFormatException(
        'Local bundle file was not found at "$sourcePath".',
      );
    }

    final archiveBytes = await sourceFile.readAsBytes();
    final preview = _readManifestPreview(archiveBytes);

    final expectedSlug = _normalizeNonEmpty(pluginSlug) ?? preview.slug;
    final expectedVersion = _normalizeNonEmpty(version) ?? preview.version;
    if (expectedSlug != preview.slug) {
      throw ToolBundleFormatException(
        'Configured slug "$expectedSlug" does not match manifest slug "${preview.slug}".',
      );
    }
    if (expectedVersion != preview.version) {
      throw ToolBundleFormatException(
        'Configured version "$expectedVersion" does not match manifest version "${preview.version}".',
      );
    }

    final baseDir = await _resolveBaseDirectory();
    final bundlesDir = Directory('${baseDir.path}/tool_bundles');
    if (!await bundlesDir.exists()) {
      await bundlesDir.create(recursive: true);
    }

    final safeSlug = _safeFilePart(expectedSlug);
    final safeVersion = _safeFilePart(expectedVersion);
    final extension = _resolveArchiveExtension(sourceFile.path);
    final importedArchivePath =
        '${bundlesDir.path}/$safeSlug-$safeVersion$extension';
    await File(importedArchivePath).writeAsBytes(archiveBytes, flush: true);

    return _prepareAndPersistBundle(
      pluginSlug: expectedSlug,
      version: expectedVersion,
      archivePath: importedArchivePath,
      archiveBytes: archiveBytes,
      grant: null,
    );
  }

  Future<List<DownloadedToolBundle>> listDownloadedBundles() {
    return _readBundles();
  }

  Future<void> deleteBundle(String pluginSlug) async {
    final normalizedSlug = pluginSlug.trim();
    if (normalizedSlug.isEmpty) return;

    final bundles = await _readBundles();
    final remaining = <DownloadedToolBundle>[];

    for (final bundle in bundles) {
      if (bundle.pluginSlug.trim() == normalizedSlug) {
        try {
          final archiveFile = File(bundle.localPath);
          if (await archiveFile.exists()) {
            await archiveFile.delete();
          }
          final extractedPath = bundle.extractedPath;
          if (extractedPath != null) {
            final extractedDir = Directory(extractedPath);
            if (await extractedDir.exists()) {
              await extractedDir.delete(recursive: true);
            }
          }
        } catch (_) {
          // Best-effort cleanup; continue even if file deletion fails.
        }
      } else {
        remaining.add(bundle);
      }
    }

    await _writeBundles(remaining);
  }

  Future<DownloadedToolBundle?> findRunnableBundle(String pluginSlug) async {
    final normalizedSlug = pluginSlug.trim();
    if (normalizedSlug.isEmpty) {
      return null;
    }

    final bundles = await _readBundles();
    var didMutate = false;
    final updatedBundles = <DownloadedToolBundle>[];
    DownloadedToolBundle? resolvedBundle;

    for (final bundle in bundles) {
      var current = bundle;
      if (bundle.pluginSlug.trim() == normalizedSlug) {
        final isIntegrityValid = await verifyBundleIntegrity(bundle);
        if (!isIntegrityValid) {
          didMutate = true;
          continue;
        }
        final existingEntryPath = bundle.entryFilePath;
        if (bundle.isRunnable &&
            existingEntryPath != null &&
            await File(existingEntryPath).exists()) {
          resolvedBundle ??= bundle;
        } else {
          final hydrated = await _hydrateBundleMetadata(bundle);
          if (hydrated != null) {
            current = hydrated;
            didMutate = true;
            resolvedBundle ??= hydrated;
          }
        }
      }
      updatedBundles.add(current);
    }

    if (didMutate) {
      await _writeBundles(updatedBundles);
    }
    return resolvedBundle;
  }

  Future<bool> verifyBundleIntegrity(DownloadedToolBundle bundle) async {
    final archiveFile = File(bundle.localPath);
    if (!await archiveFile.exists()) {
      return false;
    }
    try {
      final bytes = await archiveFile.readAsBytes();
      final actualSha = sha256.convert(bytes).toString();
      return actualSha.toLowerCase() == bundle.sha256.trim().toLowerCase();
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _resolveBaseDirectory() async {
    if (_baseDirectoryProvider != null) {
      return _baseDirectoryProvider();
    }
    return getApplicationSupportDirectory();
  }

  Future<void> _downloadWithDio(
    Uri uri,
    String savePath,
    void Function(int received, int total)? onReceiveProgress,
  ) {
    return _dio.downloadUri(
      uri,
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<DownloadedToolBundle?> _hydrateBundleMetadata(
    DownloadedToolBundle bundle,
  ) async {
    final archiveFile = File(bundle.localPath);
    if (!await archiveFile.exists()) {
      return null;
    }

    try {
      final extractionDirectory = await _resolveExtractionDirectory(bundle);
      if (await extractionDirectory.exists()) {
        await extractionDirectory.delete(recursive: true);
      }
      await extractionDirectory.create(recursive: true);

      final archiveBytes = await archiveFile.readAsBytes();
      final manifest = await _extractAndReadManifest(
        archiveBytes: archiveBytes,
        extractionDirectory: extractionDirectory,
      );

      return bundle.copyWith(
        extractedPath: extractionDirectory.path,
        manifestPath: manifest.manifestPath,
        entryFilePath: manifest.entryFilePath,
        pluginName: manifest.name,
        manifestVersion: manifest.version,
        category: manifest.category,
        iconPath: manifest.iconPath,
        iconAccentColor: manifest.iconAccentColor,
        runtimeMode: manifest.runtimeMode,
        runtimeContractVersion: manifest.runtimeContractVersion,
        designSystemVersion: manifest.designSystemVersion,
        sdkVersion: manifest.sdkVersion,
      );
    } on ToolBundleFormatException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _resolveExtractionDirectory(
    DownloadedToolBundle bundle,
  ) async {
    final existingPath = bundle.extractedPath?.trim();
    if (existingPath != null && existingPath.isNotEmpty) {
      return Directory(existingPath);
    }

    final safeSlug = _safeFilePart(bundle.pluginSlug);
    final safeVersion = _safeFilePart(bundle.version);
    final archiveDirectory = File(bundle.localPath).parent;
    return Directory('${archiveDirectory.path}/$safeSlug-$safeVersion');
  }

  Future<_ResolvedManifest> _extractAndReadManifest({
    required List<int> archiveBytes,
    required Directory extractionDirectory,
  }) async {
    final archive = _decodeArchive(archiveBytes);

    for (final entry in archive.files) {
      final normalizedEntryPath = _normalizeArchiveEntryPath(entry.name);
      if (normalizedEntryPath == null) {
        continue;
      }

      final outputPath = _resolveSafePath(
        rootPath: extractionDirectory.path,
        relativePath: normalizedEntryPath,
        context: 'archive entry',
      );

      if (entry.isFile) {
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(entry.content, flush: true);
        continue;
      }

      await Directory(outputPath).create(recursive: true);
    }

    final manifestPath = _resolveSafePath(
      rootPath: extractionDirectory.path,
      relativePath: 'manifest.json',
      context: 'manifest',
    );
    final manifestFile = File(manifestPath);
    if (!await manifestFile.exists()) {
      throw const ToolBundleFormatException('Bundle manifest.json is missing.');
    }

    final rawManifest = jsonDecode(await manifestFile.readAsString());
    if (rawManifest is! Map<String, dynamic>) {
      throw const ToolBundleFormatException(
        'Bundle manifest must be a JSON object.',
      );
    }

    final name = _readRequiredManifestField(rawManifest, 'name');
    final version = _readRequiredManifestField(rawManifest, 'version');
    final entryPath = _readRequiredManifestField(rawManifest, 'entry');
    final runtimeMode = _readOptionalManifestField(rawManifest, 'runtime_mode');
    final runtimeContractVersion = _readOptionalManifestIntField(
      rawManifest,
      'runtime_contract_version',
    );
    final designSystemVersion = _readOptionalManifestIntField(
      rawManifest,
      'design_system_version',
    );
    final sdkVersion = _readOptionalManifestField(rawManifest, 'sdk_version');
    final rawCategory = rawManifest['category'];
    final category = rawCategory is String && rawCategory.trim().isNotEmpty
        ? rawCategory.trim()
        : null;
    final resolvedEntryPath = _resolveSafePath(
      rootPath: extractionDirectory.path,
      relativePath: entryPath,
      context: 'manifest entry',
    );
    final entryFile = File(resolvedEntryPath);
    if (!await entryFile.exists()) {
      throw ToolBundleFormatException(
        'Bundle entry file "$entryPath" was not found.',
      );
    }

    String? resolvedIconPath;
    final rawIcon = rawManifest['icon'];
    if (rawIcon is String && rawIcon.trim().isNotEmpty) {
      final candidatePath = _resolveSafePath(
        rootPath: extractionDirectory.path,
        relativePath: rawIcon.trim(),
        context: 'manifest icon',
      );
      if (await File(candidatePath).exists()) {
        resolvedIconPath = candidatePath;
      }
    }
    if (resolvedIconPath == null) {
      for (final candidate in const [
        'icon.png',
        'icon.jpg',
        'icon.webp',
        'tool/icon.png',
        'tool/icon.jpg',
        'tool/icon.webp',
      ]) {
        final path = '${extractionDirectory.path}/$candidate';
        if (await File(path).exists()) {
          resolvedIconPath = path;
          break;
        }
      }
    }
    if (_isPlaceholderIconPath(resolvedIconPath)) {
      resolvedIconPath = null;
    }

    return _ResolvedManifest(
      name: name,
      version: version,
      manifestPath: manifestPath,
      entryFilePath: resolvedEntryPath,
      category: category,
      iconPath: resolvedIconPath,
      iconAccentColor: await _deriveIconAccentColor(resolvedIconPath),
      runtimeMode: runtimeMode,
      runtimeContractVersion: runtimeContractVersion,
      designSystemVersion: designSystemVersion,
      sdkVersion: sdkVersion,
    );
  }

  Future<String?> _deriveIconAccentColor(String? iconPath) async {
    if (iconPath == null || iconPath.trim().isEmpty) {
      return null;
    }
    final iconFile = File(iconPath);
    if (!await iconFile.exists()) {
      return null;
    }

    try {
      final bytes = await iconFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }

      final sampleStep = math
          .sqrt((decoded.width * decoded.height) / 5000)
          .ceil();
      final step = sampleStep < 1 ? 1 : sampleStep;
      final bins = <int, int>{};

      for (var y = 0; y < decoded.height; y += step) {
        for (var x = 0; x < decoded.width; x += step) {
          final pixel = decoded.getPixel(x, y);
          final alpha = pixel.a;
          if (alpha < 48) {
            continue;
          }
          final r = (pixel.r / 255.0 * alpha / 255.0 * 255).round();
          final g = (pixel.g / 255.0 * alpha / 255.0 * 255).round();
          final b = (pixel.b / 255.0 * alpha / 255.0 * 255).round();

          final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
          final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);
          if (maxChannel - minChannel < 18) {
            continue;
          }

          final key = ((r ~/ 16) << 8) | ((g ~/ 16) << 4) | (b ~/ 16);
          bins[key] = (bins[key] ?? 0) + 1;
        }
      }

      if (bins.isEmpty) {
        return null;
      }

      var selectedKey = bins.keys.first;
      var selectedCount = bins[selectedKey]!;
      bins.forEach((int key, int count) {
        if (count > selectedCount) {
          selectedKey = key;
          selectedCount = count;
        }
      });

      final r = ((selectedKey >> 8) & 0xF) * 16 + 8;
      final g = ((selectedKey >> 4) & 0xF) * 16 + 8;
      final b = (selectedKey & 0xF) * 16 + 8;
      return _toHexColor(r, g, b);
    } catch (_) {
      return null;
    }
  }

  String _toHexColor(int r, int g, int b) {
    String hex(int value) =>
        value.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${hex(r)}${hex(g)}${hex(b)}';
  }

  bool _isPlaceholderIconPath(String? path) {
    if (path == null) {
      return false;
    }
    final name = p.basename(path).toLowerCase();
    return name.contains('placeholder') || name.contains('default-icon');
  }

  String? _normalizeArchiveEntryPath(String raw) {
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceFirst(RegExp(r'^/+'), '');
  }

  String _resolveSafePath({
    required String rootPath,
    required String relativePath,
    required String context,
  }) {
    final normalizedRoot = p.normalize(rootPath);
    final resolvedPath = p.normalize(p.join(normalizedRoot, relativePath));
    final isSafe =
        resolvedPath == normalizedRoot ||
        p.isWithin(normalizedRoot, resolvedPath);
    if (!isSafe) {
      throw ToolBundleFormatException(
        '$context path escapes bundle extraction directory.',
      );
    }
    return resolvedPath;
  }

  String _readRequiredManifestField(Map<String, dynamic> manifest, String key) {
    final raw = manifest[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ToolBundleFormatException(
        'Bundle manifest is missing required "$key" field.',
      );
    }
    return raw.trim();
  }

  String? _readOptionalManifestField(
    Map<String, dynamic> manifest,
    String key,
  ) {
    final raw = manifest[key];
    if (raw is! String) {
      return null;
    }
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  int? _readOptionalManifestIntField(
    Map<String, dynamic> manifest,
    String key,
  ) {
    final raw = manifest[key];
    if (raw is int) {
      return raw;
    }
    return null;
  }

  _ArchiveManifestPreview _readManifestPreview(List<int> archiveBytes) {
    final archive = _decodeArchive(archiveBytes);
    ArchiveFile? manifestEntry;
    for (final entry in archive.files) {
      if (_normalizeArchiveEntryPath(entry.name) == 'manifest.json') {
        manifestEntry = entry;
        break;
      }
    }

    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const ToolBundleFormatException('Bundle manifest.json is missing.');
    }

    final manifestSource = utf8.decode(manifestEntry.content);

    final decoded = jsonDecode(manifestSource);
    if (decoded is! Map<String, dynamic>) {
      throw const ToolBundleFormatException(
        'Bundle manifest must be a JSON object.',
      );
    }

    return _ArchiveManifestPreview(
      slug: _readRequiredManifestField(decoded, 'slug'),
      version: _readRequiredManifestField(decoded, 'version'),
    );
  }

  Archive _decodeArchive(List<int> archiveBytes) {
    try {
      return ZipDecoder().decodeBytes(archiveBytes, verify: true);
    } catch (_) {
      throw const ToolBundleFormatException(
        'Bundle archive is not a valid zip archive.',
      );
    }
  }

  Future<DownloadedToolBundle> _prepareAndPersistBundle({
    required String pluginSlug,
    required String version,
    required String archivePath,
    required List<int> archiveBytes,
    String? expectedSha256,
    required PluginDownloadGrant? grant,
  }) async {
    final normalizedSlug = pluginSlug.trim();
    final normalizedVersion = version.trim();
    if (normalizedSlug.isEmpty) {
      throw const ToolBundleFormatException(
        'Bundle plugin slug must not be empty.',
      );
    }
    if (normalizedVersion.isEmpty) {
      throw const ToolBundleFormatException(
        'Bundle version must not be empty.',
      );
    }

    final calculatedSha256 = sha256.convert(archiveBytes).toString();
    final normalizedExpectedSha = expectedSha256?.toLowerCase();
    if (normalizedExpectedSha != null &&
        normalizedExpectedSha.isNotEmpty &&
        normalizedExpectedSha != calculatedSha256) {
      await File(archivePath).delete();
      throw ToolBundleIntegrityException(
        expectedSha256: normalizedExpectedSha,
        actualSha256: calculatedSha256,
      );
    }
    final normalizedTier = _normalizeTier(grantTier: grant?.tier);
    final signatureVerifiedAt = await _verifyDownloadGrantSignature(
      grant: grant,
      pluginSlug: normalizedSlug,
      version: normalizedVersion,
      calculatedSha256: calculatedSha256,
    );

    final extractionDirectory = await _resolveExtractionDirectoryFor(
      pluginSlug: normalizedSlug,
      version: normalizedVersion,
      archivePath: archivePath,
    );
    if (await extractionDirectory.exists()) {
      await extractionDirectory.delete(recursive: true);
    }
    await extractionDirectory.create(recursive: true);
    final manifest = await _extractAndReadManifest(
      archiveBytes: archiveBytes,
      extractionDirectory: extractionDirectory,
    );

    final metadata = DownloadedToolBundle(
      pluginSlug: normalizedSlug,
      version: normalizedVersion,
      localPath: archivePath,
      sha256: calculatedSha256,
      downloadedAt: DateTime.now().toUtc(),
      extractedPath: extractionDirectory.path,
      manifestPath: manifest.manifestPath,
      entryFilePath: manifest.entryFilePath,
      pluginName: manifest.name,
      manifestVersion: manifest.version,
      category: manifest.category,
      iconPath: manifest.iconPath,
      iconAccentColor: manifest.iconAccentColor,
      verifiedTier: normalizedTier,
      publisherId: grant?.publisherId,
      signature: grant?.signature,
      signatureAlgorithm: grant?.signatureAlgorithm,
      signatureVerifiedAt: signatureVerifiedAt,
      signatureSchemaVersion: grant?.signaturePayload?.schemaVersion,
      entitlementVerifiedAt: grant?.entitlementVerifiedAt,
      runtimeMode: (manifest.runtimeMode?.trim().isNotEmpty ?? false)
          ? manifest.runtimeMode?.trim()
          : grant?.runtimeMode,
      runtimeContractVersion:
          manifest.runtimeContractVersion ?? grant?.runtimeContractVersion,
      designSystemVersion:
          manifest.designSystemVersion ?? grant?.designSystemVersion,
      sdkVersion: manifest.sdkVersion ?? grant?.sdkVersion,
    );

    await _upsertBundleMetadata(metadata);
    return metadata;
  }

  String _normalizeTier({String? grantTier}) {
    final normalized = grantTier?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'free';
    }
    if (normalized == 'free') {
      return 'free';
    }
    if (normalized == 'pro' ||
        normalized == 'premium' ||
        normalized == 'paid') {
      return 'pro';
    }
    throw ToolBundleFormatException('Unsupported pricing tier "$normalized".');
  }

  Future<DateTime?> _verifyDownloadGrantSignature({
    required PluginDownloadGrant? grant,
    required String pluginSlug,
    required String version,
    required String calculatedSha256,
  }) async {
    if (grant == null) {
      return null;
    }
    final payload = grant.signaturePayload;
    final signature = grant.signature?.trim();
    if (payload == null || signature == null || signature.isEmpty) {
      if (_normalizeTier(grantTier: grant.tier) == 'pro') {
        throw const ToolBundleFormatException(
          'Pro bundle is missing signature metadata.',
        );
      }
      return null;
    }
    final signingPublicKey = await _resolveTrustedSigningPublicKey(grant);
    final normalizedPayloadTier = _normalizeTier(grantTier: payload.tier);
    final normalizedGrantTier = _normalizeTier(grantTier: grant.tier);
    if (payload.slug != pluginSlug ||
        payload.version != version ||
        payload.bundleSha256.toLowerCase() != calculatedSha256.toLowerCase()) {
      throw const ToolBundleFormatException(
        'Bundle signature payload does not match download metadata.',
      );
    }
    if (normalizedPayloadTier != normalizedGrantTier) {
      throw const ToolBundleFormatException(
        'Bundle tier metadata is inconsistent.',
      );
    }
    final canonicalPayload = jsonEncode(<String, dynamic>{
      'schema_version': payload.schemaVersion,
      'slug': payload.slug,
      'version': payload.version,
      'bundle_sha256': payload.bundleSha256,
      'tier': payload.tier,
      'publisher_id': payload.publisherId,
    });
    final keyBytes = _extractEcPublicKeyBytesFromPem(signingPublicKey);
    final publicKey = SimplePublicKey(keyBytes, type: KeyPairType.p256);
    final signatureBytes = base64Decode(signature);
    final didVerify = await Ecdsa.p256(Sha256()).verify(
      utf8.encode(canonicalPayload),
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!didVerify) {
      throw const ToolBundleFormatException(
        'Bundle signature verification failed.',
      );
    }
    return DateTime.now().toUtc();
  }

  Future<String> _resolveTrustedSigningPublicKey(
    PluginDownloadGrant grant,
  ) async {
    final pinnedRootPublicKey = _pinnedSigningRootPublicKey?.trim();
    final grantSigningPublicKey = grant.signingPublicKey?.trim();
    if (pinnedRootPublicKey == null || pinnedRootPublicKey.isEmpty) {
      if (grantSigningPublicKey == null || grantSigningPublicKey.isEmpty) {
        throw const ToolBundleFormatException(
          'Signing key is missing in download metadata.',
        );
      }
      return grantSigningPublicKey;
    }

    final meta = await _metaApi.fetchSigningMetadata();
    await _verifySigningMetadataAgainstPinnedRoot(
      signingMetadata: meta,
      pinnedRootPublicKey: pinnedRootPublicKey,
    );

    if (grantSigningPublicKey != null &&
        grantSigningPublicKey.isNotEmpty &&
        grantSigningPublicKey != meta.signingPublicKey) {
      throw const ToolBundleFormatException(
        'Download signing key does not match trusted meta key.',
      );
    }
    if (grant.signingPublicKeyId != null &&
        grant.signingPublicKeyId!.trim().isNotEmpty &&
        grant.signingPublicKeyId!.trim() != meta.signingPublicKeyId) {
      throw const ToolBundleFormatException(
        'Download signing key id does not match trusted meta key.',
      );
    }
    return meta.signingPublicKey;
  }

  Future<void> _verifySigningMetadataAgainstPinnedRoot({
    required SigningMetadata signingMetadata,
    required String pinnedRootPublicKey,
  }) async {
    final payload = signingMetadata.publicKeySignaturePayload;
    if (payload.schemaVersion != 1 ||
        payload.keyPurpose != 'bundle_signing_leaf' ||
        payload.keyAlgorithm != 'ECDSA_P256_SHA256' ||
        payload.keyId != signingMetadata.signingPublicKeyId ||
        payload.publicKeyPem != signingMetadata.signingPublicKey ||
        signingMetadata.signingPublicKeyAlgorithm != 'ECDSA_P256_SHA256' ||
        signingMetadata.publicKeySignatureAlgorithm != 'ECDSA_P256_SHA256') {
      throw const ToolBundleFormatException('Signing metadata is invalid.');
    }

    final canonicalPayload = jsonEncode(<String, dynamic>{
      'schema_version': payload.schemaVersion,
      'key_purpose': payload.keyPurpose,
      'key_algorithm': payload.keyAlgorithm,
      'key_id': payload.keyId,
      'public_key_pem': payload.publicKeyPem,
    });
    final rootKeyBytes = _extractEcPublicKeyBytesFromPem(pinnedRootPublicKey);
    final rootPublicKey = SimplePublicKey(rootKeyBytes, type: KeyPairType.p256);
    final signatureBytes = base64Decode(signingMetadata.publicKeySignature);
    final didVerify = await Ecdsa.p256(Sha256()).verify(
      utf8.encode(canonicalPayload),
      signature: Signature(signatureBytes, publicKey: rootPublicKey),
    );
    if (!didVerify) {
      throw const ToolBundleFormatException(
        'Trusted signing metadata verification failed.',
      );
    }
  }

  List<int> _extractEcPublicKeyBytesFromPem(String pem) {
    final normalized = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
    if (normalized.isEmpty) {
      throw const ToolBundleFormatException(
        'Signing key is missing in download metadata.',
      );
    }
    final der = base64Decode(normalized);
    final parser = ASN1Parser(der);
    final topSequence = parser.nextObject() as ASN1Sequence;
    final bitString = topSequence.elements[1] as ASN1BitString;
    final bytes = bitString.valueBytes();
    if (bytes.length != 65 || bytes.first != 0x04) {
      throw const ToolBundleFormatException(
        'Invalid EC public key format for bundle verification.',
      );
    }
    return bytes.sublist(1);
  }

  Future<Directory> _resolveExtractionDirectoryFor({
    required String pluginSlug,
    required String version,
    required String archivePath,
  }) async {
    final safeSlug = _safeFilePart(pluginSlug);
    final safeVersion = _safeFilePart(version);
    final archiveDirectory = File(archivePath).parent;
    return Directory('${archiveDirectory.path}/$safeSlug-$safeVersion');
  }

  Future<void> _upsertBundleMetadata(DownloadedToolBundle metadata) async {
    final normalizedSlug = metadata.pluginSlug.trim();
    final existing = await _readBundles();
    final filtered = existing
        .where(
          (DownloadedToolBundle entry) =>
              entry.pluginSlug.trim() != normalizedSlug,
        )
        .toList(growable: true);
    filtered.insert(0, metadata);
    await _writeBundles(filtered);
  }

  Future<List<DownloadedToolBundle>> _readBundles() async {
    final cached = _cachedBundles;
    if (cached != null) {
      return List<DownloadedToolBundle>.from(cached, growable: false);
    }
    final loaded = await _store.read();
    _cachedBundles = List<DownloadedToolBundle>.from(loaded, growable: false);
    return List<DownloadedToolBundle>.from(loaded, growable: false);
  }

  Future<void> _writeBundles(List<DownloadedToolBundle> bundles) async {
    _cachedBundles = List<DownloadedToolBundle>.from(bundles, growable: false);
    await _store.write(_cachedBundles!);
  }

  String? _normalizeNonEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _resolveArchiveExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    if (extension == '.ubb') {
      return '.ubb';
    }
    if (extension == '.zip') {
      return '.zip';
    }
    return '.utilivos.zip';
  }

  String _safeFilePart(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'unknown';
    }
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}

class _ResolvedManifest {
  const _ResolvedManifest({
    required this.name,
    required this.version,
    required this.manifestPath,
    required this.entryFilePath,
    this.category,
    this.iconPath,
    this.iconAccentColor,
    this.runtimeMode,
    this.runtimeContractVersion,
    this.designSystemVersion,
    this.sdkVersion,
  });

  final String name;
  final String version;
  final String manifestPath;
  final String entryFilePath;
  final String? category;
  final String? iconPath;
  final String? iconAccentColor;
  final String? runtimeMode;
  final int? runtimeContractVersion;
  final int? designSystemVersion;
  final String? sdkVersion;
}

class _ArchiveManifestPreview {
  const _ArchiveManifestPreview({required this.slug, required this.version});

  final String slug;
  final String version;
}
