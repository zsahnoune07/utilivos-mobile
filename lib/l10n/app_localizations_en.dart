// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Utilivo';

  @override
  String get tools => 'Tools';

  @override
  String get marketplace => 'Tool Library';

  @override
  String get settings => 'Settings';

  @override
  String get searchTools => 'Search tools...';

  @override
  String get browseMarketplace => 'Browse Tool Library';

  @override
  String get noInstalledTools => 'No installed tools';

  @override
  String get noInstalledToolsMessage =>
      'Browse the Tool Library to install your first tool.';

  @override
  String get noToolsMatchSearch => 'No tools match your search';

  @override
  String get noToolsMatchSearchMessage => 'Try a different search term.';

  @override
  String get launchTool => 'Launch tool';

  @override
  String get deleteTool => 'Delete tool';

  @override
  String get deleteToolConfirmTitle => 'Delete tool?';

  @override
  String deleteToolConfirmMessage(String toolName) {
    return 'Remove \"$toolName\" from this device? You can install it again from the Marketplace.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get pinTool => 'Pin tool';

  @override
  String get unpinTool => 'Unpin tool';

  @override
  String get install => 'Install';

  @override
  String get installing => 'Installing...';

  @override
  String get installed => 'Installed';

  @override
  String get viewDetails => 'View Details';

  @override
  String get discover => 'Discover';

  @override
  String get discoverSubtitle =>
      'Browse categories and discover tools from utilivo-api.';

  @override
  String get loadMore => 'Load More';

  @override
  String get category => 'Category';

  @override
  String get installedVersion => 'Installed version';

  @override
  String get status => 'Status';

  @override
  String get installedAt => 'Installed at';

  @override
  String updateAvailable(String version) {
    return 'Update available: $version';
  }

  @override
  String get upToDate => 'Up to date';
}
