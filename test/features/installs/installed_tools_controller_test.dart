import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_api.dart';
import 'package:utilivo_mobile/features/downloads/application/tool_bundle_download_service.dart';
import 'package:utilivo_mobile/features/downloads/data/downloaded_tool_bundle_store.dart';
import 'package:utilivo_mobile/features/downloads/data/models/downloaded_tool_bundle.dart';
import 'package:utilivo_mobile/features/installs/application/installed_tools_controller.dart';
import 'package:utilivo_mobile/features/installs/data/installed_tools_store.dart';
import 'package:utilivo_mobile/features/installs/data/installs_sync_meta_store.dart';
import 'package:utilivo_mobile/features/installs/data/installs_api.dart';
import 'package:utilivo_mobile/features/installs/data/installs_organization_store.dart';
import 'package:utilivo_mobile/features/installs/data/models/install_models.dart';
import 'package:utilivo_mobile/features/installs/data/models/installs_organization_models.dart';

void main() {
  test(
    'bootstrap loads cached tools first then marks update availability after online sync',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
      );
      final controller = _createController(
        store: store,
        responder: (RequestOptions options) async {
          if (options.path == '/v1/installs') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[_installJson(version: '1.0.0')],
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-alpha/versions') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'ID': 'version_2',
                    'Version': '1.1.0',
                    'Changelog': 'Update',
                  },
                ],
              },
            }, 200);
          }
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'not_found',
              'message': 'not found',
            },
          }, 404);
        },
      );

      await controller.bootstrap();
      await _waitForSettled(controller);

      expect(controller.installedTools, hasLength(1));
      final tool = controller.installedTools.first;
      expect(tool.latestAvailableVersion, '1.1.0');
      expect(tool.updateAvailable, true);
    },
  );

  test(
    'sync adds installs that exist only on the server while preserving local fields',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[
          _installRecord(
            version: '1.0.0',
          ).copyWith(pinned: true, folderId: 'folder_1'),
        ],
      );
      final syncMeta = _InMemoryInstallsSyncMetaStore();
      final folderNow = DateTime.parse('2026-03-04T09:00:00Z').toUtc();
      final organizationStore = _InMemoryInstallsOrganizationStore(
        initial: InstallsOrganizationState(
          folders: <ToolFolder>[
            ToolFolder(
              id: 'folder_1',
              name: 'Test',
              iconKey: 'folder',
              colorKey: 'purple',
              createdAt: folderNow,
              updatedAt: folderNow,
            ),
          ],
          homeSortMode: HomeSortMode.defaultManual,
        ),
      );
      final controller = _createController(
        store: store,
        syncMetaStore: syncMeta,
        organizationStore: organizationStore,
        responder: (RequestOptions options) async {
          if (options.path == '/v1/installs') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  _installJson(version: '1.0.0'),
                  <String, dynamic>{
                    'ID': 'install_2',
                    'DeviceID': 'device_1',
                    'PluginID': 'plugin_2',
                    'PluginSlug': 'tool-beta',
                    'InstalledVersionID': 'version_b1',
                    'InstalledVersion': '1.0.0',
                    'Source': 'marketplace',
                    'InstalledAt': '2026-03-05T09:00:00Z',
                    'UpdatedAt': '2026-03-05T09:00:00Z',
                  },
                ],
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-alpha') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'id': 'plugin_1',
                'slug': 'tool-alpha',
                'name': 'Tool Alpha',
                'category_slug': 'utilities',
                'category_name': 'Utilities',
                'pricing_type': 'free',
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-beta') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'id': 'plugin_2',
                'slug': 'tool-beta',
                'name': 'Tool Beta',
                'category_slug': 'utilities',
                'category_name': 'Utilities',
                'pricing_type': 'free',
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-alpha/versions' ||
              options.path == '/v1/plugins/tool-beta/versions') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{'ID': 'version_1', 'Version': '1.0.0'},
                ],
              },
            }, 200);
          }
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'not_found',
              'message': 'not found',
            },
          }, 404);
        },
      );

      await controller.bootstrap();
      await _waitForSettled(controller);

      final slugs = controller.installedTools
          .map((DeviceInstallRecord t) => t.pluginSlug)
          .toSet();
      expect(slugs, containsAll(<String>['tool-alpha', 'tool-beta']));
      final alpha = controller.installedTools.firstWhere(
        (DeviceInstallRecord t) => t.pluginSlug == 'tool-alpha',
      );
      expect(alpha.pinned, true);
      expect(alpha.folderId, 'folder_1');
      expect(syncMeta.lastWritten, isNotNull);
    },
  );

  test('offline sync falls back to cached installed tools', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final controller = _createController(
      store: store,
      responder: (RequestOptions options) async {
        if (options.path == '/v1/installs') {
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'server_error',
              'message': 'upstream unavailable',
            },
          }, 503);
        }
        return _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'not found',
          },
        }, 404);
      },
    );

    await controller.bootstrap();
    await _waitForSettled(controller);

    expect(controller.state, InstalledToolsState.ready);
    expect(controller.installedTools, hasLength(1));
    expect(controller.statusMessage, contains('Offline mode'));
  });

  test('recordInstall updates in-memory state and persists', () async {
    final store = _InMemoryInstalledToolsStore();
    final controller = _createController(
      store: store,
      responder: (RequestOptions options) async {
        if (options.path == '/v1/plugins/tool-alpha/versions') {
          return _jsonResponse(<String, dynamic>{
            'data': <String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{'ID': 'version_1', 'Version': '1.0.0'},
              ],
            },
          }, 200);
        }
        return _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'not found',
          },
        }, 404);
      },
    );

    await controller.recordInstall(_installRecord(version: '1.0.0'));
    await _waitForSettled(controller);

    expect(controller.installedTools, hasLength(1));
    expect(controller.installedTools.first.pluginSlug, 'tool-alpha');
    expect((await store.read()), hasLength(1));
  });

  test(
    'bootstrap hydrates icon metadata from cached bundles without overriding category color',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[
          _installRecord(version: '1.0.0').copyWith(categoryColor: '#112233'),
        ],
      );
      final bundleStore = _InMemoryDownloadedToolBundleStore(
        initial: <DownloadedToolBundle>[
          DownloadedToolBundle(
            pluginSlug: 'tool-alpha',
            version: '1.0.0',
            localPath: '/tmp/tool-alpha-1.0.0.ubb',
            sha256: 'abc',
            downloadedAt: DateTime.parse('2026-03-04T09:00:00Z').toUtc(),
            pluginName: 'Tool Alpha',
            category: 'Utilities',
            iconPath: '/tmp/tool-alpha-icon.png',
            iconAccentColor: '#AA3300',
          ),
        ],
      );
      final controller = _createController(
        store: store,
        responder: (RequestOptions options) async {
          if (options.path == '/v1/installs') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[_installJson(version: '1.0.0')],
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-alpha') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'id': 'plugin_1',
                'slug': 'tool-alpha',
                'name': 'Tool Alpha',
                'category_slug': 'utilities',
                'category_name': 'Utilities',
                'category_color': '#223344',
                'pricing_type': 'free',
              },
            }, 200);
          }
          if (options.path == '/v1/plugins/tool-alpha/versions') {
            return _jsonResponse(<String, dynamic>{
              'data': <String, dynamic>{
                'items': <Map<String, dynamic>>[
                  <String, dynamic>{'ID': 'version_1', 'Version': '1.0.0'},
                ],
              },
            }, 200);
          }
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'not_found',
              'message': 'not found',
            },
          }, 404);
        },
        toolBundleDownloadService: ToolBundleDownloadService(
          dio: Dio(),
          store: bundleStore,
        ),
      );

      await controller.bootstrap();
      await _waitForSettled(controller);

      final install = controller.installedTools.first;
      expect(install.iconPath, '/tmp/tool-alpha-icon.png');
      expect(install.cardAccentColor, '#AA3300');
      expect(install.categoryColor, '#223344');
    },
  );

  test('folder lifecycle create update delete keeps tools installed', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final controller = _createController(
      store: store,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );

    await controller.bootstrap();
    final folder = await controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    await controller.updateFolder(
      folderId: folder.id,
      name: 'Work Updated',
      iconKey: 'tools',
      colorKey: 'green',
    );
    await controller.assignToolToFolder(
      pluginSlug: 'tool-alpha',
      folderId: folder.id,
    );
    expect(controller.installedTools.first.folderId, folder.id);

    await controller.deleteFolder(folder.id);
    expect(controller.folders, isEmpty);
    expect(controller.installedTools.first.folderId, isNull);
    expect(controller.installedTools, hasLength(1));
  });

  test('sorting by name, install date, and last used works', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[
        _installRecord(version: '1.0.0').copyWith(
          pluginSlug: 'b-tool',
          pluginName: 'B Tool',
          installedAt: DateTime.parse('2026-03-05T10:00:00Z').toUtc(),
        ),
        _installRecord(version: '1.0.0').copyWith(
          id: 'install_2',
          pluginSlug: 'a-tool',
          pluginName: 'A Tool',
          installedAt: DateTime.parse('2026-03-06T10:00:00Z').toUtc(),
        ),
      ],
    );
    final controller = _createController(
      store: store,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await controller.bootstrap();

    await controller.setHomeSortMode(HomeSortMode.nameAsc);
    expect(controller.installedTools.first.displayName, 'A Tool');

    await controller.setHomeSortMode(HomeSortMode.installDateOldest);
    expect(controller.installedTools.first.displayName, 'B Tool');

    await controller.setHomeSortMode(HomeSortMode.lastUsed);
    await controller.markToolLaunched('a-tool');
    expect(controller.installedTools.first.pluginSlug, 'a-tool');
  });

  test('sort preference persists across bootstrap', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final orgStore = _InMemoryInstallsOrganizationStore();

    final firstController = _createController(
      store: store,
      organizationStore: orgStore,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await firstController.bootstrap();
    await firstController.setHomeSortMode(HomeSortMode.nameDesc);

    final secondController = _createController(
      store: store,
      organizationStore: orgStore,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await secondController.bootstrap();
    expect(secondController.homeSortMode, HomeSortMode.nameDesc);
  });

  test(
    'grouped home data enforces pinned, folders, then unpinned with per-group sorting',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[
          _installRecord(version: '1.0.0').copyWith(
            pluginSlug: 'pinned-z',
            pluginName: 'Pinned Z',
            pinned: true,
          ),
          _installRecord(version: '1.0.0').copyWith(
            id: 'install_2',
            pluginSlug: 'pinned-a',
            pluginName: 'Pinned A',
            pinned: true,
            folderId: 'folder_1',
          ),
          _installRecord(version: '1.0.0').copyWith(
            id: 'install_3',
            pluginSlug: 'folder-c',
            pluginName: 'Folder C',
            folderId: 'folder_1',
          ),
          _installRecord(version: '1.0.0').copyWith(
            id: 'install_4',
            pluginSlug: 'folder-b',
            pluginName: 'Folder B',
            folderId: 'folder_1',
          ),
          _installRecord(version: '1.0.0').copyWith(
            id: 'install_5',
            pluginSlug: 'unpinned-d',
            pluginName: 'Unpinned D',
          ),
          _installRecord(version: '1.0.0').copyWith(
            id: 'install_6',
            pluginSlug: 'unpinned-a',
            pluginName: 'Unpinned A',
          ),
        ],
      );
      final organizationStore = _InMemoryInstallsOrganizationStore(
        initial: InstallsOrganizationState(
          folders: <ToolFolder>[
            ToolFolder(
              id: 'folder_1',
              name: 'Work',
              iconKey: 'work',
              colorKey: 'blue',
              createdAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
              manualOrder: 0,
            ),
          ],
          homeSortMode: HomeSortMode.defaultManual,
        ),
      );
      final controller = _createController(
        store: store,
        organizationStore: organizationStore,
        responder: (options) async => _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'not found',
          },
        }, 404),
      );
      await controller.bootstrap();
      await controller.setHomeSortMode(HomeSortMode.nameAsc);

      final grouped = controller.groupedHomeData;
      expect(
        grouped.pinnedTools.map((tool) => tool.displayName).toList(),
        <String>['Pinned A', 'Pinned Z'],
      );
      expect(grouped.folders, hasLength(1));
      expect(
        grouped.folders.first.tools.map((tool) => tool.displayName).toList(),
        <String>['Folder B', 'Folder C'],
      );
      expect(
        grouped.unpinnedTools.map((tool) => tool.displayName).toList(),
        <String>['Unpinned A', 'Unpinned D'],
      );
      expect(grouped.folders.first.tools.any((tool) => tool.pinned), isFalse);
      expect(
        controller.toolsForFolder('folder_1').map((tool) => tool.displayName),
        <String>['Folder B', 'Folder C', 'Pinned A'],
      );
    },
  );

  test(
    'uninstalling tool in folder removes stale folder membership only',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
      );
      final controller = _createController(
        store: store,
        responder: (options) async => _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'not found',
          },
        }, 404),
      );
      await controller.bootstrap();
      final folder = await controller.createFolder(
        name: 'Ops',
        iconKey: 'tools',
        colorKey: 'slate',
      );
      await controller.assignToolToFolder(
        pluginSlug: 'tool-alpha',
        folderId: folder.id,
      );

      await controller.removeInstall(controller.installedTools.first);
      expect(controller.installedTools, isEmpty);
      expect(controller.folders, hasLength(1));
      expect(controller.groupedHomeData.folders.first.tools, isEmpty);
    },
  );

  test('createFolder rejects names longer than 16 characters', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final controller = _createController(
      store: store,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await controller.bootstrap();

    expect(
      () => controller.createFolder(
        name: 'ABCDEFGHIJKLMNOPQ',
        iconKey: 'work',
        colorKey: 'blue',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('createFolder rejects duplicate folder name', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final controller = _createController(
      store: store,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await controller.bootstrap();
    await controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    expect(controller.folders, hasLength(1));

    expect(
      () => controller.createFolder(
        name: 'Work',
        iconKey: 'tools',
        colorKey: 'green',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => controller.createFolder(
        name: '  work  ',
        iconKey: 'tools',
        colorKey: 'green',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(controller.folders, hasLength(1));
  });

  test('updateFolder rejects duplicate folder name', () async {
    final store = _InMemoryInstalledToolsStore(
      initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
    );
    final controller = _createController(
      store: store,
      responder: (options) async => _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{'code': 'not_found', 'message': 'not found'},
      }, 404),
    );
    await controller.bootstrap();
    final folder1 = await controller.createFolder(
      name: 'Work',
      iconKey: 'work',
      colorKey: 'blue',
    );
    await controller.createFolder(
      name: 'Personal',
      iconKey: 'home',
      colorKey: 'green',
    );
    expect(controller.folders, hasLength(2));

    expect(
      () => controller.updateFolder(
        folderId: folder1.id,
        name: 'Personal',
        iconKey: 'work',
        colorKey: 'blue',
      ),
      throwsA(isA<ArgumentError>()),
    );
    await controller.updateFolder(
      folderId: folder1.id,
      name: 'Work',
      iconKey: 'documents',
      colorKey: 'slate',
    );
    expect(controller.folderById(folder1.id)?.name, 'Work');
  });

  test(
    'updateFolder allows unchanged legacy long name but rejects new long names',
    () async {
      final store = _InMemoryInstalledToolsStore(
        initial: <DeviceInstallRecord>[_installRecord(version: '1.0.0')],
      );
      final legacyFolder = ToolFolder(
        id: 'folder_legacy',
        name: 'Legacy Folder Name Too Long',
        iconKey: 'work',
        colorKey: 'blue',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
        updatedAt: DateTime.parse('2026-03-01T00:00:00Z').toUtc(),
        manualOrder: 0,
      );
      final organizationStore = _InMemoryInstallsOrganizationStore(
        initial: InstallsOrganizationState(
          folders: <ToolFolder>[legacyFolder],
          homeSortMode: HomeSortMode.defaultManual,
        ),
      );

      final controller = _createController(
        store: store,
        organizationStore: organizationStore,
        responder: (options) async => _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'not_found',
            'message': 'not found',
          },
        }, 404),
      );
      await controller.bootstrap();

      await controller.updateFolder(
        folderId: legacyFolder.id,
        name: legacyFolder.name,
        iconKey: 'documents',
        colorKey: 'green',
      );
      expect(controller.folderById(legacyFolder.id)?.name, legacyFolder.name);

      expect(
        () => controller.updateFolder(
          folderId: legacyFolder.id,
          name: 'ABCDEFGHIJKLMNOPQ',
          iconKey: 'documents',
          colorKey: 'green',
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );
}

InstalledToolsController _createController({
  required InstalledToolsStore store,
  InstallsOrganizationStore? organizationStore,
  InstallsSyncMetaStore? syncMetaStore,
  required Future<ResponseBody> Function(RequestOptions options) responder,
  ToolBundleDownloadService? toolBundleDownloadService,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = _FakeHttpClientAdapter(responder);
  final apiClient = ApiClient(dio);

  return InstalledToolsController(
    installsApi: InstallsApi(apiClient),
    catalogApi: CatalogApi(apiClient),
    store: store,
    organizationStore:
        organizationStore ?? _InMemoryInstallsOrganizationStore(),
    syncMetaStore: syncMetaStore,
    toolBundleDownloadService: toolBundleDownloadService,
  );
}

Future<void> _waitForSettled(InstalledToolsController controller) async {
  for (var i = 0; i < 80; i++) {
    if (!controller.isBusy) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

DeviceInstallRecord _installRecord({required String version}) {
  return DeviceInstallRecord(
    id: 'install_1',
    deviceId: 'device_1',
    pluginId: 'plugin_1',
    pluginSlug: 'tool-alpha',
    source: 'marketplace',
    installedAt: DateTime.parse('2026-03-04T09:00:00Z').toUtc(),
    installedVersionId: 'version_1',
    installedVersion: version,
    updatedAt: DateTime.parse('2026-03-04T09:00:00Z').toUtc(),
  );
}

Map<String, dynamic> _installJson({required String version}) {
  return <String, dynamic>{
    'ID': 'install_1',
    'DeviceID': 'device_1',
    'PluginID': 'plugin_1',
    'PluginSlug': 'tool-alpha',
    'InstalledVersionID': 'version_1',
    'InstalledVersion': version,
    'Source': 'marketplace',
    'InstalledAt': '2026-03-04T09:00:00Z',
    'UpdatedAt': '2026-03-04T09:00:00Z',
  };
}

ResponseBody _jsonResponse(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _InMemoryInstallsSyncMetaStore implements InstallsSyncMetaStore {
  DateTime? lastWritten;

  @override
  Future<DateTime?> readLastSyncedAt() async => lastWritten;

  @override
  Future<void> writeLastSyncedAt(DateTime at) async {
    lastWritten = at;
  }
}

class _InMemoryInstalledToolsStore implements InstalledToolsStore {
  _InMemoryInstalledToolsStore({List<DeviceInstallRecord>? initial})
    : _value = initial ?? const <DeviceInstallRecord>[];

  List<DeviceInstallRecord> _value;
  final StreamController<List<DeviceInstallRecord>> _watch =
      StreamController<List<DeviceInstallRecord>>.broadcast();

  @override
  Future<void> clear() async {
    _value = const <DeviceInstallRecord>[];
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_value));
  }

  @override
  Future<List<DeviceInstallRecord>> read() async {
    return _value;
  }

  @override
  Future<void> write(List<DeviceInstallRecord> installs) async {
    _value = installs;
    _watch.add(List<DeviceInstallRecord>.unmodifiable(_value));
  }

  @override
  Stream<List<DeviceInstallRecord>> watch() async* {
    yield List<DeviceInstallRecord>.unmodifiable(_value);
    yield* _watch.stream;
  }
}

class _InMemoryDownloadedToolBundleStore implements DownloadedToolBundleStore {
  _InMemoryDownloadedToolBundleStore({List<DownloadedToolBundle>? initial})
    : _value = initial ?? const <DownloadedToolBundle>[];

  List<DownloadedToolBundle> _value;

  @override
  Future<void> clear() async {
    _value = const <DownloadedToolBundle>[];
  }

  @override
  Future<List<DownloadedToolBundle>> read() async {
    return _value;
  }

  @override
  Future<void> write(List<DownloadedToolBundle> bundles) async {
    _value = bundles;
  }
}

class _InMemoryInstallsOrganizationStore implements InstallsOrganizationStore {
  _InMemoryInstallsOrganizationStore({InstallsOrganizationState? initial})
    : _value = initial ?? InstallsOrganizationState.empty;

  InstallsOrganizationState _value;

  @override
  Future<void> clear() async {
    _value = InstallsOrganizationState.empty;
  }

  @override
  Future<InstallsOrganizationState> read() async {
    return _value;
  }

  @override
  Future<void> write(InstallsOrganizationState state) async {
    _value = state;
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._responder);

  final Future<ResponseBody> Function(RequestOptions options) _responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _responder(options);
  }
}
