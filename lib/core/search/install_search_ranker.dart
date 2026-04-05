import '../../features/installs/data/models/install_models.dart';
import '../../features/discover/application/catalog_search_ranker.dart';

const int _scoreDisplayName = 3;
const int _scoreSlug = 2;
const int _scoreCategory = 2;
const int _scoreDescription = 1;

/// Same spirit as catalog search: name strongest, category like a tag, description weakest.
int deviceInstallSearchScore(DeviceInstallRecord tool, List<String> keywords) {
  if (keywords.isEmpty) {
    return 0;
  }
  var total = 0;
  final name = tool.displayName.toLowerCase();
  final slug = tool.pluginSlug.toLowerCase();
  final cat = tool.categoryName?.toLowerCase() ?? '';
  final desc = tool.pluginDescription?.toLowerCase() ?? '';

  for (final kw in keywords) {
    if (kw.isEmpty) {
      continue;
    }
    if (name.contains(kw)) {
      total += _scoreDisplayName;
    }
    if (slug.contains(kw)) {
      total += _scoreSlug;
    }
    if (cat.isNotEmpty && cat.contains(kw)) {
      total += _scoreCategory;
    }
    if (desc.contains(kw)) {
      total += _scoreDescription;
    }
  }
  return total;
}

List<DeviceInstallRecord> rankDeviceInstallsForSearch({
  required List<DeviceInstallRecord> installs,
  required String query,
}) {
  final keywords = searchKeywordsFromQuery(query);
  if (keywords.isEmpty) {
    return List<DeviceInstallRecord>.from(installs);
  }
  final scored = installs
      .map(
        (DeviceInstallRecord t) =>
            (tool: t, score: deviceInstallSearchScore(t, keywords)),
      )
      .where((({DeviceInstallRecord tool, int score}) e) => e.score > 0)
      .toList(growable: false);
  scored.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) {
      return c;
    }
    return a.tool.displayName.toLowerCase().compareTo(
          b.tool.displayName.toLowerCase(),
        );
  });
  return scored.map((e) => e.tool).toList(growable: false);
}
