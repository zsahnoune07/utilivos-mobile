import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/core/networking/api_client.dart';
import 'package:utilivo_mobile/core/networking/network_exception.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_api.dart';
import 'package:utilivo_mobile/features/discover/data/catalog_cache_store.dart';
import 'package:utilivo_mobile/features/discover/data/models/catalog_cache_snapshot.dart';

void main() {
  test(
    'listCategories falls back to cache when network is unavailable',
    () async {
      var shouldFailCategories = false;
      var categoryRequests = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((
        RequestOptions options,
      ) async {
        if (options.path == '/v1/categories') {
          categoryRequests += 1;
          if (shouldFailCategories) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'offline',
            );
          }
          return _jsonResponse(<String, dynamic>{
            'data': <dynamic>[
              <String, dynamic>{
                'id': 'cat_1',
                'slug': 'dev-tools',
                'name': 'Dev Tools',
              },
            ],
          }, 200);
        }

        return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
      });
      addTearDown(() => dio.close(force: true));

      final api = CatalogApi(
        ApiClient(dio),
        cacheStore: _InMemoryCatalogCacheStore(),
        cachePolicy: const CatalogCachePolicy(
          freshFor: Duration.zero,
          maxStale: Duration(days: 7),
        ),
      );

      final online = await api.listCategories();
      expect(online, hasLength(1));
      expect(online.first.slug, 'dev-tools');

      shouldFailCategories = true;
      final cached = await api.listCategories();
      expect(cached, hasLength(1));
      expect(cached.first.name, 'Dev Tools');
      expect(categoryRequests, 2);
    },
  );

  test('listPlugins cache key respects query and cursor parameters', () async {
    var shouldFailPlugins = false;
    var pluginRequests = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/plugins') {
        pluginRequests += 1;
        if (shouldFailPlugins) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'offline',
          );
        }
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 'plugin_1',
                'slug': 'json-tools',
                'name': 'JSON Tools',
                'category_slug': 'dev-tools',
                'category_name': 'Dev Tools',
                'pricing_type': 'free',
              },
            ],
            'next_cursor': 'cursor_2',
          },
        }, 200);
      }

      return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
    });
    addTearDown(() => dio.close(force: true));

    final api = CatalogApi(
      ApiClient(dio),
      cacheStore: _InMemoryCatalogCacheStore(),
      cachePolicy: const CatalogCachePolicy(
        freshFor: Duration.zero,
        maxStale: Duration(days: 7),
      ),
    );

    final firstPage = await api.listPlugins(
      category: 'dev-tools',
      search: 'json',
      limit: 10,
    );
    expect(firstPage.items, hasLength(1));
    expect(firstPage.nextCursor, 'cursor_2');

    shouldFailPlugins = true;
    final cachedPage = await api.listPlugins(
      category: 'dev-tools',
      search: 'json',
      limit: 10,
    );
    expect(cachedPage.items, hasLength(1));
    expect(cachedPage.items.first.slug, 'json-tools');
    expect(pluginRequests, 2);

    await expectLater(
      () => api.listPlugins(category: 'security', search: 'json', limit: 10),
      throwsA(isA<NetworkException>()),
    );
  });

  test('listPlugins maps icon_url into thumbnailUrl', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/plugins') {
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 'plugin_1',
                'slug': 'json-tools',
                'name': 'JSON Tools',
                'category_slug': 'dev-tools',
                'category_name': 'Dev Tools',
                'pricing_type': 'free',
                'icon_url': '/v1/plugins/json-tools/icon',
              },
            ],
          },
        }, 200);
      }
      return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
    });
    addTearDown(() => dio.close(force: true));

    final api = CatalogApi(
      ApiClient(dio),
      cacheStore: _InMemoryCatalogCacheStore(),
      cachePolicy: const CatalogCachePolicy(
        freshFor: Duration.zero,
        maxStale: Duration(days: 7),
      ),
    );

    final page = await api.listPlugins();
    expect(page.items, hasLength(1));
    expect(page.items.first.thumbnailUrl, '/v1/plugins/json-tools/icon');
  });

  test('getPluginBySlug does not use cache after maxStale window', () async {
    var shouldFailPluginDetail = false;
    var now = DateTime.utc(2026, 3, 5, 10);

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = _FakeHttpClientAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/v1/plugins/tool-a') {
        if (shouldFailPluginDetail) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'offline',
          );
        }
        return _jsonResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'id': 'plugin_a',
            'slug': 'tool-a',
            'name': 'Tool A',
            'category_slug': 'dev-tools',
            'category_name': 'Dev Tools',
            'pricing_type': 'free',
          },
        }, 200);
      }

      return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
    });
    addTearDown(() => dio.close(force: true));

    final api = CatalogApi(
      ApiClient(dio),
      cacheStore: _InMemoryCatalogCacheStore(),
      cachePolicy: const CatalogCachePolicy(
        freshFor: Duration.zero,
        maxStale: Duration(hours: 24),
      ),
      nowProvider: () => now,
    );

    final online = await api.getPluginBySlug('tool-a');
    expect(online.slug, 'tool-a');

    now = now.add(const Duration(days: 2));
    shouldFailPluginDetail = true;
    await expectLater(
      () => api.getPluginBySlug('tool-a'),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'listPluginVersions falls back to cache during offline window',
    () async {
      var shouldFailVersions = false;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
      dio.httpClientAdapter = _FakeHttpClientAdapter((
        RequestOptions options,
      ) async {
        if (options.path == '/v1/plugins/tool-a/versions') {
          if (shouldFailVersions) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'offline',
            );
          }
          return _jsonResponse(<String, dynamic>{
            'data': <String, dynamic>{
              'items': <dynamic>[
                <String, dynamic>{
                  'id': 'version_1',
                  'version': '2.0.0',
                  'changelog': 'Initial release',
                },
              ],
            },
          }, 200);
        }

        return _jsonResponse(<String, dynamic>{'data': <dynamic>[]}, 200);
      });
      addTearDown(() => dio.close(force: true));

      final api = CatalogApi(
        ApiClient(dio),
        cacheStore: _InMemoryCatalogCacheStore(),
        cachePolicy: const CatalogCachePolicy(
          freshFor: Duration.zero,
          maxStale: Duration(days: 3),
        ),
      );

      final online = await api.listPluginVersions('tool-a');
      expect(online, hasLength(1));
      expect(online.first.version, '2.0.0');

      shouldFailVersions = true;
      final cached = await api.listPluginVersions('tool-a');
      expect(cached, hasLength(1));
      expect(cached.first.changelog, 'Initial release');
    },
  );
}

class _InMemoryCatalogCacheStore implements CatalogCacheStore {
  CatalogCacheSnapshot _snapshot = CatalogCacheSnapshot.empty;

  @override
  Future<void> clear() async {
    _snapshot = CatalogCacheSnapshot.empty;
  }

  @override
  Future<CatalogCacheSnapshot> read() async {
    return _snapshot;
  }

  @override
  Future<void> write(CatalogCacheSnapshot snapshot) async {
    _snapshot = snapshot;
  }
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
