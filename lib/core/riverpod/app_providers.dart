import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/app_dependencies.dart';
import '../persistence/app_database.dart';
import '../../features/installs/application/installed_tools_controller.dart';
import '../../features/installs/data/models/install_models.dart';

/// Open Drift database; overridden from [main] with the app SQLite file.
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);

/// Scoped under [UtilivosApp] so any [Consumer] can reach the live dependency graph.
final appDependenciesProvider = Provider<AppDependencies>((ref) {
  throw StateError(
    'appDependenciesProvider is not overridden. '
    'Override it from main() (or tests) via ProviderScope.',
  );
});

/// Riverpod access to the same controller used by home/discover.
final installedToolsControllerProvider = Provider<InstalledToolsController>((ref) {
  return ref.watch(appDependenciesProvider).installedToolsController;
});

/// Reactive install list from Drift (same backing store as [installedToolsControllerProvider]).
final installedToolsStreamProvider =
    StreamProvider<List<DeviceInstallRecord>>((ref) {
  return ref.watch(appDependenciesProvider).installedToolsStore.watch();
});
