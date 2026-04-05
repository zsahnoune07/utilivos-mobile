import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Utilivo'**
  String get appTitle;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @marketplace.
  ///
  /// In en, this message translates to:
  /// **'Tool Library'**
  String get marketplace;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchTools.
  ///
  /// In en, this message translates to:
  /// **'Search tools...'**
  String get searchTools;

  /// No description provided for @browseMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Browse Tool Library'**
  String get browseMarketplace;

  /// No description provided for @searchInToolLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search in Tool Library'**
  String get searchInToolLibrary;

  /// No description provided for @noInstalledTools.
  ///
  /// In en, this message translates to:
  /// **'No installed tools'**
  String get noInstalledTools;

  /// No description provided for @noInstalledToolsMessage.
  ///
  /// In en, this message translates to:
  /// **'Browse the Tool Library to install your first tool.'**
  String get noInstalledToolsMessage;

  /// No description provided for @homeInstallsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load installed tools'**
  String get homeInstallsLoadFailedTitle;

  /// No description provided for @homeInstallsOfflineDetail.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to load your tools from the library. Once installed, tools work offline.'**
  String get homeInstallsOfflineDetail;

  /// No description provided for @homeInstallsBootstrapFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Your saved tool list could not be read. Try again.'**
  String get homeInstallsBootstrapFailedDetail;

  /// No description provided for @homeInstallsSyncFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while refreshing installed tools. Try again.'**
  String get homeInstallsSyncFailedDetail;

  /// No description provided for @homeInstallsCorruptLocalDetail.
  ///
  /// In en, this message translates to:
  /// **'Some saved tool data was invalid. Your list was cleared — try again to resync.'**
  String get homeInstallsCorruptLocalDetail;

  /// No description provided for @noToolsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No tools match your search'**
  String get noToolsMatchSearch;

  /// No description provided for @noToolsMatchSearchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get noToolsMatchSearchMessage;

  /// No description provided for @launchTool.
  ///
  /// In en, this message translates to:
  /// **'Launch tool'**
  String get launchTool;

  /// No description provided for @deleteTool.
  ///
  /// In en, this message translates to:
  /// **'Delete tool'**
  String get deleteTool;

  /// No description provided for @deleteToolConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete tool?'**
  String get deleteToolConfirmTitle;

  /// No description provided for @deleteToolConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{toolName}\" from this device? You can install it again from the Marketplace.'**
  String deleteToolConfirmMessage(String toolName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @pinTool.
  ///
  /// In en, this message translates to:
  /// **'Pin tool'**
  String get pinTool;

  /// No description provided for @unpinTool.
  ///
  /// In en, this message translates to:
  /// **'Unpin tool'**
  String get unpinTool;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installing.
  ///
  /// In en, this message translates to:
  /// **'Installing...'**
  String get installing;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse categories and discover tools from utilivo-api.'**
  String get discoverSubtitle;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @installedVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed version'**
  String get installedVersion;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @installedAt.
  ///
  /// In en, this message translates to:
  /// **'Installed at'**
  String get installedAt;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String updateAvailable(String version);

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get upToDate;

  /// No description provided for @searchStartTypingTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your tools'**
  String get searchStartTypingTitle;

  /// No description provided for @searchStartTypingMessage.
  ///
  /// In en, this message translates to:
  /// **'Start typing to find tools on this device.'**
  String get searchStartTypingMessage;

  /// No description provided for @recentSearchesSection.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearchesSection;

  /// No description provided for @recentActivitySection.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivitySection;

  /// No description provided for @recentToolNoLongerInstalled.
  ///
  /// In en, this message translates to:
  /// **'This tool is no longer installed.'**
  String get recentToolNoLongerInstalled;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearSearchHistory;

  /// No description provided for @runtimeMenuCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check updates'**
  String get runtimeMenuCheckUpdates;

  /// No description provided for @runtimeMenuDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get runtimeMenuDetails;

  /// No description provided for @runtimeMenuReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get runtimeMenuReport;

  /// No description provided for @runtimeMenuSaveSession.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get runtimeMenuSaveSession;

  /// No description provided for @runtimeMenuLoadSession.
  ///
  /// In en, this message translates to:
  /// **'Load session'**
  String get runtimeMenuLoadSession;

  /// No description provided for @runtimeMenuManageSessions.
  ///
  /// In en, this message translates to:
  /// **'Manage sessions'**
  String get runtimeMenuManageSessions;

  /// No description provided for @runtimeSessionSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get runtimeSessionSaveTitle;

  /// No description provided for @runtimeSessionSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Name this session so you can reopen it later.'**
  String get runtimeSessionSaveHint;

  /// No description provided for @runtimeSessionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get runtimeSessionNameLabel;

  /// No description provided for @runtimeSessionSaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get runtimeSessionSaveConfirm;

  /// No description provided for @runtimeSessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get runtimeSessionSaved;

  /// No description provided for @runtimeSessionNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save yet. Use the tool, then try again.'**
  String get runtimeSessionNothingToSave;

  /// No description provided for @runtimeSessionLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Load session'**
  String get runtimeSessionLoadTitle;

  /// No description provided for @runtimeSessionNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved sessions for this tool.'**
  String get runtimeSessionNoSaved;

  /// No description provided for @runtimeSessionManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved sessions'**
  String get runtimeSessionManageTitle;

  /// No description provided for @runtimeSessionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get runtimeSessionRename;

  /// No description provided for @runtimeSessionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get runtimeSessionDelete;

  /// No description provided for @runtimeSessionDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get runtimeSessionDeleteConfirmTitle;

  /// No description provided for @runtimeSessionDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"? This cannot be undone.'**
  String runtimeSessionDeleteConfirmMessage(String name);

  /// No description provided for @runtimeSessionRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get runtimeSessionRenameTitle;

  /// No description provided for @runtimeSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'That saved session was not found for this tool.'**
  String get runtimeSessionNotFound;

  /// No description provided for @runtimeSessionProRequired.
  ///
  /// In en, this message translates to:
  /// **'Saved sessions are a Pro feature.'**
  String get runtimeSessionProRequired;

  /// No description provided for @runtimeSessionUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update session'**
  String get runtimeSessionUpdateButton;

  /// No description provided for @runtimeSessionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Session updated'**
  String get runtimeSessionUpdated;

  /// No description provided for @runtimeSessionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update session'**
  String get runtimeSessionUpdateFailed;

  /// No description provided for @runtimeSessionBarFallback.
  ///
  /// In en, this message translates to:
  /// **'Saved session'**
  String get runtimeSessionBarFallback;

  /// No description provided for @widgetConfigureProRequired.
  ///
  /// In en, this message translates to:
  /// **'Free includes one home screen widget. Pro unlocks unlimited widgets.'**
  String get widgetConfigureProRequired;

  /// No description provided for @widgetConfigureSecondWidgetPaywall.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used your free home screen widget. Pro unlocks unlimited widgets.'**
  String get widgetConfigureSecondWidgetPaywall;

  /// No description provided for @widgetConfigureTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose tool for widget'**
  String get widgetConfigureTitle;

  /// No description provided for @runtimeHomeWidgetProRequired.
  ///
  /// In en, this message translates to:
  /// **'This widget is not set up in the app. Open Utilivo and add the widget again, or unlock Pro for unlimited widgets.'**
  String get runtimeHomeWidgetProRequired;

  /// No description provided for @runtimeUpToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get runtimeUpToDateTitle;

  /// No description provided for @runtimeUpToDateMessage.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version installed.'**
  String get runtimeUpToDateMessage;

  /// No description provided for @runtimeUpdateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get runtimeUpdateAvailableTitle;

  /// No description provided for @runtimeUpdateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Latest: {latestVersion}. Installed: {installedVersion}.'**
  String runtimeUpdateAvailableBody(
    String latestVersion,
    String installedVersion,
  );

  /// No description provided for @runtimeToolDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool details'**
  String get runtimeToolDetailsTitle;

  /// No description provided for @runtimeReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get runtimeReportTitle;

  /// No description provided for @runtimeReportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get runtimeReportReasonLabel;

  /// No description provided for @runtimeReportDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get runtimeReportDetailsLabel;

  /// No description provided for @runtimeReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get runtimeReportSubmit;

  /// No description provided for @runtimeReportQueued.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your report was saved locally. Server submission is not wired up yet.'**
  String get runtimeReportQueued;

  /// No description provided for @runtimeReportSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason'**
  String get runtimeReportSelectReason;

  /// No description provided for @reportReasonNotWorking.
  ///
  /// In en, this message translates to:
  /// **'Not working'**
  String get reportReasonNotWorking;

  /// No description provided for @reportReasonIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect or misleading'**
  String get reportReasonIncorrect;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please enter a few more details (at least 4 characters).'**
  String get reportDetailsTooShort;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get checkingUpdates;

  /// No description provided for @latestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest version'**
  String get latestVersionLabel;

  /// No description provided for @catalogSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tools found'**
  String get catalogSearchEmptyTitle;

  /// No description provided for @catalogSearchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try different words or clear filters.'**
  String get catalogSearchEmptyMessage;

  /// No description provided for @runtimeHostAppUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get runtimeHostAppUpdateTitle;

  /// No description provided for @runtimeHostAppUpdateBody.
  ///
  /// In en, this message translates to:
  /// **'This tool requires a newer version of the app.'**
  String get runtimeHostAppUpdateBody;

  /// No description provided for @runtimeHostAppUpdateCta.
  ///
  /// In en, this message translates to:
  /// **'Update App'**
  String get runtimeHostAppUpdateCta;

  /// No description provided for @runtimeHostAppUpdateNoStoreUrl.
  ///
  /// In en, this message translates to:
  /// **'Store link is not configured for this build.'**
  String get runtimeHostAppUpdateNoStoreUrl;

  /// No description provided for @runtimePermissionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get runtimePermissionRequiredTitle;

  /// No description provided for @runtimePermissionContinueCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get runtimePermissionContinueCta;

  /// No description provided for @runtimePermissionDefaultRationale.
  ///
  /// In en, this message translates to:
  /// **'This tool needs additional access to your device to run correctly.'**
  String get runtimePermissionDefaultRationale;

  /// No description provided for @runtimePermissionDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'This tool cannot run without the permissions it needs.'**
  String get runtimePermissionDeniedBody;

  /// No description provided for @runtimePermissionRetryCta.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get runtimePermissionRetryCta;

  /// No description provided for @runtimePermissionOpenSettingsCta.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get runtimePermissionOpenSettingsCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
