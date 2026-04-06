import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/features/discover/data/models/catalog_models.dart';

void main() {
  group('CatalogPlugin', () {
    test('tierIsPro treats premium, pro, and paid as Pro catalog tier', () {
      expect(CatalogPlugin.tierIsPro('premium'), isTrue);
      expect(CatalogPlugin.tierIsPro('pro'), isTrue);
      expect(CatalogPlugin.tierIsPro('paid'), isTrue);
      expect(CatalogPlugin.tierIsPro('Premium'), isTrue);
      expect(CatalogPlugin.tierIsPro('free'), isFalse);
      expect(CatalogPlugin.tierIsPro(''), isFalse);
    });

    test('fromJson maps API premium tier and premium_preview', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p1',
        'slug': 'tool-a',
        'name': 'Tool A',
        'category_slug': 'utilities',
        'category_name': 'Utilities',
        'pricing_type': 'premium',
        'premium_preview': true,
      });
      expect(plugin.isPro, isTrue);
      expect(plugin.proPreview, isTrue);
    });

    test('fromJson pro_preview still works', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p2',
        'slug': 'tool-b',
        'name': 'Tool B',
        'category_slug': 'utilities',
        'category_name': 'Utilities',
        'pricing_type': 'pro',
        'pro_preview': true,
      });
      expect(plugin.isPro, isTrue);
      expect(plugin.proPreview, isTrue);
    });

    test('catalogIconRef uses icon_url when present', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p3',
        'slug': 'alpha',
        'name': 'Alpha',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
        'icon_url': 'https://cdn.example/icons/a.png',
      });
      expect(plugin.catalogIconRef, 'https://cdn.example/icons/a.png');
      expect(plugin.iconUrl, 'https://cdn.example/icons/a.png');
    });

    test('catalogIconRef prefers thumbnail_url over icon_url', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p3b',
        'slug': 'alpha-thumb',
        'name': 'Alpha Thumb',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
        'thumbnail_url': 'https://cdn.example/thumbs/a.png',
        'icon_url': 'https://cdn.example/icons/a.png',
      });
      expect(plugin.catalogIconRef, 'https://cdn.example/thumbs/a.png');
      expect(plugin.thumbnailUrl, 'https://cdn.example/thumbs/a.png');
      expect(plugin.iconUrl, 'https://cdn.example/icons/a.png');
    });

    test('empty thumbnail_url does not hide valid icon_url', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p3c',
        'slug': 'alpha-empty-thumb',
        'name': 'Alpha Empty Thumb',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
        'thumbnail_url': '   ',
        'icon_url': 'https://cdn.example/icons/a.png',
      });
      expect(plugin.catalogIconRef, 'https://cdn.example/icons/a.png');
      expect(plugin.thumbnailUrl, isNull);
      expect(plugin.iconUrl, 'https://cdn.example/icons/a.png');
    });

    test('catalogIconRef falls back to plugin icon path when icon_url missing', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p4',
        'slug': 'json-tools',
        'name': 'JSON',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
      });
      expect(plugin.catalogIconRef, '/v1/plugins/json-tools/icon');
    });

    test('catalogListIconRef prefers icon_url over thumbnail_url', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p5',
        'slug': 'list-icon',
        'name': 'List Icon',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
        'thumbnail_url': 'https://cdn.example/thumbs/wide.png',
        'icon_url': 'https://cdn.example/icons/square.png',
      });
      expect(plugin.catalogListIconRef, 'https://cdn.example/icons/square.png');
    });

    test('catalogListIconRef uses thumbnail only when icon_url missing', () {
      final plugin = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 'p6',
        'slug': 'thumb-only',
        'name': 'Thumb Only',
        'category_slug': 'cat',
        'category_name': 'Cat',
        'pricing_type': 'free',
        'thumbnail_url': 'https://cdn.example/thumbs/t.png',
      });
      expect(plugin.catalogListIconRef, '/v1/plugins/thumb-only/icon');
    });

    test('catalogListIconRef falls back to thumbnail when slug empty and thumb set', () {
      const plugin = CatalogPlugin(
        id: 'p7',
        slug: '',
        name: 'X',
        categorySlug: 'c',
        categoryName: 'C',
        pricingType: 'free',
        thumbnailUrl: 'https://cdn.example/thumbs/last.png',
      );
      expect(plugin.catalogListIconRef, 'https://cdn.example/thumbs/last.png');
    });

    test('fromJson parses tags as list or comma-separated string', () {
      final fromList = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 't1',
        'slug': 's',
        'name': 'N',
        'category_slug': 'c',
        'category_name': 'C',
        'pricing_type': 'free',
        'tags': <String>['a', 'b'],
      });
      expect(fromList.tags, <String>['a', 'b']);

      final fromCsv = CatalogPlugin.fromJson(<String, dynamic>{
        'id': 't2',
        'slug': 's2',
        'name': 'N2',
        'category_slug': 'c',
        'category_name': 'C',
        'pricing_type': 'free',
        'tags': 'x, y ,z',
      });
      expect(fromCsv.tags, <String>['x', 'y', 'z']);
    });
  });
}
