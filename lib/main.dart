import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/navigation/deep_link_parser.dart';
import 'core/persistence/app_database.dart';
import 'core/persistence/secure_to_drift_migration.dart';
import 'core/pro/free_tier_usage_store.dart';
import 'core/sessions/drift_ephemeral_runtime_state_repository.dart';
import 'core/sessions/runtime_state_scope_service.dart';
import 'core/navigation/app_routes.dart';
import 'core/riverpod/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final usageStore = await FreeTierUsageStore.open();
  final AppDatabase appDatabase = AppDatabase.createPersistent();
  await migrateSecureToolCachesToDriftIfNeeded(appDatabase);
  await RuntimeStateScopeService(
    DriftEphemeralRuntimeStateRepository(appDatabase),
  ).runMaintenance();
  String? deepLinkRoute;
  try {
    deepLinkRoute = parseAppDeepLink(await AppLinks().getInitialLink());
  } catch (_) {
    // AppLinks can fail on some devices or if not configured.
  }
  if (Platform.isAndroid) {
    try {
      const MethodChannel ch = MethodChannel('com.utilivo.utilivo_mobile/runtime');
      final int? pending = await ch.invokeMethod<int>('getPendingWidgetConfigureId');
      if (pending != null) {
        deepLinkRoute =
            '${AppRoutes.widgetConfigure}?androidAppWidgetId=$pending';
      }
    } catch (_) {
      // Engine may not expose the channel in tests.
    }
  }
  runApp(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(appDatabase),
      ],
      child: UtilivoApp(
        freeTierUsageStore: usageStore,
        appDatabase: appDatabase,
        initialDeepLinkRoute: deepLinkRoute,
      ),
    ),
  );
}
