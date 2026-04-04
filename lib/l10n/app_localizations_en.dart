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
  String get searchInToolLibrary => 'Search in Tool Library';

  @override
  String get noInstalledTools => 'No installed tools';

  @override
  String get noInstalledToolsMessage =>
      'Browse the Tool Library to install your first tool.';

  @override
  String get homeInstallsLoadFailedTitle => 'Couldn\'t load installed tools';

  @override
  String get homeInstallsOfflineDetail =>
      'Connect to the internet to load your tools from the library. Once installed, tools work offline.';

  @override
  String get homeInstallsBootstrapFailedDetail =>
      'Your saved tool list could not be read. Try again.';

  @override
  String get homeInstallsSyncFailedDetail =>
      'Something went wrong while refreshing installed tools. Try again.';

  @override
  String get homeInstallsCorruptLocalDetail =>
      'Some saved tool data was invalid. Your list was cleared — try again to resync.';

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

  @override
  String get searchStartTypingTitle => 'Find your tools';

  @override
  String get searchStartTypingMessage =>
      'Start typing to find tools on this device.';

  @override
  String get recentSearchesSection => 'Recent searches';

  @override
  String get recentActivitySection => 'Recent activity';

  @override
  String get recentToolNoLongerInstalled => 'This tool is no longer installed.';

  @override
  String get clearSearchHistory => 'Clear history';

  @override
  String get runtimeMenuCheckUpdates => 'Check updates';

  @override
  String get runtimeMenuDetails => 'Details';

  @override
  String get runtimeMenuReport => 'Report';

  @override
  String get runtimeMenuSaveSession => 'Save session';

  @override
  String get runtimeMenuLoadSession => 'Load session';

  @override
  String get runtimeMenuManageSessions => 'Manage sessions';

  @override
  String get runtimeSessionSaveTitle => 'Save session';

  @override
  String get runtimeSessionSaveHint =>
      'Name this session so you can reopen it later.';

  @override
  String get runtimeSessionNameLabel => 'Session name';

  @override
  String get runtimeSessionSaveConfirm => 'Save';

  @override
  String get runtimeSessionSaved => 'Session saved';

  @override
  String get runtimeSessionNothingToSave =>
      'Nothing to save yet. Use the tool, then try again.';

  @override
  String get runtimeSessionLoadTitle => 'Load session';

  @override
  String get runtimeSessionNoSaved => 'No saved sessions for this tool.';

  @override
  String get runtimeSessionManageTitle => 'Saved sessions';

  @override
  String get runtimeSessionRename => 'Rename';

  @override
  String get runtimeSessionDelete => 'Delete';

  @override
  String get runtimeSessionDeleteConfirmTitle => 'Delete session?';

  @override
  String runtimeSessionDeleteConfirmMessage(String name) {
    return 'Remove \"$name\"? This cannot be undone.';
  }

  @override
  String get runtimeSessionRenameTitle => 'Rename session';

  @override
  String get runtimeSessionNotFound =>
      'That saved session was not found for this tool.';

  @override
  String get runtimeSessionProRequired => 'Saved sessions are a Pro feature.';

  @override
  String get runtimeSessionUpdateButton => 'Update session';

  @override
  String get runtimeSessionUpdated => 'Session updated';

  @override
  String get runtimeSessionUpdateFailed => 'Could not update session';

  @override
  String get runtimeSessionBarFallback => 'Saved session';

  @override
  String get widgetConfigureProRequired =>
      'Free includes one home screen widget. Pro unlocks unlimited widgets.';

  @override
  String get widgetConfigureSecondWidgetPaywall =>
      'You\'ve used your free home screen widget. Pro unlocks unlimited widgets.';

  @override
  String get widgetConfigureTitle => 'Choose tool for widget';

  @override
  String get runtimeHomeWidgetProRequired =>
      'This widget is not set up in the app. Open Utilivo and add the widget again, or unlock Pro for unlimited widgets.';

  @override
  String get runtimeUpToDateTitle => 'Up to date';

  @override
  String get runtimeUpToDateMessage => 'You have the latest version installed.';

  @override
  String get runtimeUpdateAvailableTitle => 'Update available';

  @override
  String runtimeUpdateAvailableBody(
    String latestVersion,
    String installedVersion,
  ) {
    return 'Latest: $latestVersion. Installed: $installedVersion.';
  }

  @override
  String get runtimeToolDetailsTitle => 'Tool details';

  @override
  String get runtimeReportTitle => 'Report a problem';

  @override
  String get runtimeReportReasonLabel => 'Reason';

  @override
  String get runtimeReportDetailsLabel => 'Additional details';

  @override
  String get runtimeReportSubmit => 'Submit';

  @override
  String get runtimeReportQueued =>
      'Thanks — your report was saved locally. Server submission is not wired up yet.';

  @override
  String get runtimeReportSelectReason => 'Choose a reason';

  @override
  String get reportReasonNotWorking => 'Not working';

  @override
  String get reportReasonIncorrect => 'Incorrect or misleading';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsTooShort =>
      'Please enter a few more details (at least 4 characters).';

  @override
  String get checkingUpdates => 'Checking for updates…';

  @override
  String get latestVersionLabel => 'Latest version';

  @override
  String get catalogSearchEmptyTitle => 'No tools found';

  @override
  String get catalogSearchEmptyMessage =>
      'Try different words or clear filters.';
}
