import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/navigation/deep_link_parser.dart';
import 'core/pro/free_tier_usage_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final usageStore = await FreeTierUsageStore.open();
  String? deepLinkRoute;
  try {
    deepLinkRoute = parseAppDeepLink(await AppLinks().getInitialLink());
  } catch (_) {
    // AppLinks may throw on unsupported platforms.
  }
  runApp(
    UtilivoApp(
      freeTierUsageStore: usageStore,
      initialDeepLinkRoute: deepLinkRoute,
    ),
  );
}
