import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// App title
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile client for Claude Code & Codex'**
  String get appSubtitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// No description provided for @appLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get appLoading;

  /// No description provided for @appRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get appRetry;

  /// Common cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get commonSaveAs;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get commonLogout;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get commonOptional;

  /// No description provided for @commonScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get commonScanning;

  /// No description provided for @commonUrlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get commonUrlPlaceholder;

  /// No description provided for @commonHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get commonHome;

  /// No description provided for @commonMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get commonMessage;

  /// No description provided for @commonFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get commonFiles;

  /// No description provided for @commonFileViewer.
  ///
  /// In en, this message translates to:
  /// **'File Viewer'**
  String get commonFileViewer;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get commonDeleteConfirmTitle;

  /// No description provided for @commonDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get commonDeleteConfirmMessage;

  /// Tab navigation label for Inbox
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get tabsInbox;

  /// No description provided for @tabsSessions.
  ///
  /// In en, this message translates to:
  /// **'Terminals'**
  String get tabsSessions;

  /// No description provided for @tabsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabsSettings;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty Inbox'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect with friends to start sharing sessions'**
  String get inboxEmptyDescription;

  /// No description provided for @inboxUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get inboxUpdates;

  /// Connection status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String statusConnected(String time);

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get statusConnecting;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get statusActiveNow;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnknown;

  /// No description provided for @statusPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get statusPermissionRequired;

  /// No description provided for @statusLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String statusLastSeen(Object time);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Time ago in minutes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 minute ago} other {{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 hour ago} other {{count} hours ago}}'**
  String timeHoursAgo(num count);

  /// Authentication screen title
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get authTitle;

  /// No description provided for @authAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get authAccessDenied;

  /// No description provided for @authAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get authAuthenticationFailed;

  /// No description provided for @authEnterSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter a secret key'**
  String get authEnterSecretKey;

  /// No description provided for @authInvalidSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid secret key. Please check and try again.'**
  String get authInvalidSecretKey;

  /// No description provided for @authRestoreAccount.
  ///
  /// In en, this message translates to:
  /// **'Restore Account'**
  String get authRestoreAccount;

  /// No description provided for @authEnterUrlManually.
  ///
  /// In en, this message translates to:
  /// **'Enter URL manually'**
  String get authEnterUrlManually;

  /// No description provided for @authPasteAuthUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste the authentication URL from your terminal'**
  String get authPasteAuthUrl;

  /// No description provided for @authAuthenticateTerminal.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Terminal'**
  String get authAuthenticateTerminal;

  /// No description provided for @authAuthenticateWithUrlPaste.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Terminal with URL paste'**
  String get authAuthenticateWithUrlPaste;

  /// No description provided for @authCameraPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permissions are required to scan QR codes'**
  String get authCameraPermissionsRequired;

  /// No description provided for @authExchangingTokens.
  ///
  /// In en, this message translates to:
  /// **'Exchanging tokens...'**
  String get authExchangingTokens;

  /// No description provided for @authClaudeAuthSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to Claude'**
  String get authClaudeAuthSuccess;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Codex and Claude Code mobile client'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted and your account is stored only on your device.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get welcomeCreateAccount;

  /// No description provided for @welcomeLinkOrRestoreAccount.
  ///
  /// In en, this message translates to:
  /// **'Link or restore account'**
  String get welcomeLinkOrRestoreAccount;

  /// No description provided for @welcomeLoginWithMobileApp.
  ///
  /// In en, this message translates to:
  /// **'Login with mobile app'**
  String get welcomeLoginWithMobileApp;

  /// Sessions screen title
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionTitle;

  /// No description provided for @sessionNewSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get sessionNewSession;

  /// No description provided for @sessionStartNewToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Start a new session to get started'**
  String get sessionStartNewToGetStarted;

  /// No description provided for @sessionNoSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionNoSessionsYet;

  /// No description provided for @sessionActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionActiveSessions;

  /// No description provided for @sessionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sessionHistory;

  /// No description provided for @sessionMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get sessionMachine;

  /// No description provided for @sessionSelectMachine.
  ///
  /// In en, this message translates to:
  /// **'Select a machine'**
  String get sessionSelectMachine;

  /// No description provided for @sessionPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get sessionPath;

  /// No description provided for @sessionPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter path'**
  String get sessionPathHint;

  /// No description provided for @sessionInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message ...'**
  String get sessionInputPlaceholder;

  /// No description provided for @sessionStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get sessionStartSession;

  /// No description provided for @sessionStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting session...'**
  String get sessionStarting;

  /// No description provided for @sessionStarted.
  ///
  /// In en, this message translates to:
  /// **'Session Started'**
  String get sessionStarted;

  /// No description provided for @sessionStartedMessage.
  ///
  /// In en, this message translates to:
  /// **'The session has been started successfully.'**
  String get sessionStartedMessage;

  /// No description provided for @sessionFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start session. Make sure the daemon is running on the target machine.'**
  String get sessionFailedToStart;

  /// No description provided for @sessionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Session startup timed out. The machine may be slow or the daemon may not be responding.'**
  String get sessionTimeout;

  /// No description provided for @sessionNotConnectedToServer.
  ///
  /// In en, this message translates to:
  /// **'Not connected to server. Check your internet connection.'**
  String get sessionNotConnectedToServer;

  /// No description provided for @sessionNoMachineSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select a machine to start the session'**
  String get sessionNoMachineSelected;

  /// No description provided for @sessionNoPathSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select a directory to start the session in'**
  String get sessionNoPathSelected;

  /// No description provided for @sessionTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Type'**
  String get sessionTypeTitle;

  /// No description provided for @sessionTypeSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get sessionTypeSimple;

  /// No description provided for @sessionTypeWorktree.
  ///
  /// In en, this message translates to:
  /// **'Worktree'**
  String get sessionTypeWorktree;

  /// No description provided for @sessionTypeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get sessionTypeComingSoon;

  /// New session screen title
  ///
  /// In en, this message translates to:
  /// **'Start New Session'**
  String newSessionTitle(String directory);

  /// No description provided for @newSessionNoMachinesFound.
  ///
  /// In en, this message translates to:
  /// **'No machines found. Start a Happy session on your computer first.'**
  String get newSessionNoMachinesFound;

  /// No description provided for @newSessionAllMachinesOffline.
  ///
  /// In en, this message translates to:
  /// **'All machines appear offline'**
  String get newSessionAllMachinesOffline;

  /// No description provided for @newSessionMachineDetails.
  ///
  /// In en, this message translates to:
  /// **'View machine details →'**
  String get newSessionMachineDetails;

  /// No description provided for @newSessionDirectoryDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Directory Not Found'**
  String get newSessionDirectoryDoesNotExist;

  /// No description provided for @newSessionCreateDirectoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'The directory {directory} does not exist. Do you want to create it?'**
  String newSessionCreateDirectoryConfirm(Object directory);

  /// No description provided for @newSessionSessionSpawningFailed.
  ///
  /// In en, this message translates to:
  /// **'Session spawning failed - no session ID returned.'**
  String get newSessionSessionSpawningFailed;

  /// Session history screen title
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String sessionHistoryTitle(int count);

  /// No description provided for @sessionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions found'**
  String get sessionHistoryEmpty;

  /// No description provided for @sessionHistoryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sessionHistoryToday;

  /// No description provided for @sessionHistoryYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sessionHistoryYesterday;

  /// No description provided for @sessionHistoryDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 day ago} other {{count} days ago}}'**
  String sessionHistoryDaysAgo(num count);

  /// No description provided for @sessionHistoryViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all sessions'**
  String get sessionHistoryViewAll;

  /// Session info screen title
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String sessionInfoTitle(String currentVersion, String requiredVersion);

  /// No description provided for @sessionInfoHappySessionId.
  ///
  /// In en, this message translates to:
  /// **'Happy Session ID'**
  String get sessionInfoHappySessionId;

  /// No description provided for @sessionInfoClaudeCodeSessionId.
  ///
  /// In en, this message translates to:
  /// **'Claude Code Session ID'**
  String get sessionInfoClaudeCodeSessionId;

  /// No description provided for @sessionInfoAiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get sessionInfoAiProvider;

  /// No description provided for @sessionInfoConnectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get sessionInfoConnectionStatus;

  /// No description provided for @sessionInfoCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get sessionInfoCreated;

  /// No description provided for @sessionInfoLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get sessionInfoLastUpdated;

  /// No description provided for @sessionInfoSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get sessionInfoSequence;

  /// No description provided for @sessionInfoMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get sessionInfoMetadata;

  /// No description provided for @sessionInfoHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get sessionInfoHost;

  /// No description provided for @sessionInfoPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get sessionInfoPath;

  /// No description provided for @sessionInfoOperatingSystem.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get sessionInfoOperatingSystem;

  /// No description provided for @sessionInfoProcessId.
  ///
  /// In en, this message translates to:
  /// **'Process ID'**
  String get sessionInfoProcessId;

  /// No description provided for @sessionInfoCliVersion.
  ///
  /// In en, this message translates to:
  /// **'CLI Version'**
  String get sessionInfoCliVersion;

  /// No description provided for @sessionInfoAgentState.
  ///
  /// In en, this message translates to:
  /// **'Agent State'**
  String get sessionInfoAgentState;

  /// No description provided for @sessionInfoControlledByUser.
  ///
  /// In en, this message translates to:
  /// **'Controlled by User'**
  String get sessionInfoControlledByUser;

  /// No description provided for @sessionInfoPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get sessionInfoPendingRequests;

  /// No description provided for @sessionInfoActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get sessionInfoActivity;

  /// No description provided for @sessionInfoThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get sessionInfoThinking;

  /// No description provided for @sessionInfoThinkingSince.
  ///
  /// In en, this message translates to:
  /// **'Thinking Since'**
  String get sessionInfoThinkingSince;

  /// No description provided for @sessionInfoCliVersionOutdated.
  ///
  /// In en, this message translates to:
  /// **'CLI Update Required'**
  String get sessionInfoCliVersionOutdated;

  /// No description provided for @sessionInfoCliVersionOutdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {currentVersion} installed. Update to {requiredVersion} or later'**
  String sessionInfoCliVersionOutdatedMessage(
    Object currentVersion,
    Object requiredVersion,
  );

  /// No description provided for @sessionInfoUpdateCliInstructions.
  ///
  /// In en, this message translates to:
  /// **'Please run npm install -g happy-coder@latest'**
  String get sessionInfoUpdateCliInstructions;

  /// No description provided for @sessionInfoQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get sessionInfoQuickActions;

  /// No description provided for @sessionInfoViewMachine.
  ///
  /// In en, this message translates to:
  /// **'View Machine'**
  String get sessionInfoViewMachine;

  /// No description provided for @sessionInfoViewMachineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View machine details and sessions'**
  String get sessionInfoViewMachineSubtitle;

  /// No description provided for @sessionInfoKillSession.
  ///
  /// In en, this message translates to:
  /// **'Kill Session'**
  String get sessionInfoKillSession;

  /// No description provided for @sessionInfoKillSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to terminate this session?'**
  String get sessionInfoKillSessionConfirm;

  /// No description provided for @sessionInfoKillSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Immediately terminate the session'**
  String get sessionInfoKillSessionSubtitle;

  /// No description provided for @sessionInfoArchiveSession.
  ///
  /// In en, this message translates to:
  /// **'Archive Session'**
  String get sessionInfoArchiveSession;

  /// No description provided for @sessionInfoArchiveSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to archive this session?'**
  String get sessionInfoArchiveSessionConfirm;

  /// No description provided for @sessionInfoArchiveSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this session and stop it'**
  String get sessionInfoArchiveSessionSubtitle;

  /// No description provided for @sessionInfoDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get sessionInfoDeleteSession;

  /// No description provided for @sessionInfoDeleteSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this session'**
  String get sessionInfoDeleteSessionSubtitle;

  /// No description provided for @sessionInfoDeleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Session Permanently?'**
  String get sessionInfoDeleteSessionConfirm;

  /// No description provided for @sessionInfoDeleteSessionWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All messages and data associated with this session will be permanently deleted.'**
  String get sessionInfoDeleteSessionWarning;

  /// No description provided for @sessionInfoCopySessionId.
  ///
  /// In en, this message translates to:
  /// **'Copy Session ID'**
  String get sessionInfoCopySessionId;

  /// No description provided for @sessionInfoCopyMetadata.
  ///
  /// In en, this message translates to:
  /// **'Copy Metadata'**
  String get sessionInfoCopyMetadata;

  /// No description provided for @sessionInfoSessionIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Session ID copied to clipboard'**
  String get sessionInfoSessionIdCopied;

  /// No description provided for @sessionInfoMetadataCopied.
  ///
  /// In en, this message translates to:
  /// **'Metadata copied to clipboard'**
  String get sessionInfoMetadataCopied;

  /// No description provided for @sessionInfoCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy to clipboard'**
  String get sessionInfoCopyFailed;

  /// No description provided for @sessionInfoHappyHome.
  ///
  /// In en, this message translates to:
  /// **'Happy Home'**
  String get sessionInfoHappyHome;

  /// No description provided for @sessionInfoFailedToKillSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to kill session'**
  String get sessionInfoFailedToKillSession;

  /// No description provided for @sessionInfoFailedToArchiveSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive session'**
  String get sessionInfoFailedToArchiveSession;

  /// No description provided for @sessionInfoFailedToDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session'**
  String get sessionInfoFailedToDeleteSession;

  /// No description provided for @sessionInfoSessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted successfully'**
  String get sessionInfoSessionDeleted;

  /// Machine screen title
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String machineTitle(int count);

  /// No description provided for @machineLaunchNewSessionInDirectory.
  ///
  /// In en, this message translates to:
  /// **'Launch New Session in Directory'**
  String get machineLaunchNewSessionInDirectory;

  /// No description provided for @machineOfflineUnableToSpawn.
  ///
  /// In en, this message translates to:
  /// **'Launcher disabled while machine is offline'**
  String get machineOfflineUnableToSpawn;

  /// No description provided for @machineOfflineHelp.
  ///
  /// In en, this message translates to:
  /// **'• Make sure your computer is online\n• Run `happy daemon status` to diagnose\n• Are you running the latest CLI version? Upgrade with `npm install -g happy-coder@latest`'**
  String get machineOfflineHelp;

  /// No description provided for @machineDaemon.
  ///
  /// In en, this message translates to:
  /// **'Daemon'**
  String get machineDaemon;

  /// No description provided for @machineStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get machineStatus;

  /// No description provided for @machineStopDaemon.
  ///
  /// In en, this message translates to:
  /// **'Stop Daemon'**
  String get machineStopDaemon;

  /// No description provided for @machineLastKnownPid.
  ///
  /// In en, this message translates to:
  /// **'Last Known PID'**
  String get machineLastKnownPid;

  /// No description provided for @machineLastKnownHttpPort.
  ///
  /// In en, this message translates to:
  /// **'Last Known HTTP Port'**
  String get machineLastKnownHttpPort;

  /// No description provided for @machineStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started At'**
  String get machineStartedAt;

  /// No description provided for @machineCliVersion.
  ///
  /// In en, this message translates to:
  /// **'CLI Version'**
  String get machineCliVersion;

  /// No description provided for @machineDaemonStateVersion.
  ///
  /// In en, this message translates to:
  /// **'Daemon State Version'**
  String get machineDaemonStateVersion;

  /// No description provided for @machineActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions ({count})'**
  String machineActiveSessions(Object count);

  /// No description provided for @machineMachineGroup.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get machineMachineGroup;

  /// No description provided for @machineHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get machineHost;

  /// No description provided for @machineMachineId.
  ///
  /// In en, this message translates to:
  /// **'Machine ID'**
  String get machineMachineId;

  /// No description provided for @machineUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get machineUsername;

  /// No description provided for @machineHomeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Home Directory'**
  String get machineHomeDirectory;

  /// No description provided for @machinePlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get machinePlatform;

  /// No description provided for @machineArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get machineArchitecture;

  /// No description provided for @machineLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last Seen'**
  String get machineLastSeen;

  /// No description provided for @machineNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get machineNever;

  /// No description provided for @machineMetadataVersion.
  ///
  /// In en, this message translates to:
  /// **'Metadata Version'**
  String get machineMetadataVersion;

  /// No description provided for @machineUntitledSession.
  ///
  /// In en, this message translates to:
  /// **'Untitled Session'**
  String get machineUntitledSession;

  /// No description provided for @machineBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get machineBack;

  /// No description provided for @machineShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get machineShowLess;

  /// No description provided for @machineShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count} paths)'**
  String machineShowAll(Object count);

  /// No description provided for @machineEnterCustomPath.
  ///
  /// In en, this message translates to:
  /// **'Enter custom path'**
  String get machineEnterCustomPath;

  /// No description provided for @machineOfflineUnableToSpawnNew.
  ///
  /// In en, this message translates to:
  /// **'Unable to spawn new session, offline'**
  String get machineOfflineUnableToSpawnNew;

  /// Chat screen title
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String chatTitle(String toolName);

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatStartConversation;

  /// No description provided for @chatSendMessageToBegin.
  ///
  /// In en, this message translates to:
  /// **'Send a message to begin'**
  String get chatSendMessageToBegin;

  /// No description provided for @chatSessionSettings.
  ///
  /// In en, this message translates to:
  /// **'Session settings'**
  String get chatSessionSettings;

  /// No description provided for @chatDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get chatDeleteSession;

  /// No description provided for @chatDeleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this session?'**
  String get chatDeleteSessionConfirm;

  /// No description provided for @chatFailedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get chatFailedToSend;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'Claude is thinking...'**
  String get chatThinking;

  /// No description provided for @chatToolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running: {toolName}'**
  String chatToolRunning(Object toolName);

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String settingsTitle(String login);

  /// No description provided for @settingsConnectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connected Accounts'**
  String get settingsConnectedAccounts;

  /// No description provided for @settingsConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect account'**
  String get settingsConnectAccount;

  /// No description provided for @settingsGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get settingsGithub;

  /// No description provided for @settingsMachines.
  ///
  /// In en, this message translates to:
  /// **'Machines'**
  String get settingsMachines;

  /// No description provided for @settingsFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get settingsFeatures;

  /// No description provided for @settingsSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get settingsSocial;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account details'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize how the app looks'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get settingsVoiceAssistant;

  /// No description provided for @settingsVoiceAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure voice interaction preferences'**
  String get settingsVoiceAssistantSubtitle;

  /// No description provided for @settingsFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get settingsFeaturesTitle;

  /// No description provided for @settingsFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable app features'**
  String get settingsFeaturesSubtitle;

  /// No description provided for @settingsDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloper;

  /// No description provided for @settingsDeveloperTools.
  ///
  /// In en, this message translates to:
  /// **'Developer Tools'**
  String get settingsDeveloperTools;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutFooter.
  ///
  /// In en, this message translates to:
  /// **'Happy Coder is a Codex and Claude Code mobile client. It\'s fully end-to-end encrypted and your account is stored only on your device. Not affiliated with Anthropic.'**
  String get settingsAboutFooter;

  /// No description provided for @settingsWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get settingsWhatsNew;

  /// No description provided for @settingsWhatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the latest updates and improvements'**
  String get settingsWhatsNewSubtitle;

  /// No description provided for @settingsReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get settingsReportIssue;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsEula.
  ///
  /// In en, this message translates to:
  /// **'EULA'**
  String get settingsEula;

  /// No description provided for @settingsSupportUs.
  ///
  /// In en, this message translates to:
  /// **'Support us'**
  String get settingsSupportUs;

  /// No description provided for @settingsSupportUsSubtitlePro.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support!'**
  String get settingsSupportUsSubtitlePro;

  /// No description provided for @settingsSupportUsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support project development'**
  String get settingsSupportUsSubtitle;

  /// No description provided for @settingsScanQrCodeToAuthenticate.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code to authenticate'**
  String get settingsScanQrCodeToAuthenticate;

  /// No description provided for @settingsGithubConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected as @{login}'**
  String settingsGithubConnected(Object login);

  /// No description provided for @settingsConnectGithubAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect your GitHub account'**
  String get settingsConnectGithubAccount;

  /// No description provided for @settingsUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsUsage;

  /// No description provided for @settingsUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your API usage and costs'**
  String get settingsUsageSubtitle;

  /// No description provided for @settingsProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settingsProfiles;

  /// No description provided for @settingsProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage environment variable profiles for sessions'**
  String get settingsProfilesSubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? Make sure you have backed up your secret key!'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for the app interface'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current Language'**
  String get settingsLanguageCurrent;

  /// No description provided for @settingsLanguageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settingsLanguageAutomatic;

  /// No description provided for @settingsLanguageAutomaticSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect from device settings'**
  String get settingsLanguageAutomaticSubtitle;

  /// No description provided for @settingsLanguageNeedsRestart.
  ///
  /// In en, this message translates to:
  /// **'Language Changed'**
  String get settingsLanguageNeedsRestart;

  /// No description provided for @settingsLanguageNeedsRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'The app needs to restart to apply the new language setting.'**
  String get settingsLanguageNeedsRestartMessage;

  /// No description provided for @settingsLanguageRestartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get settingsLanguageRestartNow;

  /// No description provided for @settingsLanguageSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search languages...'**
  String get settingsLanguageSearchPlaceholder;

  /// No description provided for @settingsAppearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsAppearanceTheme;

  /// No description provided for @settingsAppearanceThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred color scheme'**
  String get settingsAppearanceThemeSubtitle;

  /// No description provided for @settingsAppearanceThemeAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get settingsAppearanceThemeAdaptive;

  /// No description provided for @settingsAppearanceThemeAdaptiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Match system settings'**
  String get settingsAppearanceThemeAdaptiveSubtitle;

  /// No description provided for @settingsAppearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceThemeLight;

  /// No description provided for @settingsAppearanceThemeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get settingsAppearanceThemeLightSubtitle;

  /// No description provided for @settingsAppearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceThemeDark;

  /// No description provided for @settingsAppearanceThemeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get settingsAppearanceThemeDarkSubtitle;

  /// No description provided for @settingsAppearanceDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsAppearanceDisplay;

  /// No description provided for @settingsAppearanceDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control layout and spacing'**
  String get settingsAppearanceDisplaySubtitle;

  /// No description provided for @settingsAppearanceInlineToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Inline Tool Calls'**
  String get settingsAppearanceInlineToolCalls;

  /// No description provided for @settingsAppearanceInlineToolCallsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display tool calls directly in chat messages'**
  String get settingsAppearanceInlineToolCallsSubtitle;

  /// No description provided for @settingsAppearanceExpandTodoLists.
  ///
  /// In en, this message translates to:
  /// **'Expand Todo Lists'**
  String get settingsAppearanceExpandTodoLists;

  /// No description provided for @settingsAppearanceExpandTodoListsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show all todos instead of just changes'**
  String get settingsAppearanceExpandTodoListsSubtitle;

  /// No description provided for @settingsAppearanceShowLineNumbersInDiffs.
  ///
  /// In en, this message translates to:
  /// **'Show Line Numbers in Diffs'**
  String get settingsAppearanceShowLineNumbersInDiffs;

  /// No description provided for @settingsAppearanceShowLineNumbersInDiffsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display line numbers in code diffs'**
  String get settingsAppearanceShowLineNumbersInDiffsSubtitle;

  /// No description provided for @settingsAppearanceShowLineNumbersInToolViews.
  ///
  /// In en, this message translates to:
  /// **'Show Line Numbers in Tool Views'**
  String get settingsAppearanceShowLineNumbersInToolViews;

  /// No description provided for @settingsAppearanceShowLineNumbersInToolViewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display line numbers in tool view diffs'**
  String get settingsAppearanceShowLineNumbersInToolViewsSubtitle;

  /// No description provided for @settingsAppearanceWrapLinesInDiffs.
  ///
  /// In en, this message translates to:
  /// **'Wrap Lines in Diffs'**
  String get settingsAppearanceWrapLinesInDiffs;

  /// No description provided for @settingsAppearanceWrapLinesInDiffsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wrap long lines instead of horizontal scrolling in diff views'**
  String get settingsAppearanceWrapLinesInDiffsSubtitle;

  /// No description provided for @settingsAppearanceAlwaysShowContextSize.
  ///
  /// In en, this message translates to:
  /// **'Always Show Context Size'**
  String get settingsAppearanceAlwaysShowContextSize;

  /// No description provided for @settingsAppearanceAlwaysShowContextSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display context usage even when not near limit'**
  String get settingsAppearanceAlwaysShowContextSizeSubtitle;

  /// No description provided for @settingsAppearanceAvatarStyle.
  ///
  /// In en, this message translates to:
  /// **'Avatar Style'**
  String get settingsAppearanceAvatarStyle;

  /// No description provided for @settingsAppearanceAvatarStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose session avatar appearance'**
  String get settingsAppearanceAvatarStyleSubtitle;

  /// No description provided for @settingsAppearanceAvatarStylePixelated.
  ///
  /// In en, this message translates to:
  /// **'Pixelated'**
  String get settingsAppearanceAvatarStylePixelated;

  /// No description provided for @settingsAppearanceAvatarStyleGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get settingsAppearanceAvatarStyleGradient;

  /// No description provided for @settingsAppearanceAvatarStyleBrutalist.
  ///
  /// In en, this message translates to:
  /// **'Brutalist'**
  String get settingsAppearanceAvatarStyleBrutalist;

  /// No description provided for @settingsAppearanceShowFlavorIcons.
  ///
  /// In en, this message translates to:
  /// **'Show AI Provider Icons'**
  String get settingsAppearanceShowFlavorIcons;

  /// No description provided for @settingsAppearanceShowFlavorIconsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display AI provider icons on session avatars'**
  String get settingsAppearanceShowFlavorIconsSubtitle;

  /// No description provided for @settingsAppearanceCompactSessionView.
  ///
  /// In en, this message translates to:
  /// **'Compact Session View'**
  String get settingsAppearanceCompactSessionView;

  /// No description provided for @settingsAppearanceCompactSessionViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show active sessions in a more compact layout'**
  String get settingsAppearanceCompactSessionViewSubtitle;

  /// No description provided for @settingsFeaturesExperiments.
  ///
  /// In en, this message translates to:
  /// **'Experiments'**
  String get settingsFeaturesExperiments;

  /// No description provided for @settingsFeaturesExperimentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable experimental features that are still in development. These features may be unstable or change without notice.'**
  String get settingsFeaturesExperimentsSubtitle;

  /// No description provided for @settingsFeaturesExperimentalFeatures.
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get settingsFeaturesExperimentalFeatures;

  /// No description provided for @settingsFeaturesExperimentalFeaturesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Experimental features enabled'**
  String get settingsFeaturesExperimentalFeaturesEnabled;

  /// No description provided for @settingsFeaturesExperimentalFeaturesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Using stable features only'**
  String get settingsFeaturesExperimentalFeaturesDisabled;

  /// No description provided for @settingsFeaturesWebFeatures.
  ///
  /// In en, this message translates to:
  /// **'Web Features'**
  String get settingsFeaturesWebFeatures;

  /// No description provided for @settingsFeaturesWebFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Features available only in the web version of the app.'**
  String get settingsFeaturesWebFeaturesSubtitle;

  /// No description provided for @settingsFeaturesEnterToSend.
  ///
  /// In en, this message translates to:
  /// **'Enter to Send'**
  String get settingsFeaturesEnterToSend;

  /// No description provided for @settingsFeaturesEnterToSendEnabled.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to send (Shift+Enter for a new line)'**
  String get settingsFeaturesEnterToSendEnabled;

  /// No description provided for @settingsFeaturesEnterToSendDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enter inserts a new line'**
  String get settingsFeaturesEnterToSendDisabled;

  /// No description provided for @settingsFeaturesCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get settingsFeaturesCommandPalette;

  /// No description provided for @settingsFeaturesCommandPaletteEnabled.
  ///
  /// In en, this message translates to:
  /// **'Press ⌘K to open'**
  String get settingsFeaturesCommandPaletteEnabled;

  /// No description provided for @settingsFeaturesCommandPaletteDisabled.
  ///
  /// In en, this message translates to:
  /// **'Quick command access disabled'**
  String get settingsFeaturesCommandPaletteDisabled;

  /// No description provided for @settingsFeaturesMarkdownCopyV2.
  ///
  /// In en, this message translates to:
  /// **'Markdown Copy v2'**
  String get settingsFeaturesMarkdownCopyV2;

  /// No description provided for @settingsFeaturesMarkdownCopyV2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Long press opens copy modal'**
  String get settingsFeaturesMarkdownCopyV2Subtitle;

  /// No description provided for @settingsFeaturesHideInactiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Hide inactive sessions'**
  String get settingsFeaturesHideInactiveSessions;

  /// No description provided for @settingsFeaturesHideInactiveSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show only active chats in your list'**
  String get settingsFeaturesHideInactiveSessionsSubtitle;

  /// No description provided for @settingsFeaturesEnhancedSessionWizard.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Session Wizard'**
  String get settingsFeaturesEnhancedSessionWizard;

  /// No description provided for @settingsFeaturesEnhancedSessionWizardEnabled.
  ///
  /// In en, this message translates to:
  /// **'Profile-first session launcher active'**
  String get settingsFeaturesEnhancedSessionWizardEnabled;

  /// No description provided for @settingsFeaturesEnhancedSessionWizardDisabled.
  ///
  /// In en, this message translates to:
  /// **'Using standard session launcher'**
  String get settingsFeaturesEnhancedSessionWizardDisabled;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get settingsAccountTitle;

  /// No description provided for @settingsAccountStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get settingsAccountStatus;

  /// No description provided for @settingsAccountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsAccountStatusActive;

  /// No description provided for @settingsAccountStatusNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not Authenticated'**
  String get settingsAccountStatusNotAuthenticated;

  /// No description provided for @settingsAccountAnonymousId.
  ///
  /// In en, this message translates to:
  /// **'Anonymous ID'**
  String get settingsAccountAnonymousId;

  /// No description provided for @settingsAccountPublicId.
  ///
  /// In en, this message translates to:
  /// **'Public ID'**
  String get settingsAccountPublicId;

  /// No description provided for @settingsAccountNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get settingsAccountNotAvailable;

  /// No description provided for @settingsAccountLinkNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Link New Device'**
  String get settingsAccountLinkNewDevice;

  /// No description provided for @settingsAccountLinkNewDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code to link device'**
  String get settingsAccountLinkNewDeviceSubtitle;

  /// No description provided for @settingsAccountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsAccountProfile;

  /// No description provided for @settingsAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get settingsAccountName;

  /// No description provided for @settingsAccountGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get settingsAccountGithub;

  /// No description provided for @settingsAccountTapToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to disconnect'**
  String get settingsAccountTapToDisconnect;

  /// No description provided for @settingsAccountServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsAccountServer;

  /// No description provided for @settingsAccountBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsAccountBackup;

  /// No description provided for @settingsAccountBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Your secret key is the only way to recover your account. Save it in a secure place like a password manager.'**
  String get settingsAccountBackupDescription;

  /// No description provided for @settingsAccountSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get settingsAccountSecretKey;

  /// No description provided for @settingsAccountTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get settingsAccountTapToReveal;

  /// No description provided for @settingsAccountTapToHide.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide'**
  String get settingsAccountTapToHide;

  /// No description provided for @settingsAccountSecretKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'SECRET KEY (TAP TO COPY)'**
  String get settingsAccountSecretKeyLabel;

  /// No description provided for @settingsAccountSecretKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Secret key copied to clipboard. Store it in a safe place!'**
  String get settingsAccountSecretKeyCopied;

  /// No description provided for @settingsAccountSecretKeyCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy secret key'**
  String get settingsAccountSecretKeyCopyFailed;

  /// No description provided for @settingsAccountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsAccountPrivacy;

  /// No description provided for @settingsAccountPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app by sharing anonymous usage data. No personal information is collected.'**
  String get settingsAccountPrivacyDescription;

  /// No description provided for @settingsAccountAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get settingsAccountAnalytics;

  /// No description provided for @settingsAccountAnalyticsDisabled.
  ///
  /// In en, this message translates to:
  /// **'No data is shared'**
  String get settingsAccountAnalyticsDisabled;

  /// No description provided for @settingsAccountAnalyticsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Anonymous usage data is shared'**
  String get settingsAccountAnalyticsEnabled;

  /// No description provided for @settingsAccountDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsAccountDangerZone;

  /// No description provided for @settingsAccountLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsAccountLogout;

  /// No description provided for @settingsAccountLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out and clear local data'**
  String get settingsAccountLogoutSubtitle;

  /// No description provided for @settingsServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get settingsServerTitle;

  /// No description provided for @settingsServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsServerUrl;

  /// No description provided for @settingsServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Please enter a server URL'**
  String get settingsServerUrlLabel;

  /// No description provided for @settingsServerNotValidHappyServer.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Happy Server'**
  String get settingsServerNotValidHappyServer;

  /// No description provided for @settingsServerChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change Server'**
  String get settingsServerChangeServer;

  /// No description provided for @settingsServerContinueWithServer.
  ///
  /// In en, this message translates to:
  /// **'Continue with this server?'**
  String get settingsServerContinueWithServer;

  /// No description provided for @settingsServerResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsServerResetToDefault;

  /// No description provided for @settingsServerResetServerDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset server to default?'**
  String get settingsServerResetServerDefault;

  /// No description provided for @settingsServerValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating...'**
  String get settingsServerValidating;

  /// No description provided for @settingsServerValidatingServer.
  ///
  /// In en, this message translates to:
  /// **'Validating server...'**
  String get settingsServerValidatingServer;

  /// No description provided for @settingsServerServerReturnedError.
  ///
  /// In en, this message translates to:
  /// **'Server returned an error'**
  String get settingsServerServerReturnedError;

  /// No description provided for @settingsServerFailedToConnectToServer.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to server'**
  String get settingsServerFailedToConnectToServer;

  /// No description provided for @settingsServerCurrentlyUsingCustomServer.
  ///
  /// In en, this message translates to:
  /// **'Currently using custom server'**
  String get settingsServerCurrentlyUsingCustomServer;

  /// No description provided for @settingsServerCustomServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom Server URL'**
  String get settingsServerCustomServerUrlLabel;

  /// No description provided for @settingsServerAdvancedFeatureFooter.
  ///
  /// In en, this message translates to:
  /// **'This is an advanced feature. Only change the server if you know what you\'re doing. You will need to log out and log in again after changing servers.'**
  String get settingsServerAdvancedFeatureFooter;

  /// No description provided for @settingsVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get settingsVoiceTitle;

  /// No description provided for @settingsVoiceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsVoiceLanguage;

  /// No description provided for @settingsVoiceLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for voice assistant interactions. This setting syncs across all your devices.'**
  String get settingsVoiceLanguageSubtitle;

  /// No description provided for @settingsVoicePreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get settingsVoicePreferredLanguage;

  /// No description provided for @settingsVoicePreferredLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language used for voice assistant responses'**
  String get settingsVoicePreferredLanguageSubtitle;

  /// No description provided for @settingsVoiceLanguageSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search languages...'**
  String get settingsVoiceLanguageSearchPlaceholder;

  /// No description provided for @settingsVoiceLanguageSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get settingsVoiceLanguageSearchTitle;

  /// Voice language selection footer
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 language} other {{count} languages}} available'**
  String settingsVoiceLanguageFooter(int count);

  /// No description provided for @settingsVoiceLanguageAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get settingsVoiceLanguageAutoDetect;

  /// No description provided for @settingsProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settingsProfilesTitle;

  /// No description provided for @settingsProfilesNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No Profile'**
  String get settingsProfilesNoProfile;

  /// No description provided for @settingsProfilesNoProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Use default environment settings'**
  String get settingsProfilesNoProfileDescription;

  /// No description provided for @settingsProfilesDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default Model'**
  String get settingsProfilesDefaultModel;

  /// No description provided for @settingsProfilesAddProfile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get settingsProfilesAddProfile;

  /// No description provided for @settingsProfilesProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get settingsProfilesProfileName;

  /// No description provided for @settingsProfilesEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter profile name'**
  String get settingsProfilesEnterName;

  /// No description provided for @settingsProfilesBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get settingsProfilesBaseUrl;

  /// No description provided for @settingsProfilesAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Auth Token'**
  String get settingsProfilesAuthToken;

  /// No description provided for @settingsProfilesEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter auth token'**
  String get settingsProfilesEnterToken;

  /// No description provided for @settingsProfilesModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsProfilesModel;

  /// No description provided for @settingsProfilesTmuxSession.
  ///
  /// In en, this message translates to:
  /// **'Tmux Session'**
  String get settingsProfilesTmuxSession;

  /// No description provided for @settingsProfilesEnterTmuxSession.
  ///
  /// In en, this message translates to:
  /// **'Enter tmux session name'**
  String get settingsProfilesEnterTmuxSession;

  /// No description provided for @settingsProfilesTmuxTempDir.
  ///
  /// In en, this message translates to:
  /// **'Tmux Temp Directory'**
  String get settingsProfilesTmuxTempDir;

  /// No description provided for @settingsProfilesEnterTmuxTempDir.
  ///
  /// In en, this message translates to:
  /// **'Enter temp directory path'**
  String get settingsProfilesEnterTmuxTempDir;

  /// No description provided for @settingsProfilesTmuxUpdateEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Update environment automatically'**
  String get settingsProfilesTmuxUpdateEnvironment;

  /// No description provided for @settingsProfilesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Profile name is required'**
  String get settingsProfilesNameRequired;

  /// Profile deletion confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the profile \"{name}\"?'**
  String settingsProfilesDeleteConfirm(String name);

  /// No description provided for @settingsProfilesEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsProfilesEditProfile;

  /// No description provided for @settingsProfilesAddProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Profile'**
  String get settingsProfilesAddProfileTitle;

  /// No description provided for @settingsProfilesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get settingsProfilesDeleteTitle;

  /// No description provided for @settingsProfilesDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String settingsProfilesDeleteMessage(Object name);

  /// No description provided for @settingsProfilesDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsProfilesDeleteConfirmAction;

  /// No description provided for @settingsProfilesDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsProfilesDeleteCancel;

  /// No description provided for @settingsUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsUsageTitle;

  /// No description provided for @settingsUsageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get settingsUsageToday;

  /// No description provided for @settingsUsageLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get settingsUsageLast7Days;

  /// No description provided for @settingsUsageLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get settingsUsageLast30Days;

  /// No description provided for @settingsUsageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total Tokens'**
  String get settingsUsageTotalTokens;

  /// No description provided for @settingsUsageTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get settingsUsageTotalCost;

  /// No description provided for @settingsUsageTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get settingsUsageTokens;

  /// No description provided for @settingsUsageCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get settingsUsageCost;

  /// No description provided for @settingsUsageUsageOverTime.
  ///
  /// In en, this message translates to:
  /// **'Usage over time'**
  String get settingsUsageUsageOverTime;

  /// No description provided for @settingsUsageByModel.
  ///
  /// In en, this message translates to:
  /// **'By Model'**
  String get settingsUsageByModel;

  /// No description provided for @settingsUsageNoData.
  ///
  /// In en, this message translates to:
  /// **'No usage data available'**
  String get settingsUsageNoData;

  /// No description provided for @settingsDeveloperTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloperTitle;

  /// Developer settings version display
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsDeveloperVersion(String version);

  /// No description provided for @settingsDeveloperCopyDebugInfo.
  ///
  /// In en, this message translates to:
  /// **'Copy Debug Info'**
  String get settingsDeveloperCopyDebugInfo;

  /// No description provided for @settingsDeveloperDebugInfoCopied.
  ///
  /// In en, this message translates to:
  /// **'Debug info copied to clipboard'**
  String get settingsDeveloperDebugInfoCopied;

  /// No description provided for @errorsNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error occurred'**
  String get errorsNetworkError;

  /// No description provided for @errorsServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error occurred'**
  String get errorsServerError;

  /// No description provided for @errorsUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errorsUnknownError;

  /// No description provided for @errorsConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get errorsConnectionTimeout;

  /// No description provided for @errorsAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get errorsAuthenticationFailed;

  /// No description provided for @errorsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get errorsPermissionDenied;

  /// No description provided for @errorsFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get errorsFileNotFound;

  /// No description provided for @errorsInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format'**
  String get errorsInvalidFormat;

  /// No description provided for @errorsOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get errorsOperationFailed;

  /// No description provided for @errorsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get errorsTryAgain;

  /// No description provided for @errorsContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support if the problem persists'**
  String get errorsContactSupport;

  /// No description provided for @errorsSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get errorsSessionNotFound;

  /// No description provided for @errorsVoiceSessionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start voice session'**
  String get errorsVoiceSessionFailed;

  /// No description provided for @errorsVoiceServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice service is temporarily unavailable'**
  String get errorsVoiceServiceUnavailable;

  /// No description provided for @errorsOauthInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize OAuth flow'**
  String get errorsOauthInitializationFailed;

  /// No description provided for @errorsTokenStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to store authentication tokens'**
  String get errorsTokenStorageFailed;

  /// No description provided for @errorsOauthStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'Security validation failed. Please try again'**
  String get errorsOauthStateMismatch;

  /// No description provided for @errorsTokenExchangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to exchange authorization code'**
  String get errorsTokenExchangeFailed;

  /// No description provided for @errorsOauthAuthorizationDenied.
  ///
  /// In en, this message translates to:
  /// **'Authorization was denied'**
  String get errorsOauthAuthorizationDenied;

  /// No description provided for @errorsWebViewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load authentication page'**
  String get errorsWebViewLoadFailed;

  /// No description provided for @errorsFailedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user profile'**
  String get errorsFailedToLoadProfile;

  /// No description provided for @errorsUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get errorsUserNotFound;

  /// No description provided for @errorsSessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session has been deleted'**
  String get errorsSessionDeleted;

  /// No description provided for @errorsSessionDeletedDescription.
  ///
  /// In en, this message translates to:
  /// **'This session has been permanently removed'**
  String get errorsSessionDeletedDescription;

  /// Field validation error
  ///
  /// In en, this message translates to:
  /// **'{field}: {reason}'**
  String errorsFieldError(String field, String reason);

  /// Validation error with min/max
  ///
  /// In en, this message translates to:
  /// **'{field} must be between {min} and {max}'**
  String errorsValidationError(String field, int min, int max);

  /// Retry countdown message
  ///
  /// In en, this message translates to:
  /// **'Retry in {seconds, plural, =1 {1 second} other {{seconds} seconds}}'**
  String errorsRetryIn(int seconds);

  /// No description provided for @errorsErrorWithCode.
  ///
  /// In en, this message translates to:
  /// **'{message} (Error {code})'**
  String errorsErrorWithCode(Object code, Object message);

  /// No description provided for @errorsDisconnectServiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect {service}'**
  String errorsDisconnectServiceFailed(Object service);

  /// No description provided for @errorsConnectServiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect {service}. Please try again.'**
  String errorsConnectServiceFailed(Object service);

  /// No description provided for @errorsFailedToLoadFriends.
  ///
  /// In en, this message translates to:
  /// **'Failed to load friends list'**
  String get errorsFailedToLoadFriends;

  /// No description provided for @errorsFailedToAcceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept friend request'**
  String get errorsFailedToAcceptRequest;

  /// No description provided for @errorsFailedToRejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject friend request'**
  String get errorsFailedToRejectRequest;

  /// No description provided for @errorsFailedToRemoveFriend.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove friend'**
  String get errorsFailedToRemoveFriend;

  /// No description provided for @errorsSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get errorsSearchFailed;

  /// No description provided for @errorsFailedToSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to send friend request'**
  String get errorsFailedToSendRequest;

  /// No description provided for @terminalWebBrowserRequired.
  ///
  /// In en, this message translates to:
  /// **'Web Browser Required'**
  String get terminalWebBrowserRequired;

  /// No description provided for @terminalWebBrowserRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Terminal connection links can only be opened in a web browser for security reasons. Please use the QR code scanner or open this link on a computer.'**
  String get terminalWebBrowserRequiredDescription;

  /// No description provided for @terminalProcessingConnection.
  ///
  /// In en, this message translates to:
  /// **'Processing connection...'**
  String get terminalProcessingConnection;

  /// No description provided for @terminalInvalidConnectionLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid Connection Link'**
  String get terminalInvalidConnectionLink;

  /// No description provided for @terminalInvalidConnectionLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'The connection link is missing or invalid. Please check the URL and try again.'**
  String get terminalInvalidConnectionLinkDescription;

  /// No description provided for @terminalConnectTerminal.
  ///
  /// In en, this message translates to:
  /// **'Connect Terminal'**
  String get terminalConnectTerminal;

  /// No description provided for @terminalRequestDescription.
  ///
  /// In en, this message translates to:
  /// **'A terminal is requesting to connect to your Happy Coder account. This will allow the terminal to send and receive messages securely.'**
  String get terminalRequestDescription;

  /// No description provided for @terminalConnectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Connection Details'**
  String get terminalConnectionDetails;

  /// No description provided for @terminalPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Public Key'**
  String get terminalPublicKey;

  /// No description provided for @terminalEncryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get terminalEncryption;

  /// No description provided for @terminalEndToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get terminalEndToEndEncrypted;

  /// No description provided for @terminalAcceptConnection.
  ///
  /// In en, this message translates to:
  /// **'Accept Connection'**
  String get terminalAcceptConnection;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get terminalConnecting;

  /// No description provided for @terminalReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get terminalReject;

  /// No description provided for @terminalSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get terminalSecurity;

  /// No description provided for @terminalSecurityFooter.
  ///
  /// In en, this message translates to:
  /// **'This connection link was processed securely in your browser and was never sent to any server. Your private data will remain secure and only you can decrypt the messages.'**
  String get terminalSecurityFooter;

  /// No description provided for @terminalSecurityFooterDevice.
  ///
  /// In en, this message translates to:
  /// **'This connection was processed securely on your device and was never sent to any server. Your private data will remain secure and only you can decrypt the messages.'**
  String get terminalSecurityFooterDevice;

  /// No description provided for @terminalClientSideProcessing.
  ///
  /// In en, this message translates to:
  /// **'Client-Side Processing'**
  String get terminalClientSideProcessing;

  /// No description provided for @terminalLinkProcessedLocally.
  ///
  /// In en, this message translates to:
  /// **'Link processed locally in browser'**
  String get terminalLinkProcessedLocally;

  /// No description provided for @terminalLinkProcessedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Link processed locally on device'**
  String get terminalLinkProcessedOnDevice;

  /// No description provided for @sidebarSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminals'**
  String get sidebarSessionsTitle;

  /// No description provided for @sidebarStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get sidebarStatusConnected;

  /// No description provided for @sidebarStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get sidebarStatusConnecting;

  /// No description provided for @sidebarStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get sidebarStatusDisconnected;

  /// No description provided for @sidebarStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sidebarStatusError;

  /// No description provided for @commandPalettePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a command or search...'**
  String get commandPalettePlaceholder;

  /// No description provided for @toolViewInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get toolViewInput;

  /// No description provided for @toolViewOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get toolViewOutput;

  /// No description provided for @toolViewDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get toolViewDescription;

  /// No description provided for @toolViewInputParams.
  ///
  /// In en, this message translates to:
  /// **'Input Parameters'**
  String get toolViewInputParams;

  /// No description provided for @toolViewError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get toolViewError;

  /// No description provided for @toolViewCompleted.
  ///
  /// In en, this message translates to:
  /// **'Tool completed successfully'**
  String get toolViewCompleted;

  /// No description provided for @toolViewNoOutput.
  ///
  /// In en, this message translates to:
  /// **'No output was produced'**
  String get toolViewNoOutput;

  /// No description provided for @toolViewRunning.
  ///
  /// In en, this message translates to:
  /// **'Tool is running...'**
  String get toolViewRunning;

  /// No description provided for @toolViewRawJsonDevMode.
  ///
  /// In en, this message translates to:
  /// **'Raw JSON (Dev Mode)'**
  String get toolViewRawJsonDevMode;

  /// No description provided for @toolNamesTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get toolNamesTask;

  /// No description provided for @toolNamesTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get toolNamesTerminal;

  /// No description provided for @toolNamesSearchFiles.
  ///
  /// In en, this message translates to:
  /// **'Search Files'**
  String get toolNamesSearchFiles;

  /// No description provided for @toolNamesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get toolNamesSearch;

  /// No description provided for @toolNamesSearchContent.
  ///
  /// In en, this message translates to:
  /// **'Search Content'**
  String get toolNamesSearchContent;

  /// No description provided for @toolNamesListFiles.
  ///
  /// In en, this message translates to:
  /// **'List Files'**
  String get toolNamesListFiles;

  /// No description provided for @toolNamesPlanProposal.
  ///
  /// In en, this message translates to:
  /// **'Plan proposal'**
  String get toolNamesPlanProposal;

  /// No description provided for @toolNamesReadFile.
  ///
  /// In en, this message translates to:
  /// **'Read File'**
  String get toolNamesReadFile;

  /// No description provided for @toolNamesEditFile.
  ///
  /// In en, this message translates to:
  /// **'Edit File'**
  String get toolNamesEditFile;

  /// No description provided for @toolNamesWriteFile.
  ///
  /// In en, this message translates to:
  /// **'Write File'**
  String get toolNamesWriteFile;

  /// No description provided for @toolNamesFetchUrl.
  ///
  /// In en, this message translates to:
  /// **'Fetch URL'**
  String get toolNamesFetchUrl;

  /// No description provided for @toolNamesReadNotebook.
  ///
  /// In en, this message translates to:
  /// **'Read Notebook'**
  String get toolNamesReadNotebook;

  /// No description provided for @toolNamesEditNotebook.
  ///
  /// In en, this message translates to:
  /// **'Edit Notebook'**
  String get toolNamesEditNotebook;

  /// No description provided for @toolNamesTodoList.
  ///
  /// In en, this message translates to:
  /// **'Todo List'**
  String get toolNamesTodoList;

  /// No description provided for @toolNamesWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get toolNamesWebSearch;

  /// No description provided for @toolNamesReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get toolNamesReasoning;

  /// No description provided for @toolNamesApplyChanges.
  ///
  /// In en, this message translates to:
  /// **'Update file'**
  String get toolNamesApplyChanges;

  /// No description provided for @toolNamesViewDiff.
  ///
  /// In en, this message translates to:
  /// **'Current file changes'**
  String get toolNamesViewDiff;

  /// No description provided for @toolNamesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get toolNamesQuestion;

  /// Terminal tool description
  ///
  /// In en, this message translates to:
  /// **'Terminal(cmd: {cmd})'**
  String toolDescTerminalCmd(String cmd);

  /// No description provided for @toolDescSearchPattern.
  ///
  /// In en, this message translates to:
  /// **'Search(pattern: {pattern})'**
  String toolDescSearchPattern(Object pattern);

  /// No description provided for @toolDescSearchPath.
  ///
  /// In en, this message translates to:
  /// **'Search(path: {basename})'**
  String toolDescSearchPath(Object basename);

  /// No description provided for @toolDescFetchUrlHost.
  ///
  /// In en, this message translates to:
  /// **'Fetch URL(url: {host})'**
  String toolDescFetchUrlHost(Object host);

  /// No description provided for @toolDescEditNotebookMode.
  ///
  /// In en, this message translates to:
  /// **'Edit Notebook(file: {path}, mode: {mode})'**
  String toolDescEditNotebookMode(Object mode, Object path);

  /// No description provided for @toolDescTodoListCount.
  ///
  /// In en, this message translates to:
  /// **'Todo List(count: {count})'**
  String toolDescTodoListCount(Object count);

  /// No description provided for @toolDescWebSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'Web Search(query: {query})'**
  String toolDescWebSearchQuery(Object query);

  /// No description provided for @toolDescGrepPattern.
  ///
  /// In en, this message translates to:
  /// **'grep(pattern: {pattern})'**
  String toolDescGrepPattern(Object pattern);

  /// No description provided for @toolDescMultiEditEdits.
  ///
  /// In en, this message translates to:
  /// **'{path} ({count} edits)'**
  String toolDescMultiEditEdits(Object count, Object path);

  /// No description provided for @toolDescReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading {file}'**
  String toolDescReadingFile(Object file);

  /// No description provided for @toolDescWritingFile.
  ///
  /// In en, this message translates to:
  /// **'Writing {file}'**
  String toolDescWritingFile(Object file);

  /// No description provided for @toolDescModifyingFile.
  ///
  /// In en, this message translates to:
  /// **'Modifying {file}'**
  String toolDescModifyingFile(Object file);

  /// No description provided for @toolDescModifyingFiles.
  ///
  /// In en, this message translates to:
  /// **'Modifying {count} files'**
  String toolDescModifyingFiles(Object count);

  /// No description provided for @toolDescModifyingMultipleFiles.
  ///
  /// In en, this message translates to:
  /// **'{file} and {count} more'**
  String toolDescModifyingMultipleFiles(Object count, Object file);

  /// No description provided for @toolDescShowingDiff.
  ///
  /// In en, this message translates to:
  /// **'Showing changes'**
  String get toolDescShowingDiff;

  /// No description provided for @filesSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get filesSearchPlaceholder;

  /// No description provided for @filesDetachedHead.
  ///
  /// In en, this message translates to:
  /// **'detached HEAD'**
  String get filesDetachedHead;

  /// No description provided for @filesSummary.
  ///
  /// In en, this message translates to:
  /// **'{staged} staged • {unstaged} unstaged'**
  String filesSummary(Object staged, Object unstaged);

  /// No description provided for @filesNotRepo.
  ///
  /// In en, this message translates to:
  /// **'Not a git repository'**
  String get filesNotRepo;

  /// No description provided for @filesNotUnderGit.
  ///
  /// In en, this message translates to:
  /// **'This directory is not under git version control'**
  String get filesNotUnderGit;

  /// No description provided for @filesSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching files...'**
  String get filesSearching;

  /// No description provided for @filesNoFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get filesNoFilesFound;

  /// No description provided for @filesNoFilesInProject.
  ///
  /// In en, this message translates to:
  /// **'No files in project'**
  String get filesNoFilesInProject;

  /// No description provided for @filesTryDifferentTerm.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get filesTryDifferentTerm;

  /// File search results count
  ///
  /// In en, this message translates to:
  /// **'Search Results ({count})'**
  String filesSearchResults(int count);

  /// No description provided for @filesProjectRoot.
  ///
  /// In en, this message translates to:
  /// **'Project root'**
  String get filesProjectRoot;

  /// No description provided for @filesStagedChanges.
  ///
  /// In en, this message translates to:
  /// **'Staged Changes ({count})'**
  String filesStagedChanges(Object count);

  /// No description provided for @filesUnstagedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unstaged Changes ({count})'**
  String filesUnstagedChanges(Object count);

  /// No description provided for @filesLoadingFile.
  ///
  /// In en, this message translates to:
  /// **'Loading {fileName}...'**
  String filesLoadingFile(Object fileName);

  /// No description provided for @filesBinaryFile.
  ///
  /// In en, this message translates to:
  /// **'Binary File'**
  String get filesBinaryFile;

  /// No description provided for @filesCannotDisplayBinary.
  ///
  /// In en, this message translates to:
  /// **'Cannot display binary file content'**
  String get filesCannotDisplayBinary;

  /// No description provided for @filesDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get filesDiff;

  /// No description provided for @filesFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get filesFile;

  /// No description provided for @filesFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get filesFileEmpty;

  /// No description provided for @filesNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes to display'**
  String get filesNoChanges;

  /// No description provided for @profileUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get profileUserProfile;

  /// No description provided for @profileDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get profileDetails;

  /// No description provided for @profileFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get profileFirstName;

  /// No description provided for @profileLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get profileLastName;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatus;

  /// No description provided for @agentPermissionModeTitle.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION MODE'**
  String get agentPermissionModeTitle;

  /// No description provided for @agentPermissionModeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get agentPermissionModeDefault;

  /// No description provided for @agentPermissionModeAcceptEdits.
  ///
  /// In en, this message translates to:
  /// **'Accept Edits'**
  String get agentPermissionModeAcceptEdits;

  /// No description provided for @agentPermissionModePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan Mode'**
  String get agentPermissionModePlan;

  /// No description provided for @agentPermissionModeBypassPermissions.
  ///
  /// In en, this message translates to:
  /// **'Yolo Mode'**
  String get agentPermissionModeBypassPermissions;

  /// No description provided for @agentPermissionModeBadgeAcceptAllEdits.
  ///
  /// In en, this message translates to:
  /// **'Accept All Edits'**
  String get agentPermissionModeBadgeAcceptAllEdits;

  /// No description provided for @agentPermissionModeBadgeBypassAllPermissions.
  ///
  /// In en, this message translates to:
  /// **'Bypass All Permissions'**
  String get agentPermissionModeBadgeBypassAllPermissions;

  /// No description provided for @agentPermissionModeBadgePlanMode.
  ///
  /// In en, this message translates to:
  /// **'Plan Mode'**
  String get agentPermissionModeBadgePlanMode;

  /// No description provided for @agentAgentClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude'**
  String get agentAgentClaude;

  /// No description provided for @agentAgentCodex.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get agentAgentCodex;

  /// No description provided for @agentAgentGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get agentAgentGemini;

  /// No description provided for @agentModelTitle.
  ///
  /// In en, this message translates to:
  /// **'MODEL'**
  String get agentModelTitle;

  /// No description provided for @agentModelConfigureInCli.
  ///
  /// In en, this message translates to:
  /// **'Configure models in CLI settings'**
  String get agentModelConfigureInCli;

  /// Context usage remaining
  ///
  /// In en, this message translates to:
  /// **'{percent}% left'**
  String agentContextRemaining(int percent);

  /// No description provided for @agentSuggestionFileLabel.
  ///
  /// In en, this message translates to:
  /// **'FILE'**
  String get agentSuggestionFileLabel;

  /// No description provided for @agentSuggestionFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'FOLDER'**
  String get agentSuggestionFolderLabel;

  /// No description provided for @agentNoMachinesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No machines'**
  String get agentNoMachinesAvailable;

  /// No description provided for @updateBannerUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateBannerUpdateAvailable;

  /// No description provided for @updateBannerPressToApply.
  ///
  /// In en, this message translates to:
  /// **'Press to apply the update'**
  String get updateBannerPressToApply;

  /// No description provided for @updateBannerWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateBannerWhatsNew;

  /// No description provided for @updateBannerSeeLatest.
  ///
  /// In en, this message translates to:
  /// **'See the latest updates and improvements'**
  String get updateBannerSeeLatest;

  /// No description provided for @updateBannerNativeUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'App Update Available'**
  String get updateBannerNativeUpdateAvailable;

  /// No description provided for @updateBannerTapToUpdateAppStore.
  ///
  /// In en, this message translates to:
  /// **'Tap to update in App Store'**
  String get updateBannerTapToUpdateAppStore;

  /// No description provided for @updateBannerTapToUpdatePlayStore.
  ///
  /// In en, this message translates to:
  /// **'Tap to update in Play Store'**
  String get updateBannerTapToUpdatePlayStore;

  /// Changelog version header
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String changelogVersion(int version);

  /// No description provided for @changelogNoEntriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No changelog entries available.'**
  String get changelogNoEntriesAvailable;

  /// No description provided for @modalsAuthenticateTerminal.
  ///
  /// In en, this message translates to:
  /// **'Authenticate Terminal'**
  String get modalsAuthenticateTerminal;

  /// No description provided for @modalsPasteUrlFromTerminal.
  ///
  /// In en, this message translates to:
  /// **'Paste the authentication URL from your terminal'**
  String get modalsPasteUrlFromTerminal;

  /// No description provided for @modalsDeviceLinkedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Device linked successfully'**
  String get modalsDeviceLinkedSuccessfully;

  /// No description provided for @modalsTerminalConnectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Terminal connected successfully'**
  String get modalsTerminalConnectedSuccessfully;

  /// No description provided for @modalsInvalidAuthUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid authentication URL'**
  String get modalsInvalidAuthUrl;

  /// No description provided for @modalsDeveloperMode.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get modalsDeveloperMode;

  /// No description provided for @modalsDeveloperModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode enabled'**
  String get modalsDeveloperModeEnabled;

  /// No description provided for @modalsDeveloperModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode disabled'**
  String get modalsDeveloperModeDisabled;

  /// No description provided for @modalsDisconnectGithub.
  ///
  /// In en, this message translates to:
  /// **'Disconnect GitHub'**
  String get modalsDisconnectGithub;

  /// No description provided for @modalsDisconnectGithubConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect your GitHub account?'**
  String get modalsDisconnectGithubConfirm;

  /// Disconnect service dialog
  ///
  /// In en, this message translates to:
  /// **'Disconnect {service}'**
  String modalsDisconnectService(String service);

  /// No description provided for @modalsDisconnectServiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect {service} from your account?'**
  String modalsDisconnectServiceConfirm(Object service);

  /// No description provided for @modalsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get modalsDisconnect;

  /// No description provided for @modalsFailedToConnectTerminal.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect terminal'**
  String get modalsFailedToConnectTerminal;

  /// No description provided for @modalsCameraPermissionsRequiredToConnectTerminal.
  ///
  /// In en, this message translates to:
  /// **'Camera permissions are required to connect terminal'**
  String get modalsCameraPermissionsRequiredToConnectTerminal;

  /// No description provided for @modalsFailedToLinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Failed to link device'**
  String get modalsFailedToLinkDevice;

  /// No description provided for @navigationConnectTerminal.
  ///
  /// In en, this message translates to:
  /// **'Connect Terminal'**
  String get navigationConnectTerminal;

  /// No description provided for @navigationLinkNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Link New Device'**
  String get navigationLinkNewDevice;

  /// No description provided for @navigationRestoreWithSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Restore with Secret Key'**
  String get navigationRestoreWithSecretKey;

  /// No description provided for @navigationWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get navigationWhatsNew;

  /// No description provided for @navigationFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get navigationFriends;

  /// No description provided for @emptyMainScreenReadyToCode.
  ///
  /// In en, this message translates to:
  /// **'Ready to code?'**
  String get emptyMainScreenReadyToCode;

  /// No description provided for @emptyMainScreenInstallCli.
  ///
  /// In en, this message translates to:
  /// **'Install the Happy CLI'**
  String get emptyMainScreenInstallCli;

  /// No description provided for @emptyMainScreenRunIt.
  ///
  /// In en, this message translates to:
  /// **'Run it'**
  String get emptyMainScreenRunIt;

  /// No description provided for @emptyMainScreenScanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code'**
  String get emptyMainScreenScanQrCode;

  /// No description provided for @emptyMainScreenOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open Camera'**
  String get emptyMainScreenOpenCamera;

  /// No description provided for @reviewEnjoyingApp.
  ///
  /// In en, this message translates to:
  /// **'Enjoying the app?'**
  String get reviewEnjoyingApp;

  /// No description provided for @reviewFeedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'We\'d love to hear your feedback!'**
  String get reviewFeedbackPrompt;

  /// No description provided for @reviewYesILoveIt.
  ///
  /// In en, this message translates to:
  /// **'Yes, I love it!'**
  String get reviewYesILoveIt;

  /// No description provided for @reviewNotReally.
  ///
  /// In en, this message translates to:
  /// **'Not really'**
  String get reviewNotReally;

  /// Copy toast message
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String itemsCopiedToClipboard(String label);

  /// Permission mode switch message
  ///
  /// In en, this message translates to:
  /// **'Switched to {mode} mode'**
  String messageSwitchedToMode(String mode);

  /// No description provided for @messageUnknownEvent.
  ///
  /// In en, this message translates to:
  /// **'Unknown event'**
  String get messageUnknownEvent;

  /// No description provided for @messageUsageLimitUntil.
  ///
  /// In en, this message translates to:
  /// **'Usage limit reached until {time}'**
  String messageUsageLimitUntil(Object time);

  /// No description provided for @messageUnknownTime.
  ///
  /// In en, this message translates to:
  /// **'unknown time'**
  String get messageUnknownTime;

  /// No description provided for @codexPermissionsYesForSession.
  ///
  /// In en, this message translates to:
  /// **'Yes, and don\'t ask for a session'**
  String get codexPermissionsYesForSession;

  /// No description provided for @codexPermissionsStopAndExplain.
  ///
  /// In en, this message translates to:
  /// **'Stop, and explain what to do'**
  String get codexPermissionsStopAndExplain;

  /// No description provided for @claudePermissionsYesAllowAllEdits.
  ///
  /// In en, this message translates to:
  /// **'Yes, allow all edits during this session'**
  String get claudePermissionsYesAllowAllEdits;

  /// No description provided for @claudePermissionsYesForTool.
  ///
  /// In en, this message translates to:
  /// **'Yes, don\'t ask again for this tool'**
  String get claudePermissionsYesForTool;

  /// No description provided for @claudePermissionsNoTellClaude.
  ///
  /// In en, this message translates to:
  /// **'No, and provide feedback'**
  String get claudePermissionsNoTellClaude;

  /// No description provided for @textSelectionSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select text range'**
  String get textSelectionSelectText;

  /// No description provided for @textSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Text'**
  String get textSelectionTitle;

  /// No description provided for @textSelectionNoTextProvided.
  ///
  /// In en, this message translates to:
  /// **'No text provided'**
  String get textSelectionNoTextProvided;

  /// No description provided for @textSelectionTextNotFound.
  ///
  /// In en, this message translates to:
  /// **'Text not found or expired'**
  String get textSelectionTextNotFound;

  /// No description provided for @textSelectionTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to clipboard'**
  String get textSelectionTextCopied;

  /// No description provided for @textSelectionFailedToCopy.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy text to clipboard'**
  String get textSelectionFailedToCopy;

  /// No description provided for @textSelectionNoTextToCopy.
  ///
  /// In en, this message translates to:
  /// **'No text available to copy'**
  String get textSelectionNoTextToCopy;

  /// No description provided for @markdownCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get markdownCodeCopied;

  /// No description provided for @markdownCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed'**
  String get markdownCopyFailed;

  /// No description provided for @markdownMermaidRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to render mermaid diagram'**
  String get markdownMermaidRenderFailed;

  /// No description provided for @artifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get artifactsTitle;

  /// No description provided for @artifactsCountSingular.
  ///
  /// In en, this message translates to:
  /// **'1 artifact'**
  String get artifactsCountSingular;

  /// Artifact count plural form
  ///
  /// In en, this message translates to:
  /// **'{count} artifacts'**
  String artifactsCountPlural(int count);

  /// No description provided for @artifactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No artifacts yet'**
  String get artifactsEmpty;

  /// No description provided for @artifactsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first artifact to get started'**
  String get artifactsEmptyDescription;

  /// No description provided for @artifactsNew.
  ///
  /// In en, this message translates to:
  /// **'New Artifact'**
  String get artifactsNew;

  /// No description provided for @artifactsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Artifact'**
  String get artifactsEdit;

  /// No description provided for @artifactsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get artifactsDelete;

  /// No description provided for @artifactsUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update artifact. Please try again.'**
  String get artifactsUpdateError;

  /// No description provided for @artifactsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Artifact not found'**
  String get artifactsNotFound;

  /// No description provided for @artifactsDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get artifactsDiscardChanges;

  /// No description provided for @artifactsDiscardChangesDescription.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get artifactsDiscardChangesDescription;

  /// No description provided for @artifactsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete artifact?'**
  String get artifactsDeleteConfirm;

  /// No description provided for @artifactsDeleteConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get artifactsDeleteConfirmDescription;

  /// No description provided for @artifactsTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get artifactsTitleLabel;

  /// No description provided for @artifactsTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter a title for your artifact'**
  String get artifactsTitlePlaceholder;

  /// No description provided for @artifactsBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'CONTENT'**
  String get artifactsBodyLabel;

  /// No description provided for @artifactsBodyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write your content here...'**
  String get artifactsBodyPlaceholder;

  /// No description provided for @artifactsEmptyFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title or content'**
  String get artifactsEmptyFieldsError;

  /// No description provided for @artifactsCreateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create artifact. Please try again.'**
  String get artifactsCreateError;

  /// No description provided for @artifactsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get artifactsSave;

  /// No description provided for @artifactsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get artifactsSaving;

  /// No description provided for @artifactsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading artifacts...'**
  String get artifactsLoading;

  /// No description provided for @artifactsError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load artifact'**
  String get artifactsError;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsManageFriends.
  ///
  /// In en, this message translates to:
  /// **'Manage your friends and connections'**
  String get friendsManageFriends;

  /// No description provided for @friendsSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get friendsSearchTitle;

  /// No description provided for @friendsPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend Requests'**
  String get friendsPendingRequests;

  /// No description provided for @friendsMyFriends.
  ///
  /// In en, this message translates to:
  /// **'My Friends'**
  String get friendsMyFriends;

  /// No description provided for @friendsNoFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any friends yet'**
  String get friendsNoFriendsYet;

  /// No description provided for @friendsFindFriends.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get friendsFindFriends;

  /// No description provided for @friendsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get friendsRemove;

  /// No description provided for @friendsPendingRequest.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendsPendingRequest;

  /// Friend request sent date
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String friendsSentOn(String date);

  /// No description provided for @friendsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendsAccept;

  /// No description provided for @friendsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get friendsReject;

  /// No description provided for @friendsAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get friendsAddFriend;

  /// No description provided for @friendsAlreadyFriends.
  ///
  /// In en, this message translates to:
  /// **'Already Friends'**
  String get friendsAlreadyFriends;

  /// No description provided for @friendsRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Request Pending'**
  String get friendsRequestPending;

  /// No description provided for @friendsSearchInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter a username to search for friends'**
  String get friendsSearchInstructions;

  /// No description provided for @friendsSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter username...'**
  String get friendsSearchPlaceholder;

  /// No description provided for @friendsSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get friendsSearching;

  /// No description provided for @friendsUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get friendsUserNotFound;

  /// No description provided for @friendsNoUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found with that username'**
  String get friendsNoUserFound;

  /// No description provided for @friendsCheckUsername.
  ///
  /// In en, this message translates to:
  /// **'Please check the username and try again'**
  String get friendsCheckUsername;

  /// No description provided for @friendsHowToFind.
  ///
  /// In en, this message translates to:
  /// **'How to Find Friends'**
  String get friendsHowToFind;

  /// No description provided for @friendsFindInstructions.
  ///
  /// In en, this message translates to:
  /// **'Search for friends by their username. Both you and your friend need to have GitHub connected to send friend requests.'**
  String get friendsFindInstructions;

  /// No description provided for @friendsRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent!'**
  String get friendsRequestSent;

  /// No description provided for @friendsRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted!'**
  String get friendsRequestAccepted;

  /// No description provided for @friendsRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Friend request rejected'**
  String get friendsRequestRejected;

  /// No description provided for @friendsFriendRemoved.
  ///
  /// In en, this message translates to:
  /// **'Friend removed'**
  String get friendsFriendRemoved;

  /// No description provided for @friendsConfirmRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Friend'**
  String get friendsConfirmRemove;

  /// No description provided for @friendsConfirmRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this friend?'**
  String get friendsConfirmRemoveMessage;

  /// No description provided for @friendsCannotAddYourself.
  ///
  /// In en, this message translates to:
  /// **'You cannot send a friend request to yourself'**
  String get friendsCannotAddYourself;

  /// No description provided for @friendsBothMustHaveGithub.
  ///
  /// In en, this message translates to:
  /// **'Both users must have GitHub connected to become friends'**
  String get friendsBothMustHaveGithub;

  /// No description provided for @friendsStatusNone.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get friendsStatusNone;

  /// No description provided for @friendsStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get friendsStatusRequested;

  /// No description provided for @friendsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get friendsStatusPending;

  /// No description provided for @friendsStatusFriend.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsStatusFriend;

  /// No description provided for @friendsStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get friendsStatusRejected;

  /// No description provided for @friendsAcceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept Request'**
  String get friendsAcceptRequest;

  /// No description provided for @friendsRemoveFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove Friend'**
  String get friendsRemoveFriend;

  /// No description provided for @friendsRemoveFriendConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} as a friend?'**
  String friendsRemoveFriendConfirm(Object name);

  /// No description provided for @friendsRequestSentDescription.
  ///
  /// In en, this message translates to:
  /// **'Your friend request has been sent to {name}'**
  String friendsRequestSentDescription(Object name);

  /// No description provided for @friendsRequestFriendship.
  ///
  /// In en, this message translates to:
  /// **'Request friendship'**
  String get friendsRequestFriendship;

  /// No description provided for @friendsCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel friendship request'**
  String get friendsCancelRequest;

  /// No description provided for @friendsCancelRequestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel your friendship request to {name}?'**
  String friendsCancelRequestConfirm(Object name);

  /// No description provided for @friendsDenyRequest.
  ///
  /// In en, this message translates to:
  /// **'Deny friendship'**
  String get friendsDenyRequest;

  /// No description provided for @friendsNowFriendsWith.
  ///
  /// In en, this message translates to:
  /// **'You are now friends with {name}'**
  String friendsNowFriendsWith(Object name);

  /// Feed notification for friend request
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request'**
  String feedFriendRequestFrom(String name);

  /// No description provided for @feedFriendRequestGeneric.
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get feedFriendRequestGeneric;

  /// No description provided for @feedFriendAccepted.
  ///
  /// In en, this message translates to:
  /// **'You are now friends with {name}'**
  String feedFriendAccepted(Object name);

  /// No description provided for @feedFriendAcceptedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get feedFriendAcceptedGeneric;

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usageLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get usageLast7Days;

  /// No description provided for @usageLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get usageLast30Days;

  /// No description provided for @usageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total Tokens'**
  String get usageTotalTokens;

  /// No description provided for @usageTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get usageTotalCost;

  /// No description provided for @usageTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get usageTokens;

  /// No description provided for @usageCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get usageCost;

  /// No description provided for @usageUsageOverTime.
  ///
  /// In en, this message translates to:
  /// **'Usage over time'**
  String get usageUsageOverTime;

  /// No description provided for @usageByModel.
  ///
  /// In en, this message translates to:
  /// **'By Model'**
  String get usageByModel;

  /// No description provided for @usageNoData.
  ///
  /// In en, this message translates to:
  /// **'No usage data available'**
  String get usageNoData;
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
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
