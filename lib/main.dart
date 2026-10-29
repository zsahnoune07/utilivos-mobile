import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/navigation/deep_link_parser.dart';
import 'core/persistence/app_database.dart';
import 'core/persistence/secure_to_drift_migration.dart';
import 'core/pro/free_tier_usage_store.dart';
import 'core/riverpod/app_providers.dart';
import 'core/sessions/drift_ephemeral_runtime_state_repository.dart';
import 'core/sessions/runtime_state_scope_service.dart';
import 'core/navigation/app_routes.dart';
import 'core/notifications/app_notification_service.dart';
import 'core/notifications/notification_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const sentryDsnFromEnv =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  final sentryDsnTrimmedForInit = sentryDsnFromEnv.trim();
  // sentry 9.x rejects null/empty DSN inside [SentryFlutter.init] ("DSN is required").
  if (sentryDsnTrimmedForInit.isEmpty) {
    await _runUtilivosApp();
    return;
  }

  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      options.dsn = sentryDsnTrimmedForInit;
      options.tracesSampleRate = 0.15;
      options.sendDefaultPii = false;
    },
    appRunner: _runUtilivosApp,
  );
}

Future<void> _runUtilivosApp() async {
  const sentryDsnRaw = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  final sentryDsnTrimmed = sentryDsnRaw.trim();
  assert(() {
    if (sentryDsnTrimmed.isEmpty) {
      debugPrint(
        'UTILIVOS: SENTRY_DSN is unset; Sentry is disabled (expected for local debug).',
      );
    }
    return true;
  }());
  if (kReleaseMode && sentryDsnTrimmed.isEmpty) {
    debugPrint(
      'UTILIVOS: SENTRY_DSN is empty in release build; crash reporting is disabled. '
      'Pass --dart-define=SENTRY_DSN=... (e.g. via tool/flutter_build_from_env.sh).',
    );
  }

  final usageStore = await FreeTierUsageStore.open();
  final AppDatabase appDatabase = AppDatabase.createPersistent();
  await migrateSecureToolCachesToDriftIfNeeded(appDatabase);
  await RuntimeStateScopeService(
    DriftEphemeralRuntimeStateRepository(appDatabase),
  ).runMaintenance();
  String? deepLinkRoute;
  try {
    deepLinkRoute = parseAppDeepLink(
      await AppLinks().getInitialLink().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      ),
    );
  } catch (_) {
    // AppLinks can fail on some devices or if not configured.
  }
  if (Platform.isAndroid) {
    try {
      const MethodChannel ch =
          MethodChannel('com.utilivos.utilivos_mobile/runtime');
      final int? pending = await ch
          .invokeMethod<int>('getPendingWidgetConfigureId')
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      if (pending != null) {
        deepLinkRoute =
            '${AppRoutes.widgetConfigure}?androidAppWidgetId=$pending';
      }
    } catch (_) {
      // Engine may not expose the channel in tests.
    }
  }

  final notificationPreferences = await NotificationPreferences.open();
  final appNotificationService = AppNotificationService(
    notificationPreferences: notificationPreferences,
  );
  await appNotificationService.initialize();

  final dependencies = AppDependencies.create(
    freeTierUsageStore: usageStore,
    appDatabase: appDatabase,
    notificationPreferences: notificationPreferences,
    appNotificationService: appNotificationService,
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(appDatabase),
        appDependenciesProvider.overrideWithValue(dependencies),
      ],
      child: UtilivosApp(
        dependencies: dependencies,
        freeTierUsageStore: usageStore,
        appDatabase: appDatabase,
        initialDeepLinkRoute: deepLinkRoute,
      ),
    ),
  );
}
