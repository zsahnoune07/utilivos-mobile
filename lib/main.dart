import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/navigation/deep_link_parser.dart';
import 'core/persistence/app_database.dart';
import 'core/persistence/secure_to_drift_migration.dart';
import 'core/pro/free_tier_usage_store.dart';
import 'core/riverpod/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final usageStore = await FreeTierUsageStore.open();
  final AppDatabase appDatabase = AppDatabase.createPersistent();
  await migrateSecureToolCachesToDriftIfNeeded(appDatabase);
  String? deepLinkRoute;
  try {
    deepLinkRoute = parseAppDeepLink(await AppLinks().getInitialLink());
  } catch (_) {
    // AppLinks can fail on some devices or if not configured.
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
