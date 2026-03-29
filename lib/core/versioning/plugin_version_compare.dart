/// Compares plugin semver-like strings the same way [InstalledToolsController] does.
bool isPluginUpdateAvailable({
  required String? installedVersion,
  required String? latestVersion,
}) {
  if (installedVersion == null || latestVersion == null) {
    return false;
  }

  final installed = installedVersion.trim();
  final latest = latestVersion.trim();
  if (installed.isEmpty || latest.isEmpty || installed == latest) {
    return false;
  }

  final installedParts = parsePluginVersionParts(installed);
  final latestParts = parsePluginVersionParts(latest);
  if (installedParts == null || latestParts == null) {
    return latest != installed;
  }

  final maxLength = installedParts.length > latestParts.length
      ? installedParts.length
      : latestParts.length;
  for (var i = 0; i < maxLength; i++) {
    final installedPart = i < installedParts.length ? installedParts[i] : 0;
    final latestPart = i < latestParts.length ? latestParts[i] : 0;
    if (latestPart > installedPart) {
      return true;
    }
    if (latestPart < installedPart) {
      return false;
    }
  }

  return false;
}

List<int>? parsePluginVersionParts(String value) {
  final parts = value.split('.');
  if (parts.isEmpty) {
    return null;
  }

  final parsed = <int>[];
  final leadingDigitsPattern = RegExp(r'^\d+');
  for (final rawPart in parts) {
    final match = leadingDigitsPattern.firstMatch(rawPart.trim());
    if (match == null) {
      return null;
    }
    parsed.add(int.parse(match.group(0)!));
  }
  return parsed;
}
