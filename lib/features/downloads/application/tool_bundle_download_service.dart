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
import '../../../core/dev/bundle_verification_dev.dart';

typedef BundleDownloadProgress = void Function(double progress);
typedef BundleFileDownloader =
    Future<void> Function(
      Uri uri,
      String savePath,
      void Function(int received, int total)? onReceiveProgress,
    );
typedef BundleBaseDirectoryProvider = Future<Directory> Function();

class ToolBundleIntegrityException implements Exception {
  ToolBundleIntegrityException({
    required this.expectedSha256,
    required this.actualSha256,
    Map<String, String>? devOnlyDetails,
  }) : devOnlyDetails = (kUtilivosBundleDevDiagnosticsEnabled &&
            devOnlyDetails != null)
        ? Map<String, String>.unmodifiable(devOnlyDetails)
        : null;

  final String expectedSha256;
  final String actualSha256;
  final Map<String, String>? devOnlyDetails;

  @override
  String toString() {
    return 'ToolBundleIntegrityException(expected=$expectedSha256, actual=$actualSha256)';
  }
}

class ToolBundleFormatException implements Exception {
  ToolBundleFormatException(
    this.message, {
    Map<String, String>? devOnlyDetails,
  }) : devOnlyDetails = (kUtilivosBundleDevDiagnosticsEnabled &&
            devOnlyDetails != null)
        ? Map<String, String>.unmodifiable(devOnlyDetails)
        : null;

  final String message;
  final Map<String, String>? devOnlyDetails;

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

  static const int _maxArchiveFileEntries = 500;
  static const int _maxExtractedUncompressedBytes = 50 * 1024 * 1024;

  /// Dev-only: archive path, size, hash, and grant context for the downloaded
  /// .ubb (Utilivos bundle, zip container). Merged into [ToolBundleFormatException.devOnlyDetails]
  /// when [kUtilivosBundleDevDiagnosticsEnabled] is true; otherwise empty.
  Map<String, String> _ubbFileDevMap({
    required String archivePath,
    required List<int> archiveBytes,
    required String pluginSlug,
    required String version,
    String? calculatedSha256,
    PluginDownloadGrant? grant,
    String? extractionDirectoryPath,
  }) {
    if (!kUtilivosBundleDevDiagnosticsEnabled) {
      return const <String, String>{};
    }
    int? onDisk;
    try {
      final f = File(archivePath);
      if (f.existsSync()) {
        onDisk = f.lengthSync();
      }
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
    }
    final mem = archiveBytes.length;
    final m = <String, String>{
      'ubb_local_path': archivePath,
      'ubb_file_basename': p.basename(archivePath),
      'ubb_file_ext': p.extension(archivePath),
      'ubb_size_bytes_in_memory': mem.toString(),
      'ubb_size_mb_in_memory': (mem / (1024 * 1024)).toStringAsFixed(4),
      'ubb_plugin_slug': pluginSlug,
      'ubb_version': version,
    };
    if (onDisk != null) {
      m['ubb_size_bytes_on_disk'] = onDisk.toString();
      m['ubb_size_mb_on_disk'] =
          (onDisk / (1024 * 1024)).toStringAsFixed(4);
    }
    if (calculatedSha256 != null && calculatedSha256.isNotEmpty) {
      m['ubb_sha256_computed'] = calculatedSha256;
    }
    if (extractionDirectoryPath != null && extractionDirectoryPath.isNotEmpty) {
      m['ubb_extract_directory'] = extractionDirectoryPath;
    }
    if (grant != null) {
      m['ubb_grant_version'] = grant.version.trim();
      m['ubb_grant_tier'] = grant.tier?.trim() ?? '';
      m['ubb_grant_expected_checksum'] = grant.checksumSha256?.trim() ?? '';
      m['ubb_signing_key_id'] = grant.signingPublicKeyId?.trim() ?? '';
      m['ubb_publisher_id'] = grant.publisherId?.trim() ?? '';
      m['ubb_http_method'] = grant.method?.trim() ?? '';
      final u = grant.url.trim();
      if (u.isNotEmpty) {
        try {
          final uri = Uri.parse(u);
          m['ubb_download_scheme'] = uri.scheme;
          m['ubb_download_host'] = uri.host;
          m['ubb_download_path'] = uri.path;
        } catch (_) {
          m['ubb_download_url'] = 'parse_error';
        }
      }
    }
    return m;
  }

  Map<String, String>? _devDetailsWithUbb(
    Map<String, String> ubb,
    Map<String, String> specific,
  ) {
    if (!kUtilivosBundleDevDiagnosticsEnabled) {
      return null;
    }
    return <String, String>{...ubb, ...specific};
  }

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

    // Always .ubb on disk — zip-backed archives are often shown as .zip (MIME) when
    // users save from browsers or file pickers; the app keeps the canonical name.
    final filePath = '${bundlesDir.path}/$safeSlug-$safeVersion.ubb';
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
      throw ToolBundleFormatException(
        'Local bundle import is disabled in production builds.',
      );
    }
    final sourcePath = localArchivePath.trim();
    if (sourcePath.isEmpty) {
      throw ToolBundleFormatException(
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
    // Do not mirror .zip / .utilivos.zip (path's last ext is .zip for *.utilivos.zip);
    // persist as the canonical .ubb name.
    final importedArchivePath =
        '${bundlesDir.path}/$safeSlug-$safeVersion.ubb';
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
      final ubb = _ubbFileDevMap(
        archivePath: bundle.localPath,
        archiveBytes: archiveBytes,
        pluginSlug: bundle.pluginSlug,
        version: bundle.version,
        calculatedSha256: bundle.sha256,
        grant: null,
        extractionDirectoryPath: extractionDirectory.path,
      );
      final manifest = await _extractAndReadManifest(
        archiveBytes: archiveBytes,
        extractionDirectory: extractionDirectory,
        ubbFileDev: ubb,
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
    Map<String, String> ubbFileDev = const {},
  }) async {
    final archive = _decodeArchive(archiveBytes, ubbFileDev: ubbFileDev);

    var extractedUncompressedBytes = 0;
    var archiveEntryCount = 0;
    for (final entry in archive.files) {
      archiveEntryCount++;
      if (archiveEntryCount > _maxArchiveFileEntries) {
        throw ToolBundleFormatException(
          'Bundle contains too many entries (max $_maxArchiveFileEntries).',
          devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'ubb_too_many_zip_entries',
            'max_entries': '$_maxArchiveFileEntries',
            'ubb_entry_count': '$archiveEntryCount',
          }),
        );
      }

      final normalizedEntryPath = _normalizeArchiveEntryPath(entry.name);
      if (normalizedEntryPath == null) {
        continue;
      }

      final outputPath = _resolveSafePath(
        rootPath: extractionDirectory.path,
        relativePath: normalizedEntryPath,
        context: 'archive entry',
        ubbFileDev: ubbFileDev,
      );

      if (entry.isFile) {
        final uncompressed = entry.size;
        extractedUncompressedBytes += uncompressed;
        if (extractedUncompressedBytes > _maxExtractedUncompressedBytes) {
          throw ToolBundleFormatException(
            'Bundle uncompressed size exceeds '
            '${_maxExtractedUncompressedBytes ~/ (1024 * 1024)} MB.',
            devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
              'tag': kUtilivosDevBundleErrorTag,
              'stage': 'ubb_uncompressed_quota',
              'ubb_entry_uncompressed_running_total': '$extractedUncompressedBytes',
              'ubb_uncompressed_max': '$_maxExtractedUncompressedBytes',
            }),
          );
        }
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
      ubbFileDev: ubbFileDev,
    );
    final manifestFile = File(manifestPath);
    if (!await manifestFile.exists()) {
      throw ToolBundleFormatException(
        'Bundle manifest.json is missing.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_missing_manifest',
        }),
      );
    }

    final rawManifest = jsonDecode(await manifestFile.readAsString());
    if (rawManifest is! Map<String, dynamic>) {
      throw ToolBundleFormatException(
        'Bundle manifest must be a JSON object.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_manifest_not_object',
        }),
      );
    }

    final name = _readRequiredManifestField(
      rawManifest,
      'name',
      ubbFileDev: ubbFileDev,
    );
    final version = _readRequiredManifestField(
      rawManifest,
      'version',
      ubbFileDev: ubbFileDev,
    );
    final entryPath = _readRequiredManifestField(
      rawManifest,
      'entry',
      ubbFileDev: ubbFileDev,
    );
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
      ubbFileDev: ubbFileDev,
    );
    final entryFile = File(resolvedEntryPath);
    if (!await entryFile.exists()) {
      throw ToolBundleFormatException(
        'Bundle entry file "$entryPath" was not found.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_missing_entry',
          'manifest_entry_path': entryPath,
        }),
      );
    }

    String? resolvedIconPath;
    final rawIcon = rawManifest['icon'];
    if (rawIcon is String && rawIcon.trim().isNotEmpty) {
      final candidatePath = _resolveSafePath(
        rootPath: extractionDirectory.path,
        relativePath: rawIcon.trim(),
        context: 'manifest icon',
        ubbFileDev: ubbFileDev,
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
    final trimmed = iconPath.trim();
    final iconFile = File(trimmed);
    if (!await iconFile.exists()) {
      return null;
    }
    return compute(_deriveIconAccentColorWorker, trimmed);
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
    Map<String, String> ubbFileDev = const {},
  }) {
    final normalizedRoot = p.normalize(rootPath);
    final resolvedPath = p.normalize(p.join(normalizedRoot, relativePath));
    final isSafe =
        resolvedPath == normalizedRoot ||
        p.isWithin(normalizedRoot, resolvedPath);
    if (!isSafe) {
      throw ToolBundleFormatException(
        '$context path escapes bundle extraction directory.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_unsafe_path',
          'context': context,
        }),
      );
    }
    return resolvedPath;
  }

  String _readRequiredManifestField(
    Map<String, dynamic> manifest,
    String key, {
    Map<String, String> ubbFileDev = const {},
  }) {
    final raw = manifest[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw ToolBundleFormatException(
        'Bundle manifest is missing required "$key" field.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_manifest_missing_field',
        }),
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
    final ubb = _ubbFileDevMap(
      archivePath: '(import_preview)',
      archiveBytes: archiveBytes,
      pluginSlug: '(import_preview)',
      version: '(import_preview)',
      calculatedSha256: null,
      grant: null,
      extractionDirectoryPath: null,
    );
    final archive = _decodeArchive(archiveBytes, ubbFileDev: ubb);
    ArchiveFile? manifestEntry;
    for (final entry in archive.files) {
      if (_normalizeArchiveEntryPath(entry.name) == 'manifest.json') {
        manifestEntry = entry;
        break;
      }
    }

    if (manifestEntry == null || !manifestEntry.isFile) {
      throw ToolBundleFormatException(
        'Bundle manifest.json is missing.',
        devOnlyDetails: _devDetailsWithUbb(ubb, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_import_preview_no_manifest',
        }),
      );
    }

    final manifestSource = utf8.decode(manifestEntry.content);

    final decoded = jsonDecode(manifestSource);
    if (decoded is! Map<String, dynamic>) {
      throw ToolBundleFormatException(
        'Bundle manifest must be a JSON object.',
        devOnlyDetails: _devDetailsWithUbb(ubb, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_import_preview_manifest_not_object',
        }),
      );
    }

    return _ArchiveManifestPreview(
      slug: _readRequiredManifestField(decoded, 'slug', ubbFileDev: ubb),
      version: _readRequiredManifestField(decoded, 'version', ubbFileDev: ubb),
    );
  }

  Archive _decodeArchive(
    List<int> archiveBytes, {
    Map<String, String> ubbFileDev = const {},
  }) {
    try {
      return ZipDecoder().decodeBytes(archiveBytes, verify: true);
    } catch (e) {
      throw ToolBundleFormatException(
        'Bundle archive is not a valid zip archive.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ubb_zip_decode',
          'zip_decode_error': e.toString(),
        }),
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
      throw ToolBundleFormatException(
        'Bundle plugin slug must not be empty.',
        devOnlyDetails: _devDetailsWithUbb(
          _ubbFileDevMap(
            archivePath: archivePath,
            archiveBytes: archiveBytes,
            pluginSlug: '(empty)',
            version: normalizedVersion,
            calculatedSha256: null,
            grant: grant,
            extractionDirectoryPath: null,
          ),
          {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'ubb_empty_slug',
          },
        ),
      );
    }
    if (normalizedVersion.isEmpty) {
      throw ToolBundleFormatException(
        'Bundle version must not be empty.',
        devOnlyDetails: _devDetailsWithUbb(
          _ubbFileDevMap(
            archivePath: archivePath,
            archiveBytes: archiveBytes,
            pluginSlug: normalizedSlug,
            version: '(empty)',
            calculatedSha256: null,
            grant: grant,
            extractionDirectoryPath: null,
          ),
          {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'ubb_empty_version',
          },
        ),
      );
    }

    final calculatedSha256 = sha256.convert(archiveBytes).toString();
    var ubb = _ubbFileDevMap(
      archivePath: archivePath,
      archiveBytes: archiveBytes,
      pluginSlug: normalizedSlug,
      version: normalizedVersion,
      calculatedSha256: calculatedSha256,
      grant: grant,
      extractionDirectoryPath: null,
    );
    final normalizedExpectedSha = expectedSha256?.toLowerCase();
    if (normalizedExpectedSha != null &&
        normalizedExpectedSha.isNotEmpty &&
        normalizedExpectedSha != calculatedSha256) {
      await File(archivePath).delete();
      ubb = _ubbFileDevMap(
        archivePath: archivePath,
        archiveBytes: archiveBytes,
        pluginSlug: normalizedSlug,
        version: normalizedVersion,
        calculatedSha256: calculatedSha256,
        grant: grant,
        extractionDirectoryPath: null,
      );
      throw ToolBundleIntegrityException(
        expectedSha256: normalizedExpectedSha,
        actualSha256: calculatedSha256,
        devOnlyDetails: _devDetailsWithUbb(
          ubb,
          {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'zip_sha256_check',
            'ubb_expected_sha256_from_grant': normalizedExpectedSha,
            'ubb_computed_sha256': calculatedSha256,
            'ubb_local_path': archivePath,
          },
        ),
      );
    }
    final normalizedTier = _normalizeTier(grantTier: grant?.tier, ubb: ubb);
    final signatureVerifiedAt = await _verifyDownloadGrantSignature(
      grant: grant,
      pluginSlug: normalizedSlug,
      version: normalizedVersion,
      calculatedSha256: calculatedSha256,
      ubbFileDev: ubb,
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
    if (kUtilivosBundleDevDiagnosticsEnabled && ubb.isNotEmpty) {
      ubb = <String, String>{
        ...ubb,
        'ubb_extract_directory': extractionDirectory.path,
      };
    }
    final manifest = await _extractAndReadManifest(
      archiveBytes: archiveBytes,
      extractionDirectory: extractionDirectory,
      ubbFileDev: ubb,
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

  String _normalizeTier({String? grantTier, Map<String, String> ubb = const {}}) {
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
    throw ToolBundleFormatException(
      'Unsupported pricing tier "$normalized".',
      devOnlyDetails: _devDetailsWithUbb(ubb, {
        'tag': kUtilivosDevBundleErrorTag,
        'stage': 'unsupported_tier',
        'tier_raw': grantTier?.trim() ?? '',
      }),
    );
  }

  Future<DateTime?> _verifyDownloadGrantSignature({
    required PluginDownloadGrant? grant,
    required String pluginSlug,
    required String version,
    required String calculatedSha256,
    Map<String, String> ubbFileDev = const {},
  }) async {
    if (grant == null) {
      return null;
    }
    final payload = grant.signaturePayload;
    final signature = grant.signature?.trim();
    if (payload == null || signature == null || signature.isEmpty) {
      if (_normalizeTier(grantTier: grant.tier, ubb: ubbFileDev) == 'pro') {
        throw ToolBundleFormatException(
          'Pro bundle is missing signature metadata.',
          devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'pro_missing_sig',
          }),
        );
      }
      return null;
    }
    final signingPublicKey = await _resolveTrustedSigningPublicKey(
      grant,
      ubbFileDev: ubbFileDev,
    );
    final normalizedPayloadTier = _normalizeTier(
      grantTier: payload.tier,
      ubb: ubbFileDev,
    );
    final normalizedGrantTier = _normalizeTier(
      grantTier: grant.tier,
      ubb: ubbFileDev,
    );
    if (payload.slug != pluginSlug ||
        payload.version != version ||
        payload.bundleSha256.toLowerCase() != calculatedSha256.toLowerCase()) {
      throw ToolBundleFormatException(
        'Bundle signature payload does not match download metadata.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'sig_payload_mismatch',
          'sig_payload_slug': payload.slug,
          'sig_payload_version': payload.version,
          'sig_payload_bundle_sha256': payload.bundleSha256,
        }),
      );
    }
    if (normalizedPayloadTier != normalizedGrantTier) {
      throw ToolBundleFormatException(
        'Bundle tier metadata is inconsistent.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'sig_tier_mismatch',
        }),
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
    final keyBytes = _extractEcPublicKeyBytesFromPem(
      signingPublicKey,
      keyRole: 'leaf_signing',
      ubbFileDev: ubbFileDev,
    );
    final publicKey = SimplePublicKey(keyBytes, type: KeyPairType.p256);
    final signatureBytes = base64Decode(signature);
    final didVerify = await Ecdsa.p256(Sha256()).verify(
      utf8.encode(canonicalPayload),
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!didVerify) {
      throw ToolBundleFormatException(
        'Bundle signature verification failed.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ecdsa_verification_leaf',
          'canonicalPayload': canonicalPayload,
          'signingKey_pem_preview': _pemDebugPreview(signingPublicKey),
          'signature_b64_len': '${signature.length}',
          'plugin_slug': pluginSlug,
          'version': version,
          'calculated_sha256': calculatedSha256,
        }),
      );
    }
    return DateTime.now().toUtc();
  }

  Future<String> _resolveTrustedSigningPublicKey(
    PluginDownloadGrant grant, {
    Map<String, String> ubbFileDev = const {},
  }) async {
    final pinnedRootPublicKey = _pinnedSigningRootPublicKey?.trim();
    final grantSigningPublicKey = grant.signingPublicKey?.trim();
    if (pinnedRootPublicKey == null || pinnedRootPublicKey.isEmpty) {
      if (grantSigningPublicKey == null || grantSigningPublicKey.isEmpty) {
        throw ToolBundleFormatException(
          'Signing key is missing in download metadata.',
          devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
            'tag': kUtilivosDevBundleErrorTag,
            'stage': 'missing_pinned_and_grant_key',
          }),
        );
      }
      return grantSigningPublicKey;
    }

    final meta = await _metaApi.fetchSigningMetadata();
    await _verifySigningMetadataAgainstPinnedRoot(
      signingMetadata: meta,
      pinnedRootPublicKey: pinnedRootPublicKey,
      ubbFileDev: ubbFileDev,
    );

    if (grantSigningPublicKey != null &&
        grantSigningPublicKey.isNotEmpty &&
        grantSigningPublicKey != meta.signingPublicKey) {
      throw ToolBundleFormatException(
        'Download signing key does not match trusted meta key.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'grant_vs_meta_key',
          'grant_key_preview': _pemDebugPreview(grantSigningPublicKey),
          'meta_key_preview': _pemDebugPreview(meta.signingPublicKey),
        }),
      );
    }
    if (grant.signingPublicKeyId != null &&
        grant.signingPublicKeyId!.trim().isNotEmpty &&
        grant.signingPublicKeyId!.trim() != meta.signingPublicKeyId) {
      throw ToolBundleFormatException(
        'Download signing key id does not match trusted meta key.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'grant_vs_meta_key_id',
          'grant_key_id': grant.signingPublicKeyId!.trim(),
          'meta_key_id': meta.signingPublicKeyId,
        }),
      );
    }
    return meta.signingPublicKey;
  }

  Future<void> _verifySigningMetadataAgainstPinnedRoot({
    required SigningMetadata signingMetadata,
    required String pinnedRootPublicKey,
    Map<String, String> ubbFileDev = const {},
  }) async {
    final payload = signingMetadata.publicKeySignaturePayload;
    if (payload.schemaVersion != 1 ||
        payload.keyPurpose != 'bundle_signing_leaf' ||
        payload.keyAlgorithm != 'ECDSA_P256_SHA256' ||
        payload.keyId != signingMetadata.signingPublicKeyId ||
        payload.publicKeyPem != signingMetadata.signingPublicKey ||
        signingMetadata.signingPublicKeyAlgorithm != 'ECDSA_P256_SHA256' ||
        signingMetadata.publicKeySignatureAlgorithm != 'ECDSA_P256_SHA256') {
      throw ToolBundleFormatException(
        'Signing metadata is invalid.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'metadata_field_checks',
          'expected_schema': '1',
          'actual_schema': '${payload.schemaVersion}',
          'key_purpose': payload.keyPurpose,
          'key_algorithm': payload.keyAlgorithm,
          'payload_key_id': payload.keyId,
          'metadata_signing_key_id': signingMetadata.signingPublicKeyId,
          'payload_match_pem':
              '${payload.publicKeyPem == signingMetadata.signingPublicKey}',
          'metadata_alg': signingMetadata.signingPublicKeyAlgorithm,
          'metadata_sig_alg': signingMetadata.publicKeySignatureAlgorithm,
        }),
      );
    }

    final canonicalPayload = jsonEncode(<String, dynamic>{
      'schema_version': payload.schemaVersion,
      'key_purpose': payload.keyPurpose,
      'key_algorithm': payload.keyAlgorithm,
      'key_id': payload.keyId,
      'public_key_pem': payload.publicKeyPem,
    });
    final rootKeyBytes = _extractEcPublicKeyBytesFromPem(
      pinnedRootPublicKey,
      keyRole: 'pinned_root',
      ubbFileDev: ubbFileDev,
    );
    final rootPublicKey = SimplePublicKey(rootKeyBytes, type: KeyPairType.p256);
    final signatureBytes = base64Decode(signingMetadata.publicKeySignature);
    final didVerify = await Ecdsa.p256(Sha256()).verify(
      utf8.encode(canonicalPayload),
      signature: Signature(signatureBytes, publicKey: rootPublicKey),
    );
    if (!didVerify) {
      throw ToolBundleFormatException(
        'Trusted signing metadata verification failed.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'stage': 'ecdsa_root_over_metadata',
          'canonicalPayload': canonicalPayload,
          'pinned_root_pem_preview': _pemDebugPreview(
            pinnedRootPublicKey,
          ),
          'leaf_key_pem_preview': _pemDebugPreview(
            signingMetadata.signingPublicKey,
          ),
          'public_key_sig_b64_len':
              '${signingMetadata.publicKeySignature.length}',
        }),
      );
    }
  }

  String _pemDebugPreview(String pem) {
    final t = pem.replaceAll('\r', '').trim();
    if (t.isEmpty) {
      return '(empty)';
    }
    if (t.length <= 360) {
      return t;
    }
    return '${t.substring(0, 200)}…[${t.length} total chars]…'
        '${t.substring(t.length - 120)}';
  }

  List<int> _extractEcPublicKeyBytesFromPem(
    String pem, {
    required String keyRole,
    Map<String, String> ubbFileDev = const {},
  }) {
    Map<String, String> keyShapeDetails({
      required int derLength,
      required int valueByteLen,
      int? firstByte,
      String? extra,
    }) {
      return {
        'tag': kUtilivosDevBundleErrorTag,
        'key_role': keyRole,
        'der_length': '$derLength',
        'spki_value_bytes_len': '$valueByteLen',
        'value_first_byte':
            firstByte == null ? 'n/a' : '0x${firstByte.toRadixString(16)}',
        'expected': 'SPKI EC P-256: uncompressed point, 65 bytes, 0x04 prefix',
        'pem_preview': _pemDebugPreview(pem),
        if (extra != null) 'parse_error': extra,
      };
    }

    final normalized = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
    if (normalized.isEmpty) {
      throw ToolBundleFormatException(
        'Signing key is missing in download metadata.',
        devOnlyDetails: _devDetailsWithUbb(
          ubbFileDev,
          keyShapeDetails(
            derLength: 0,
            valueByteLen: 0,
            extra: 'empty_after_pem_stripping',
          ),
        ),
      );
    }
    try {
      final der = base64Decode(normalized);
      final parser = ASN1Parser(der);
      final topSequence = parser.nextObject() as ASN1Sequence;
      final bitString = topSequence.elements[1] as ASN1BitString;
      final bytes = bitString.valueBytes();
      if (bytes.isEmpty) {
        throw ToolBundleFormatException(
          'Invalid EC public key format for bundle verification.',
          devOnlyDetails: _devDetailsWithUbb(
            ubbFileDev,
            keyShapeDetails(
              derLength: der.length,
              valueByteLen: 0,
              extra: 'empty_bit_string',
            ),
          ),
        );
      }
      if (bytes.length != 65 || bytes.first != 0x04) {
        throw ToolBundleFormatException(
          'Invalid EC public key format for bundle verification.',
          devOnlyDetails: _devDetailsWithUbb(
            ubbFileDev,
            keyShapeDetails(
              derLength: der.length,
              valueByteLen: bytes.length,
              firstByte: bytes.first,
            ),
          ),
        );
      }
      return bytes.sublist(1);
    } catch (e) {
      if (e is ToolBundleFormatException) {
        rethrow;
      }
      throw ToolBundleFormatException(
        'Invalid EC public key format for bundle verification.',
        devOnlyDetails: _devDetailsWithUbb(ubbFileDev, {
          'tag': kUtilivosDevBundleErrorTag,
          'key_role': keyRole,
          'exception': e.toString(),
          'pem_preview': _pemDebugPreview(pem),
        }),
      );
    }
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

String? _deriveIconAccentColorWorker(String iconPath) {
  final iconFile = File(iconPath);
  if (!iconFile.existsSync()) {
    return null;
  }
  try {
    final bytes = iconFile.readAsBytesSync();
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
    return _accentRgbToHex(r, g, b);
  } catch (_) {
    return null;
  }
}

String _accentRgbToHex(int r, int g, int b) {
  String hex(int value) =>
      value.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${hex(r)}${hex(g)}${hex(b)}';
}
