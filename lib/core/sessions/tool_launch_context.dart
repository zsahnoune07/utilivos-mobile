import 'dart:math';

/// How the host opened the tool runtime (see plan_pro_features.md Phase 2).
enum ToolLaunchMode {
  /// Default: state lives only in [RuntimeStateScopeService] for this [launchToken].
  ephemeral,

  /// `restore=1` / explicit resume: legacy disk snapshot via [ToolSessionStore].
  legacyFileRestore,

  /// Home-screen widget (same persistence rules as ephemeral for now).
  widget,

  /// Drift named session (`?session=id`); bridge uses ephemeral storage seeded from DB.
  namedSession,
}

/// Immutable metadata for a single runtime open; every navigation to the tool
/// runtime must use a new [launchToken].
class ToolLaunchContext {
  ToolLaunchContext({
    required this.toolId,
    required this.toolSlug,
    required this.launchMode,
    required this.launchToken,
    required this.openedAt,
    this.sessionId,
    this.widgetInstanceId,
    this.installId,
    this.installedVersion,
  }) : assert(toolId.trim().isNotEmpty),
       assert(toolSlug.trim().isNotEmpty),
       assert(launchToken.trim().isNotEmpty);

  /// Stable install row id when known; otherwise falls back to [toolSlug].
  final String toolId;

  final String toolSlug;

  final ToolLaunchMode launchMode;

  /// Drift named session id (Phase 3+); null for ephemeral / legacy restore.
  final String? sessionId;

  /// Platform widget instance id when [launchMode] is [ToolLaunchMode.widget].
  final String? widgetInstanceId;

  final String? installId;
  final String? installedVersion;

  /// Unique per open; drives ephemeral row key in SQLite.
  final String launchToken;

  final DateTime openedAt;

  /// `persistState` / `loadState` use Drift ephemeral storage.
  bool get usesEphemeralPersistence =>
      launchMode == ToolLaunchMode.ephemeral ||
      launchMode == ToolLaunchMode.widget ||
      launchMode == ToolLaunchMode.namedSession;

  /// Clear ephemeral row when leaving runtime (not for legacy file restore).
  bool get shouldClearEphemeralOnDispose => usesEphemeralPersistence;

  /// Shown to the tool as `restoreRequested` (legacy disk path).
  bool get legacyRestoreRequested =>
      launchMode == ToolLaunchMode.legacyFileRestore;

  static String generateLaunchToken() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = Random.secure().nextInt(1 << 30);
    return 'launch_${t}_$r';
  }

  /// Normal open from home / library / catalog.
  factory ToolLaunchContext.ephemeral({
    required String toolId,
    required String toolSlug,
    String? installId,
    String? installedVersion,
  }) {
    return ToolLaunchContext(
      toolId: toolId,
      toolSlug: toolSlug,
      launchMode: ToolLaunchMode.ephemeral,
      launchToken: generateLaunchToken(),
      openedAt: DateTime.now().toUtc(),
      installId: installId,
      installedVersion: installedVersion,
    );
  }

  /// `restore=1` deep link / pin — keeps using [ToolSessionStore] until Phase 3.
  factory ToolLaunchContext.legacyFileRestore({
    required String toolId,
    required String toolSlug,
    String? installId,
    String? installedVersion,
  }) {
    return ToolLaunchContext(
      toolId: toolId,
      toolSlug: toolSlug,
      launchMode: ToolLaunchMode.legacyFileRestore,
      launchToken: generateLaunchToken(),
      openedAt: DateTime.now().toUtc(),
      installId: installId,
      installedVersion: installedVersion,
    );
  }

  factory ToolLaunchContext.widgetLaunch({
    required String toolId,
    required String toolSlug,
    required String widgetInstanceId,
    String? installId,
    String? installedVersion,
  }) {
    return ToolLaunchContext(
      toolId: toolId,
      toolSlug: toolSlug,
      launchMode: ToolLaunchMode.widget,
      launchToken: generateLaunchToken(),
      openedAt: DateTime.now().toUtc(),
      widgetInstanceId: widgetInstanceId,
      installId: installId,
      installedVersion: installedVersion,
    );
  }

  factory ToolLaunchContext.namedSessionLaunch({
    required String toolId,
    required String toolSlug,
    required String sessionId,
    String? installId,
    String? installedVersion,
  }) {
    final sid = sessionId.trim();
    return ToolLaunchContext(
      toolId: toolId,
      toolSlug: toolSlug,
      launchMode: ToolLaunchMode.namedSession,
      launchToken: generateLaunchToken(),
      openedAt: DateTime.now().toUtc(),
      sessionId: sid,
      installId: installId,
      installedVersion: installedVersion,
    );
  }
}
