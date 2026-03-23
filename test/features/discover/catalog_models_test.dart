import 'package:flutter_test/flutter_test.dart';
import 'package:utilivo_mobile/features/discover/data/models/catalog_models.dart';

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
  });
}
