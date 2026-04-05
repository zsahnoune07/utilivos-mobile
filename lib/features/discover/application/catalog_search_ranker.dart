import '../data/models/catalog_models.dart';

const int _scoreName = 3;
const int _scoreTag = 2;
const int _scoreDescription = 1;

/// Splits user query into normalized keywords (whitespace).
List<String> searchKeywordsFromQuery(String query) {
  final t = query.trim().toLowerCase();
  if (t.isEmpty) {
    return const <String>[];
  }
  return t
      .split(RegExp(r'\s+'))
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}

/// Per-keyword additive score: name +3, any tag +2, short/long description +1.
int catalogPluginSearchScore(CatalogPlugin plugin, List<String> keywords) {
  if (keywords.isEmpty) {
    return 0;
  }
  var total = 0;
  final name = plugin.name.toLowerCase();
  final shortD = plugin.shortDescription?.toLowerCase() ?? '';
  final longD = plugin.longDescription?.toLowerCase() ?? '';
  final tags = plugin.tags.map((String e) => e.toLowerCase()).toList(growable: false);

  for (final kw in keywords) {
    if (kw.isEmpty) {
      continue;
    }
    if (name.contains(kw)) {
      total += _scoreName;
    }
    var tagHit = false;
    for (final tag in tags) {
      if (tag.contains(kw)) {
        tagHit = true;
        break;
      }
    }
    if (tagHit) {
      total += _scoreTag;
    }
    if (shortD.contains(kw) || longD.contains(kw)) {
      total += _scoreDescription;
    }
  }
  return total;
}

/// Sorts by score descending; tie-breaker: name, then slug.
List<CatalogPlugin> rankCatalogPlugins({
  required List<CatalogPlugin> plugins,
  required String query,
  int maxResults = 100,
}) {
  final keywords = searchKeywordsFromQuery(query);
  if (keywords.isEmpty) {
    return List<CatalogPlugin>.from(plugins);
  }
  final scored = plugins
      .map(
        (CatalogPlugin p) =>
            (plugin: p, score: catalogPluginSearchScore(p, keywords)),
      )
      .where((({CatalogPlugin plugin, int score}) e) => e.score > 0)
      .toList(growable: false);
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) {
      return c;
    }
    final n = a.plugin.name.toLowerCase().compareTo(b.plugin.name.toLowerCase());
    if (n != 0) {
      return n;
    }
    return a.plugin.slug.toLowerCase().compareTo(b.plugin.slug.toLowerCase());
  });
  final list = scored.map((e) => e.plugin).toList(growable: false);
  if (list.length <= maxResults) {
    return list;
  }
  return list.sublist(0, maxResults);
}

/// Merges plugins by [CatalogPlugin.slug]; keeps first occurrence order, then fills missing from others.
const int kDiscoverSearchResultsCap = 100;

/// Ranks cached + API search hits; keeps API-only rows that scored 0 on the client.
List<CatalogPlugin> buildDiscoverSearchResults({
  required String query,
  required List<CatalogPlugin> apiAccumulatedPageItems,
  required List<CatalogPlugin> cacheUnion,
  int maxResults = kDiscoverSearchResultsCap,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return List<CatalogPlugin>.from(apiAccumulatedPageItems);
  }
  final merged = mergeCatalogPluginsBySlug(
    apiAccumulatedPageItems,
    cacheUnion,
  );
  final rankedPositive = rankCatalogPlugins(
    plugins: merged,
    query: trimmed,
    maxResults: maxResults,
  );
  final seen = <String>{
    for (final CatalogPlugin p in rankedPositive) p.slug.trim().toLowerCase(),
  };
  final tail = <CatalogPlugin>[];
  for (final CatalogPlugin p in apiAccumulatedPageItems) {
    final k = p.slug.trim().toLowerCase();
    if (k.isEmpty || seen.contains(k)) {
      continue;
    }
    seen.add(k);
    tail.add(p);
  }
  final combined = <CatalogPlugin>[...rankedPositive, ...tail];
  if (combined.length > maxResults) {
    return combined.sublist(0, maxResults);
  }
  return combined;
}

List<CatalogPlugin> mergeCatalogPluginsBySlug(
  List<CatalogPlugin> primary,
  List<CatalogPlugin> secondary,
) {
  final seen = <String>{};
  final out = <CatalogPlugin>[];
  void addAll(List<CatalogPlugin> list) {
    for (final p in list) {
      final k = p.slug.trim().toLowerCase();
      if (k.isEmpty || seen.contains(k)) {
        continue;
      }
      seen.add(k);
      out.add(p);
    }
  }

  addAll(primary);
  addAll(secondary);
  return out;
}
