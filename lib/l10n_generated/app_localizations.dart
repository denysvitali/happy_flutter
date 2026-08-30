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

  /// Common cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

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

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get commonOptional;

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

  /// No description provided for @tabsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabsSettings;

  /// No description provided for @tabsLoops.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get tabsLoops;

  /// Connection status
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

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

  /// No description provided for @sessionNoSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get sessionNoSessionsYet;

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

  /// No description provided for @chatStopCurrentTask.
  ///
  /// In en, this message translates to:
  /// **'Stop current task'**
  String get chatStopCurrentTask;

  /// No description provided for @chatStopAgentProcess.
  ///
  /// In en, this message translates to:
  /// **'Stop agent process'**
  String get chatStopAgentProcess;

  /// No description provided for @chatStopAgentProcessConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop agent process?'**
  String get chatStopAgentProcessConfirmTitle;

  /// No description provided for @chatStopAgentProcessConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This terminates the session\'s process or pod. The conversation is kept and can be restarted by sending another message.'**
  String get chatStopAgentProcessConfirmBody;

  /// No description provided for @chatStopAgentProcessSuccess.
  ///
  /// In en, this message translates to:
  /// **'Agent process stopped'**
  String get chatStopAgentProcessSuccess;

  /// No description provided for @chatStopAgentProcessFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not stop the agent process. It may still be running.'**
  String get chatStopAgentProcessFailure;

  /// No description provided for @newSessionPhaseCheckingMachine.
  ///
  /// In en, this message translates to:
  /// **'Checking machine…'**
  String get newSessionPhaseCheckingMachine;

  /// No description provided for @newSessionPhaseSavingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Saving preferences…'**
  String get newSessionPhaseSavingPreferences;

  /// No description provided for @newSessionPhasePreparingWorktree.
  ///
  /// In en, this message translates to:
  /// **'Creating worktree…'**
  String get newSessionPhasePreparingWorktree;

  /// No description provided for @newSessionPhaseSchedulingContainer.
  ///
  /// In en, this message translates to:
  /// **'Scheduling container and preparing repository…'**
  String get newSessionPhaseSchedulingContainer;

  /// No description provided for @newSessionPhaseStartingAgent.
  ///
  /// In en, this message translates to:
  /// **'Starting agent…'**
  String get newSessionPhaseStartingAgent;

  /// No description provided for @newSessionPhaseFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing session…'**
  String get newSessionPhaseFinalizing;

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

  /// No description provided for @newSessionMachineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Machine is unreachable. Make sure the Happy daemon is running and try again.'**
  String get newSessionMachineUnreachable;

  /// No description provided for @newSessionDaemonOutdated.
  ///
  /// In en, this message translates to:
  /// **'This machine\'s Happy daemon is outdated. Update Happy on the machine, restart the daemon, and try again.'**
  String get newSessionDaemonOutdated;

  /// No description provided for @newSessionCouldNotStartSession.
  ///
  /// In en, this message translates to:
  /// **'Could not start session. Please try again.'**
  String get newSessionCouldNotStartSession;

  /// No description provided for @newSessionRepositoryUrl.
  ///
  /// In en, this message translates to:
  /// **'Git repository'**
  String get newSessionRepositoryUrl;

  /// No description provided for @newSessionRepositoryRequired.
  ///
  /// In en, this message translates to:
  /// **'A git repository is required'**
  String get newSessionRepositoryRequired;

  /// No description provided for @newSessionGitRef.
  ///
  /// In en, this message translates to:
  /// **'Branch or ref'**
  String get newSessionGitRef;

  /// No description provided for @newSessionGitRefHint.
  ///
  /// In en, this message translates to:
  /// **'main'**
  String get newSessionGitRefHint;

  /// No description provided for @newSessionGitRefRequired.
  ///
  /// In en, this message translates to:
  /// **'A branch or git ref is required'**
  String get newSessionGitRefRequired;

  /// No description provided for @newSessionKubernetesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This daemon cannot create Kubernetes pods'**
  String get newSessionKubernetesUnavailable;

  /// No description provided for @newSessionSpawnLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get newSessionSpawnLocal;

  /// No description provided for @newSessionSpawnKubernetes.
  ///
  /// In en, this message translates to:
  /// **'Kubernetes'**
  String get newSessionSpawnKubernetes;

  /// No description provided for @newSessionRepositoryUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://github.com/org/repo.git'**
  String get newSessionRepositoryUrlHint;

  /// No description provided for @newSessionReadyToCreate.
  ///
  /// In en, this message translates to:
  /// **'Ready to create session'**
  String get newSessionReadyToCreate;

  /// No description provided for @sessionPodSection.
  ///
  /// In en, this message translates to:
  /// **'Kubernetes pod'**
  String get sessionPodSection;

  /// No description provided for @sessionPod.
  ///
  /// In en, this message translates to:
  /// **'Session pod'**
  String get sessionPod;

  /// No description provided for @sessionPodScheduling.
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get sessionPodScheduling;

  /// No description provided for @sessionPodReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get sessionPodReady;

  /// No description provided for @sessionPodPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sessionPodPaused;

  /// No description provided for @sessionPodArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get sessionPodArchived;

  /// No description provided for @sessionPodFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get sessionPodFailed;

  /// No description provided for @sessionPodLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the pod state. Check that the daemon is online and up to date.'**
  String get sessionPodLoadFailed;

  /// No description provided for @sessionPodLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get sessionPodLogs;

  /// No description provided for @sessionPodLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pod logs are available yet.'**
  String get sessionPodLogsEmpty;

  /// No description provided for @sessionPodLogsTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the most recent pod log lines.'**
  String get sessionPodLogsTruncated;

  /// No description provided for @sessionPodPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get sessionPodPause;

  /// No description provided for @sessionPodResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get sessionPodResume;

  /// No description provided for @sessionPodKill.
  ///
  /// In en, this message translates to:
  /// **'Kill pod'**
  String get sessionPodKill;

  /// No description provided for @claudeAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Claude Code authentication'**
  String get claudeAuthTitle;

  /// No description provided for @claudeAuthSharedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Shared Claude Code credentials'**
  String get claudeAuthSharedCredentials;

  /// No description provided for @claudeAuthSharedCredentialsHelp.
  ///
  /// In en, this message translates to:
  /// **'Authenticate once with your Claude subscription and share it with all session pods.'**
  String get claudeAuthSharedCredentialsHelp;

  /// No description provided for @claudeAuthInstructions.
  ///
  /// In en, this message translates to:
  /// **'Start authentication, sign in to Claude Code in your browser, then paste the authorization response below.'**
  String get claudeAuthInstructions;

  /// No description provided for @claudeAuthAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Claude Code is authenticated. New session pods will use the shared credentials.'**
  String get claudeAuthAuthenticated;

  /// No description provided for @claudeAuthOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open sign-in link'**
  String get claudeAuthOpenLink;

  /// No description provided for @claudeAuthResponse.
  ///
  /// In en, this message translates to:
  /// **'Authorization response'**
  String get claudeAuthResponse;

  /// No description provided for @claudeAuthResponseHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete response from Claude'**
  String get claudeAuthResponseHint;

  /// No description provided for @claudeAuthBegin.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get claudeAuthBegin;

  /// No description provided for @claudeAuthAgain.
  ///
  /// In en, this message translates to:
  /// **'Authenticate again'**
  String get claudeAuthAgain;

  /// No description provided for @claudeAuthComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get claudeAuthComplete;

  /// No description provided for @sessionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionHistoryTitle;

  /// No description provided for @sessionInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get sessionInfoTitle;

  /// No description provided for @sessionInfoThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get sessionInfoThinking;

  /// No description provided for @sessionInfoMetadataCopied.
  ///
  /// In en, this message translates to:
  /// **'Metadata copied to clipboard'**
  String get sessionInfoMetadataCopied;

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

  /// No description provided for @machineLastKnownPid.
  ///
  /// In en, this message translates to:
  /// **'Last Known PID'**
  String get machineLastKnownPid;

  /// No description provided for @machineCliVersion.
  ///
  /// In en, this message translates to:
  /// **'CLI Version'**
  String get machineCliVersion;

  /// No description provided for @machineCompatibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Happy update recommended'**
  String get machineCompatibilityTitle;

  /// No description provided for @machineCompatibilityMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {currentVersion} is installed. Update to {requiredVersion} or later for the latest remote features.'**
  String machineCompatibilityMessage(
    String currentVersion,
    String requiredVersion,
  );

  /// No description provided for @machineCompatibilityAction.
  ///
  /// In en, this message translates to:
  /// **'Copy update command'**
  String get machineCompatibilityAction;

  /// No description provided for @machineCompatibilityCopied.
  ///
  /// In en, this message translates to:
  /// **'Update command copied'**
  String get machineCompatibilityCopied;

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

  /// No description provided for @machineShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get machineShowLess;

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get chatStartConversation;

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

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

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

  /// No description provided for @settingsHubToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents & Tools'**
  String get settingsHubToolsTitle;

  /// No description provided for @workflowPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workflow presets'**
  String get workflowPresetsTitle;

  /// No description provided for @workflowPresetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Presets update existing app settings and can be adjusted later.'**
  String get workflowPresetsDescription;

  /// No description provided for @workflowPresetFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get workflowPresetFocusTitle;

  /// No description provided for @workflowPresetFocusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet chat, compact sessions, unread-first navigation'**
  String get workflowPresetFocusSubtitle;

  /// No description provided for @workflowPresetVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get workflowPresetVoiceTitle;

  /// No description provided for @workflowPresetVoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Speech on, inline context, mission-control browsing'**
  String get workflowPresetVoiceSubtitle;

  /// No description provided for @workflowPresetLowNoiseTitle.
  ///
  /// In en, this message translates to:
  /// **'Low noise'**
  String get workflowPresetLowNoiseTitle;

  /// No description provided for @workflowPresetLowNoiseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide tool chatter and inactive work by default'**
  String get workflowPresetLowNoiseSubtitle;

  /// No description provided for @workflowPresetDebugTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get workflowPresetDebugTitle;

  /// No description provided for @workflowPresetDebugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show internals, tool calls, todos, and developer logging'**
  String get workflowPresetDebugSubtitle;

  /// No description provided for @workflowPresetActiveSuffix.
  ///
  /// In en, this message translates to:
  /// **'- Active'**
  String get workflowPresetActiveSuffix;

  /// No description provided for @workflowPresetAppliedSnack.
  ///
  /// In en, this message translates to:
  /// **'preset applied'**
  String get workflowPresetAppliedSnack;

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

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

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

  /// No description provided for @settingsAccountDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsAccountDangerZone;

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

  /// No description provided for @settingsServerResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsServerResetToDefault;

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

  /// No description provided for @commandPaletteSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPaletteSemanticsLabel;

  /// No description provided for @commandPaletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No commands found'**
  String get commandPaletteNoResults;

  /// No description provided for @commandPaletteTryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get commandPaletteTryDifferentSearch;

  /// No description provided for @toolStateApprovalNeeded.
  ///
  /// In en, this message translates to:
  /// **'Approval needed'**
  String get toolStateApprovalNeeded;

  /// No description provided for @toolStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolStateRunning;

  /// No description provided for @toolStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get toolStateDone;

  /// No description provided for @toolStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolStateFailed;

  /// No description provided for @toolStateQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get toolStateQueued;

  /// No description provided for @toolStateCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get toolStateCanceled;

  /// No description provided for @toolStateStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get toolStateStopped;

  /// No description provided for @toolOutputExpandHint.
  ///
  /// In en, this message translates to:
  /// **'Expand tool output'**
  String get toolOutputExpandHint;

  /// No description provided for @toolOutputCollapseHint.
  ///
  /// In en, this message translates to:
  /// **'Collapse tool output'**
  String get toolOutputCollapseHint;

  /// No description provided for @toolOutputShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get toolOutputShowMore;

  /// No description provided for @toolOutputShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get toolOutputShowLess;

  /// No description provided for @toolDetailsOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Open tool details'**
  String get toolDetailsOpenHint;

  /// No description provided for @toolDetailsView.
  ///
  /// In en, this message translates to:
  /// **'View tool details'**
  String get toolDetailsView;

  /// No description provided for @toolDetailsButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Use the details button to view input & output'**
  String get toolDetailsButtonHint;

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

  /// Desktop self-updater: a newer release was found
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String desktopUpdateAvailable(String version);

  /// No description provided for @desktopUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get desktopUpdateDownload;

  /// No description provided for @desktopUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get desktopUpdateDownloading;

  /// Desktop self-updater download progress
  ///
  /// In en, this message translates to:
  /// **'Downloading update… {progress}%'**
  String desktopUpdateDownloadingProgress(int progress);

  /// No description provided for @desktopUpdateReady.
  ///
  /// In en, this message translates to:
  /// **'Update installed — restart to apply'**
  String get desktopUpdateReady;

  /// No description provided for @desktopUpdateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get desktopUpdateRestart;

  /// No description provided for @changelogNoEntriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No changelog entries available.'**
  String get changelogNoEntriesAvailable;

  /// First-run sessions empty-state title
  ///
  /// In en, this message translates to:
  /// **'Connect your computer'**
  String get emptySessionsFirstTimeTitle;

  /// First-run sessions setup explanation
  ///
  /// In en, this message translates to:
  /// **'Link Happy to a computer, then start coding from anywhere.'**
  String get emptySessionsFirstTimeSubtitle;

  /// No description provided for @emptySessionsFirstTimeStep1Label.
  ///
  /// In en, this message translates to:
  /// **'Install Happy CLI'**
  String get emptySessionsFirstTimeStep1Label;

  /// No description provided for @emptySessionsFirstTimeStep1Detail.
  ///
  /// In en, this message translates to:
  /// **'npm install -g happy-coder@latest'**
  String get emptySessionsFirstTimeStep1Detail;

  /// No description provided for @emptySessionsFirstTimeStep2Label.
  ///
  /// In en, this message translates to:
  /// **'Link your account'**
  String get emptySessionsFirstTimeStep2Label;

  /// No description provided for @emptySessionsFirstTimeStep2Detail.
  ///
  /// In en, this message translates to:
  /// **'Run happy auth login --method mobile'**
  String get emptySessionsFirstTimeStep2Detail;

  /// No description provided for @emptySessionsFirstTimeStep3Label.
  ///
  /// In en, this message translates to:
  /// **'Keep your computer available'**
  String get emptySessionsFirstTimeStep3Label;

  /// No description provided for @emptySessionsFirstTimeStep3Detail.
  ///
  /// In en, this message translates to:
  /// **'Run happy daemon install'**
  String get emptySessionsFirstTimeStep3Detail;

  /// Action that opens the computer QR linking flow
  ///
  /// In en, this message translates to:
  /// **'Connect computer'**
  String get sessionsConnectComputer;

  /// Sessions empty-state title when linked computers are offline
  ///
  /// In en, this message translates to:
  /// **'Computer offline'**
  String get emptySessionsOfflineTitle;

  /// Guidance shown when no linked computer is reachable
  ///
  /// In en, this message translates to:
  /// **'Bring a linked computer online, then refresh to start a session.'**
  String get emptySessionsOfflineSubtitle;

  /// Action that opens linked computer management
  ///
  /// In en, this message translates to:
  /// **'View computers'**
  String get sessionsViewComputers;

  /// Primary action for creating a coding session
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get sessionsStartSession;

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

  /// No description provided for @textSelectionFailedToCopy.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy text to clipboard'**
  String get textSelectionFailedToCopy;

  /// No description provided for @artifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get artifactsTitle;

  /// No description provided for @artifactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No artifacts yet'**
  String get artifactsEmpty;

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

  /// No description provided for @artifactsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete artifact?'**
  String get artifactsDeleteConfirm;

  /// No description provided for @artifactsTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get artifactsTitleLabel;

  /// No description provided for @offlineBannerNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBannerNoConnection;

  /// No description provided for @offlineBannerLiveUpdatesDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Live updates disconnected'**
  String get offlineBannerLiveUpdatesDisconnected;

  /// No description provided for @offlineBannerServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service connection unavailable'**
  String get offlineBannerServiceUnavailable;

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

  /// Screen-reader label for the offline/reconnecting banner, combining the banner role and its current status text
  ///
  /// In en, this message translates to:
  /// **'Connection status. {status}'**
  String a11yConnectionStatusBanner(String status);

  /// Screen-reader label combining a settings row title and subtitle
  ///
  /// In en, this message translates to:
  /// **'{title}. {subtitle}'**
  String a11ySettingsRow(String title, String subtitle);

  /// Screen-reader label for a bottom-nav tab carrying a badge
  ///
  /// In en, this message translates to:
  /// **'{label}, {count, plural, =1{1 new item} other{{count} new items}}'**
  String a11yTabWithBadge(String label, int count);

  /// Screen-reader label combining an empty-state title and subtitle
  ///
  /// In en, this message translates to:
  /// **'{title}. {subtitle}'**
  String a11yEmptyState(String title, String subtitle);

  /// Screen-reader label announcing an error placeholder
  ///
  /// In en, this message translates to:
  /// **'Error. {message}'**
  String a11yErrorState(String message);

  /// Screen-reader state for an enabled settings toggle
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get a11ySettingsRowOn;

  /// Screen-reader state for a disabled settings toggle
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get a11ySettingsRowOff;

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

  /// No description provided for @sessionsNew.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get sessionsNew;

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

  /// No description provided for @sessionsGrok.
  ///
  /// In en, this message translates to:
  /// **'Grok'**
  String get sessionsGrok;

  /// No description provided for @sessionsAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get sessionsAgent;

  /// No description provided for @sessionsNoSessionSelected.
  ///
  /// In en, this message translates to:
  /// **'No session selected'**
  String get sessionsNoSessionSelected;

  /// No description provided for @sessionsNoSessionSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a session from the list to open its chat, or start a new one.'**
  String get sessionsNoSessionSelectedHint;

  /// No description provided for @sessionsResizeSidebar.
  ///
  /// In en, this message translates to:
  /// **'Resize the session list'**
  String get sessionsResizeSidebar;

  /// No description provided for @paneWidthPixels.
  ///
  /// In en, this message translates to:
  /// **'{width} pixels wide'**
  String paneWidthPixels(int width);

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

  /// No description provided for @sessionsViewStyleMissionControl.
  ///
  /// In en, this message translates to:
  /// **'Mission Control'**
  String get sessionsViewStyleMissionControl;

  /// No description provided for @missionControlFocusQueue.
  ///
  /// In en, this message translates to:
  /// **'Focus queue'**
  String get missionControlFocusQueue;

  /// No description provided for @missionControlFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get missionControlFilterAll;

  /// No description provided for @missionControlWorkspacePulse.
  ///
  /// In en, this message translates to:
  /// **'Workspace pulse'**
  String get missionControlWorkspacePulse;

  /// No description provided for @missionControlReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get missionControlReview;

  /// Compact unread count displayed on a Mission Control tile
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String missionControlNewCount(int count);

  /// No description provided for @missionControlStatBlocked.
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get missionControlStatBlocked;

  /// No description provided for @missionControlStatError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get missionControlStatError;

  /// No description provided for @missionControlStatUnread.
  ///
  /// In en, this message translates to:
  /// **'unread'**
  String get missionControlStatUnread;

  /// No description provided for @missionControlStatWorking.
  ///
  /// In en, this message translates to:
  /// **'working'**
  String get missionControlStatWorking;

  /// No description provided for @missionControlStatIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get missionControlStatIdle;

  /// No description provided for @missionControlMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get missionControlMarkRead;

  /// No description provided for @missionControlTriage.
  ///
  /// In en, this message translates to:
  /// **'Session actions'**
  String get missionControlTriage;

  /// No description provided for @missionControlPinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get missionControlPinToTop;

  /// No description provided for @missionControlUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get missionControlUnpin;

  /// No description provided for @missionControlSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 1 hour'**
  String get missionControlSnooze;

  /// No description provided for @missionControlUnsnooze.
  ///
  /// In en, this message translates to:
  /// **'Unsnooze'**
  String get missionControlUnsnooze;

  /// No description provided for @missionControlMuteWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace muted'**
  String get missionControlMuteWorkspace;

  /// No description provided for @missionControlUnmuteWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace unmuted'**
  String get missionControlUnmuteWorkspace;

  /// No description provided for @missionControlMutedLabel.
  ///
  /// In en, this message translates to:
  /// **'muted'**
  String get missionControlMutedLabel;

  /// Workspace row fallback when no lane has activity
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 session} other {{count} sessions}}'**
  String missionControlSessionCount(int count);

  /// Expander for overflow action rows in Mission Control
  ///
  /// In en, this message translates to:
  /// **'… +{count} more'**
  String missionControlMoreActions(int count);

  /// Drawer for workspaces with no recent activity
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 quiet workspace} other {{count} quiet workspaces}}'**
  String missionControlQuietWorkspaces(int count);

  /// Stall hint on a live stream that has not updated for at least ten minutes (e.g. "12m silent")
  ///
  /// In en, this message translates to:
  /// **'{duration} silent'**
  String missionControlSilent(String duration);

  /// Momentary banner when the Mission Control focus queue becomes empty
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get missionControlAllClear;

  /// Cross-session chronological activity feed heading
  ///
  /// In en, this message translates to:
  /// **'Live wire'**
  String get missionControlLiveWire;

  /// Live wire placeholder before any event fires
  ///
  /// In en, this message translates to:
  /// **'Watching {count} streams…'**
  String missionControlLiveWireEmpty(int count);

  /// Live wire label for a message the user sent from anywhere
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get missionControlWireSent;

  /// Live wire label for an agent that stopped working cleanly
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get missionControlWireDone;

  /// Live wire label for a session entering the active set
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get missionControlWireJoined;

  /// Menu item opening the glanceable session preview sheet
  ///
  /// In en, this message translates to:
  /// **'Quick look'**
  String get missionControlPeekQuickLook;

  /// Primary action in the peek sheet — jump into the full chat
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get missionControlPeekOpenChat;

  /// Destructive action in the peek sheet — abort the running agent
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get missionControlPeekStop;

  /// Confirmation after a stop sent from the peek sheet
  ///
  /// In en, this message translates to:
  /// **'Stop requested'**
  String get missionControlPeekStopRequested;

  /// Error when the stop request from the peek sheet failed
  ///
  /// In en, this message translates to:
  /// **'Could not stop the agent. Try again.'**
  String get missionControlPeekStopFailed;

  /// Peek sheet empty state when nothing is cached locally
  ///
  /// In en, this message translates to:
  /// **'No cached messages yet — open the chat to load them.'**
  String get missionControlPeekNoMessages;

  /// Role label above user bubbles in the peek sheet
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get missionControlPeekYou;

  /// Role label above agent bubbles in the peek sheet
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get missionControlPeekAgent;

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

  /// No description provided for @autoArchiveIdleNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get autoArchiveIdleNever;

  /// No description provided for @autoArchiveIdle30Min.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get autoArchiveIdle30Min;

  /// No description provided for @autoArchiveIdle2Hours.
  ///
  /// In en, this message translates to:
  /// **'2 hours'**
  String get autoArchiveIdle2Hours;

  /// No description provided for @autoArchiveIdle8Hours.
  ///
  /// In en, this message translates to:
  /// **'8 hours'**
  String get autoArchiveIdle8Hours;

  /// No description provided for @autoArchiveIdle1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get autoArchiveIdle1Day;

  /// No description provided for @autoArchiveIdle7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get autoArchiveIdle7Days;

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

  /// No description provided for @webSearchQueriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Queries'**
  String get webSearchQueriesLabel;

  /// No description provided for @webSearchNoResultsNote.
  ///
  /// In en, this message translates to:
  /// **'Search completed — result pages are not included in the transcript.'**
  String get webSearchNoResultsNote;

  /// No description provided for @messageFocusSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get messageFocusSelectText;

  /// No description provided for @messageFocusSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get messageFocusSpeak;

  /// No description provided for @messageFocusStopSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get messageFocusStopSpeaking;

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

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message...'**
  String get chatInputHint;

  /// No description provided for @chatComposerExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand editor'**
  String get chatComposerExpand;

  /// No description provided for @chatComposerCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse editor'**
  String get chatComposerCollapse;

  /// No description provided for @chatComposerFullscreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Compose message'**
  String get chatComposerFullscreenTitle;

  /// Character count in the full-screen composer
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 character} other {{count} characters}}'**
  String chatComposerCharacterCount(int count);

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

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatQueueNextTurn.
  ///
  /// In en, this message translates to:
  /// **'Queue for next turn'**
  String get chatQueueNextTurn;

  /// No description provided for @chatNextTurn.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get chatNextTurn;

  /// Action that steers the currently running Codex turn
  ///
  /// In en, this message translates to:
  /// **'Update current turn'**
  String get chatUpdateCurrentTurn;

  /// Compact visible label for updating the running Codex turn
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get chatUpdateCurrentTurnShort;

  /// Explains the two destinations available while a Codex turn is running
  ///
  /// In en, this message translates to:
  /// **'Update changes the running turn; Queue starts afterward.'**
  String get chatActiveTurnDeliveryHint;

  /// No description provided for @chatQueuedForNextTurn.
  ///
  /// In en, this message translates to:
  /// **'Queued for next turn'**
  String get chatQueuedForNextTurn;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatSending;

  /// No description provided for @chatSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatSent;

  /// No description provided for @chatCopyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopyMessage;

  /// No description provided for @chatChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatChat;

  /// No description provided for @chatFailedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get chatFailedToLoadMessages;

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

  /// No description provided for @grokUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Grok Usage'**
  String get grokUsageTitle;

  /// No description provided for @grokUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly billing allowance for Grok Build on your machines'**
  String get grokUsageSubtitle;

  /// No description provided for @grokUsageAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get grokUsageAccount;

  /// No description provided for @grokUsageEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get grokUsageEmail;

  /// No description provided for @grokUsageBillingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Billing period'**
  String get grokUsageBillingPeriod;

  /// No description provided for @grokUsageMonthlyAllowance.
  ///
  /// In en, this message translates to:
  /// **'Monthly allowance'**
  String get grokUsageMonthlyAllowance;

  /// No description provided for @grokUsageMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Included credits'**
  String get grokUsageMonthlyLimit;

  /// No description provided for @grokUsageOnDemandCap.
  ///
  /// In en, this message translates to:
  /// **'Pay-as-you-go cap'**
  String get grokUsageOnDemandCap;

  /// No description provided for @grokUsageOnDemandDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get grokUsageOnDemandDisabled;

  /// No description provided for @grokUsageNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines available'**
  String get grokUsageNoMachines;

  /// No description provided for @grokUsageSelectMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get grokUsageSelectMachine;

  /// No description provided for @grokUsageNoMachinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a machine to inspect local Grok Build usage'**
  String get grokUsageNoMachinesSubtitle;

  /// No description provided for @grokUsageNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Grok usage not available'**
  String get grokUsageNotAvailable;

  /// No description provided for @grokUsageNotAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make sure Grok Build is signed in on the selected machine'**
  String get grokUsageNotAvailableSubtitle;

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

  /// No description provided for @codexUsageResetsAt.
  ///
  /// In en, this message translates to:
  /// **'Resets {time}'**
  String codexUsageResetsAt(String time);

  /// No description provided for @codexUsageLimitResets.
  ///
  /// In en, this message translates to:
  /// **'Usage limit resets'**
  String get codexUsageLimitResets;

  /// No description provided for @codexUsageResetsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available resets'**
  String get codexUsageResetsAvailable;

  /// No description provided for @codexUsageLimitReset.
  ///
  /// In en, this message translates to:
  /// **'Full reset'**
  String get codexUsageLimitReset;

  /// No description provided for @codexUsageDoesNotExpire.
  ///
  /// In en, this message translates to:
  /// **'Does not expire'**
  String get codexUsageDoesNotExpire;

  /// No description provided for @codexUsageExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Less than 1 day left · {date}} =1{1 day left · {date}} other{{days} days left · {date}}}'**
  String codexUsageExpiresInDays(int days, String date);

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

  /// No description provided for @claudeLocalUsageMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get claudeLocalUsageMessages;

  /// No description provided for @claudeLocalUsageSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get claudeLocalUsageSessions;

  /// No description provided for @claudeLocalUsageToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Tool calls'**
  String get claudeLocalUsageToolCalls;

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

  /// No description provided for @toolViewFullContent.
  ///
  /// In en, this message translates to:
  /// **'View full content'**
  String get toolViewFullContent;

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

  /// No description provided for @permissionAppliedOnce.
  ///
  /// In en, this message translates to:
  /// **'Permission approved for this request'**
  String get permissionAppliedOnce;

  /// No description provided for @permissionAppliedForSession.
  ///
  /// In en, this message translates to:
  /// **'Permission approved for this session'**
  String get permissionAppliedForSession;

  /// No description provided for @permissionDenialApplied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenialApplied;

  /// No description provided for @permissionYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get permissionYes;

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

  /// No description provided for @permissionActionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Permission action in progress'**
  String get permissionActionInProgress;

  /// No description provided for @permissionMoreApprovalOptions.
  ///
  /// In en, this message translates to:
  /// **'More approval options'**
  String get permissionMoreApprovalOptions;

  /// No description provided for @permissionHideApprovalOptions.
  ///
  /// In en, this message translates to:
  /// **'Hide approval options'**
  String get permissionHideApprovalOptions;

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

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnline;

  /// No description provided for @chatStatusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get chatStatusStopping;

  /// No description provided for @chatStatusAgentFailed.
  ///
  /// In en, this message translates to:
  /// **'Agent failed'**
  String get chatStatusAgentFailed;

  /// No description provided for @chatStatusWillRestart.
  ///
  /// In en, this message translates to:
  /// **'Will restart'**
  String get chatStatusWillRestart;

  /// No description provided for @chatStatusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get chatStatusReconnecting;

  /// No description provided for @chatStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get chatStatusConnecting;

  /// No description provided for @chatStatusApprovalNeeded.
  ///
  /// In en, this message translates to:
  /// **'Approval needed'**
  String get chatStatusApprovalNeeded;

  /// No description provided for @chatStatusWorkingOnSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Working on sub-tasks'**
  String get chatStatusWorkingOnSubtasks;

  /// No description provided for @chatStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get chatStatusThinking;

  /// No description provided for @chatActivityThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get chatActivityThinking;

  /// No description provided for @chatActivityStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get chatActivityStopping;

  /// No description provided for @chatActivityStopUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Stop not confirmed — still running'**
  String get chatActivityStopUnconfirmed;

  /// No description provided for @chatActivityStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatActivityStop;

  /// No description provided for @chatStatusRetryQueued.
  ///
  /// In en, this message translates to:
  /// **'Retry queued'**
  String get chatStatusRetryQueued;

  /// No description provided for @chatStatusNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get chatStatusNotDelivered;

  /// No description provided for @chatStatusSentSlow.
  ///
  /// In en, this message translates to:
  /// **'Sent (slow)'**
  String get chatStatusSentSlow;

  /// No description provided for @chatSendSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get chatSendSending;

  /// No description provided for @chatSendSendingSemantic.
  ///
  /// In en, this message translates to:
  /// **'Message sending'**
  String get chatSendSendingSemantic;

  /// No description provided for @chatSendRetryQueuedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Message retry queued'**
  String get chatSendRetryQueuedSemantic;

  /// No description provided for @chatSendDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatSendDelivered;

  /// No description provided for @chatSendDeliveredSlow.
  ///
  /// In en, this message translates to:
  /// **'Delivered — slow'**
  String get chatSendDeliveredSlow;

  /// No description provided for @chatSendDeliveredSemantic.
  ///
  /// In en, this message translates to:
  /// **'Message delivered'**
  String get chatSendDeliveredSemantic;

  /// No description provided for @chatSendDeliveredSlowSemantic.
  ///
  /// In en, this message translates to:
  /// **'Message delivered after a slow send'**
  String get chatSendDeliveredSlowSemantic;

  /// No description provided for @chatSendNotDeliveredSemantic.
  ///
  /// In en, this message translates to:
  /// **'Message not delivered'**
  String get chatSendNotDeliveredSemantic;

  /// No description provided for @chatSendNotDeliveredRetrySemantic.
  ///
  /// In en, this message translates to:
  /// **'Message not delivered — tap to retry'**
  String get chatSendNotDeliveredRetrySemantic;

  /// No description provided for @chatSendFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed — tap to retry'**
  String get chatSendFailedRetry;

  /// No description provided for @chatClearFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the conversation. Try again.'**
  String get chatClearFailedSafe;

  /// No description provided for @chatLifecycleFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session agent stopped'**
  String get chatLifecycleFailedTitle;

  /// No description provided for @chatLifecycleRecoverableMessage.
  ///
  /// In en, this message translates to:
  /// **'The agent process stopped. Sending a message will try to restart it before delivery.'**
  String get chatLifecycleRecoverableMessage;

  /// No description provided for @chatLifecycleBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'The agent process stopped and cannot be restored. Start a new session to continue.'**
  String get chatLifecycleBlockedMessage;

  /// No description provided for @chatConversationCleared.
  ///
  /// In en, this message translates to:
  /// **'Conversation cleared'**
  String get chatConversationCleared;

  /// Inline chat divider shown when the agent starts replying with a different model
  ///
  /// In en, this message translates to:
  /// **'Model changed: {from} → {to}'**
  String chatModelChanged(String from, String to);

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

  /// No description provided for @profilesEnvAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get profilesEnvAddRow;

  /// No description provided for @profilesEnvRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove variable'**
  String get profilesEnvRemoveRow;

  /// No description provided for @profilesEnvShowValue.
  ///
  /// In en, this message translates to:
  /// **'Show value'**
  String get profilesEnvShowValue;

  /// No description provided for @profilesEnvHideValue.
  ///
  /// In en, this message translates to:
  /// **'Hide value'**
  String get profilesEnvHideValue;

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

  /// No description provided for @profilesCompatibleAgents.
  ///
  /// In en, this message translates to:
  /// **'Compatible agents'**
  String get profilesCompatibleAgents;

  /// No description provided for @profilesCompatibleAgentsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which agents can use this profile'**
  String get profilesCompatibleAgentsHint;

  /// No description provided for @profilesCodexProviderEnvHint.
  ///
  /// In en, this message translates to:
  /// **'Codex sessions can use the provider definitions below. Environment variables remain available for advanced or legacy configurations.'**
  String get profilesCodexProviderEnvHint;

  /// No description provided for @profilesCodexProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Codex providers'**
  String get profilesCodexProvidersTitle;

  /// No description provided for @profilesCodexProvidersHint.
  ///
  /// In en, this message translates to:
  /// **'Add model_providers entries for Codex-compatible gateways. Keys stay in the environment variable named below.'**
  String get profilesCodexProvidersHint;

  /// No description provided for @profilesCodexDefaultProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Default provider ID (optional)'**
  String get profilesCodexDefaultProviderLabel;

  /// No description provided for @profilesCodexDefaultProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Uses the first provider when empty'**
  String get profilesCodexDefaultProviderHint;

  /// No description provided for @profilesCodexProviderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider ID'**
  String get profilesCodexProviderIdLabel;

  /// No description provided for @profilesCodexProviderIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. llm-proxy'**
  String get profilesCodexProviderIdHint;

  /// No description provided for @profilesCodexProviderIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use only letters, numbers, hyphens, and underscores'**
  String get profilesCodexProviderIdInvalid;

  /// No description provided for @profilesCodexProviderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get profilesCodexProviderNameLabel;

  /// No description provided for @profilesCodexProviderNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. LLM Proxy'**
  String get profilesCodexProviderNameHint;

  /// No description provided for @profilesCodexProviderBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get profilesCodexProviderBaseUrlLabel;

  /// No description provided for @profilesCodexProviderBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://gateway.example/v1'**
  String get profilesCodexProviderBaseUrlHint;

  /// No description provided for @profilesCodexProviderEnvKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key environment variable'**
  String get profilesCodexProviderEnvKeyLabel;

  /// No description provided for @profilesCodexProviderEnvKeyHint.
  ///
  /// In en, this message translates to:
  /// **'LLM_PROXY_API_KEY'**
  String get profilesCodexProviderEnvKeyHint;

  /// No description provided for @profilesCodexProviderEnvKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use an uppercase environment variable name'**
  String get profilesCodexProviderEnvKeyInvalid;

  /// No description provided for @profilesCodexProviderWireApiLabel.
  ///
  /// In en, this message translates to:
  /// **'Wire API'**
  String get profilesCodexProviderWireApiLabel;

  /// No description provided for @profilesCodexProviderResponses.
  ///
  /// In en, this message translates to:
  /// **'Responses API'**
  String get profilesCodexProviderResponses;

  /// No description provided for @profilesCodexProviderChat.
  ///
  /// In en, this message translates to:
  /// **'Chat Completions'**
  String get profilesCodexProviderChat;

  /// No description provided for @profilesCodexProviderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get profilesCodexProviderAdd;

  /// No description provided for @profilesCodexProviderRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove provider'**
  String get profilesCodexProviderRemove;

  /// No description provided for @profilesCodexProvidersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Codex providers configured'**
  String get profilesCodexProvidersEmpty;

  /// No description provided for @profilesModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get profilesModelsTitle;

  /// No description provided for @profilesModelsHint.
  ///
  /// In en, this message translates to:
  /// **'Models available when this profile is selected'**
  String get profilesModelsHint;

  /// No description provided for @profilesModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model identifier'**
  String get profilesModelLabel;

  /// No description provided for @profilesModelAdd.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get profilesModelAdd;

  /// No description provided for @profilesModelRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get profilesModelRemove;

  /// No description provided for @profilesModelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No models configured'**
  String get profilesModelsEmpty;

  /// No description provided for @profilesContextWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Context window'**
  String get profilesContextWindowTitle;

  /// No description provided for @profilesContextWindowHint.
  ///
  /// In en, this message translates to:
  /// **'Token limit for this profile\'s Claude-compatible models. 1M requires Claude Code\'s extended window.'**
  String get profilesContextWindowHint;

  /// No description provided for @profilesContextWindowDefault.
  ///
  /// In en, this message translates to:
  /// **'Provider default'**
  String get profilesContextWindowDefault;

  /// No description provided for @profilesContextWindow1M.
  ///
  /// In en, this message translates to:
  /// **'1M tokens'**
  String get profilesContextWindow1M;

  /// No description provided for @profilesAtLeastOneAgent.
  ///
  /// In en, this message translates to:
  /// **'Select at least one agent'**
  String get profilesAtLeastOneAgent;

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

  /// No description provided for @voiceUseOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Use offline voice'**
  String get voiceUseOfflineTitle;

  /// No description provided for @voiceUseOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High-quality on-device TTS via sherpa-onnx. Falls back to system TTS while the model downloads or if generation fails.'**
  String get voiceUseOfflineSubtitle;

  /// No description provided for @voiceTestTtsPhrase.
  ///
  /// In en, this message translates to:
  /// **'Hello! Text to speech is working.'**
  String get voiceTestTtsPhrase;

  /// No description provided for @voiceOfflineVoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline voices'**
  String get voiceOfflineVoicesTitle;

  /// No description provided for @voiceDictationModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dictation models'**
  String get voiceDictationModelsTitle;

  /// No description provided for @voiceInstalledLabel.
  ///
  /// In en, this message translates to:
  /// **'installed'**
  String get voiceInstalledLabel;

  /// No description provided for @voiceDownloadStatusReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get voiceDownloadStatusReady;

  /// No description provided for @voiceDownloadStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'downloading…'**
  String get voiceDownloadStatusDownloading;

  /// No description provided for @voiceDownloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'download failed'**
  String get voiceDownloadStatusFailed;

  /// No description provided for @voiceDownloadStatusNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'not downloaded'**
  String get voiceDownloadStatusNotDownloaded;

  /// No description provided for @voiceDownloadFailedRetrySuffix.
  ///
  /// In en, this message translates to:
  /// **' · download failed, tap retry'**
  String get voiceDownloadFailedRetrySuffix;

  /// No description provided for @voiceDownloadNotDownloadedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · not downloaded'**
  String get voiceDownloadNotDownloadedSuffix;

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

  /// No description provided for @sessionInfoActionExportDebug.
  ///
  /// In en, this message translates to:
  /// **'Export Debug Info'**
  String get sessionInfoActionExportDebug;

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

  /// No description provided for @sessionInfoDebugExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Debug info copied to clipboard'**
  String get sessionInfoDebugExportCopied;

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

  /// Badge shown when the daemon verified sandbox enforcement
  ///
  /// In en, this message translates to:
  /// **'Sandboxed'**
  String get sessionSandboxEnforced;

  /// Badge shown when sandboxing was requested but not enforced
  ///
  /// In en, this message translates to:
  /// **'Not sandboxed'**
  String get sessionSandboxNotEnforced;

  /// Badge shown when sandboxing was not requested
  ///
  /// In en, this message translates to:
  /// **'Sandbox off'**
  String get sessionSandboxOff;

  /// Tooltip for a verified sandbox badge
  ///
  /// In en, this message translates to:
  /// **'Isolation enforced by {backend}'**
  String sessionSandboxEnforcedTooltip(String backend);

  /// Fallback tooltip when a sandbox failure reason is unavailable
  ///
  /// In en, this message translates to:
  /// **'Sandboxing was requested but not enforced'**
  String get sessionSandboxNotEnforcedTooltip;

  /// Tooltip for a session whose sandbox policy was off
  ///
  /// In en, this message translates to:
  /// **'Sandboxing was not requested for this session'**
  String get sessionSandboxOffTooltip;

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
  /// **'WORKING DIRECTORY'**
  String get terminalIdLabel;

  /// No description provided for @terminalIdHint.
  ///
  /// In en, this message translates to:
  /// **'/path/to/project'**
  String get terminalIdHint;

  /// No description provided for @terminalDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get terminalDisconnect;

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
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

  /// No description provided for @commandCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get commandCategoryGeneral;

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
  /// **'Run command'**
  String get commandTerminalTitle;

  /// No description provided for @commandTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run a command on a connected machine'**
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

  /// Editable starter prompt inserted by the Write code suggestion
  ///
  /// In en, this message translates to:
  /// **'Build this feature with production-ready code: '**
  String get chatSuggestionWriteCodePrompt;

  /// Editable starter prompt inserted by the Debug an issue suggestion
  ///
  /// In en, this message translates to:
  /// **'Investigate and fix this issue. Start by reproducing it: '**
  String get chatSuggestionDebugIssuePrompt;

  /// Editable starter prompt inserted by the Explain code suggestion
  ///
  /// In en, this message translates to:
  /// **'Explain how this code works, including the key data flow: '**
  String get chatSuggestionExplainCodePrompt;

  /// Editable starter prompt inserted by the Review PR suggestion
  ///
  /// In en, this message translates to:
  /// **'Review the current changes for correctness, regressions, and missing tests.'**
  String get chatSuggestionReviewPrPrompt;

  /// Empty-chat capability hint for attaching project files
  ///
  /// In en, this message translates to:
  /// **'@ files'**
  String get chatCapabilityFiles;

  /// Empty-chat capability hint for slash commands
  ///
  /// In en, this message translates to:
  /// **'/ commands'**
  String get chatCapabilityCommands;

  /// Empty-chat capability hint for voice dictation
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatCapabilityVoice;

  /// Heading above session-specific files, workflows, and loops actions
  ///
  /// In en, this message translates to:
  /// **'Session workspace'**
  String get chatWorkspaceTitle;

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

  /// Relative time under one minute
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get relativeJustNow;

  /// Relative time on the previous calendar day
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get relativeYesterday;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String relativeMinutesAgo(int n);

  /// No description provided for @relativeMinutesCompact.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String relativeMinutesCompact(int n);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String relativeHoursAgo(int n);

  /// No description provided for @relativeHoursCompact.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String relativeHoursCompact(int n);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String relativeDaysAgo(int n);

  /// No description provided for @relativeDaysCompact.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String relativeDaysCompact(int n);

  /// No description provided for @dateTimeToday.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String dateTimeToday(String time);

  /// No description provided for @dateTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday at {time}'**
  String dateTimeYesterday(String time);

  /// No description provided for @commandCategoryRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get commandCategoryRecentSessions;

  /// No description provided for @commandSessionFallback.
  ///
  /// In en, this message translates to:
  /// **'Session {id}'**
  String commandSessionFallback(String id);

  /// No description provided for @commandSwitchToSession.
  ///
  /// In en, this message translates to:
  /// **'Switch to session'**
  String get commandSwitchToSession;

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

  /// No description provided for @authLinkRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve device linking?'**
  String get authLinkRequestTitle;

  /// No description provided for @authLinkRequestBody.
  ///
  /// In en, this message translates to:
  /// **'A {requestType} is asking for access to your account. Only approve a request you initiated.\n\nSecurity fingerprint:\n{fingerprint}'**
  String authLinkRequestBody(String requestType, String fingerprint);

  /// No description provided for @authLinkRequestTerminal.
  ///
  /// In en, this message translates to:
  /// **'terminal'**
  String get authLinkRequestTerminal;

  /// No description provided for @authLinkRequestAccount.
  ///
  /// In en, this message translates to:
  /// **'device'**
  String get authLinkRequestAccount;

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

  /// No description provided for @commonUnsavedChangesContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to leave?'**
  String get commonUnsavedChangesContent;

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

  /// No description provided for @profilesSelectToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a profile to edit'**
  String get profilesSelectToEdit;

  /// No description provided for @profilesImportedFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Imported Profile'**
  String get profilesImportedFallbackName;

  /// No description provided for @profilesCopySuffix.
  ///
  /// In en, this message translates to:
  /// **' (Copy)'**
  String get profilesCopySuffix;

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

  /// No description provided for @settingsVoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice Settings'**
  String get settingsVoiceSettings;

  /// No description provided for @terminalConnect.
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get terminalConnect;

  /// No description provided for @terminalConnected.
  ///
  /// In en, this message translates to:
  /// **'Commands run independently. Shell state is not preserved.'**
  String get terminalConnected;

  /// No description provided for @terminalConnectInfo.
  ///
  /// In en, this message translates to:
  /// **'Run one-off shell commands on a linked machine. This is not an interactive terminal.'**
  String get terminalConnectInfo;

  /// No description provided for @terminalCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed. Check the machine connection and try again.'**
  String get terminalCommandFailed;

  /// No description provided for @terminalDisconnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close the command runner?'**
  String get terminalDisconnectConfirm;

  /// No description provided for @terminalIdError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a working directory'**
  String get terminalIdError;

  /// No description provided for @terminalNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines connected. Start the Happy CLI on a machine first.'**
  String get terminalNoMachines;

  /// No description provided for @terminalNoMachineConnected.
  ///
  /// In en, this message translates to:
  /// **'No machine is connected.'**
  String get terminalNoMachineConnected;

  /// No description provided for @terminalOutputTruncated.
  ///
  /// In en, this message translates to:
  /// **'Output was truncated by the machine.'**
  String get terminalOutputTruncated;

  /// No description provided for @terminalOutputTruncatedBytes.
  ///
  /// In en, this message translates to:
  /// **'Output was truncated by the machine ({size} total).'**
  String terminalOutputTruncatedBytes(String size);

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

  /// No description provided for @appearanceThemeBasedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Based on your device\'s {mode} appearance setting.'**
  String appearanceThemeBasedOnDevice(String mode);

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

  /// No description provided for @providersConnectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connected accounts'**
  String get providersConnectedAccounts;

  /// No description provided for @providersBuiltInLimits.
  ///
  /// In en, this message translates to:
  /// **'Built-in limits'**
  String get providersBuiltInLimits;

  /// No description provided for @providersAccountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No connected accounts} =1 {1 connected account} other {{count} connected accounts}}'**
  String providersAccountSummary(int count);

  /// No description provided for @providersAttentionSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {All usage checks are healthy} =1 {1 account needs attention} other {{count} accounts need attention}}'**
  String providersAttentionSummary(int count);

  /// No description provided for @providersUpdatingUsage.
  ///
  /// In en, this message translates to:
  /// **'Updating usage…'**
  String get providersUpdatingUsage;

  /// No description provided for @providersUsageStale.
  ///
  /// In en, this message translates to:
  /// **'Usage may be stale'**
  String get providersUsageStale;

  /// No description provided for @providersHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get providersHealthy;

  /// No description provided for @providersNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get providersNeedsAttention;

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

  /// No description provided for @providersRemoveAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove account'**
  String get providersRemoveAccountFailed;

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
  /// **'Add your Kimi, MiniMax, or Z.AI account to track usage.'**
  String get providersEmptySubtitle;

  /// No description provided for @providersNoUsageData.
  ///
  /// In en, this message translates to:
  /// **'No usage data available'**
  String get providersNoUsageData;

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

  /// No description provided for @providersZaiApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providersZaiApiKeyLabel;

  /// No description provided for @providersZaiApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your Z.AI console API key'**
  String get providersZaiApiKeyHint;

  /// No description provided for @providersZaiBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providersZaiBaseUrlLabel;

  /// No description provided for @providersZaiBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.z.ai'**
  String get providersZaiBaseUrlHint;

  /// No description provided for @providersGrokAccessTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get providersGrokAccessTokenLabel;

  /// No description provided for @providersGrokAccessTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the access_token from ~/.grok/auth.json'**
  String get providersGrokAccessTokenHint;

  /// No description provided for @providersGrokBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providersGrokBaseUrlLabel;

  /// No description provided for @providersGrokBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://cli-chat-proxy.grok.com/v1'**
  String get providersGrokBaseUrlHint;

  /// No description provided for @providersQwenApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providersQwenApiKeyLabel;

  /// No description provided for @providersQwenApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your Qwen Cloud API key (sk-sp-…)'**
  String get providersQwenApiKeyHint;

  /// No description provided for @providersQwenBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get providersQwenBaseUrlLabel;

  /// No description provided for @providersQwenBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://home.qwencloud.com'**
  String get providersQwenBaseUrlHint;

  /// No description provided for @providersNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'This provider is not yet supported.'**
  String get providersNotImplemented;

  /// No description provided for @providersRenameAccount.
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get providersRenameAccount;

  /// No description provided for @providersRenameAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename account'**
  String get providersRenameAccountFailed;

  /// No description provided for @providersResetsIn.
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String providersResetsIn(String time);

  /// No description provided for @loopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get loopsTitle;

  /// No description provided for @loopsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No loops scheduled'**
  String get loopsEmptyTitle;

  /// No description provided for @loopsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Type /loop in chat to schedule a recurring prompt.'**
  String get loopsEmptyDescription;

  /// No description provided for @allLoopsTitle.
  ///
  /// In en, this message translates to:
  /// **'All loops'**
  String get allLoopsTitle;

  /// No description provided for @allLoopsScheduledTab.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get allLoopsScheduledTab;

  /// No description provided for @allLoopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No active loops} =1{1 active loop} other{{count} active loops}}'**
  String allLoopsCount(int count);

  /// No description provided for @allLoopsPausedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 paused} =1{1 paused loop} other{{count} paused loops}}'**
  String allLoopsPausedCount(int count);

  /// No description provided for @allLoopsAcrossSessions.
  ///
  /// In en, this message translates to:
  /// **'across {count, plural, =1{1 session} other{{count} sessions}}'**
  String allLoopsAcrossSessions(int count);

  /// No description provided for @allLoopsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No loops scheduled'**
  String get allLoopsEmptyTitle;

  /// No description provided for @allLoopsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Type /loop in any session to schedule a recurring prompt.'**
  String get allLoopsEmptyDescription;

  /// No description provided for @allLoopsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allLoopsFilterAll;

  /// No description provided for @allLoopsNoActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'No active loops'**
  String get allLoopsNoActiveTitle;

  /// No description provided for @allLoopsNoActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Paused and expired loops are still available under All.'**
  String get allLoopsNoActiveDescription;

  /// No description provided for @allLoopsNoPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'No paused loops'**
  String get allLoopsNoPausedTitle;

  /// No description provided for @allLoopsNoPausedDescription.
  ///
  /// In en, this message translates to:
  /// **'Pause an active loop to keep it here without deleting it.'**
  String get allLoopsNoPausedDescription;

  /// No description provided for @allLoopsShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all loops'**
  String get allLoopsShowAll;

  /// No description provided for @allLoopsGroupLoopCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 loop} other{{count} loops}}'**
  String allLoopsGroupLoopCount(int count);

  /// No description provided for @allLoopsGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, {count, plural, =1{1 loop} other{{count} loops}}'**
  String allLoopsGroupLabel(String name, int count);

  /// No description provided for @allLoopsViewPerSession.
  ///
  /// In en, this message translates to:
  /// **'View per session'**
  String get allLoopsViewPerSession;

  /// No description provided for @loopsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New loop'**
  String get loopsCreateTitle;

  /// No description provided for @loopsIntervalLabel.
  ///
  /// In en, this message translates to:
  /// **'Cron expression'**
  String get loopsIntervalLabel;

  /// No description provided for @loopsIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. */5 * * * * — every 5 minutes'**
  String get loopsIntervalHint;

  /// No description provided for @loopsPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get loopsPromptLabel;

  /// No description provided for @loopsPromptHint.
  ///
  /// In en, this message translates to:
  /// **'What should Claude do each time?'**
  String get loopsPromptHint;

  /// No description provided for @loopsRecurringLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get loopsRecurringLabel;

  /// No description provided for @loopsCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get loopsCancelButton;

  /// No description provided for @loopsScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get loopsScheduleButton;

  /// No description provided for @loopsPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get loopsPauseButton;

  /// No description provided for @loopsResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get loopsResumeButton;

  /// No description provided for @loopsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get loopsDeleteButton;

  /// No description provided for @loopsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete loop'**
  String get loopsDeleteConfirmTitle;

  /// No description provided for @loopsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete loop {id}? This cannot be undone.'**
  String loopsDeleteConfirmMessage(String id);

  /// No description provided for @loopsFireCount.
  ///
  /// In en, this message translates to:
  /// **'Fired {count} times'**
  String loopsFireCount(int count);

  /// No description provided for @loopsLastFired.
  ///
  /// In en, this message translates to:
  /// **'Last fired {time}'**
  String loopsLastFired(String time);

  /// No description provided for @loopsNeverFired.
  ///
  /// In en, this message translates to:
  /// **'Never fired'**
  String get loopsNeverFired;

  /// No description provided for @loopsJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get loopsJustNow;

  /// No description provided for @loopsSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} seconds ago'**
  String loopsSecondsAgo(int n);

  /// No description provided for @loopsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} minutes ago'**
  String loopsMinutesAgo(int n);

  /// No description provided for @loopsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} hours ago'**
  String loopsHoursAgo(int n);

  /// No description provided for @loopsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String loopsDaysAgo(int n);

  /// No description provided for @loopsExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get loopsExpired;

  /// No description provided for @loopsExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours} hours'**
  String loopsExpiresInHours(int hours);

  /// No description provided for @loopsExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days'**
  String loopsExpiresInDays(int days);

  /// No description provided for @loopsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get loopsStatusActive;

  /// No description provided for @loopsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get loopsStatusPaused;

  /// No description provided for @loopsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get loopsStatusExpired;

  /// No description provided for @loopsScheduleEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {n} minutes'**
  String loopsScheduleEveryMinutes(String n);

  /// No description provided for @loopsScheduleEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every {n} hours'**
  String loopsScheduleEveryHours(String n);

  /// No description provided for @loopsScheduleDaily9am.
  ///
  /// In en, this message translates to:
  /// **'Daily at 9:00 AM'**
  String get loopsScheduleDaily9am;

  /// No description provided for @loopsAddLoop.
  ///
  /// In en, this message translates to:
  /// **'Add loop'**
  String get loopsAddLoop;

  /// No description provided for @loopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No loops} =1{1 loop} other{{count} loops}}'**
  String loopsCount(int count);

  /// No description provided for @loopsBadgeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 loop} other{{count} loops}}'**
  String loopsBadgeCount(int count);

  /// No description provided for @loopsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load loops'**
  String get loopsLoadFailed;

  /// No description provided for @loopsScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to schedule loop'**
  String get loopsScheduleFailed;

  /// No description provided for @loopsLoopScheduled.
  ///
  /// In en, this message translates to:
  /// **'Loop {id} scheduled'**
  String loopsLoopScheduled(String id);

  /// No description provided for @loopsLoopCancelled.
  ///
  /// In en, this message translates to:
  /// **'Loop {id} cancelled'**
  String loopsLoopCancelled(String id);

  /// No description provided for @loopsLoopCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel loop'**
  String get loopsLoopCancelFailed;

  /// No description provided for @loopsLoopPauseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pause loop'**
  String get loopsLoopPauseFailed;

  /// No description provided for @loopsLoopResumeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume loop'**
  String get loopsLoopResumeFailed;

  /// No description provided for @loopsValidationRequiredInterval.
  ///
  /// In en, this message translates to:
  /// **'Cron expression is required'**
  String get loopsValidationRequiredInterval;

  /// No description provided for @loopsValidationRequiredPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt is required'**
  String get loopsValidationRequiredPrompt;

  /// No description provided for @loopsValidationInvalidCron.
  ///
  /// In en, this message translates to:
  /// **'Cron expression is invalid (expected 5 fields)'**
  String get loopsValidationInvalidCron;

  /// Tooltip for the attach-image button in the chat composer
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get chatAttachImage;

  /// Option to pick an image from the photo library
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get chatAttachFromGallery;

  /// Option to take a photo with the camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatAttachFromCamera;

  /// Accessibility label for removing a staged image attachment
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatRemoveAttachment;

  /// No description provided for @chatAttachmentLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} images per message'**
  String chatAttachmentLimit(int max);

  /// Error shown when a selected image cannot be normalized for sending
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add that image. Please try a JPEG or PNG under 5 MB'**
  String get chatImageAddFailed;

  /// Error shown when combined image attachments exceed the message size limit
  ///
  /// In en, this message translates to:
  /// **'Those images are too large to send together. Remove one and try again'**
  String get chatImagePayloadTooLarge;

  /// Placeholder shown for an image whose data was stripped from the offline cache
  ///
  /// In en, this message translates to:
  /// **'Image (not available offline)'**
  String get chatImageNotCached;

  /// Generic refresh action label
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Generic overflow-menu tooltip
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// Label shown on a save button while the write is in flight
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// Settings row opening remote MCP server management
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get settingsMcpServers;

  /// Subtitle for the MCP servers settings row
  ///
  /// In en, this message translates to:
  /// **'Manage Claude Code MCP servers on your machines'**
  String get settingsMcpServersSubtitle;

  /// Title of the MCP server management screen
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get mcpServersTitle;

  /// Action that opens the new-MCP-server form
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get mcpAddServer;

  /// No description provided for @mcpEnableTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable {name}?'**
  String mcpEnableTrustTitle(String name);

  /// No description provided for @mcpEnableTrustBody.
  ///
  /// In en, this message translates to:
  /// **'Review this server before allowing it to provide tools to the agent.\n\nTarget: {target}\nScope: {scope}\nProject: {project}\nSecret names: {secrets}'**
  String mcpEnableTrustBody(
    String target,
    String scope,
    String project,
    String secrets,
  );

  /// No description provided for @mcpEnableServer.
  ///
  /// In en, this message translates to:
  /// **'Enable server'**
  String get mcpEnableServer;

  /// No description provided for @mcpEnabledWithUndo.
  ///
  /// In en, this message translates to:
  /// **'MCP server enabled'**
  String get mcpEnabledWithUndo;

  /// No description provided for @mcpNoProject.
  ///
  /// In en, this message translates to:
  /// **'All projects in this scope'**
  String get mcpNoProject;

  /// No description provided for @mcpNoSecrets.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get mcpNoSecrets;

  /// Title of the MCP server edit form
  ///
  /// In en, this message translates to:
  /// **'Edit MCP server'**
  String get mcpEditTitle;

  /// Section title for the machine picker
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get mcpMachineSection;

  /// Section title for the project directory picker
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get mcpProjectSection;

  /// Helper text under the project picker
  ///
  /// In en, this message translates to:
  /// **'Choose a project to also manage its project-scoped servers.'**
  String get mcpProjectHelper;

  /// Project picker option meaning no project selected
  ///
  /// In en, this message translates to:
  /// **'All machines scopes only'**
  String get mcpProjectNone;

  /// Validation error when a project scope has no directory
  ///
  /// In en, this message translates to:
  /// **'Select a project directory for this scope'**
  String get mcpProjectRequired;

  /// Empty state title when the machine declares no MCP servers
  ///
  /// In en, this message translates to:
  /// **'No MCP servers'**
  String get mcpNoServersTitle;

  /// Empty state subtitle for MCP servers
  ///
  /// In en, this message translates to:
  /// **'Add a server to make new tools available to Claude Code on this machine.'**
  String get mcpNoServersSubtitle;

  /// Error shown when the mcp-set RPC fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the MCP server'**
  String get mcpSaveFailed;

  /// Error shown when toggling a server fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change {name}'**
  String mcpToggleFailed(String name);

  /// Title of the MCP server delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete MCP server'**
  String get mcpDeleteTitle;

  /// Body of the MCP server delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the {scope} scope on this machine?'**
  String mcpDeleteConfirm(String name, String scope);

  /// Error shown when deleting a server fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete {name}'**
  String mcpDeleteFailed(String name);

  /// Label for the user MCP scope
  ///
  /// In en, this message translates to:
  /// **'User — ~/.claude.json'**
  String get mcpScopeUser;

  /// Label for the user-settings MCP scope
  ///
  /// In en, this message translates to:
  /// **'User settings — ~/.claude/settings.json'**
  String get mcpScopeUserSettings;

  /// Label for the local MCP scope
  ///
  /// In en, this message translates to:
  /// **'Project (private) — ~/.claude.json'**
  String get mcpScopeLocal;

  /// Label for the project MCP scope
  ///
  /// In en, this message translates to:
  /// **'Project (shared) — .mcp.json'**
  String get mcpScopeProject;

  /// Label for the project-settings MCP scope
  ///
  /// In en, this message translates to:
  /// **'Project settings — .claude/settings.json'**
  String get mcpScopeProjectSettings;

  /// Label for the local-settings MCP scope
  ///
  /// In en, this message translates to:
  /// **'Project settings (local) — .claude/settings.local.json'**
  String get mcpScopeLocalSettings;

  /// Helper text under the scope picker
  ///
  /// In en, this message translates to:
  /// **'Scope decides which file on the machine the server is written to.'**
  String get mcpScopeHelper;

  /// Badge shown when a server requires an interactive login
  ///
  /// In en, this message translates to:
  /// **'Needs auth'**
  String get mcpBadgeNeedsAuth;

  /// Badge shown when a higher-priority scope declares the same server name
  ///
  /// In en, this message translates to:
  /// **'Shadowed'**
  String get mcpBadgeShadowed;

  /// Badge shown for a shared .mcp.json server that has not been approved
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get mcpBadgeAwaitingApproval;

  /// Header for the list of Claude config file paths
  ///
  /// In en, this message translates to:
  /// **'Configuration files'**
  String get mcpSourceFiles;

  /// Note shown when enableAllProjectMcpServers is set
  ///
  /// In en, this message translates to:
  /// **'Shared project servers are auto-approved on this machine.'**
  String get mcpApproveAllEnabled;

  /// Section title for the name and scope fields
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get mcpIdentitySection;

  /// Section title for the transport selector
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mcpTransportSection;

  /// Section title for stdio command fields
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get mcpProcessSection;

  /// Section title for URL-based transport fields
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get mcpEndpointSection;

  /// Label for the MCP server name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mcpFieldName;

  /// Label for the MCP server scope field
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get mcpFieldScope;

  /// Label for the MCP server project directory field
  ///
  /// In en, this message translates to:
  /// **'Project directory'**
  String get mcpFieldProject;

  /// Label for the stdio command field
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpFieldCommand;

  /// Label for the stdio arguments field
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get mcpFieldArgs;

  /// Label for the stdio environment field
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get mcpFieldEnv;

  /// Label for the remote endpoint URL field
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get mcpFieldUrl;

  /// Label for the remote endpoint headers field
  ///
  /// In en, this message translates to:
  /// **'Headers'**
  String get mcpFieldHeaders;

  /// Helper text for the MCP server name field
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, spaces, dot, dash, underscore.'**
  String get mcpNameHelper;

  /// Helper text explaining why name and scope are locked while editing
  ///
  /// In en, this message translates to:
  /// **'Name and scope identify the server and cannot be changed. Delete and re-add to move it.'**
  String get mcpNameLockedHelper;

  /// Validation error for an empty MCP server name
  ///
  /// In en, this message translates to:
  /// **'Enter a server name'**
  String get mcpNameRequired;

  /// Validation error for an invalid MCP server name
  ///
  /// In en, this message translates to:
  /// **'Use only letters, numbers, spaces, dot, dash, underscore'**
  String get mcpNameInvalid;

  /// Helper text for the stdio command field
  ///
  /// In en, this message translates to:
  /// **'Executable to run, e.g. npx or an absolute path.'**
  String get mcpCommandHelper;

  /// Validation error for an empty stdio command
  ///
  /// In en, this message translates to:
  /// **'Enter a command'**
  String get mcpCommandRequired;

  /// Helper text for the stdio arguments field
  ///
  /// In en, this message translates to:
  /// **'One argument per line.'**
  String get mcpArgsHelper;

  /// Helper text for the stdio environment field
  ///
  /// In en, this message translates to:
  /// **'Values stay masked. Add, replace, or remove environment variables.'**
  String get mcpEnvHelper;

  /// Helper text for the headers field
  ///
  /// In en, this message translates to:
  /// **'Values stay masked. Add, replace, or remove request headers.'**
  String get mcpHeadersHelper;

  /// Button to add a masked MCP environment variable or header
  ///
  /// In en, this message translates to:
  /// **'Add secret'**
  String get mcpSecretAdd;

  /// Button to replace a stored MCP secret value
  ///
  /// In en, this message translates to:
  /// **'Replace secret'**
  String get mcpSecretReplace;

  /// Field label for an MCP environment variable or header name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mcpSecretKey;

  /// Validation error for an empty MCP secret key
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get mcpSecretKeyRequired;

  /// Validation error for a duplicate MCP secret key
  ///
  /// In en, this message translates to:
  /// **'That name already exists'**
  String get mcpSecretKeyExists;

  /// Masked value field for an MCP environment variable or header
  ///
  /// In en, this message translates to:
  /// **'New value'**
  String get mcpSecretValue;

  /// Validation error for an empty MCP secret value
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get mcpSecretValueRequired;

  /// Status for an MCP secret that will be replaced on save
  ///
  /// In en, this message translates to:
  /// **'Replacement ready'**
  String get mcpSecretReplacementReady;

  /// Presence-only status for a stored MCP secret
  ///
  /// In en, this message translates to:
  /// **'Stored securely'**
  String get mcpSecretStored;

  /// Button to delete an MCP environment variable or header
  ///
  /// In en, this message translates to:
  /// **'Remove secret'**
  String get mcpSecretRemove;

  /// Validation error for an empty endpoint URL
  ///
  /// In en, this message translates to:
  /// **'Enter a URL'**
  String get mcpUrlRequired;

  /// Validation error for a malformed endpoint URL
  ///
  /// In en, this message translates to:
  /// **'Enter a full URL including https://'**
  String get mcpUrlInvalid;

  /// Title of the per-project sandbox screen
  ///
  /// In en, this message translates to:
  /// **'Sandbox'**
  String get sandboxTitle;

  /// Section title for the machine picker on the sandbox screen
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get sandboxMachineSection;

  /// Section title for the project picker on the sandbox screen
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get sandboxProjectSection;

  /// Shown when the machine cannot run sandboxed sessions
  ///
  /// In en, this message translates to:
  /// **'Sandboxing unavailable'**
  String get sandboxUnavailableTitle;

  /// Shown when the machine config opted out of sandboxing
  ///
  /// In en, this message translates to:
  /// **'Sandboxing is turned off for this machine. Sessions run with full access to the file system.'**
  String get sandboxMachineDisabled;

  /// Explains what the sandbox does
  ///
  /// In en, this message translates to:
  /// **'Sandboxed sessions see this project directory and the public internet. Everything else on the machine — your home directory, SSH keys, other projects — is not there.'**
  String get sandboxExplainer;

  /// Label of the per-project sandbox switch
  ///
  /// In en, this message translates to:
  /// **'Sandbox this project'**
  String get sandboxEnabledForProject;

  /// Subtitle when a project has no explicit sandbox choice
  ///
  /// In en, this message translates to:
  /// **'Following the machine default'**
  String get sandboxFollowsMachine;

  /// Section title for the granted folders list
  ///
  /// In en, this message translates to:
  /// **'Extra folders'**
  String get sandboxFoldersSection;

  /// Empty state title for granted folders
  ///
  /// In en, this message translates to:
  /// **'No extra folders'**
  String get sandboxNoFolders;

  /// Empty state subtitle for granted folders
  ///
  /// In en, this message translates to:
  /// **'Sessions can only reach the project directory itself. Add a folder if this project needs one.'**
  String get sandboxNoFoldersSubtitle;

  /// Button that grants another folder to the project
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get sandboxAddFolder;

  /// Label of the folder path field
  ///
  /// In en, this message translates to:
  /// **'Absolute path'**
  String get sandboxFolderPath;

  /// Hint for the folder path field
  ///
  /// In en, this message translates to:
  /// **'/home/you/go/pkg/mod'**
  String get sandboxFolderPathHint;

  /// Validation error for an empty or relative folder path
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute path'**
  String get sandboxFolderPathRequired;

  /// Grant mode label
  ///
  /// In en, this message translates to:
  /// **'Read and write'**
  String get sandboxModeReadWrite;

  /// Grant mode label
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get sandboxModeReadOnly;

  /// Tooltip for removing a granted folder
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get sandboxRemoveFolder;

  /// Confirmation body when revoking a folder
  ///
  /// In en, this message translates to:
  /// **'Sessions in this project will no longer reach {path}.'**
  String sandboxRemoveFolderConfirm(String path);

  /// Fallback error when a sandbox write fails
  ///
  /// In en, this message translates to:
  /// **'Could not save the sandbox policy'**
  String get sandboxSaveFailed;

  /// Describes the public egress mode
  ///
  /// In en, this message translates to:
  /// **'Network: public internet only — the local network, other machines and localhost are refused.'**
  String get sandboxNetworkPublic;

  /// Describes the allowlist egress mode
  ///
  /// In en, this message translates to:
  /// **'Network: only the hosts allowed below.'**
  String get sandboxNetworkAllowlist;

  /// Describes the disabled egress mode
  ///
  /// In en, this message translates to:
  /// **'Network: no egress at all.'**
  String get sandboxNetworkNone;

  /// Settings row opening per-project sandbox management
  ///
  /// In en, this message translates to:
  /// **'Sandbox'**
  String get settingsSandbox;

  /// Subtitle for the sandbox settings row
  ///
  /// In en, this message translates to:
  /// **'Choose what a project\'s sessions can reach on your machines'**
  String get settingsSandboxSubtitle;

  /// Fallback reason shown when no online machine reports sandbox support
  ///
  /// In en, this message translates to:
  /// **'Connect or update a machine daemon that supports sandboxing'**
  String get settingsSandboxUnavailable;

  /// Session card activity line while a tool is executing
  ///
  /// In en, this message translates to:
  /// **'Running {tool}'**
  String sessionActivityRunningTool(String tool);

  /// Session card activity line for a pending tool permission
  ///
  /// In en, this message translates to:
  /// **'{tool} needs approval'**
  String sessionActivityToolApproval(String tool);

  /// Session card activity line while the agent is thinking
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get sessionActivityWorking;

  /// Badge on a session card whose auto-archive is due
  ///
  /// In en, this message translates to:
  /// **'Archive pending'**
  String get sessionsArchivePending;

  /// Badge for an auto-archive less than a minute away
  ///
  /// In en, this message translates to:
  /// **'Archives in <1m'**
  String get sessionsArchivesSoon;

  /// Badge counting down the minutes to auto-archive
  ///
  /// In en, this message translates to:
  /// **'Archives in {minutes}m'**
  String sessionsArchivesInMinutes(int minutes);

  /// Fallback title of the full-screen code reader
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeBlockTitle;

  /// Tooltip for the code block full-screen button
  ///
  /// In en, this message translates to:
  /// **'Open full screen'**
  String get codeBlockOpenFullScreen;

  /// Tooltip for enabling soft wrapping in code blocks
  ///
  /// In en, this message translates to:
  /// **'Wrap long lines'**
  String get codeBlockEnableWrap;

  /// Tooltip for switching code blocks back to horizontal scrolling
  ///
  /// In en, this message translates to:
  /// **'Scroll long lines'**
  String get codeBlockDisableWrap;

  /// Tappable footer opening the full-screen reader for clipped code
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 more line} other{Show {count} more lines}}'**
  String codeBlockShowAllLines(int count);

  /// Non-interactive notice that code lines were clipped
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more line} other{{count} more lines}}'**
  String codeBlockHiddenLines(int count);

  /// Notice that a very large code block was truncated
  ///
  /// In en, this message translates to:
  /// **'Showing {displayed} of {total} characters'**
  String codeBlockTruncated(int displayed, int total);

  /// Tooltip for a button that dismisses a banner or notice
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Tooltip for a button that dismisses an inline error message
  ///
  /// In en, this message translates to:
  /// **'Dismiss error'**
  String get commonDismissError;

  /// Tooltip for the button that clears the search field
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// Tooltip for copying the FCM push token in dev tools
  ///
  /// In en, this message translates to:
  /// **'Copy push token'**
  String get devCopyPushToken;

  /// Tooltip for the button that duplicates a profile
  ///
  /// In en, this message translates to:
  /// **'Duplicate Profile'**
  String get profilesDuplicateProfile;

  /// Tooltip for revealing the obscured API key field
  ///
  /// In en, this message translates to:
  /// **'Show API key'**
  String get profilesShowApiKey;

  /// Tooltip for obscuring the API key field
  ///
  /// In en, this message translates to:
  /// **'Hide API key'**
  String get profilesHideApiKey;

  /// Tooltip for the button that clears the server URL field
  ///
  /// In en, this message translates to:
  /// **'Clear server URL'**
  String get serverUrlClear;

  /// Tooltip for navigating up to the parent SFTP folder
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get sftpParentFolder;

  /// Tooltip for copying the agent's thinking block text
  ///
  /// In en, this message translates to:
  /// **'Copy thinking'**
  String get chatCopyThinking;

  /// Tooltip and semantics label for the scroll-to-bottom pill
  ///
  /// In en, this message translates to:
  /// **'Scroll to latest message'**
  String get chatScrollToLatest;

  /// Tooltip for the checkbox that marks a task complete
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get tasksMarkComplete;

  /// Tooltip for the checkbox that marks a task incomplete
  ///
  /// In en, this message translates to:
  /// **'Mark incomplete'**
  String get tasksMarkIncomplete;

  /// Title of the cross-session tasks screen
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// Empty-state title on the tasks screen
  ///
  /// In en, this message translates to:
  /// **'No active tasks'**
  String get tasksEmptyTitle;

  /// Empty-state explanation on the tasks screen
  ///
  /// In en, this message translates to:
  /// **'Tasks from your sessions will appear here, grouped by priority.'**
  String get tasksEmptySubtitle;

  /// Critical task priority label
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get tasksPriorityCritical;

  /// High task priority label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tasksPriorityHigh;

  /// Medium task priority label
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tasksPriorityMedium;

  /// Low task priority label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tasksPriorityLow;

  /// No description provided for @artifactsSourceSessions.
  ///
  /// In en, this message translates to:
  /// **'Source sessions'**
  String get artifactsSourceSessions;

  /// No description provided for @artifactsSourceSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the conversations that produced or updated this artifact.'**
  String get artifactsSourceSessionsSubtitle;

  /// No description provided for @workflowRefreshWarning.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing saved progress.'**
  String get workflowRefreshWarning;

  /// No description provided for @workflowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Workflows'**
  String get workflowsTitle;

  /// No description provided for @workflowsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 workflow} other{{count} workflows}}'**
  String workflowsCount(int count);

  /// No description provided for @workflowsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Workflows unavailable'**
  String get workflowsUnavailableTitle;

  /// No description provided for @workflowsUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This machine does not support workflow history yet. Update the Happy CLI to use it.'**
  String get workflowsUnavailableSubtitle;

  /// No description provided for @workflowsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No workflows yet'**
  String get workflowsEmptyTitle;

  /// No description provided for @workflowsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Workflow runs will appear here when an agent starts one.'**
  String get workflowsEmptySubtitle;

  /// No description provided for @workflowsLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load workflows'**
  String get workflowsLoadFailedTitle;

  /// No description provided for @workflowLoadFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'Workflow data is unavailable right now. Try again.'**
  String get workflowLoadFailedSafe;

  /// No description provided for @workflowNotFoundSafe.
  ///
  /// In en, this message translates to:
  /// **'This workflow run is unavailable.'**
  String get workflowNotFoundSafe;

  /// No description provided for @workflowRunFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'This workflow run failed unexpectedly.'**
  String get workflowRunFailedSafe;

  /// No description provided for @workflowAgentFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'This agent step failed unexpectedly.'**
  String get workflowAgentFailedSafe;

  /// No description provided for @workflowErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get workflowErrorTitle;

  /// No description provided for @workflowTitle.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get workflowTitle;

  /// No description provided for @connectionDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection diagnostics'**
  String get connectionDiagnosticsTitle;

  /// No description provided for @connectionDiagnosticsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get connectionDiagnosticsNetwork;

  /// No description provided for @connectionDiagnosticsLiveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Live updates'**
  String get connectionDiagnosticsLiveUpdates;

  /// No description provided for @connectionDiagnosticsLastDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Last disconnect'**
  String get connectionDiagnosticsLastDisconnect;

  /// No description provided for @connectionDiagnosticsNoDisconnect.
  ///
  /// In en, this message translates to:
  /// **'No disconnect recorded'**
  String get connectionDiagnosticsNoDisconnect;

  /// No description provided for @connectionDiagnosticsDisconnectedFor.
  ///
  /// In en, this message translates to:
  /// **'Disconnected for'**
  String get connectionDiagnosticsDisconnectedFor;

  /// No description provided for @connectionDiagnosticsReconnectAttempt.
  ///
  /// In en, this message translates to:
  /// **'Reconnect attempt'**
  String get connectionDiagnosticsReconnectAttempt;

  /// No description provided for @connectionDiagnosticsService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get connectionDiagnosticsService;

  /// No description provided for @connectionDiagnosticsCheckingService.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get connectionDiagnosticsCheckingService;

  /// No description provided for @connectionDiagnosticsServiceDegradedSafe.
  ///
  /// In en, this message translates to:
  /// **'Some services are degraded'**
  String get connectionDiagnosticsServiceDegradedSafe;

  /// No description provided for @connectionDiagnosticsServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get connectionDiagnosticsServiceUnavailable;

  /// No description provided for @connectionDiagnosticsAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get connectionDiagnosticsAuthenticationRequired;

  /// No description provided for @connectionDiagnosticsTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get connectionDiagnosticsTimedOut;

  /// No description provided for @connectionDiagnosticsConnectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Connection closed'**
  String get connectionDiagnosticsConnectionClosed;

  /// No description provided for @connectionDiagnosticsElapsedSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 second} other {{count} seconds}}'**
  String connectionDiagnosticsElapsedSeconds(int count);

  /// No description provided for @connectionDiagnosticsElapsedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 minute} other {{count} minutes}}'**
  String connectionDiagnosticsElapsedMinutes(int count);

  /// No description provided for @connectionDiagnosticsElapsedHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1 {1 hour} other {{hours} hours}} {minutes, plural, =0 {} =1 {1 minute} other {{minutes} minutes}}'**
  String connectionDiagnosticsElapsedHoursMinutes(int hours, int minutes);

  /// No description provided for @settingsHealthStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get settingsHealthStatus;

  /// No description provided for @settingsHealthSyncReady.
  ///
  /// In en, this message translates to:
  /// **'Sync ready'**
  String get settingsHealthSyncReady;

  /// No description provided for @settingsHealthSyncAttention.
  ///
  /// In en, this message translates to:
  /// **'Sync needs attention'**
  String get settingsHealthSyncAttention;

  /// No description provided for @settingsHealthApplyingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Connected and applying the latest updates'**
  String get settingsHealthApplyingUpdates;

  /// No description provided for @settingsHealthReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for sessions, messages, and settings updates'**
  String get settingsHealthReady;

  /// No description provided for @settingsHealthOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline. Updates will resume when the network returns'**
  String get settingsHealthOffline;

  /// No description provided for @settingsHealthLoading.
  ///
  /// In en, this message translates to:
  /// **'Connected, waiting for initial data to finish loading'**
  String get settingsHealthLoading;

  /// No description provided for @settingsHealthReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to live updates'**
  String get settingsHealthReconnecting;

  /// No description provided for @settingsHealthNoMachines.
  ///
  /// In en, this message translates to:
  /// **'No machines linked yet'**
  String get settingsHealthNoMachines;

  /// No description provided for @settingsHealthMachinesOnline.
  ///
  /// In en, this message translates to:
  /// **'{online} online of {total} linked'**
  String settingsHealthMachinesOnline(int online, int total);

  /// No description provided for @settingsHealthSessionsOnline.
  ///
  /// In en, this message translates to:
  /// **'{online} online of {total} total'**
  String settingsHealthSessionsOnline(int online, int total);

  /// No description provided for @settingsHealthAccountRecovery.
  ///
  /// In en, this message translates to:
  /// **'Account and recovery'**
  String get settingsHealthAccountRecovery;

  /// No description provided for @settingsHealthAccountRecoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup key, linked devices, restore, and services'**
  String get settingsHealthAccountRecoverySubtitle;

  /// No description provided for @settingsHealthSocketGeneration.
  ///
  /// In en, this message translates to:
  /// **'Socket generation'**
  String get settingsHealthSocketGeneration;

  /// No description provided for @settingsHealthLastSocketEvent.
  ///
  /// In en, this message translates to:
  /// **'Last socket event age'**
  String get settingsHealthLastSocketEvent;

  /// No description provided for @settingsHealthNoSocketEvent.
  ///
  /// In en, this message translates to:
  /// **'No event recorded'**
  String get settingsHealthNoSocketEvent;

  /// No description provided for @settingsHealthOutbox.
  ///
  /// In en, this message translates to:
  /// **'Message outbox'**
  String get settingsHealthOutbox;

  /// No description provided for @settingsHealthOutboxCounts.
  ///
  /// In en, this message translates to:
  /// **'{pending} pending, {failed} failed'**
  String settingsHealthOutboxCounts(int pending, int failed);

  /// No description provided for @settingsHealthSyncDomains.
  ///
  /// In en, this message translates to:
  /// **'Sync domains'**
  String get settingsHealthSyncDomains;

  /// No description provided for @settingsHealthCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get settingsHealthCopyDiagnostics;

  /// No description provided for @settingsHealthDomainSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get settingsHealthDomainSessions;

  /// No description provided for @settingsHealthDomainMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get settingsHealthDomainMessages;

  /// No description provided for @settingsHealthDomainMachines.
  ///
  /// In en, this message translates to:
  /// **'Machines'**
  String get settingsHealthDomainMachines;

  /// No description provided for @settingsHealthDomainSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsHealthDomainSettings;

  /// No description provided for @settingsHealthDomainProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsHealthDomainProfile;

  /// No description provided for @settingsHealthDomainArtifacts.
  ///
  /// In en, this message translates to:
  /// **'Artifacts'**
  String get settingsHealthDomainArtifacts;

  /// No description provided for @settingsHealthDomainGitStatus.
  ///
  /// In en, this message translates to:
  /// **'Git status'**
  String get settingsHealthDomainGitStatus;

  /// No description provided for @settingsHealthDomainFriendRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get settingsHealthDomainFriendRequests;

  /// No description provided for @settingsHealthDomainLoops.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get settingsHealthDomainLoops;

  /// No description provided for @settingsHealthDomainWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Workflows'**
  String get settingsHealthDomainWorkflows;

  /// No description provided for @settingsHealthDomainSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing now'**
  String get settingsHealthDomainSyncing;

  /// No description provided for @settingsHealthDomainQueued.
  ///
  /// In en, this message translates to:
  /// **'Update queued'**
  String get settingsHealthDomainQueued;

  /// No description provided for @settingsHealthDomainNoFreshness.
  ///
  /// In en, this message translates to:
  /// **'No completed refresh recorded'**
  String get settingsHealthDomainNoFreshness;

  /// No description provided for @settingsHealthDomainFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String settingsHealthDomainFailed(String reason);

  /// No description provided for @settingsHealthDomainUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {elapsed} ago'**
  String settingsHealthDomainUpdated(String elapsed);

  /// No description provided for @settingsHealthDomainState.
  ///
  /// In en, this message translates to:
  /// **'{state} · revision {revision}'**
  String settingsHealthDomainState(String state, int revision);

  /// No description provided for @settingsHealthFailureDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Encrypted data could not be read'**
  String get settingsHealthFailureDecrypt;

  /// No description provided for @settingsHealthFailureInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Refresh was interrupted'**
  String get settingsHealthFailureInterrupted;

  /// No description provided for @settingsHealthFailureInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Invalid response data'**
  String get settingsHealthFailureInvalidData;

  /// No description provided for @remoteFeatureErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'The selected machine is offline.'**
  String get remoteFeatureErrorOffline;

  /// No description provided for @remoteFeatureErrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This feature requires a newer Happy daemon.'**
  String get remoteFeatureErrorUnsupported;

  /// No description provided for @remoteFeatureErrorTemporary.
  ///
  /// In en, this message translates to:
  /// **'The machine could not complete the request. Try again.'**
  String get remoteFeatureErrorTemporary;

  /// No description provided for @remoteFeatureErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'The machine rejected the request. Check the values and try again.'**
  String get remoteFeatureErrorRejected;

  /// No description provided for @remoteFeatureErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The request could not be completed.'**
  String get remoteFeatureErrorUnknown;

  /// No description provided for @accountRevealBackupKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reveal backup key?'**
  String get accountRevealBackupKeyTitle;

  /// No description provided for @accountRevealBackupKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone who sees this key can access your account. Make sure nobody can see your screen.'**
  String get accountRevealBackupKeyWarning;

  /// No description provided for @accountRevealAction.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get accountRevealAction;

  /// No description provided for @accountCopyBackupKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy backup key?'**
  String get accountCopyBackupKeyTitle;

  /// No description provided for @accountCopyBackupKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'The key grants full account access. It will be cleared from the clipboard after 60 seconds.'**
  String get accountCopyBackupKeyWarning;

  /// No description provided for @accountCopyKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get accountCopyKeyAction;

  /// No description provided for @accountClipboardExpiry.
  ///
  /// In en, this message translates to:
  /// **'Clipboard clears in 60s.'**
  String get accountClipboardExpiry;

  /// No description provided for @accountSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch account?'**
  String get accountSwitchTitle;

  /// No description provided for @accountSwitchWarning.
  ///
  /// In en, this message translates to:
  /// **'This will replace the account on this device with account {fingerprint}. Unsaved drafts and pending sends may not carry over.'**
  String accountSwitchWarning(String fingerprint);

  /// No description provided for @accountSwitchAction.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get accountSwitchAction;

  /// No description provided for @accountShowBackupKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Show backup key'**
  String get accountShowBackupKeyAction;

  /// No description provided for @accountHideBackupKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Hide backup key'**
  String get accountHideBackupKeyAction;

  /// No description provided for @accountRestoreServiceError.
  ///
  /// In en, this message translates to:
  /// **'The restore service could not complete the request.'**
  String get accountRestoreServiceError;

  /// No description provided for @accountRestoreRejectedCode.
  ///
  /// In en, this message translates to:
  /// **'The restore service rejected the key (code {code}).'**
  String accountRestoreRejectedCode(int code);

  /// No description provided for @accountRestoreGenericError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the account. Check your connection and try again.'**
  String get accountRestoreGenericError;

  /// Accessibility label for opening the session that owns a task
  ///
  /// In en, this message translates to:
  /// **'{task}, from {session}. Open session'**
  String tasksOpenSession(String task, String session);

  /// Title of the goal loops screen
  ///
  /// In en, this message translates to:
  /// **'Goal loops'**
  String get goalLoopsTitle;

  /// FAB label to start a goal loop
  ///
  /// In en, this message translates to:
  /// **'New goal loop'**
  String get goalLoopsNewButton;

  /// Title of the create goal loop sheet
  ///
  /// In en, this message translates to:
  /// **'Start a goal loop'**
  String get goalLoopsCreateTitle;

  /// Explains what a goal loop does
  ///
  /// In en, this message translates to:
  /// **'The agent works towards the goal in repeated sessions, each starting with an empty context, until it reports the goal reached.'**
  String get goalLoopsCreateSubtitle;

  /// Label for the goal text field
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalLoopsGoalLabel;

  /// Example goal
  ///
  /// In en, this message translates to:
  /// **'Get the integration test suite passing on CI'**
  String get goalLoopsGoalHint;

  /// Guidance for writing a good goal
  ///
  /// In en, this message translates to:
  /// **'Say what \"done\" means. A goal the agent can check for itself is one it can stop on.'**
  String get goalLoopsGoalHelper;

  /// Helper under the directory field
  ///
  /// In en, this message translates to:
  /// **'Each iteration runs here and keeps its notes in the progress file.'**
  String get goalLoopsDirectoryHelper;

  /// Toggle for optional goal loop settings
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get goalLoopsAdvanced;

  /// Label for the goal loop model field
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get goalLoopsModelLabel;

  /// Examples of goal loop model selections
  ///
  /// In en, this message translates to:
  /// **'opus:max or gpt-5.5:high'**
  String get goalLoopsModelHint;

  /// Helper under the goal loop model field
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the agent\'s default model. The same model is used for every iteration.'**
  String get goalLoopsModelHelper;

  /// Iteration cap slider label
  ///
  /// In en, this message translates to:
  /// **'Stop after {count} iterations'**
  String goalLoopsMaxIterations(int count);

  /// Helper under the iteration cap slider
  ///
  /// In en, this message translates to:
  /// **'A safety net for a goal that can never be reached. The loop normally stops on its own well before this.'**
  String get goalLoopsMaxIterationsHelper;

  /// Label for the progress file field
  ///
  /// In en, this message translates to:
  /// **'Progress file'**
  String get goalLoopsProgressFileLabel;

  /// Helper under the progress file field
  ///
  /// In en, this message translates to:
  /// **'The loop\'s only memory between iterations. Created for you if it does not exist.'**
  String get goalLoopsProgressFileHelper;

  /// Label for per-iteration extra instructions
  ///
  /// In en, this message translates to:
  /// **'Extra instructions'**
  String get goalLoopsInstructionsLabel;

  /// Example extra instructions
  ///
  /// In en, this message translates to:
  /// **'Never push to main. Run mise run test before claiming anything passes.'**
  String get goalLoopsInstructionsHint;

  /// Helper for extra instructions
  ///
  /// In en, this message translates to:
  /// **'Added to every iteration\'s prompt.'**
  String get goalLoopsInstructionsHelper;

  /// Submit button of the create goal loop sheet
  ///
  /// In en, this message translates to:
  /// **'Start loop'**
  String get goalLoopsStartButton;

  /// Section header for loops still iterating
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get goalLoopsActiveSection;

  /// Section header for loops that ended
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get goalLoopsFinishedSection;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No goal loops'**
  String get goalLoopsEmptyTitle;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'A goal loop keeps restarting an agent with a fresh context until its goal is reached.'**
  String get goalLoopsEmptyMessage;

  /// Iteration counter under the progress bar
  ///
  /// In en, this message translates to:
  /// **'{done} of {max} iterations'**
  String goalLoopsIterationProgress(int done, int max);

  /// Shown while an iteration is in flight
  ///
  /// In en, this message translates to:
  /// **'Working now'**
  String get goalLoopsIterating;

  /// Opens the session of the current or last iteration
  ///
  /// In en, this message translates to:
  /// **'Open session'**
  String get goalLoopsOpenSession;

  /// Restarts a loop that stopped
  ///
  /// In en, this message translates to:
  /// **'Resume loop'**
  String get goalLoopsResumeButton;

  /// Delete confirmation body for a goal loop
  ///
  /// In en, this message translates to:
  /// **'Delete this goal loop? The progress file is left on disk.'**
  String get goalLoopsDeleteConfirmMessage;

  /// Status chip: still iterating
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get goalLoopsStatusRunning;

  /// Status chip: goal reached
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get goalLoopsStatusComplete;

  /// Status chip: blocked on a human
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get goalLoopsStatusBlocked;

  /// Status chip: iterations stopped changing anything
  ///
  /// In en, this message translates to:
  /// **'Stalled'**
  String get goalLoopsStatusStalled;

  /// Status chip: hit the iteration cap
  ///
  /// In en, this message translates to:
  /// **'Out of iterations'**
  String get goalLoopsStatusExhausted;
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
