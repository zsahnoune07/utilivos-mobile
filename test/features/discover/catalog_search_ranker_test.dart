import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/features/discover/application/catalog_search_ranker.dart';
import 'package:utilivos_mobile/features/discover/data/models/catalog_models.dart';

CatalogPlugin _p({
  required String slug,
  required String name,
  List<String> tags = const <String>[],
  String? shortDescription,
  String? longDescription,
}) {
  return CatalogPlugin(
    id: slug,
    slug: slug,
    name: name,
    categorySlug: 'c',
    categoryName: 'Cat',
    pricingType: 'free',
    tags: tags,
    shortDescription: shortDescription,
    longDescription: longDescription,
  );
}

void main() {
  group('catalogPluginSearchScore', () {
    test('name match weighted higher than description', () {
      final byName = _p(slug: 'a', name: 'BMI Helper');
      final byDesc = _p(
        slug: 'b',
        name: 'Other',
        longDescription: 'unrelated bmi text here',
      );
      final kw = searchKeywordsFromQuery('bmi');
      expect(
        catalogPluginSearchScore(byName, kw) >=
            catalogPluginSearchScore(byDesc, kw),
        isTrue,
      );
    });

    test('tag match without name substring', () {
      final plugin = _p(
        slug: 'c',
        name: 'Wallet Tools',
        tags: <String>['crypto', 'finance'],
      );
      final score = catalogPluginSearchScore(
        plugin,
        searchKeywordsFromQuery('crypto'),
      );
      expect(score, greaterThan(0));
    });

    test('multi-keyword additive', () {
      final plugin = _p(
        slug: 'd',
        name: 'Health BMI',
        tags: <String>['fitness'],
        shortDescription: 'wellness guide',
      );
      final s1 = catalogPluginSearchScore(
        plugin,
        searchKeywordsFromQuery('health'),
      );
      final s2 = catalogPluginSearchScore(
        plugin,
        searchKeywordsFromQuery('health wellness'),
      );
      expect(s2, greaterThan(s1));
    });
  });

  group('buildDiscoverSearchResults', () {
    test('retains API row when client score is zero', () {
      final api = _p(slug: 'api-only', name: 'Obscure', tags: <String>[]);
      final cache = _p(
        slug: 'tagged',
        name: 'X',
        tags: <String>['crypto'],
      );
      final out = buildDiscoverSearchResults(
        query: 'crypto',
        apiAccumulatedPageItems: <CatalogPlugin>[api],
        cacheUnion: <CatalogPlugin>[cache],
      );
      expect(out.map((e) => e.slug).toList(), contains('tagged'));
      expect(out.map((e) => e.slug).toList(), contains('api-only'));
    });
  });
}
