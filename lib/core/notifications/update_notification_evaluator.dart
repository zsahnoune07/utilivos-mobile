import '../../features/installs/data/models/install_models.dart';

String updateDedupeKey(String slug, String? latestVersion) {
  final v = (latestVersion ?? '').trim();
  return '${slug.trim().toLowerCase()}|$v';
}

/// Tools that [newly] became eligible for an "update available" notification.
List<DeviceInstallRecord> findNewlyNoteworthyUpdates({
  required List<DeviceInstallRecord> before,
  required List<DeviceInstallRecord> after,
  required Set<String> dedupeKeys,
  required bool restrictToWidgetSlugs,
  required Set<String> widgetSlugs,
}) {
  final beforeBySlug = <String, DeviceInstallRecord>{
    for (final t in before) t.pluginSlug.trim().toLowerCase(): t,
  };
  final out = <DeviceInstallRecord>[];
  for (final a in after) {
    if (!a.updateAvailable) {
      continue;
    }
    final slugKey = a.pluginSlug.trim().toLowerCase();
    if (restrictToWidgetSlugs && !widgetSlugs.contains(slugKey)) {
      continue;
    }
    final latest = a.latestAvailableVersion?.trim();
    if (latest == null || latest.isEmpty) {
      continue;
    }
    final key = updateDedupeKey(a.pluginSlug, latest);
    if (dedupeKeys.contains(key)) {
      continue;
    }
    final b = beforeBySlug[slugKey];
    if (b == null) {
      out.add(a);
      continue;
    }
    if (!b.updateAvailable) {
      out.add(a);
      continue;
    }
    if (b.latestAvailableVersion != a.latestAvailableVersion) {
      out.add(a);
    }
  }
  return out;
}
