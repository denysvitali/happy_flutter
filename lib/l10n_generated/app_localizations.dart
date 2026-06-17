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
/// import 'l10n_generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

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

  /// No description provided for @sessionInitialMessage.
  ///
  /// In en, this message translates to:
  /// **'Initial message'**
  String get sessionInitialMessage;

  /// No description provided for @sessionInitialMessageHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like to work on?'**
  String get sessionInitialMessageHint;

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

  /// No description provided for @newSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSessionTitle;

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

  /// No description provided for @newSessionMachineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Machine is unreachable. Make sure the Happy daemon is running and try again.'**
  String get newSessionMachineUnreachable;

  /// No description provided for @newSessionCouldNotStartSession.
  ///
  /// In en, this message translates to:
  /// **'Could not start session. Please try again.'**
  String get newSessionCouldNotStartSession;

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

  /// No description provided for @sessionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionHistoryTitle;

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

  /// No description provided for @sessionInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get sessionInfoTitle;

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

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

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

  /// No description provided for @settingsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get settingsSessions;

  /// No description provided for @settingsSessionsViewStyle.
  ///
  /// In en, this message translates to:
  /// **'Session view style'**
  String get settingsSessionsViewStyle;

  /// No description provided for @settingsSessionsViewStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how sessions are grouped in the sessions tab'**
  String get settingsSessionsViewStyleSubtitle;

  /// No description provided for @settingsFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get settingsFeatures;

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

  /// No description provided for @errorsSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get errorsSearchFailed;

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

  /// No description provided for @emptySessionsFirstTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started with Happy'**
  String get emptySessionsFirstTimeTitle;

  /// No description provided for @emptySessionsFirstTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your computer to start coding sessions from your phone.'**
  String get emptySessionsFirstTimeSubtitle;

  /// No description provided for @emptySessionsFirstTimeStep1Label.
  ///
  /// In en, this message translates to:
  /// **'Install CLI'**
  String get emptySessionsFirstTimeStep1Label;

  /// No description provided for @emptySessionsFirstTimeStep1Detail.
  ///
  /// In en, this message translates to:
  /// **'Run happy install on your computer'**
  String get emptySessionsFirstTimeStep1Detail;

  /// No description provided for @emptySessionsFirstTimeStep2Label.
  ///
  /// In en, this message translates to:
  /// **'Start daemon'**
  String get emptySessionsFirstTimeStep2Label;

  /// No description provided for @emptySessionsFirstTimeStep2Detail.
  ///
  /// In en, this message translates to:
  /// **'Run happy start in your project'**
  String get emptySessionsFirstTimeStep2Detail;

  /// No description provided for @emptySessionsFirstTimeStep3Label.
  ///
  /// In en, this message translates to:
  /// **'Scan & connect'**
  String get emptySessionsFirstTimeStep3Label;

  /// No description provided for @emptySessionsFirstTimeStep3Detail.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button and scan the QR code'**
  String get emptySessionsFirstTimeStep3Detail;

  /// No description provided for @emptySessionsReturningTitle.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get emptySessionsReturningTitle;

  /// No description provided for @emptySessionsReturningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your previous sessions have ended. Start a new one to keep coding.'**
  String get emptySessionsReturningSubtitle;

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

  /// No description provided for @offlineBannerNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBannerNoConnection;

  /// No description provided for @offlineBannerReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get offlineBannerReconnecting;

  /// No description provided for @offlineBannerReconnectingIn.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting in {seconds}s…'**
  String offlineBannerReconnectingIn(int seconds);

  /// No description provided for @offlineBannerReconnectNow.
  ///
  /// In en, this message translates to:
  /// **'Reconnect now'**
  String get offlineBannerReconnectNow;

  /// No description provided for @commonVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get commonVersion;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get commonCopyCode;

  /// No description provided for @commonFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get commonFile;

  /// No description provided for @commonFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get commonFolder;

  /// No description provided for @commonCmd.
  ///
  /// In en, this message translates to:
  /// **'Cmd'**
  String get commonCmd;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code to connect'**
  String get authSubtitle;

  /// No description provided for @authScanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get authScanQR;

  /// No description provided for @authEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter Token Manually'**
  String get authEnterToken;

  /// No description provided for @authServerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get authServerUrlHint;

  /// No description provided for @authTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Authentication Token'**
  String get authTokenHint;

  /// No description provided for @authConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get authConnect;

  /// No description provided for @authConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get authConnecting;

  /// No description provided for @authInvalidQR.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code'**
  String get authInvalidQR;

  /// No description provided for @authServerConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server'**
  String get authServerConnectionError;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsNew.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get sessionsNew;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionsEmpty;

  /// No description provided for @sessionsCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Create your first session to get started'**
  String get sessionsCreateFirst;

  /// No description provided for @sessionsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sessionsToday;

  /// No description provided for @sessionsYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sessionsYesterday;

  /// No description provided for @sessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get sessionsThisWeek;

  /// No description provided for @sessionsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get sessionsThisMonth;

  /// No description provided for @sessionsOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get sessionsOlder;

  /// No description provided for @dateGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateGroupToday;

  /// No description provided for @dateGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateGroupYesterday;

  /// No description provided for @dateGroupThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get dateGroupThisWeek;

  /// No description provided for @dateGroupThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get dateGroupThisMonth;

  /// No description provided for @dateGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get dateGroupOlder;

  /// No description provided for @sessionsActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE SESSIONS'**
  String get sessionsActiveSessions;

  /// No description provided for @sessionsNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'NEEDS ATTENTION'**
  String get sessionsNeedsAttention;

  /// No description provided for @sessionsAllSessions.
  ///
  /// In en, this message translates to:
  /// **'ALL SESSIONS'**
  String get sessionsAllSessions;

  /// No description provided for @sessionsArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get sessionsArchivedLabel;

  /// No description provided for @sessionsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived ({count})'**
  String sessionsShowArchived(int count);

  /// No description provided for @sessionsHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get sessionsHideArchived;

  /// No description provided for @sessionsShowOlderArchived.
  ///
  /// In en, this message translates to:
  /// **'Show older archived ({count})'**
  String sessionsShowOlderArchived(int count);

  /// No description provided for @sessionsHideOlderArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide older archived'**
  String get sessionsHideOlderArchived;

  /// No description provided for @sessionsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get sessionsArchive;

  /// No description provided for @sessionsArchiveSession.
  ///
  /// In en, this message translates to:
  /// **'Archive Session'**
  String get sessionsArchiveSession;

  /// No description provided for @sessionsSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get sessionsSimple;

  /// No description provided for @sessionsWorktree.
  ///
  /// In en, this message translates to:
  /// **'Worktree'**
  String get sessionsWorktree;

  /// No description provided for @sessionsClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude'**
  String get sessionsClaude;

  /// No description provided for @sessionsCodex.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get sessionsCodex;

  /// No description provided for @sessionsGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get sessionsGemini;

  /// No description provided for @sessionsPi.
  ///
  /// In en, this message translates to:
  /// **'pi'**
  String get sessionsPi;

  /// No description provided for @sessionsOpencode.
  ///
  /// In en, this message translates to:
  /// **'OpenCode'**
  String get sessionsOpencode;

  /// No description provided for @sessionsType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sessionsType;

  /// No description provided for @sessionsAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get sessionsAgent;

  /// No description provided for @sessionsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get sessionsSelectAll;

  /// No description provided for @sessionsDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get sessionsDeselectAll;

  /// No description provided for @sessionsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sessionsPin;

  /// No description provided for @sessionsUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sessionsUnpin;

  /// No description provided for @sessionsFolders.
  ///
  /// In en, this message translates to:
  /// **'Session Folders'**
  String get sessionsFolders;

  /// No description provided for @sessionsFoldersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No folders yet. Create one to organize your sessions.'**
  String get sessionsFoldersEmpty;

  /// No description provided for @sessionsFoldersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get sessionsFoldersAdd;

  /// No description provided for @sessionsFoldersName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get sessionsFoldersName;

  /// No description provided for @sessionsFoldersDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete folder \"{name}\"? Sessions in this folder will become unfiled.'**
  String sessionsFoldersDeleteConfirm(String name);

  /// No description provided for @sessionsFoldersRename.
  ///
  /// In en, this message translates to:
  /// **'Rename Folder'**
  String get sessionsFoldersRename;

  /// No description provided for @sessionsFolderActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 active} other {{count} active}}'**
  String sessionsFolderActiveCount(int count);

  /// No description provided for @sessionsFolderArchivedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 archived} other {{count} archived}}'**
  String sessionsFolderArchivedCount(int count);

  /// No description provided for @sessionsViewStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic list'**
  String get sessionsViewStyleClassic;

  /// No description provided for @sessionsViewStyleFolderCentric.
  ///
  /// In en, this message translates to:
  /// **'Folder-centric'**
  String get sessionsViewStyleFolderCentric;

  /// No description provided for @sessionsViewStyleUnreadFocus.
  ///
  /// In en, this message translates to:
  /// **'Unread Focus'**
  String get sessionsViewStyleUnreadFocus;

  /// No description provided for @sessionsViewStyleBeaconGrid.
  ///
  /// In en, this message translates to:
  /// **'Beacon Grid'**
  String get sessionsViewStyleBeaconGrid;

  /// No description provided for @sessionsViewStyleCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get sessionsViewStyleCommandPalette;

  /// No description provided for @sessionsViewStyleSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe Actions'**
  String get sessionsViewStyleSwipe;

  /// No description provided for @autoArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Archive'**
  String get autoArchiveTitle;

  /// No description provided for @autoArchiveSection.
  ///
  /// In en, this message translates to:
  /// **'Auto-Archive'**
  String get autoArchiveSection;

  /// No description provided for @autoArchiveAfterDays.
  ///
  /// In en, this message translates to:
  /// **'Archive after days'**
  String get autoArchiveAfterDays;

  /// No description provided for @autoArchiveAfterDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'Archive sessions older than N days'**
  String get autoArchiveAfterDaysDesc;

  /// No description provided for @autoArchiveIdleAfterDays.
  ///
  /// In en, this message translates to:
  /// **'Archive idle after days'**
  String get autoArchiveIdleAfterDays;

  /// No description provided for @autoArchiveIdleAfterDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'Archive sessions with no activity for N days'**
  String get autoArchiveIdleAfterDaysDesc;

  /// No description provided for @autoArchiveOnClose.
  ///
  /// In en, this message translates to:
  /// **'Archive on app close'**
  String get autoArchiveOnClose;

  /// No description provided for @autoArchiveOnCloseDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically archive matching sessions when the app closes'**
  String get autoArchiveOnCloseDesc;

  /// No description provided for @autoArchiveDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get autoArchiveDisabled;

  /// No description provided for @autoArchiveDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get autoArchiveDays;

  /// No description provided for @sessionsRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get sessionsRecentTitle;

  /// No description provided for @sessionsRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent sessions'**
  String get sessionsRecentEmpty;

  /// No description provided for @sessionsPressBackToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get sessionsPressBackToExit;

  /// No description provided for @sessionsFailedToArchive.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive session'**
  String get sessionsFailedToArchive;

  /// No description provided for @sessionsFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session'**
  String get sessionsFailedToDelete;

  /// No description provided for @messageDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageDetailTitle;

  /// No description provided for @toolDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool Details'**
  String get toolDetailsTitle;

  /// No description provided for @sessionInfoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get sessionInfoNotFound;

  /// No description provided for @messageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Message not found'**
  String get messageNotFound;

  /// No description provided for @messageDetailContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get messageDetailContent;

  /// No description provided for @messageDetailDetails.
  ///
  /// In en, this message translates to:
  /// **'Message Details'**
  String get messageDetailDetails;

  /// No description provided for @messageDetailNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get messageDetailNoDetails;

  /// No description provided for @messageDetailModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get messageDetailModel;

  /// No description provided for @messageDetailSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get messageDetailSent;

  /// No description provided for @messageDetailMessageId.
  ///
  /// In en, this message translates to:
  /// **'Message ID'**
  String get messageDetailMessageId;

  /// No description provided for @messageDetailSeq.
  ///
  /// In en, this message translates to:
  /// **'Seq'**
  String get messageDetailSeq;

  /// No description provided for @messageDetailTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get messageDetailTimestamp;

  /// No description provided for @messageDetailDebugData.
  ///
  /// In en, this message translates to:
  /// **'Debug Data'**
  String get messageDetailDebugData;

  /// No description provided for @commonNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get commonNA;

  /// No description provided for @messageDetailPermission.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get messageDetailPermission;

  /// No description provided for @messageDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get messageDetailStatus;

  /// No description provided for @messageDetailReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get messageDetailReason;

  /// No description provided for @messageDetailInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get messageDetailInput;

  /// No description provided for @messageDetailOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get messageDetailOutput;

  /// No description provided for @messageDetailSubagentTools.
  ///
  /// In en, this message translates to:
  /// **'Sub-agent Tools'**
  String get messageDetailSubagentTools;

  /// No description provided for @messageDetailTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get messageDetailTool;

  /// No description provided for @messageDetailState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get messageDetailState;

  /// No description provided for @messageDetailAgentType.
  ///
  /// In en, this message translates to:
  /// **'Agent type'**
  String get messageDetailAgentType;

  /// No description provided for @messageDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get messageDetailDescription;

  /// No description provided for @messageDetailShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get messageDetailShare;

  /// No description provided for @messageDetailBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get messageDetailBookmark;

  /// No description provided for @commonCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopiedToClipboard;

  /// No description provided for @accountBackupKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup Key'**
  String get accountBackupKeyLabel;

  /// No description provided for @accountBackupKeyHint.
  ///
  /// In en, this message translates to:
  /// **'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'**
  String get accountBackupKeyHint;

  /// No description provided for @accountEnterBackupKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter your backup key'**
  String get accountEnterBackupKey;

  /// No description provided for @commonUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get commonUnsavedChangesTitle;

  /// No description provided for @chatUnsentMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsent Message'**
  String get chatUnsentMessageTitle;

  /// No description provided for @chatStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get chatStay;

  /// No description provided for @chatLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get chatLeave;

  /// No description provided for @sessionsGroupByDate.
  ///
  /// In en, this message translates to:
  /// **'Group by date'**
  String get sessionsGroupByDate;

  /// No description provided for @pickSelectMachine.
  ///
  /// In en, this message translates to:
  /// **'Select Machine'**
  String get pickSelectMachine;

  /// No description provided for @pickSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select Profile'**
  String get pickSelectProfile;

  /// No description provided for @pickSelectPath.
  ///
  /// In en, this message translates to:
  /// **'Select Path'**
  String get pickSelectPath;

  /// No description provided for @pickNoMachinesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No machines available'**
  String get pickNoMachinesAvailable;

  /// No description provided for @pickRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get pickRecent;

  /// No description provided for @pickAllMachines.
  ///
  /// In en, this message translates to:
  /// **'All Machines'**
  String get pickAllMachines;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get chatInputHint;

  /// No description provided for @chatInputProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get chatInputProfileTitle;

  /// No description provided for @chatInputProfileDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get chatInputProfileDefault;

  /// No description provided for @chatInputProfileDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server-configured defaults'**
  String get chatInputProfileDefaultSubtitle;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatEmpty;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatCopyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopyMessage;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteMessage;

  /// No description provided for @chatClearSession.
  ///
  /// In en, this message translates to:
  /// **'Clear Session'**
  String get chatClearSession;

  /// No description provided for @chatConfirmClear.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear this session?'**
  String get chatConfirmClear;

  /// No description provided for @chatActionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Action'**
  String get chatActionConfirm;

  /// No description provided for @chatActionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get chatActionReject;

  /// No description provided for @chatActionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatActionAccept;

  /// No description provided for @chatChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatChat;

  /// No description provided for @chatChatLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get chatChatLoading;

  /// No description provided for @chatFailedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get chatFailedToLoadMessages;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @noLanguagesFound.
  ///
  /// In en, this message translates to:
  /// **'No languages found'**
  String get noLanguagesFound;

  /// No description provided for @settingsServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsServerNotReachable.
  ///
  /// In en, this message translates to:
  /// **'Server not reachable'**
  String get settingsServerNotReachable;

  /// No description provided for @settingsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get settingsVoice;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsLogs;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @profilesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get profilesDeleteTitle;

  /// No description provided for @profilesFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile'**
  String get profilesFailedToSave;

  /// No description provided for @profilesDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Profile \"{name}\" duplicated'**
  String profilesDuplicated(String name);

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// No description provided for @timePeriod.
  ///
  /// In en, this message translates to:
  /// **'Time Period'**
  String get timePeriod;

  /// No description provided for @totals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get totals;

  /// No description provided for @byModel.
  ///
  /// In en, this message translates to:
  /// **'By Model'**
  String get byModel;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 Days'**
  String get sevenDays;

  /// No description provided for @thirtyDays.
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get thirtyDays;

  /// No description provided for @totalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total Tokens'**
  String get totalTokens;

  /// No description provided for @totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get totalCost;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @avgCostPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg. Cost/Day'**
  String get avgCostPerDay;

  /// No description provided for @avgTokensPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg. Tokens/Day'**
  String get avgTokensPerDay;

  /// No description provided for @noUsageData.
  ///
  /// In en, this message translates to:
  /// **'No usage data'**
  String get noUsageData;

  /// No description provided for @noUsageDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start using Happy to see your usage stats'**
  String get noUsageDataSubtitle;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load usage data'**
  String get failedToLoad;

  /// No description provided for @claudeCodeLimits.
  ///
  /// In en, this message translates to:
  /// **'Claude Code Limits'**
  String get claudeCodeLimits;

  /// No description provided for @claudeLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Claude Code Limits'**
  String get claudeLimitsTitle;

  /// No description provided for @claudeLimitsUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get claudeLimitsUsage;

  /// No description provided for @codexUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Codex Usage'**
  String get codexUsageTitle;

  /// No description provided for @codexUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate limits and credits for Codex on your machines'**
  String get codexUsageSubtitle;

  /// No description provided for @codexUsageAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get codexUsageAccount;

  /// No description provided for @codexUsageEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get codexUsageEmail;

  /// No description provided for @codexUsagePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get codexUsagePlan;

  /// No description provided for @codexUsageSessionLimits.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get codexUsageSessionLimits;

  /// No description provided for @codexUsageCodeReview.
  ///
  /// In en, this message translates to:
  /// **'Code Review'**
  String get codexUsageCodeReview;

  /// No description provided for @codexUsageFiveHourWindow.
  ///
  /// In en, this message translates to:
  /// **'5-hour window'**
  String get codexUsageFiveHourWindow;

  /// No description provided for @codexUsageWeeklyWindow.
  ///
  /// In en, this message translates to:
  /// **'Weekly window'**
  String get codexUsageWeeklyWindow;

  /// No description provided for @codexUsagePrimaryWindow.
  ///
  /// In en, this message translates to:
  /// **'Primary window'**
  String get codexUsagePrimaryWindow;

  /// No description provided for @codexUsageSecondaryWindow.
  ///
  /// In en, this message translates to:
  /// **'Secondary window'**
  String get codexUsageSecondaryWindow;

  /// No description provided for @codexUsageCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get codexUsageCredits;

  /// No description provided for @codexUsageCreditsBalance.
  ///
  /// In en, this message translates to:
  /// **'Credits Balance'**
  String get codexUsageCreditsBalance;

  /// No description provided for @codexUsageCreditsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Credits Available'**
  String get codexUsageCreditsAvailable;

  /// No description provided for @codexUsageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get codexUsageUnlimited;

  /// No description provided for @codexUsageNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines available'**
  String get codexUsageNoMachines;

  /// No description provided for @codexUsageSelectMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get codexUsageSelectMachine;

  /// No description provided for @claudeLimitsResetsAt.
  ///
  /// In en, this message translates to:
  /// **'Resets'**
  String get claudeLimitsResetsAt;

  /// No description provided for @claudeLimitsExtraUsage.
  ///
  /// In en, this message translates to:
  /// **'Extra Usage'**
  String get claudeLimitsExtraUsage;

  /// No description provided for @claudeLimitsMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly Limit'**
  String get claudeLimitsMonthlyLimit;

  /// No description provided for @claudeLimitsUsedCredits.
  ///
  /// In en, this message translates to:
  /// **'Used Credits'**
  String get claudeLimitsUsedCredits;

  /// No description provided for @claudeLocalUsageSection.
  ///
  /// In en, this message translates to:
  /// **'Token Usage'**
  String get claudeLocalUsageSection;

  /// No description provided for @claudeLocalUsageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total tokens'**
  String get claudeLocalUsageTotal;

  /// No description provided for @claudeLocalUsageNoData.
  ///
  /// In en, this message translates to:
  /// **'No local usage yet'**
  String get claudeLocalUsageNoData;

  /// No description provided for @claudeLocalUsageNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a Claude Code session to see token stats'**
  String get claudeLocalUsageNoDataSubtitle;

  /// No description provided for @claudeLocalUsageLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get claudeLocalUsageLast30Days;

  /// No description provided for @claudeLocalUsageRequiresUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update your machine daemon to see local usage'**
  String get claudeLocalUsageRequiresUpdate;

  /// No description provided for @claudeLocalUsageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get claudeLocalUsageRefresh;

  /// No description provided for @claudeLocalUsageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load local usage'**
  String get claudeLocalUsageFailed;

  /// No description provided for @claudeLocalUsageLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get claudeLocalUsageLifetime;

  /// No description provided for @claudeLimitsNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines available'**
  String get claudeLimitsNoMachines;

  /// No description provided for @claudeLimitsSelectMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get claudeLimitsSelectMachine;

  /// No description provided for @featuresExperiments.
  ///
  /// In en, this message translates to:
  /// **'Experiments'**
  String get featuresExperiments;

  /// No description provided for @featuresExperimentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Try experimental features'**
  String get featuresExperimentsDesc;

  /// No description provided for @settingsServerResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Server URL reset to default'**
  String get settingsServerResetSuccess;

  /// No description provided for @settingsServerSaved.
  ///
  /// In en, this message translates to:
  /// **'Server URL saved'**
  String get settingsServerSaved;

  /// No description provided for @settingsServerSaveVerify.
  ///
  /// In en, this message translates to:
  /// **'Save & Verify'**
  String get settingsServerSaveVerify;

  /// No description provided for @settingsOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get settingsOnline;

  /// No description provided for @settingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get settingsOffline;

  /// No description provided for @toolViewFullContent.
  ///
  /// In en, this message translates to:
  /// **'View full content'**
  String get toolViewFullContent;

  /// No description provided for @toolEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get toolEdit;

  /// No description provided for @toolRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get toolRead;

  /// No description provided for @toolWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get toolWrite;

  /// No description provided for @toolBash.
  ///
  /// In en, this message translates to:
  /// **'Bash'**
  String get toolBash;

  /// No description provided for @toolGlob.
  ///
  /// In en, this message translates to:
  /// **'Glob'**
  String get toolGlob;

  /// No description provided for @toolGrep.
  ///
  /// In en, this message translates to:
  /// **'Grep'**
  String get toolGrep;

  /// No description provided for @toolLs.
  ///
  /// In en, this message translates to:
  /// **'List Files'**
  String get toolLs;

  /// No description provided for @toolPatch.
  ///
  /// In en, this message translates to:
  /// **'Patch'**
  String get toolPatch;

  /// No description provided for @toolDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get toolDiff;

  /// No description provided for @toolSectionDiff.
  ///
  /// In en, this message translates to:
  /// **'DIFF'**
  String get toolSectionDiff;

  /// No description provided for @toolSectionContent.
  ///
  /// In en, this message translates to:
  /// **'CONTENT'**
  String get toolSectionContent;

  /// No description provided for @toolSectionCommand.
  ///
  /// In en, this message translates to:
  /// **'COMMAND'**
  String get toolSectionCommand;

  /// No description provided for @toolSectionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get toolSectionReading;

  /// No description provided for @toolSectionWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get toolSectionWriting;

  /// No description provided for @toolSectionInput.
  ///
  /// In en, this message translates to:
  /// **'INPUT'**
  String get toolSectionInput;

  /// No description provided for @toolSectionOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get toolSectionOutput;

  /// No description provided for @toolTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get toolTask;

  /// No description provided for @toolTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get toolTodo;

  /// No description provided for @toolWebFetch.
  ///
  /// In en, this message translates to:
  /// **'Web Fetch'**
  String get toolWebFetch;

  /// No description provided for @toolWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get toolWebSearch;

  /// No description provided for @toolExitPlan.
  ///
  /// In en, this message translates to:
  /// **'Exit Plan'**
  String get toolExitPlan;

  /// No description provided for @toolAskUser.
  ///
  /// In en, this message translates to:
  /// **'Ask User'**
  String get toolAskUser;

  /// No description provided for @permissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// No description provided for @permissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get permissionDeny;

  /// No description provided for @permissionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get permissionStop;

  /// No description provided for @permissionYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get permissionYes;

  /// No description provided for @permissionDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get permissionDefault;

  /// No description provided for @permissionAcceptEdits.
  ///
  /// In en, this message translates to:
  /// **'Accept Edits'**
  String get permissionAcceptEdits;

  /// No description provided for @permissionPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan Mode'**
  String get permissionPlan;

  /// No description provided for @permissionYolo.
  ///
  /// In en, this message translates to:
  /// **'YOLO'**
  String get permissionYolo;

  /// No description provided for @permissionReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get permissionReadOnly;

  /// No description provided for @permissionSafeYolo.
  ///
  /// In en, this message translates to:
  /// **'Safe Yolo'**
  String get permissionSafeYolo;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get permissionRequired;

  /// No description provided for @permissionApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get permissionApproved;

  /// No description provided for @permissionDeniedLabel.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionDeniedLabel;

  /// No description provided for @permissionSessionOffline.
  ///
  /// In en, this message translates to:
  /// **'Session offline'**
  String get permissionSessionOffline;

  /// No description provided for @permissionAllEdits.
  ///
  /// In en, this message translates to:
  /// **'All edits'**
  String get permissionAllEdits;

  /// No description provided for @permissionForSession.
  ///
  /// In en, this message translates to:
  /// **'For session'**
  String get permissionForSession;

  /// No description provided for @permissionActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Permission action failed'**
  String get permissionActionFailed;

  /// No description provided for @permissionModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Mode'**
  String get permissionModeTitle;

  /// No description provided for @permissionModeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get permissionModeDefault;

  /// No description provided for @permissionModeAcceptEdits.
  ///
  /// In en, this message translates to:
  /// **'Accept Edits'**
  String get permissionModeAcceptEdits;

  /// No description provided for @permissionModePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get permissionModePlan;

  /// No description provided for @permissionModeBypass.
  ///
  /// In en, this message translates to:
  /// **'Yolo'**
  String get permissionModeBypass;

  /// No description provided for @permissionModeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get permissionModeReadOnly;

  /// No description provided for @permissionModeSafeYolo.
  ///
  /// In en, this message translates to:
  /// **'Safe YOLO'**
  String get permissionModeSafeYolo;

  /// No description provided for @permissionModeYolo.
  ///
  /// In en, this message translates to:
  /// **'YOLO'**
  String get permissionModeYolo;

  /// No description provided for @permissionModeDefaultDesc.
  ///
  /// In en, this message translates to:
  /// **'Ask for permissions'**
  String get permissionModeDefaultDesc;

  /// No description provided for @permissionModeAcceptEditsDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-approve edits'**
  String get permissionModeAcceptEditsDesc;

  /// No description provided for @permissionModePlanDesc.
  ///
  /// In en, this message translates to:
  /// **'Plan before executing'**
  String get permissionModePlanDesc;

  /// No description provided for @permissionModeBypassDesc.
  ///
  /// In en, this message translates to:
  /// **'Skip all permissions'**
  String get permissionModeBypassDesc;

  /// No description provided for @permissionModeReadOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Read-only mode'**
  String get permissionModeReadOnlyDesc;

  /// No description provided for @permissionModeSafeYoloDesc.
  ///
  /// In en, this message translates to:
  /// **'Safe YOLO mode'**
  String get permissionModeSafeYoloDesc;

  /// No description provided for @permissionModeYoloDesc.
  ///
  /// In en, this message translates to:
  /// **'YOLO mode'**
  String get permissionModeYoloDesc;

  /// No description provided for @voiceAssistantActive.
  ///
  /// In en, this message translates to:
  /// **'Voice assistant active'**
  String get voiceAssistantActive;

  /// No description provided for @voiceAssistantConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get voiceAssistantConnecting;

  /// No description provided for @voiceAssistantDefault.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceAssistantDefault;

  /// No description provided for @voiceAssistantTapToEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap to end'**
  String get voiceAssistantTapToEnd;

  /// No description provided for @transcriptionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Setting up transcription...'**
  String get transcriptionInitializing;

  /// No description provided for @transcriptionReady.
  ///
  /// In en, this message translates to:
  /// **'Transcription ready'**
  String get transcriptionReady;

  /// No description provided for @transcriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Transcription unavailable'**
  String get transcriptionUnavailable;

  /// No description provided for @authClientError.
  ///
  /// In en, this message translates to:
  /// **'Client Error'**
  String get authClientError;

  /// No description provided for @authServerError.
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get authServerError;

  /// No description provided for @authCertificateError.
  ///
  /// In en, this message translates to:
  /// **'Certificate Error'**
  String get authCertificateError;

  /// No description provided for @authConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get authConnectionFailed;

  /// No description provided for @authServerSettings.
  ///
  /// In en, this message translates to:
  /// **'Server Settings'**
  String get authServerSettings;

  /// No description provided for @authLinkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Account'**
  String get authLinkAccount;

  /// No description provided for @authTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get authTryAgain;

  /// No description provided for @authSecretKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get authSecretKeyLabel;

  /// No description provided for @authPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get authPaste;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @voiceAssistantError.
  ///
  /// In en, this message translates to:
  /// **'Voice assistant error'**
  String get voiceAssistantError;

  /// No description provided for @appearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appearanceTheme;

  /// No description provided for @appearanceThemeAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get appearanceThemeAdaptive;

  /// No description provided for @appearanceThemeAdaptiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Match system settings'**
  String get appearanceThemeAdaptiveDesc;

  /// No description provided for @appearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceThemeLight;

  /// No description provided for @appearanceThemeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get appearanceThemeLightDesc;

  /// No description provided for @appearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceThemeDark;

  /// No description provided for @appearanceThemeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get appearanceThemeDarkDesc;

  /// No description provided for @appearanceThemeApplied.
  ///
  /// In en, this message translates to:
  /// **'{theme} theme applied'**
  String appearanceThemeApplied(String theme);

  /// No description provided for @appearanceThemePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get appearanceThemePreview;

  /// No description provided for @appearanceThemeDarkModeActive.
  ///
  /// In en, this message translates to:
  /// **'Dark mode active'**
  String get appearanceThemeDarkModeActive;

  /// No description provided for @appearanceThemeLightModeActive.
  ///
  /// In en, this message translates to:
  /// **'Light mode active'**
  String get appearanceThemeLightModeActive;

  /// No description provided for @appearanceThemeSampleContent.
  ///
  /// In en, this message translates to:
  /// **'Sample content'**
  String get appearanceThemeSampleContent;

  /// No description provided for @appearanceThemeColorPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get appearanceThemeColorPrimary;

  /// No description provided for @appearanceThemeColorSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get appearanceThemeColorSecondary;

  /// No description provided for @searchLanguages.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get searchLanguages;

  /// No description provided for @settingsBehavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get settingsBehavior;

  /// No description provided for @settingsViewInline.
  ///
  /// In en, this message translates to:
  /// **'View Inline'**
  String get settingsViewInline;

  /// No description provided for @settingsViewInlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show tool calls inline in chat'**
  String get settingsViewInlineSubtitle;

  /// No description provided for @settingsHideToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Hide Tool Calls'**
  String get settingsHideToolCalls;

  /// No description provided for @settingsHideToolCallsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide tool call rows in chat while keeping permission prompts visible'**
  String get settingsHideToolCallsSubtitle;

  /// No description provided for @settingsExpandTodos.
  ///
  /// In en, this message translates to:
  /// **'Expand Todos'**
  String get settingsExpandTodos;

  /// No description provided for @settingsShowLineNumbers.
  ///
  /// In en, this message translates to:
  /// **'Show Line Numbers'**
  String get settingsShowLineNumbers;

  /// No description provided for @settingsCompactSessionView.
  ///
  /// In en, this message translates to:
  /// **'Compact Session View'**
  String get settingsCompactSessionView;

  /// No description provided for @settingsShowFlavorIcons.
  ///
  /// In en, this message translates to:
  /// **'Show Flavor Icons'**
  String get settingsShowFlavorIcons;

  /// No description provided for @settingsAvatarStyle.
  ///
  /// In en, this message translates to:
  /// **'Avatar Style'**
  String get settingsAvatarStyle;

  /// No description provided for @settingsWrapLinesInDiffs.
  ///
  /// In en, this message translates to:
  /// **'Wrap Lines in Diffs'**
  String get settingsWrapLinesInDiffs;

  /// No description provided for @userProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfileTitle;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @accountAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountAccountSettings;

  /// No description provided for @accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfile;

  /// No description provided for @accountBackupKey.
  ///
  /// In en, this message translates to:
  /// **'Backup Key'**
  String get accountBackupKey;

  /// No description provided for @accountShowBackupKey.
  ///
  /// In en, this message translates to:
  /// **'Show Backup Key'**
  String get accountShowBackupKey;

  /// No description provided for @accountCopyBackupKey.
  ///
  /// In en, this message translates to:
  /// **'Copy Backup Key'**
  String get accountCopyBackupKey;

  /// No description provided for @accountCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get accountCopyToClipboard;

  /// No description provided for @accountRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get accountRestore;

  /// No description provided for @accountRestoreAccount.
  ///
  /// In en, this message translates to:
  /// **'Restore Account'**
  String get accountRestoreAccount;

  /// No description provided for @accountDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get accountDevices;

  /// No description provided for @accountLinkedDevices.
  ///
  /// In en, this message translates to:
  /// **'Linked Devices'**
  String get accountLinkedDevices;

  /// No description provided for @accountLinkNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Link New Device'**
  String get accountLinkNewDevice;

  /// No description provided for @accountConnectedServices.
  ///
  /// In en, this message translates to:
  /// **'Connected Services'**
  String get accountConnectedServices;

  /// No description provided for @accountBackupKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Backup key copied'**
  String get accountBackupKeyCopied;

  /// No description provided for @accountNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get accountNotConnected;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get accountPasteFromClipboard;

  /// No description provided for @accountRestoredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account restored successfully'**
  String get accountRestoredSuccess;

  /// No description provided for @accountLinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Link Device'**
  String get accountLinkDevice;

  /// No description provided for @accountScanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get accountScanQR;

  /// No description provided for @accountShowQR.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get accountShowQR;

  /// No description provided for @accountEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter URL'**
  String get accountEnterUrl;

  /// No description provided for @accountApproveLinking.
  ///
  /// In en, this message translates to:
  /// **'Approve Linking'**
  String get accountApproveLinking;

  /// No description provided for @accountUnlinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Unlink Device'**
  String get accountUnlinkDevice;

  /// No description provided for @accountUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get accountUnlink;

  /// No description provided for @accountFailedToUnlink.
  ///
  /// In en, this message translates to:
  /// **'Failed to unlink device'**
  String get accountFailedToUnlink;

  /// No description provided for @accountScanHint.
  ///
  /// In en, this message translates to:
  /// **'New device: tap \"Link or Restore Account\"'**
  String get accountScanHint;

  /// No description provided for @accountThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This Device'**
  String get accountThisDevice;

  /// No description provided for @settingsCertificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get settingsCertificates;

  /// No description provided for @settingsUserCaCertificates.
  ///
  /// In en, this message translates to:
  /// **'User CA Certificates'**
  String get settingsUserCaCertificates;

  /// No description provided for @settingsNoUserCertificates.
  ///
  /// In en, this message translates to:
  /// **'No user certificates installed'**
  String get settingsNoUserCertificates;

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnline;

  /// No description provided for @chatConversationCleared.
  ///
  /// In en, this message translates to:
  /// **'Conversation cleared'**
  String get chatConversationCleared;

  /// No description provided for @chatMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get chatMoreOptions;

  /// No description provided for @settingsClaudeCode.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get settingsClaudeCode;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsConnected;

  /// No description provided for @settingsTextToSpeech.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get settingsTextToSpeech;

  /// No description provided for @settingsGitHub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get settingsGitHub;

  /// No description provided for @settingsDeveloperEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsDeveloperEnabled;

  /// No description provided for @featuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get featuresTitle;

  /// No description provided for @devLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get devLogsTitle;

  /// No description provided for @devLogsCount.
  ///
  /// In en, this message translates to:
  /// **'Logs ({count})'**
  String devLogsCount(int count);

  /// No description provided for @devLogsCountFiltered.
  ///
  /// In en, this message translates to:
  /// **'Logs ({count} filtered)'**
  String devLogsCountFiltered(int count);

  /// No description provided for @devLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get devLogsEmpty;

  /// No description provided for @devLogsClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get devLogsClearFilter;

  /// No description provided for @devLogsNoLogsToCopy.
  ///
  /// In en, this message translates to:
  /// **'No logs to copy'**
  String get devLogsNoLogsToCopy;

  /// No description provided for @devLogsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get devLogsClearTitle;

  /// No description provided for @devLogsClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get devLogsClearAction;

  /// No description provided for @devLogsSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Logs'**
  String get devLogsSearchTitle;

  /// No description provided for @devLogsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter search term...'**
  String get devLogsSearchHint;

  /// No description provided for @devLogsAllLevels.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get devLogsAllLevels;

  /// No description provided for @devLogsLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get devLogsLevelDebug;

  /// No description provided for @devLogsLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get devLogsLevelInfo;

  /// No description provided for @devLogsLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get devLogsLevelWarning;

  /// No description provided for @devLogsLevelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get devLogsLevelError;

  /// No description provided for @devLogsLogEntryCopied.
  ///
  /// In en, this message translates to:
  /// **'Log entry copied'**
  String get devLogsLogEntryCopied;

  /// No description provided for @devLogsCopyEntry.
  ///
  /// In en, this message translates to:
  /// **'Copy Entry'**
  String get devLogsCopyEntry;

  /// No description provided for @devLogsAddTestLog.
  ///
  /// In en, this message translates to:
  /// **'Add Test Log'**
  String get devLogsAddTestLog;

  /// No description provided for @devLogsCopyAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy All Logs'**
  String get devLogsCopyAllLogs;

  /// No description provided for @devLogsFilterByLevel.
  ///
  /// In en, this message translates to:
  /// **'Filter by Level'**
  String get devLogsFilterByLevel;

  /// No description provided for @devLogsSearchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search Logs'**
  String get devLogsSearchLogs;

  /// No description provided for @networkInspectorClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Request Log'**
  String get networkInspectorClearTitle;

  /// No description provided for @networkInspectorEntryCopied.
  ///
  /// In en, this message translates to:
  /// **'Entry copied'**
  String get networkInspectorEntryCopied;

  /// No description provided for @developerTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developerTitle;

  /// No description provided for @developerClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get developerClearCache;

  /// No description provided for @developerResetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get developerResetSettings;

  /// No description provided for @developerModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get developerModeTitle;

  /// No description provided for @developerModeEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Enabled - Debug tools are visible'**
  String get developerModeEnabledDesc;

  /// No description provided for @developerNotYetImplemented.
  ///
  /// In en, this message translates to:
  /// **'Not yet implemented'**
  String get developerNotYetImplemented;

  /// No description provided for @developerClearCacheAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get developerClearCacheAction;

  /// No description provided for @developerCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get developerCacheCleared;

  /// No description provided for @developerResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get developerResetAction;

  /// No description provided for @developerSettingsReset.
  ///
  /// In en, this message translates to:
  /// **'Settings reset'**
  String get developerSettingsReset;

  /// No description provided for @developerSectionDebugTools.
  ///
  /// In en, this message translates to:
  /// **'Debug Tools'**
  String get developerSectionDebugTools;

  /// No description provided for @developerSectionTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get developerSectionTesting;

  /// No description provided for @developerSectionCacheStorage.
  ///
  /// In en, this message translates to:
  /// **'Cache & Storage'**
  String get developerSectionCacheStorage;

  /// No description provided for @developerSectionSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get developerSectionSync;

  /// No description provided for @developerSectionBuildInfo.
  ///
  /// In en, this message translates to:
  /// **'Build Info'**
  String get developerSectionBuildInfo;

  /// No description provided for @developerNetworkInspector.
  ///
  /// In en, this message translates to:
  /// **'Network Inspector'**
  String get developerNetworkInspector;

  /// No description provided for @developerLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'View application logs'**
  String get developerLogsDesc;

  /// No description provided for @developerEncryptionDebug.
  ///
  /// In en, this message translates to:
  /// **'Encryption Debug'**
  String get developerEncryptionDebug;

  /// No description provided for @developerSessionDebug.
  ///
  /// In en, this message translates to:
  /// **'Session Debug'**
  String get developerSessionDebug;

  /// No description provided for @developerTestNotifications.
  ///
  /// In en, this message translates to:
  /// **'Test Notifications'**
  String get developerTestNotifications;

  /// No description provided for @developerTestSentryException.
  ///
  /// In en, this message translates to:
  /// **'Test Sentry (Exception)'**
  String get developerTestSentryException;

  /// No description provided for @developerTestSentryUnhandled.
  ///
  /// In en, this message translates to:
  /// **'Test Sentry (Unhandled)'**
  String get developerTestSentryUnhandled;

  /// No description provided for @developerTestSentryUnhandledDesc.
  ///
  /// In en, this message translates to:
  /// **'Throw an unhandled error'**
  String get developerTestSentryUnhandledDesc;

  /// No description provided for @developerClearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear cached data'**
  String get developerClearCacheDesc;

  /// No description provided for @developerResetSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings to defaults'**
  String get developerResetSettingsDesc;

  /// No description provided for @developerForceSyncSettings.
  ///
  /// In en, this message translates to:
  /// **'Re-sync Settings'**
  String get developerForceSyncSettings;

  /// No description provided for @developerForceSyncSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Re-fetch settings from the server'**
  String get developerForceSyncSettingsDesc;

  /// No description provided for @developerForceSyncSettingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to re-sync settings from the server?'**
  String get developerForceSyncSettingsConfirm;

  /// No description provided for @developerForceSyncSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Re-sync'**
  String get developerForceSyncSettingsAction;

  /// No description provided for @developerForceSyncSettingsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings re-synced'**
  String get developerForceSyncSettingsSuccess;

  /// No description provided for @developerForceSyncSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Failed to re-sync settings'**
  String get developerForceSyncSettingsError;

  /// No description provided for @developerAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get developerAppVersion;

  /// No description provided for @developerBuildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get developerBuildNumber;

  /// No description provided for @developerFlutterVersion.
  ///
  /// In en, this message translates to:
  /// **'Flutter Version'**
  String get developerFlutterVersion;

  /// No description provided for @developerDartVersion.
  ///
  /// In en, this message translates to:
  /// **'Dart Version'**
  String get developerDartVersion;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get profilesNone;

  /// No description provided for @profilesDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Use default configuration'**
  String get profilesDefaultDescription;

  /// No description provided for @profilesCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Profiles'**
  String get profilesCustomTitle;

  /// No description provided for @profilesProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profilesProfileName;

  /// No description provided for @profilesAddProfile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get profilesAddProfile;

  /// No description provided for @profilesEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profilesEditProfile;

  /// No description provided for @profilesDeleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get profilesDeleteProfile;

  /// No description provided for @profilesNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MiniMax, Kimi Code, DeepSeek'**
  String get profilesNameHint;

  /// No description provided for @profilesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get profilesNameRequired;

  /// No description provided for @profilesDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get profilesDescriptionLabel;

  /// No description provided for @profilesEnvVarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment Variables'**
  String get profilesEnvVarsTitle;

  /// No description provided for @profilesEnvKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get profilesEnvKeyLabel;

  /// No description provided for @profilesEnvKeyHint.
  ///
  /// In en, this message translates to:
  /// **'VARIABLE_NAME'**
  String get profilesEnvKeyHint;

  /// No description provided for @profilesEnvValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get profilesEnvValueLabel;

  /// No description provided for @profilesScriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Startup Shell Script'**
  String get profilesScriptTitle;

  /// No description provided for @profilesScriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Bash script'**
  String get profilesScriptLabel;

  /// No description provided for @profilesImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Shell Script'**
  String get profilesImportTitle;

  /// No description provided for @profilesImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get profilesImportButton;

  /// No description provided for @profilesImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Shell script content'**
  String get profilesImportLabel;

  /// No description provided for @profilesImportParsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed environment variables'**
  String get profilesImportParsed;

  /// No description provided for @profilesImportLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Import from script'**
  String get profilesImportLabelShort;

  /// No description provided for @profilesQuickSetup.
  ///
  /// In en, this message translates to:
  /// **'Quick Setup'**
  String get profilesQuickSetup;

  /// No description provided for @profilesWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'New AI Profile'**
  String get profilesWizardTitle;

  /// No description provided for @profilesWizardStep1.
  ///
  /// In en, this message translates to:
  /// **'Choose Provider'**
  String get profilesWizardStep1;

  /// No description provided for @profilesWizardStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select your AI provider'**
  String get profilesWizardStep1Subtitle;

  /// No description provided for @profilesWizardStep2.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get profilesWizardStep2;

  /// No description provided for @profilesWizardStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter API key and settings'**
  String get profilesWizardStep2Subtitle;

  /// No description provided for @profilesWizardStep3.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get profilesWizardStep3;

  /// No description provided for @profilesWizardStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your settings'**
  String get profilesWizardStep3Subtitle;

  /// No description provided for @profilesWizardSelectProvider.
  ///
  /// In en, this message translates to:
  /// **'Select a provider to get started'**
  String get profilesWizardSelectProvider;

  /// No description provided for @profilesWizardBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get profilesWizardBaseUrl;

  /// No description provided for @profilesWizardModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get profilesWizardModel;

  /// No description provided for @profilesWizardSmallFastModel.
  ///
  /// In en, this message translates to:
  /// **'Small Fast Model'**
  String get profilesWizardSmallFastModel;

  /// No description provided for @profilesWizardTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout (ms)'**
  String get profilesWizardTimeout;

  /// No description provided for @profilesWizardTimeoutHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional - defaults to 300000ms'**
  String get profilesWizardTimeoutHelp;

  /// No description provided for @changelogTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get changelogTitle;

  /// No description provided for @changelogOpenGitHub.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub Releases'**
  String get changelogOpenGitHub;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceTitle;

  /// No description provided for @voiceLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Language'**
  String get voiceLanguageTitle;

  /// No description provided for @voiceTtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get voiceTtsTitle;

  /// No description provided for @voiceTtsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read assistant messages aloud'**
  String get voiceTtsSubtitle;

  /// No description provided for @voiceTestTts.
  ///
  /// In en, this message translates to:
  /// **'Test TTS'**
  String get voiceTestTts;

  /// No description provided for @voiceTestTtsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to hear a test phrase'**
  String get voiceTestTtsSubtitle;

  /// No description provided for @voiceSelectEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Select the TTS engine.'**
  String get voiceSelectEngineHint;

  /// No description provided for @voiceDefaultEngine.
  ///
  /// In en, this message translates to:
  /// **'Default Engine'**
  String get voiceDefaultEngine;

  /// No description provided for @voiceDefaultEngineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use system default'**
  String get voiceDefaultEngineSubtitle;

  /// No description provided for @voiceSelectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get voiceSelectLanguageTitle;

  /// No description provided for @voiceLanguagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} languages available'**
  String voiceLanguagesCount(int count);

  /// No description provided for @claudeConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Claude API'**
  String get claudeConnectTitle;

  /// No description provided for @claudeConnectTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Claude'**
  String get claudeConnectTerminalTitle;

  /// No description provided for @claudeConnectManualLabel.
  ///
  /// In en, this message translates to:
  /// **'MANUAL API KEY ENTRY'**
  String get claudeConnectManualLabel;

  /// No description provided for @claudeConnectApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get claudeConnectApiKeyLabel;

  /// No description provided for @claudeConnectApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'sk-ant-...'**
  String get claudeConnectApiKeyHint;

  /// No description provided for @claudeConnectBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL (optional)'**
  String get claudeConnectBaseUrlLabel;

  /// No description provided for @claudeConnectBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.anthropic.com'**
  String get claudeConnectBaseUrlHint;

  /// No description provided for @claudeConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get claudeConnectButton;

  /// No description provided for @sessionFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get sessionFilesTitle;

  /// No description provided for @sessionFilesNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get sessionFilesNotFound;

  /// No description provided for @sessionFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get sessionFilesEmpty;

  /// No description provided for @sessionInfoCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get sessionInfoCopied;

  /// No description provided for @sessionInfoUpdateCommandCopied.
  ///
  /// In en, this message translates to:
  /// **'Update command copied'**
  String get sessionInfoUpdateCommandCopied;

  /// No description provided for @sessionInfoCliOutdated.
  ///
  /// In en, this message translates to:
  /// **'CLI Version Outdated'**
  String get sessionInfoCliOutdated;

  /// No description provided for @sessionInfoSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get sessionInfoSectionDetails;

  /// No description provided for @sessionInfoLabelSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionInfoLabelSessionId;

  /// No description provided for @sessionInfoLabelCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get sessionInfoLabelCreated;

  /// No description provided for @sessionInfoLabelLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get sessionInfoLabelLastUpdated;

  /// No description provided for @sessionInfoLabelSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get sessionInfoLabelSequence;

  /// No description provided for @sessionInfoSectionQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get sessionInfoSectionQuickActions;

  /// No description provided for @sessionInfoActionViewMachine.
  ///
  /// In en, this message translates to:
  /// **'View Machine'**
  String get sessionInfoActionViewMachine;

  /// No description provided for @sessionInfoActionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive Session'**
  String get sessionInfoActionArchive;

  /// No description provided for @sessionInfoActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get sessionInfoActionDelete;

  /// No description provided for @sessionInfoSectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get sessionInfoSectionMetadata;

  /// No description provided for @sessionInfoLabelHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get sessionInfoLabelHost;

  /// No description provided for @sessionInfoLabelPath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get sessionInfoLabelPath;

  /// No description provided for @sessionInfoLabelMachineId.
  ///
  /// In en, this message translates to:
  /// **'Machine ID'**
  String get sessionInfoLabelMachineId;

  /// No description provided for @sessionInfoLabelCliVersion.
  ///
  /// In en, this message translates to:
  /// **'CLI Version'**
  String get sessionInfoLabelCliVersion;

  /// No description provided for @sessionInfoLabelAiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get sessionInfoLabelAiProvider;

  /// No description provided for @sessionInfoLabelClaudeSessionId.
  ///
  /// In en, this message translates to:
  /// **'Claude Code Session ID'**
  String get sessionInfoLabelClaudeSessionId;

  /// No description provided for @sessionInfoLabelProcessId.
  ///
  /// In en, this message translates to:
  /// **'Process ID'**
  String get sessionInfoLabelProcessId;

  /// No description provided for @sessionInfoLabelHappyHome.
  ///
  /// In en, this message translates to:
  /// **'Happy Home'**
  String get sessionInfoLabelHappyHome;

  /// No description provided for @sessionInfoLabelOs.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get sessionInfoLabelOs;

  /// No description provided for @sessionInfoActionCopyMetadata.
  ///
  /// In en, this message translates to:
  /// **'Copy Metadata'**
  String get sessionInfoActionCopyMetadata;

  /// No description provided for @sessionInfoSectionAgentState.
  ///
  /// In en, this message translates to:
  /// **'Agent State'**
  String get sessionInfoSectionAgentState;

  /// No description provided for @sessionInfoLabelControlledByUser.
  ///
  /// In en, this message translates to:
  /// **'Controlled by user'**
  String get sessionInfoLabelControlledByUser;

  /// No description provided for @sessionInfoLabelPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get sessionInfoLabelPendingRequests;

  /// No description provided for @sessionInfoSectionActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get sessionInfoSectionActivity;

  /// No description provided for @sessionInfoLabelThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get sessionInfoLabelThinking;

  /// No description provided for @sessionInfoLabelThinkingSince.
  ///
  /// In en, this message translates to:
  /// **'Thinking since'**
  String get sessionInfoLabelThinkingSince;

  /// No description provided for @sessionInfoSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get sessionInfoSectionTools;

  /// No description provided for @sessionInfoActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sessionInfoActive;

  /// No description provided for @sessionInfoInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get sessionInfoInactive;

  /// No description provided for @commonId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get commonId;

  /// No description provided for @commonCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get commonCreated;

  /// No description provided for @commonUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get commonUpdated;

  /// No description provided for @commonSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get commonSequence;

  /// No description provided for @artifactsContentLabel.
  ///
  /// In en, this message translates to:
  /// **'CONTENT'**
  String get artifactsContentLabel;

  /// No description provided for @artifactsDetail.
  ///
  /// In en, this message translates to:
  /// **'Artifact'**
  String get artifactsDetail;

  /// No description provided for @artifactsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get artifactsStatus;

  /// No description provided for @artifactsDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get artifactsDraft;

  /// No description provided for @artifactsFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete artifact'**
  String get artifactsFailedToDelete;

  /// No description provided for @artifactsFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save artifact'**
  String get artifactsFailedToSave;

  /// No description provided for @artifactsFailedToCreate.
  ///
  /// In en, this message translates to:
  /// **'Failed to create artifact'**
  String get artifactsFailedToCreate;

  /// No description provided for @artifactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search artifacts...'**
  String get artifactsSearchHint;

  /// No description provided for @artifactsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching artifacts'**
  String get artifactsNoResults;

  /// No description provided for @machineHomeDir.
  ///
  /// In en, this message translates to:
  /// **'Home Dir'**
  String get machineHomeDir;

  /// No description provided for @machineInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get machineInfo;

  /// No description provided for @machineRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get machineRunning;

  /// No description provided for @machineStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get machineStopped;

  /// No description provided for @machineRemoveMachine.
  ///
  /// In en, this message translates to:
  /// **'Remove Machine'**
  String get machineRemoveMachine;

  /// No description provided for @machineOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get machineOnline;

  /// No description provided for @machineOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get machineOffline;

  /// No description provided for @machineConnectedNow.
  ///
  /// In en, this message translates to:
  /// **'Connected now'**
  String get machineConnectedNow;

  /// No description provided for @machineLastSeenAt.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String machineLastSeenAt(String time);

  /// No description provided for @machineSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions ({count})'**
  String machineSessions(int count);

  /// No description provided for @terminalSelectMachineHint.
  ///
  /// In en, this message translates to:
  /// **'Select machine'**
  String get terminalSelectMachineHint;

  /// No description provided for @terminalSelectMachineError.
  ///
  /// In en, this message translates to:
  /// **'Please select a machine'**
  String get terminalSelectMachineError;

  /// No description provided for @terminalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'TERMINAL / SESSION ID'**
  String get terminalIdLabel;

  /// No description provided for @terminalIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. main, dev, 1234'**
  String get terminalIdHint;

  /// No description provided for @terminalDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get terminalDisconnect;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalSendCommand.
  ///
  /// In en, this message translates to:
  /// **'Send command'**
  String get terminalSendCommand;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @sessionsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get sessionsClearSearch;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get commonUnknown;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get commonGoHome;

  /// No description provided for @commonPressBackAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get commonPressBackAgainToExit;

  /// No description provided for @commonUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get commonUnsavedChanges;

  /// No description provided for @commonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// No description provided for @commonStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get commonStay;

  /// No description provided for @commonUnsentMessage.
  ///
  /// In en, this message translates to:
  /// **'Unsent Message'**
  String get commonUnsentMessage;

  /// No description provided for @commonOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Operation In Progress'**
  String get commonOperationInProgress;

  /// No description provided for @terminalEnterCommand.
  ///
  /// In en, this message translates to:
  /// **'Enter command...'**
  String get terminalEnterCommand;

  /// No description provided for @commandSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search commands...'**
  String get commandSearchHint;

  /// No description provided for @commandCategorySessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get commandCategorySessions;

  /// No description provided for @commandCategoryNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get commandCategoryNavigation;

  /// No description provided for @commandCategoryRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get commandCategoryRecent;

  /// No description provided for @commandNewSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get commandNewSessionTitle;

  /// No description provided for @commandNewSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat session'**
  String get commandNewSessionSubtitle;

  /// No description provided for @commandViewSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'View All Sessions'**
  String get commandViewSessionsTitle;

  /// No description provided for @commandViewSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse your chat history'**
  String get commandViewSessionsSubtitle;

  /// No description provided for @commandSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commandSettingsTitle;

  /// No description provided for @commandSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your preferences'**
  String get commandSettingsSubtitle;

  /// No description provided for @commandAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get commandAccountTitle;

  /// No description provided for @commandAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account'**
  String get commandAccountSubtitle;

  /// No description provided for @commandConnectDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Device'**
  String get commandConnectDeviceTitle;

  /// No description provided for @commandConnectDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a new device via web'**
  String get commandConnectDeviceSubtitle;

  /// No description provided for @commandArtifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get commandArtifactsTitle;

  /// No description provided for @commandArtifactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse your artifacts'**
  String get commandArtifactsSubtitle;

  /// No description provided for @commandTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get commandTerminalTitle;

  /// No description provided for @commandTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access terminal sessions'**
  String get commandTerminalSubtitle;

  /// No description provided for @networkInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Inspector ({count})'**
  String networkInspectorTitle(int count);

  /// No description provided for @networkInspectorCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get networkInspectorCopyAll;

  /// No description provided for @networkInspectorNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get networkInspectorNoRequests;

  /// No description provided for @networkInspectorLabelRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get networkInspectorLabelRequests;

  /// No description provided for @networkInspectorLabelSent.
  ///
  /// In en, this message translates to:
  /// **'↑ Sent'**
  String get networkInspectorLabelSent;

  /// No description provided for @networkInspectorLabelReceived.
  ///
  /// In en, this message translates to:
  /// **'↓ Received'**
  String get networkInspectorLabelReceived;

  /// No description provided for @networkInspectorLabelDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get networkInspectorLabelDuration;

  /// No description provided for @networkInspectorLabelSentBody.
  ///
  /// In en, this message translates to:
  /// **'Sent (body)'**
  String get networkInspectorLabelSentBody;

  /// No description provided for @networkInspectorLabelReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'Received (body)'**
  String get networkInspectorLabelReceivedBody;

  /// No description provided for @developerSentToSentry.
  ///
  /// In en, this message translates to:
  /// **'Sent to Sentry: {eventId}'**
  String developerSentToSentry(String eventId);

  /// No description provided for @chatHowCanIHelpToday.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get chatHowCanIHelpToday;

  /// No description provided for @chatSuggestionWriteCode.
  ///
  /// In en, this message translates to:
  /// **'Write code'**
  String get chatSuggestionWriteCode;

  /// No description provided for @chatSuggestionDebugIssue.
  ///
  /// In en, this message translates to:
  /// **'Debug an issue'**
  String get chatSuggestionDebugIssue;

  /// No description provided for @chatSuggestionExplainCode.
  ///
  /// In en, this message translates to:
  /// **'Explain code'**
  String get chatSuggestionExplainCode;

  /// No description provided for @chatSuggestionReviewPr.
  ///
  /// In en, this message translates to:
  /// **'Review PR'**
  String get chatSuggestionReviewPr;

  /// No description provided for @pickRecentPaths.
  ///
  /// In en, this message translates to:
  /// **'Recent Paths'**
  String get pickRecentPaths;

  /// No description provided for @pickSuggestedPaths.
  ///
  /// In en, this message translates to:
  /// **'Suggested Paths'**
  String get pickSuggestedPaths;

  /// No description provided for @pickProfileNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get pickProfileNone;

  /// No description provided for @pickProfileNoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Use default configuration'**
  String get pickProfileNoneDesc;

  /// No description provided for @pickProfileBuiltInSection.
  ///
  /// In en, this message translates to:
  /// **'BUILT-IN'**
  String get pickProfileBuiltInSection;

  /// No description provided for @pickProfileCustomSection.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM'**
  String get pickProfileCustomSection;

  /// No description provided for @pickProfileCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Custom profile'**
  String get pickProfileCustomDescription;

  /// No description provided for @agentFallbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentFallbackDescription;

  /// No description provided for @agentNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get agentNoMessages;

  /// No description provided for @agentFallbackTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get agentFallbackTask;

  /// No description provided for @agentsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsListTitle;

  /// No description provided for @agentsListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No agents running'**
  String get agentsListEmpty;

  /// No description provided for @subAgentBannerRunning.
  ///
  /// In en, this message translates to:
  /// **'{running} of {total} sub-agents running'**
  String subAgentBannerRunning(int running, int total);

  /// No description provided for @subAgentBannerComplete.
  ///
  /// In en, this message translates to:
  /// **'{total} sub-agents finished'**
  String subAgentBannerComplete(int total);

  /// No description provided for @subAgentBannerError.
  ///
  /// In en, this message translates to:
  /// **'{error} of {total} sub-agents failed'**
  String subAgentBannerError(int error, int total);

  /// No description provided for @subAgentBannerTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get subAgentBannerTapToOpen;

  /// No description provided for @subAgentBannerIcon.
  ///
  /// In en, this message translates to:
  /// **'Sub-agents'**
  String get subAgentBannerIcon;

  /// No description provided for @fileViewerNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get fileViewerNoContent;

  /// No description provided for @artifactsJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get artifactsJustNow;

  /// No description provided for @artifactsYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get artifactsYesterday;

  /// No description provided for @artifactsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String artifactsMinutesAgo(int n);

  /// No description provided for @artifactsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String artifactsHoursAgo(int n);

  /// No description provided for @artifactsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String artifactsDaysAgo(int n);

  /// No description provided for @userFallbackName.
  ///
  /// In en, this message translates to:
  /// **'this user'**
  String get userFallbackName;

  /// No description provided for @commandCategoryRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get commandCategoryRecentSessions;

  /// No description provided for @featuresSectionExperiments.
  ///
  /// In en, this message translates to:
  /// **'Experiments'**
  String get featuresSectionExperiments;

  /// No description provided for @featuresSectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get featuresSectionDisplay;

  /// No description provided for @featuresCompactMode.
  ///
  /// In en, this message translates to:
  /// **'Compact Mode'**
  String get featuresCompactMode;

  /// No description provided for @featuresShowLineNumbers.
  ///
  /// In en, this message translates to:
  /// **'Show Line Numbers'**
  String get featuresShowLineNumbers;

  /// No description provided for @featuresWrapLinesInDiffs.
  ///
  /// In en, this message translates to:
  /// **'Wrap Lines in Diffs'**
  String get featuresWrapLinesInDiffs;

  /// No description provided for @serverCheckingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking connection...'**
  String get serverCheckingConnection;

  /// No description provided for @serverConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get serverConnected;

  /// No description provided for @serverConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get serverConnectionFailed;

  /// No description provided for @serverVerifyingServer.
  ///
  /// In en, this message translates to:
  /// **'Verifying server...'**
  String get serverVerifyingServer;

  /// No description provided for @serverCustomUrlSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM SERVER URL'**
  String get serverCustomUrlSectionLabel;

  /// No description provided for @machinesNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines'**
  String get machinesNoMachines;

  /// No description provided for @voiceAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get voiceAutoDetect;

  /// No description provided for @accountBackupKeyCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Backup key copied to clipboard'**
  String get accountBackupKeyCopiedToClipboard;

  /// No description provided for @accountBackupKeyDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Save this key in a safe place. You can use it to restore your account.'**
  String get accountBackupKeyDialogContent;

  /// No description provided for @accountInvalidKeyFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid key format. Use XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'**
  String get accountInvalidKeyFormat;

  /// No description provided for @accountLinkedDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage devices linked to your account'**
  String get accountLinkedDevicesSubtitle;

  /// No description provided for @accountLinkNewDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate QR code for another device'**
  String get accountLinkNewDeviceSubtitle;

  /// No description provided for @accountRestoreAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recover account from backup key'**
  String get accountRestoreAccountSubtitle;

  /// No description provided for @accountRestoreInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your backup key to restore your account.'**
  String get accountRestoreInstruction;

  /// No description provided for @accountScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the QR code displayed on the new device'**
  String get accountScanInstruction;

  /// No description provided for @accountShowBackupKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your account recovery key'**
  String get accountShowBackupKeySubtitle;

  /// No description provided for @accountShowQRInstructions.
  ///
  /// In en, this message translates to:
  /// **'1. Open Happy on the new device\n2. Tap \"Link or Restore Account\"\n3. Scan this QR code'**
  String get accountShowQRInstructions;

  /// No description provided for @accountUnlinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this device?'**
  String get accountUnlinkConfirm;

  /// No description provided for @artifactsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first artifact using the + button.'**
  String get artifactsEmptySubtitle;

  /// No description provided for @artifactsEnterContent.
  ///
  /// In en, this message translates to:
  /// **'Enter new content'**
  String get artifactsEnterContent;

  /// No description provided for @artifactsEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a new title'**
  String get artifactsEnterTitle;

  /// No description provided for @artifactsEnterTitleOrContent.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title or content.'**
  String get artifactsEnterTitleOrContent;

  /// No description provided for @artifactsNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term.'**
  String get artifactsNoResultsSubtitle;

  /// No description provided for @authConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Please check your server URL and try again.'**
  String get authConnectionError;

  /// No description provided for @authDeviceLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device linked successfully!'**
  String get authDeviceLinkedSuccess;

  /// No description provided for @authErrorDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Error details copied'**
  String get authErrorDetailsCopied;

  /// No description provided for @authFailedToLinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Failed to link device'**
  String get authFailedToLinkDevice;

  /// No description provided for @authInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid key. Use backup key (11 groups), base64, base64url, or 64-char hex.'**
  String get authInvalidKey;

  /// No description provided for @authPleaseEnterSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter a secret key'**
  String get authPleaseEnterSecretKey;

  /// No description provided for @authProcessingDeviceLink.
  ///
  /// In en, this message translates to:
  /// **'Processing device link...'**
  String get authProcessingDeviceLink;

  /// No description provided for @authSecretKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Backup key / base64 / hex'**
  String get authSecretKeyHint;

  /// No description provided for @authSecretKeyInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter backup key (11 groups like XXXXX-XXXXX...), base64/base64url, or 64-char hex key.'**
  String get authSecretKeyInstruction;

  /// No description provided for @authServerUrlSaved.
  ///
  /// In en, this message translates to:
  /// **'Server URL saved and applied.'**
  String get authServerUrlSaved;

  /// No description provided for @authSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first to approve device linking'**
  String get authSignInFirst;

  /// No description provided for @authSignInWithSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Secret Key'**
  String get authSignInWithSecretKey;

  /// No description provided for @authSecretKeyReassurance.
  ///
  /// In en, this message translates to:
  /// **'We\'ll never ask for this in email or support chats. Only enter it here.'**
  String get authSecretKeyReassurance;

  /// No description provided for @authSecretKeyReassuranceTitle.
  ///
  /// In en, this message translates to:
  /// **'Your key stays private'**
  String get authSecretKeyReassuranceTitle;

  /// No description provided for @authContinueToKeyInput.
  ///
  /// In en, this message translates to:
  /// **'Enter Secret Key'**
  String get authContinueToKeyInput;

  /// No description provided for @authSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please sign in again.'**
  String get authSomethingWentWrong;

  /// No description provided for @authWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval...'**
  String get authWaitingForApproval;

  /// No description provided for @authApprovalFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan not completed'**
  String get authApprovalFailedTitle;

  /// No description provided for @authApprovalFailedBody.
  ///
  /// In en, this message translates to:
  /// **'This can happen if the desktop app closed or the request timed out. Try scanning the QR code again.'**
  String get authApprovalFailedBody;

  /// No description provided for @chatBeginningOfConversation.
  ///
  /// In en, this message translates to:
  /// **'Beginning of conversation'**
  String get chatBeginningOfConversation;

  /// No description provided for @chatFailedToDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session'**
  String get chatFailedToDeleteSession;

  /// No description provided for @chatLastSeenJustNow.
  ///
  /// In en, this message translates to:
  /// **'Last seen just now'**
  String get chatLastSeenJustNow;

  /// No description provided for @chatPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission required'**
  String get chatPermissionRequired;

  /// No description provided for @chatSuggestionDebugIssueDesc.
  ///
  /// In en, this message translates to:
  /// **'Find and fix a bug in your code'**
  String get chatSuggestionDebugIssueDesc;

  /// No description provided for @chatSuggestionExplainCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Understand how something works'**
  String get chatSuggestionExplainCodeDesc;

  /// No description provided for @chatSuggestionReviewPrDesc.
  ///
  /// In en, this message translates to:
  /// **'Get feedback on your changes'**
  String get chatSuggestionReviewPrDesc;

  /// No description provided for @chatSuggestionWriteCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate a function or component'**
  String get chatSuggestionWriteCodeDesc;

  /// No description provided for @chatUnsentMessageContent.
  ///
  /// In en, this message translates to:
  /// **'You have an unsent message. Are you sure you want to leave?'**
  String get chatUnsentMessageContent;

  /// No description provided for @claudeCodeLimitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate limits for Claude Code on your machines'**
  String get claudeCodeLimitsSubtitle;

  /// No description provided for @claudeConnectCliInfo.
  ///
  /// In en, this message translates to:
  /// **'API key management is handled via the CLI. Run: happy connect claude'**
  String get claudeConnectCliInfo;

  /// No description provided for @claudeConnectDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Your API key is stored locally on this device only.'**
  String get claudeConnectDisclaimer;

  /// No description provided for @claudeConnectManualDesc.
  ///
  /// In en, this message translates to:
  /// **'Alternatively, enter your Anthropic API key directly.'**
  String get claudeConnectManualDesc;

  /// No description provided for @claudeConnectTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run the following command in your terminal:'**
  String get claudeConnectTerminalSubtitle;

  /// No description provided for @claudeLimitsNoMachinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a machine to check Claude Code limits'**
  String get claudeLimitsNoMachinesSubtitle;

  /// No description provided for @claudeLimitsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Claude Code limits not available'**
  String get claudeLimitsNotAvailable;

  /// No description provided for @claudeLimitsNotAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make sure Claude Code is installed and authenticated on the selected machine'**
  String get claudeLimitsNotAvailableSubtitle;

  /// No description provided for @codexUsageNoMachinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a machine to inspect local Codex usage'**
  String get codexUsageNoMachinesSubtitle;

  /// No description provided for @codexUsageNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Codex usage not available'**
  String get codexUsageNotAvailable;

  /// No description provided for @codexUsageNotAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make sure Codex has run on the selected machine and Python 3 is available'**
  String get codexUsageNotAvailableSubtitle;

  /// No description provided for @commonOperationInProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'An operation is in progress. Are you sure you want to leave?'**
  String get commonOperationInProgressConfirm;

  /// No description provided for @commonUnsavedChangesContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get commonUnsavedChangesContent;

  /// No description provided for @commonUnsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get commonUnsavedChangesMessage;

  /// No description provided for @commonUnsentMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'You have an unsent message. Are you sure you want to leave?'**
  String get commonUnsentMessageConfirm;

  /// No description provided for @developerClearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all cached data?'**
  String get developerClearCacheConfirm;

  /// No description provided for @developerEncryptionDebugDesc.
  ///
  /// In en, this message translates to:
  /// **'View encryption keys and certificates'**
  String get developerEncryptionDebugDesc;

  /// No description provided for @developerModeDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get developerModeDisabledDesc;

  /// No description provided for @developerNetworkInspectorDesc.
  ///
  /// In en, this message translates to:
  /// **'View API requests and responses'**
  String get developerNetworkInspectorDesc;

  /// No description provided for @developerResetSettingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings to defaults?'**
  String get developerResetSettingsConfirm;

  /// No description provided for @developerSessionDebugDesc.
  ///
  /// In en, this message translates to:
  /// **'View active sessions and connections'**
  String get developerSessionDebugDesc;

  /// No description provided for @developerTestNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Send a test push notification'**
  String get developerTestNotificationsDesc;

  /// No description provided for @developerTestSentryExceptionDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture a test exception via Sentry'**
  String get developerTestSentryExceptionDesc;

  /// No description provided for @devLogsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all logs?'**
  String get devLogsClearConfirm;

  /// No description provided for @devLogsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Logs will appear here as they are generated'**
  String get devLogsEmptyDesc;

  /// No description provided for @devLogsOnlyAvailableInDevMode.
  ///
  /// In en, this message translates to:
  /// **'Logs are only available when Developer Mode is enabled.\n\nGo to Settings and enable Developer Mode to view logs.'**
  String get devLogsOnlyAvailableInDevMode;

  /// No description provided for @featuresAlwaysShowContextSize.
  ///
  /// In en, this message translates to:
  /// **'Always Show Context Size'**
  String get featuresAlwaysShowContextSize;

  /// No description provided for @featuresAlwaysShowContextSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Show context window usage'**
  String get featuresAlwaysShowContextSizeDesc;

  /// No description provided for @featuresCompactModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce spacing in chat messages'**
  String get featuresCompactModeDesc;

  /// No description provided for @featuresEnhancedSessionWizard.
  ///
  /// In en, this message translates to:
  /// **'Enhanced Session Wizard'**
  String get featuresEnhancedSessionWizard;

  /// No description provided for @featuresEnhancedSessionWizardDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the improved session creation flow'**
  String get featuresEnhancedSessionWizardDesc;

  /// No description provided for @featuresExperimentalTitle.
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get featuresExperimentalTitle;

  /// No description provided for @featuresHideInactiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Hide Inactive Sessions'**
  String get featuresHideInactiveSessions;

  /// No description provided for @featuresHideInactiveSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide sessions not used recently'**
  String get featuresHideInactiveSessionsDesc;

  /// No description provided for @featuresShowLineNumbersDesc.
  ///
  /// In en, this message translates to:
  /// **'Display line numbers in code blocks'**
  String get featuresShowLineNumbersDesc;

  /// No description provided for @featuresWrapLinesInDiffsDesc.
  ///
  /// In en, this message translates to:
  /// **'Wrap long lines in diff views'**
  String get featuresWrapLinesInDiffsDesc;

  /// No description provided for @fileViewerContentError.
  ///
  /// In en, this message translates to:
  /// **'The file content could not be loaded.'**
  String get fileViewerContentError;

  /// No description provided for @machineLastKnownStatus.
  ///
  /// In en, this message translates to:
  /// **'Last Known Status'**
  String get machineLastKnownStatus;

  /// No description provided for @networkInspectorClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all requests?'**
  String get networkInspectorClearConfirm;

  /// No description provided for @networkInspectorCopyInstruction.
  ///
  /// In en, this message translates to:
  /// **'Copy the log and send it to developers to investigate network usage.'**
  String get networkInspectorCopyInstruction;

  /// No description provided for @networkInspectorNoRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'HTTP requests will appear here as they happen.'**
  String get networkInspectorNoRequestsSubtitle;

  /// No description provided for @permissionExpiredNoPending.
  ///
  /// In en, this message translates to:
  /// **'Permission expired \\u2014 no longer pending'**
  String get permissionExpiredNoPending;

  /// No description provided for @permissionExpiredRestarted.
  ///
  /// In en, this message translates to:
  /// **'Permission expired \\u2014 session was restarted'**
  String get permissionExpiredRestarted;

  /// No description provided for @pickPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter path (e.g. /home/user/projects)'**
  String get pickPathHint;

  /// No description provided for @pickProfileChooseBackend.
  ///
  /// In en, this message translates to:
  /// **'Choose an AI backend profile for your session.'**
  String get pickProfileChooseBackend;

  /// No description provided for @profilesAddProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start from scratch with empty configuration'**
  String get profilesAddProfileSubtitle;

  /// No description provided for @profilesDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. MiniMax via OpenAI-compatible API'**
  String get profilesDescriptionHint;

  /// No description provided for @profilesEnvVarsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No environment variables. Tap Add to set one.'**
  String get profilesEnvVarsEmpty;

  /// No description provided for @profilesEnvVarsHint.
  ///
  /// In en, this message translates to:
  /// **'Set ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, ANTHROPIC_MODEL, etc.'**
  String get profilesEnvVarsHint;

  /// No description provided for @profilesImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the contents of a shell script containing export statements (e.g., setup-hunter-alpha.sh)'**
  String get profilesImportHint;

  /// No description provided for @profilesImportNoVars.
  ///
  /// In en, this message translates to:
  /// **'No environment variables found in the script.'**
  String get profilesImportNoVars;

  /// No description provided for @profilesQuickSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Select a provider to pre-fill configuration'**
  String get profilesQuickSetupHint;

  /// No description provided for @profilesScriptDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs before each session starts. Use to export variables or configure the environment.'**
  String get profilesScriptDescription;

  /// No description provided for @profilesWizardReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Review your settings and tap Save to create the profile.'**
  String get profilesWizardReviewHint;

  /// No description provided for @profilesWizardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step setup with guided configuration'**
  String get profilesWizardSubtitle;

  /// No description provided for @serverCurrentlyUsingCustomUrl.
  ///
  /// In en, this message translates to:
  /// **'Currently using a custom server URL.'**
  String get serverCurrentlyUsingCustomUrl;

  /// No description provided for @serverUrlCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Server URL cannot be empty'**
  String get serverUrlCannotBeEmpty;

  /// No description provided for @sessionFilesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Files modified during the session will appear here.'**
  String get sessionFilesEmptySubtitle;

  /// No description provided for @sessionsArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will stop the running session. Are you sure?'**
  String get sessionsArchiveConfirm;

  /// No description provided for @sessionsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the session and all its messages.'**
  String get sessionsDeleteConfirm;

  /// No description provided for @sessionsGroupByFolder.
  ///
  /// In en, this message translates to:
  /// **'Group by folder'**
  String get sessionsGroupByFolder;

  /// No description provided for @sessionsNewDialogPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'New session dialog would go here'**
  String get sessionsNewDialogPlaceholder;

  /// No description provided for @sessionsNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No sessions match your search'**
  String get sessionsNoSearchResults;

  /// No description provided for @settingsClaudeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Claude disconnected'**
  String get settingsClaudeDisconnected;

  /// No description provided for @settingsCompactSessionViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use smaller cards for sessions'**
  String get settingsCompactSessionViewSubtitle;

  /// No description provided for @settingsConfigureVoice.
  ///
  /// In en, this message translates to:
  /// **'Configure ElevenLabs voice'**
  String get settingsConfigureVoice;

  /// No description provided for @settingsConfigureVoiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Configure voice assistant'**
  String get settingsConfigureVoiceAssistant;

  /// No description provided for @settingsDeveloperOptions.
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get settingsDeveloperOptions;

  /// No description provided for @settingsDeveloperTapToEnable.
  ///
  /// In en, this message translates to:
  /// **'Open developer options'**
  String get settingsDeveloperTapToEnable;

  /// No description provided for @settingsGitHubDisconnected.
  ///
  /// In en, this message translates to:
  /// **'GitHub disconnected'**
  String get settingsGitHubDisconnected;

  /// No description provided for @settingsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsNotConnected;

  /// No description provided for @settingsServerResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset the server URL to the default? This cannot be undone.'**
  String get settingsServerResetConfirm;

  /// No description provided for @settingsShowFlavorIconsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show AI provider icons in avatars'**
  String get settingsShowFlavorIconsSubtitle;

  /// No description provided for @settingsTextToSpeechSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read assistant messages aloud'**
  String get settingsTextToSpeechSubtitle;

  /// No description provided for @settingsUserCertificatesInstalled.
  ///
  /// In en, this message translates to:
  /// **'User certificates are installed'**
  String get settingsUserCertificatesInstalled;

  /// No description provided for @settingsVoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice Settings'**
  String get settingsVoiceSettings;

  /// No description provided for @terminalConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Terminal'**
  String get terminalConnect;

  /// No description provided for @terminalConnected.
  ///
  /// In en, this message translates to:
  /// **'Terminal connected.'**
  String get terminalConnected;

  /// No description provided for @terminalConnectInfo.
  ///
  /// In en, this message translates to:
  /// **'Connect to a terminal session running on one of your machines.'**
  String get terminalConnectInfo;

  /// No description provided for @terminalDisconnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect from the terminal?'**
  String get terminalDisconnectConfirm;

  /// No description provided for @terminalIdError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a terminal or session ID'**
  String get terminalIdError;

  /// No description provided for @terminalNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines connected. Start the Happy CLI on a machine first.'**
  String get terminalNoMachines;

  /// No description provided for @terminalOutputPending.
  ///
  /// In en, this message translates to:
  /// **'[output pending]'**
  String get terminalOutputPending;

  /// No description provided for @voiceSelectLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Select the language for voice output.'**
  String get voiceSelectLanguageHint;

  /// No description provided for @featuresMarkdownCopyV2.
  ///
  /// In en, this message translates to:
  /// **'Markdown Copy V2'**
  String get featuresMarkdownCopyV2;

  /// No description provided for @featuresMarkdownCopyV2Desc.
  ///
  /// In en, this message translates to:
  /// **'Use improved markdown copying'**
  String get featuresMarkdownCopyV2Desc;

  /// No description provided for @artifactsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artifact} other{{count} artifacts}}'**
  String artifactsCount(int count);

  /// No description provided for @authErrorLinkingDevice.
  ///
  /// In en, this message translates to:
  /// **'Error linking device: {error}'**
  String authErrorLinkingDevice(String error);

  /// No description provided for @chatLastSeenMinutes.
  ///
  /// In en, this message translates to:
  /// **'Last seen {minutes}m ago'**
  String chatLastSeenMinutes(int minutes);

  /// No description provided for @chatLastSeenHours.
  ///
  /// In en, this message translates to:
  /// **'Last seen {hours}h ago'**
  String chatLastSeenHours(int hours);

  /// No description provided for @chatLastSeenDays.
  ///
  /// In en, this message translates to:
  /// **'Last seen {days}d ago'**
  String chatLastSeenDays(int days);

  /// No description provided for @chatFailedToClear.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear: {error}'**
  String chatFailedToClear(String error);

  /// No description provided for @devLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'{count} log entries copied'**
  String devLogsCopied(int count);

  /// No description provided for @machineRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{name}\"?'**
  String machineRemoveConfirm(String name);

  /// No description provided for @machineDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete machine ({statusCode})'**
  String machineDeleteFailed(int statusCode);

  /// No description provided for @sessionsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String sessionsSelectedCount(int count);

  /// No description provided for @sessionsArchiveNConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Archive 1 session?} other{Archive {count} sessions?}}'**
  String sessionsArchiveNConfirm(int count);

  /// No description provided for @sessionsArchivePartialFail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}} failed to archive'**
  String sessionsArchivePartialFail(int count);

  /// No description provided for @sessionsDeleteNConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 session?} other{Delete {count} sessions?}} This cannot be undone.'**
  String sessionsDeleteNConfirm(int count);

  /// No description provided for @sessionsDeletePartialFail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}} failed to delete'**
  String sessionsDeletePartialFail(int count);

  /// No description provided for @accountLastActive.
  ///
  /// In en, this message translates to:
  /// **'{platform} • Last active {time}'**
  String accountLastActive(String platform, String time);

  /// No description provided for @profilesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String profilesDeleteConfirm(String name);

  /// No description provided for @settingsFailedToDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect: {error}'**
  String settingsFailedToDisconnect(String error);

  /// No description provided for @settingsConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as @{login}'**
  String settingsConnectedAs(String login);

  /// No description provided for @settingsFailedToStartOAuth.
  ///
  /// In en, this message translates to:
  /// **'Failed to start OAuth: {error}'**
  String settingsFailedToStartOAuth(String error);

  /// No description provided for @appearanceThemeBasedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Based on your device\'s {mode} appearance setting.'**
  String appearanceThemeBasedOnDevice(String mode);

  /// No description provided for @smartFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Features'**
  String get smartFeaturesTitle;

  /// No description provided for @smartFeaturesSection.
  ///
  /// In en, this message translates to:
  /// **'On-device AI'**
  String get smartFeaturesSection;

  /// No description provided for @smartFeaturesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Smart Features'**
  String get smartFeaturesEnabled;

  /// No description provided for @smartFeaturesEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable on-device AI features for smarter session ranking and auto-generated tags'**
  String get smartFeaturesEnabledDesc;

  /// No description provided for @smartFeaturesStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get smartFeaturesStatus;

  /// No description provided for @smartFeaturesReady.
  ///
  /// In en, this message translates to:
  /// **'Model ready'**
  String get smartFeaturesReady;

  /// No description provided for @smartFeaturesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Model not loaded'**
  String get smartFeaturesUnavailable;

  /// No description provided for @smartFeaturesUnavailableDesc.
  ///
  /// In en, this message translates to:
  /// **'Download the on-device AI model below to power session ranking and auto-tags. Until then, simple heuristics are used.'**
  String get smartFeaturesUnavailableDesc;

  /// No description provided for @smartFeaturesModelSection.
  ///
  /// In en, this message translates to:
  /// **'On-device model'**
  String get smartFeaturesModelSection;

  /// No description provided for @smartFeaturesModelNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get smartFeaturesModelNotDownloaded;

  /// No description provided for @smartFeaturesModelReady.
  ///
  /// In en, this message translates to:
  /// **'Downloaded and ready'**
  String get smartFeaturesModelReady;

  /// No description provided for @smartFeaturesDownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download model'**
  String get smartFeaturesDownloadModel;

  /// No description provided for @smartFeaturesDownloadModelDesc.
  ///
  /// In en, this message translates to:
  /// **'Downloads the Gemma model ({size}). Wi-Fi strongly recommended.'**
  String smartFeaturesDownloadModelDesc(String size);

  /// No description provided for @smartFeaturesDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String smartFeaturesDownloading(int percent);

  /// No description provided for @smartFeaturesDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Tap to retry.'**
  String get smartFeaturesDownloadFailed;

  /// No description provided for @smartFeaturesLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model…'**
  String get smartFeaturesLoadingModel;

  /// No description provided for @semanticSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Semantic Search'**
  String get semanticSearchTitle;

  /// No description provided for @semanticSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Rank sessions by semantic similarity to your query'**
  String get semanticSearchDesc;

  /// No description provided for @autoTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Tags'**
  String get autoTagsTitle;

  /// No description provided for @autoTagsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically generate tags for sessions based on content'**
  String get autoTagsDesc;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your friend list is empty'**
  String get friendsEmptyTitle;

  /// No description provided for @friendsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add friends to see when they are online and share sessions.'**
  String get friendsEmptySubtitle;

  /// No description provided for @friendsFindFriends.
  ///
  /// In en, this message translates to:
  /// **'Find friends'**
  String get friendsFindFriends;

  /// No description provided for @friendsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by username or email'**
  String get friendsSearchHint;

  /// No description provided for @tabsProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get tabsProviders;

  /// No description provided for @providersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providersTitle;

  /// No description provided for @providersUsageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get providersUsageSectionTitle;

  /// No description provided for @providersAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get providersAddAccount;

  /// No description provided for @providersAddAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save account'**
  String get providersAddAccountFailed;

  /// No description provided for @providersRemoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get providersRemoveAccount;

  /// No description provided for @providersRemoveAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove account'**
  String get providersRemoveAccountFailed;

  /// No description provided for @providersLongPressToRemove.
  ///
  /// In en, this message translates to:
  /// **'Long-press to select'**
  String get providersLongPressToRemove;

  /// No description provided for @providersSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 selected} other {{count} selected}}'**
  String providersSelectedCount(int count);

  /// No description provided for @providersDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name}?'**
  String providersDeleteConfirmMessage(String name);

  /// No description provided for @providersDeleteSelectedConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {Are you sure you want to remove 1 account?} other {Are you sure you want to remove {count} accounts?}}'**
  String providersDeleteSelectedConfirmMessage(int count);

  /// No description provided for @providersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No provider accounts'**
  String get providersEmptyTitle;

  /// No description provided for @providersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your Kimi or MiniMax account to track usage.'**
  String get providersEmptySubtitle;

  /// No description provided for @providersNoUsageData.
  ///
  /// In en, this message translates to:
  /// **'No usage data available'**
  String get providersNoUsageData;

  /// No description provided for @providersSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get providersSubscription;

  /// No description provided for @providersTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providersTypeLabel;

  /// No description provided for @providersAccountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get providersAccountNameLabel;

  /// No description provided for @providersAccountNameHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get providersAccountNameHint;

  /// No description provided for @providersKimiApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providersKimiApiKeyLabel;

  /// No description provided for @providersKimiApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your Kimi Coding Plan API key'**
  String get providersKimiApiKeyHint;

  /// No description provided for @providersKimiBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providersKimiBaseUrlLabel;

  /// No description provided for @providersKimiBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.kimi.com/coding/v1'**
  String get providersKimiBaseUrlHint;

  /// No description provided for @providersMiniMaxApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providersMiniMaxApiKeyLabel;

  /// No description provided for @providersMiniMaxApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your MiniMax API key'**
  String get providersMiniMaxApiKeyHint;

  /// No description provided for @providersNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'This provider is not yet supported.'**
  String get providersNotImplemented;

  /// No description provided for @providersResetsIn.
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String providersResetsIn(String time);
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
