// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Happy';

  @override
  String get appSubtitle => 'Mobile client for Claude Code & Codex';

  @override
  String get appVersion => 'Version';

  @override
  String get appLoading => 'Loading...';

  @override
  String get appRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveAs => 'Save As';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonLogout => 'Logout';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonScanning => 'Scanning...';

  @override
  String get commonUrlPlaceholder => 'https://example.com';

  @override
  String get commonHome => 'Home';

  @override
  String get commonMessage => 'Message';

  @override
  String get commonFiles => 'Files';

  @override
  String get commonFileViewer => 'File Viewer';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String get commonDeleteConfirmMessage =>
      'Are you sure you want to delete this?';

  @override
  String get tabsSessions => 'Terminals';

  @override
  String get tabsSettings => 'Settings';

  @override
  String statusConnected(String time) {
    return 'Connected';
  }

  @override
  String get statusConnecting => 'Connecting';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusError => 'Error';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusActiveNow => 'Active now';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get statusPermissionRequired => 'Permission required';

  @override
  String statusLastSeen(Object time) {
    return 'Last seen $time';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get authTitle => 'Authenticate';

  @override
  String get authAccessDenied => 'Access denied';

  @override
  String get authAuthenticationFailed => 'Authentication failed';

  @override
  String get authEnterSecretKey => 'Please enter a secret key';

  @override
  String get authInvalidSecretKey =>
      'Invalid secret key. Please check and try again.';

  @override
  String get authRestoreAccount => 'Restore Account';

  @override
  String get authEnterUrlManually => 'Enter URL manually';

  @override
  String get authPasteAuthUrl =>
      'Paste the authentication URL from your terminal';

  @override
  String get authAuthenticateTerminal => 'Authenticate Terminal';

  @override
  String get authAuthenticateWithUrlPaste =>
      'Authenticate Terminal with URL paste';

  @override
  String get authCameraPermissionsRequired =>
      'Camera permissions are required to scan QR codes';

  @override
  String get authExchangingTokens => 'Exchanging tokens...';

  @override
  String get authClaudeAuthSuccess => 'Successfully connected to Claude';

  @override
  String get welcomeTitle => 'Codex and Claude Code mobile client';

  @override
  String get welcomeSubtitle =>
      'End-to-end encrypted and your account is stored only on your device.';

  @override
  String get welcomeCreateAccount => 'Create account';

  @override
  String get welcomeLinkOrRestoreAccount => 'Link or restore account';

  @override
  String get welcomeLoginWithMobileApp => 'Login with mobile app';

  @override
  String get sessionTitle => 'Sessions';

  @override
  String get sessionNewSession => 'New Session';

  @override
  String get sessionStartNewToGetStarted =>
      'Start a new session to get started';

  @override
  String get sessionNoSessionsYet => 'No sessions yet';

  @override
  String get sessionActiveSessions => 'Active';

  @override
  String get sessionHistory => 'History';

  @override
  String get sessionMachine => 'Machine';

  @override
  String get sessionSelectMachine => 'Select a machine';

  @override
  String get sessionPath => 'Path';

  @override
  String get sessionPathHint => 'Enter path';

  @override
  String get sessionInitialMessage => 'Initial message';

  @override
  String get sessionInitialMessageHint => 'What would you like to work on?';

  @override
  String get sessionInputPlaceholder => 'Type a message ...';

  @override
  String get sessionStartSession => 'Start Session';

  @override
  String get sessionStarting => 'Starting session...';

  @override
  String get sessionStarted => 'Session Started';

  @override
  String get sessionStartedMessage =>
      'The session has been started successfully.';

  @override
  String get sessionFailedToStart =>
      'Failed to start session. Make sure the daemon is running on the target machine.';

  @override
  String get sessionTimeout =>
      'Session startup timed out. The machine may be slow or the daemon may not be responding.';

  @override
  String get sessionNotConnectedToServer =>
      'Not connected to server. Check your internet connection.';

  @override
  String get sessionNoMachineSelected =>
      'Please select a machine to start the session';

  @override
  String get sessionNoPathSelected =>
      'Please select a directory to start the session in';

  @override
  String get sessionTypeTitle => 'Session Type';

  @override
  String get sessionTypeSimple => 'Simple';

  @override
  String get sessionTypeWorktree => 'Worktree';

  @override
  String get sessionTypeComingSoon => 'Coming soon';

  @override
  String get newSessionTitle => 'New Session';

  @override
  String get newSessionNoMachinesFound =>
      'No machines found. Start a Happy session on your computer first.';

  @override
  String get newSessionAllMachinesOffline => 'All machines appear offline';

  @override
  String get newSessionMachineUnreachable =>
      'Machine is unreachable. Make sure the Happy daemon is running and try again.';

  @override
  String get newSessionCouldNotStartSession =>
      'Could not start session. Please try again.';

  @override
  String get newSessionMachineDetails => 'View machine details →';

  @override
  String get newSessionDirectoryDoesNotExist => 'Directory Not Found';

  @override
  String newSessionCreateDirectoryConfirm(Object directory) {
    return 'The directory $directory does not exist. Do you want to create it?';
  }

  @override
  String get newSessionSessionSpawningFailed =>
      'Session spawning failed - no session ID returned.';

  @override
  String get sessionHistoryTitle => 'Sessions';

  @override
  String get sessionHistoryEmpty => 'No sessions found';

  @override
  String get sessionHistoryToday => 'Today';

  @override
  String get sessionHistoryYesterday => 'Yesterday';

  @override
  String sessionHistoryDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryViewAll => 'View all sessions';

  @override
  String get sessionInfoTitle => 'Session Info';

  @override
  String get sessionInfoHappySessionId => 'Happy Session ID';

  @override
  String get sessionInfoClaudeCodeSessionId => 'Claude Code Session ID';

  @override
  String get sessionInfoAiProvider => 'AI Provider';

  @override
  String get sessionInfoConnectionStatus => 'Connection Status';

  @override
  String get sessionInfoCreated => 'Created';

  @override
  String get sessionInfoLastUpdated => 'Last Updated';

  @override
  String get sessionInfoSequence => 'Sequence';

  @override
  String get sessionInfoMetadata => 'Metadata';

  @override
  String get sessionInfoHost => 'Host';

  @override
  String get sessionInfoPath => 'Path';

  @override
  String get sessionInfoOperatingSystem => 'Operating System';

  @override
  String get sessionInfoProcessId => 'Process ID';

  @override
  String get sessionInfoCliVersion => 'CLI Version';

  @override
  String get sessionInfoAgentState => 'Agent State';

  @override
  String get sessionInfoControlledByUser => 'Controlled by User';

  @override
  String get sessionInfoPendingRequests => 'Pending Requests';

  @override
  String get sessionInfoActivity => 'Activity';

  @override
  String get sessionInfoThinking => 'Thinking';

  @override
  String get sessionInfoThinkingSince => 'Thinking Since';

  @override
  String get sessionInfoCliVersionOutdated => 'CLI Update Required';

  @override
  String sessionInfoCliVersionOutdatedMessage(
    Object currentVersion,
    Object requiredVersion,
  ) {
    return 'Version $currentVersion installed. Update to $requiredVersion or later';
  }

  @override
  String get sessionInfoUpdateCliInstructions =>
      'Please run npm install -g happy-coder@latest';

  @override
  String get sessionInfoQuickActions => 'Quick Actions';

  @override
  String get sessionInfoViewMachine => 'View Machine';

  @override
  String get sessionInfoViewMachineSubtitle =>
      'View machine details and sessions';

  @override
  String get sessionInfoKillSession => 'Kill Session';

  @override
  String get sessionInfoKillSessionConfirm =>
      'Are you sure you want to terminate this session?';

  @override
  String get sessionInfoKillSessionSubtitle =>
      'Immediately terminate the session';

  @override
  String get sessionInfoArchiveSession => 'Archive Session';

  @override
  String get sessionInfoArchiveSessionConfirm =>
      'Are you sure you want to archive this session?';

  @override
  String get sessionInfoArchiveSessionSubtitle =>
      'Archive this session and stop it';

  @override
  String get sessionInfoDeleteSession => 'Delete Session';

  @override
  String get sessionInfoDeleteSessionSubtitle =>
      'Permanently remove this session';

  @override
  String get sessionInfoDeleteSessionConfirm => 'Delete Session Permanently?';

  @override
  String get sessionInfoDeleteSessionWarning =>
      'This action cannot be undone. All messages and data associated with this session will be permanently deleted.';

  @override
  String get sessionInfoCopySessionId => 'Copy Session ID';

  @override
  String get sessionInfoCopyMetadata => 'Copy Metadata';

  @override
  String get sessionInfoSessionIdCopied => 'Session ID copied to clipboard';

  @override
  String get sessionInfoMetadataCopied => 'Metadata copied to clipboard';

  @override
  String get sessionInfoCopyFailed => 'Failed to copy to clipboard';

  @override
  String get sessionInfoHappyHome => 'Happy Home';

  @override
  String get sessionInfoFailedToKillSession => 'Failed to kill session';

  @override
  String get sessionInfoFailedToArchiveSession => 'Failed to archive session';

  @override
  String get sessionInfoFailedToDeleteSession => 'Failed to delete session';

  @override
  String get sessionInfoSessionDeleted => 'Session deleted successfully';

  @override
  String machineTitle(int count) {
    return 'Machine';
  }

  @override
  String get machineLaunchNewSessionInDirectory =>
      'Launch New Session in Directory';

  @override
  String get machineOfflineUnableToSpawn =>
      'Launcher disabled while machine is offline';

  @override
  String get machineOfflineHelp =>
      '• Make sure your computer is online\n• Run `happy daemon status` to diagnose\n• Are you running the latest CLI version? Upgrade with `npm install -g happy-coder@latest`';

  @override
  String get machineDaemon => 'Daemon';

  @override
  String get machineStatus => 'Status';

  @override
  String get machineStopDaemon => 'Stop Daemon';

  @override
  String get machineLastKnownPid => 'Last Known PID';

  @override
  String get machineLastKnownHttpPort => 'Last Known HTTP Port';

  @override
  String get machineStartedAt => 'Started At';

  @override
  String get machineCliVersion => 'CLI Version';

  @override
  String get machineDaemonStateVersion => 'Daemon State Version';

  @override
  String machineActiveSessions(Object count) {
    return 'Active Sessions ($count)';
  }

  @override
  String get machineMachineGroup => 'Machine';

  @override
  String get machineHost => 'Host';

  @override
  String get machineMachineId => 'Machine ID';

  @override
  String get machineUsername => 'Username';

  @override
  String get machineHomeDirectory => 'Home Directory';

  @override
  String get machinePlatform => 'Platform';

  @override
  String get machineArchitecture => 'Architecture';

  @override
  String get machineLastSeen => 'Last Seen';

  @override
  String get machineNever => 'Never';

  @override
  String get machineMetadataVersion => 'Metadata Version';

  @override
  String get machineUntitledSession => 'Untitled Session';

  @override
  String get machineBack => 'Back';

  @override
  String get machineShowLess => 'Show less';

  @override
  String machineShowAll(Object count) {
    return 'Show all ($count paths)';
  }

  @override
  String get machineEnterCustomPath => 'Enter custom path';

  @override
  String get machineOfflineUnableToSpawnNew =>
      'Unable to spawn new session, offline';

  @override
  String chatTitle(String toolName) {
    return 'Chat';
  }

  @override
  String get chatStartConversation => 'Start a conversation';

  @override
  String get chatSendMessageToBegin => 'Send a message to begin';

  @override
  String get chatSessionSettings => 'Session settings';

  @override
  String get chatDeleteSession => 'Delete session';

  @override
  String get chatDeleteSessionConfirm =>
      'Are you sure you want to delete this session?';

  @override
  String get chatFailedToSend => 'Failed to send message';

  @override
  String get chatThinking => 'Claude is thinking...';

  @override
  String chatToolRunning(Object toolName) {
    return 'Running: $toolName';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsConnectedAccounts => 'Connected Accounts';

  @override
  String get settingsConnectAccount => 'Connect account';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsMachines => 'Machines';

  @override
  String get settingsSessions => 'Sessions';

  @override
  String get settingsSessionsViewStyle => 'Session view style';

  @override
  String get settingsSessionsViewStyleSubtitle =>
      'Choose how sessions are grouped in the sessions tab';

  @override
  String get settingsFeatures => 'Features';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountSubtitle => 'Manage your account details';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Customize how the app looks';

  @override
  String get settingsVoiceAssistant => 'Voice Assistant';

  @override
  String get settingsVoiceAssistantSubtitle =>
      'Configure voice interaction preferences';

  @override
  String get settingsFeaturesTitle => 'Features';

  @override
  String get settingsFeaturesSubtitle => 'Enable or disable app features';

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String get settingsDeveloperTools => 'Developer Tools';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutFooter =>
      'Happy Coder is a Codex and Claude Code mobile client. It\'s fully end-to-end encrypted and your account is stored only on your device. Not affiliated with Anthropic.';

  @override
  String get settingsWhatsNew => 'What\'s New';

  @override
  String get settingsWhatsNewSubtitle =>
      'See the latest updates and improvements';

  @override
  String get settingsReportIssue => 'Report an Issue';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsEula => 'EULA';

  @override
  String get settingsSupportUs => 'Support us';

  @override
  String get settingsSupportUsSubtitlePro => 'Thank you for your support!';

  @override
  String get settingsSupportUsSubtitle => 'Support project development';

  @override
  String get settingsScanQrCodeToAuthenticate => 'Scan QR code to authenticate';

  @override
  String settingsGithubConnected(Object login) {
    return 'Connected as @$login';
  }

  @override
  String get settingsConnectGithubAccount => 'Connect your GitHub account';

  @override
  String get settingsUsage => 'Usage';

  @override
  String get settingsUsageSubtitle => 'View your API usage and costs';

  @override
  String get settingsProfiles => 'Profiles';

  @override
  String get settingsProfilesSubtitle =>
      'Manage environment variable profiles for sessions';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirm =>
      'Are you sure you want to sign out? Make sure you have backed up your secret key!';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Choose your preferred language for the app interface';

  @override
  String get settingsLanguageCurrent => 'Current Language';

  @override
  String get settingsLanguageAutomatic => 'Automatic';

  @override
  String get settingsLanguageAutomaticSubtitle => 'Detect from device settings';

  @override
  String get settingsLanguageNeedsRestart => 'Language Changed';

  @override
  String get settingsLanguageNeedsRestartMessage =>
      'The app needs to restart to apply the new language setting.';

  @override
  String get settingsLanguageRestartNow => 'Restart Now';

  @override
  String get settingsLanguageSearchPlaceholder => 'Search languages...';

  @override
  String get settingsAppearanceTheme => 'Theme';

  @override
  String get settingsAppearanceThemeSubtitle =>
      'Choose your preferred color scheme';

  @override
  String get settingsAppearanceThemeAdaptive => 'Adaptive';

  @override
  String get settingsAppearanceThemeAdaptiveSubtitle => 'Match system settings';

  @override
  String get settingsAppearanceThemeLight => 'Light';

  @override
  String get settingsAppearanceThemeLightSubtitle => 'Always use light theme';

  @override
  String get settingsAppearanceThemeDark => 'Dark';

  @override
  String get settingsAppearanceThemeDarkSubtitle => 'Always use dark theme';

  @override
  String get settingsAppearanceDisplay => 'Display';

  @override
  String get settingsAppearanceDisplaySubtitle => 'Control layout and spacing';

  @override
  String get settingsAppearanceInlineToolCalls => 'Inline Tool Calls';

  @override
  String get settingsAppearanceInlineToolCallsSubtitle =>
      'Display tool calls directly in chat messages';

  @override
  String get settingsAppearanceExpandTodoLists => 'Expand Todo Lists';

  @override
  String get settingsAppearanceExpandTodoListsSubtitle =>
      'Show all todos instead of just changes';

  @override
  String get settingsAppearanceShowLineNumbersInDiffs =>
      'Show Line Numbers in Diffs';

  @override
  String get settingsAppearanceShowLineNumbersInDiffsSubtitle =>
      'Display line numbers in code diffs';

  @override
  String get settingsAppearanceShowLineNumbersInToolViews =>
      'Show Line Numbers in Tool Views';

  @override
  String get settingsAppearanceShowLineNumbersInToolViewsSubtitle =>
      'Display line numbers in tool view diffs';

  @override
  String get settingsAppearanceWrapLinesInDiffs => 'Wrap Lines in Diffs';

  @override
  String get settingsAppearanceWrapLinesInDiffsSubtitle =>
      'Wrap long lines instead of horizontal scrolling in diff views';

  @override
  String get settingsAppearanceAlwaysShowContextSize =>
      'Always Show Context Size';

  @override
  String get settingsAppearanceAlwaysShowContextSizeSubtitle =>
      'Display context usage even when not near limit';

  @override
  String get settingsAppearanceAvatarStyle => 'Avatar Style';

  @override
  String get settingsAppearanceAvatarStyleSubtitle =>
      'Choose session avatar appearance';

  @override
  String get settingsAppearanceAvatarStylePixelated => 'Pixelated';

  @override
  String get settingsAppearanceAvatarStyleGradient => 'Gradient';

  @override
  String get settingsAppearanceAvatarStyleBrutalist => 'Brutalist';

  @override
  String get settingsAppearanceShowFlavorIcons => 'Show AI Provider Icons';

  @override
  String get settingsAppearanceShowFlavorIconsSubtitle =>
      'Display AI provider icons on session avatars';

  @override
  String get settingsAppearanceCompactSessionView => 'Compact Session View';

  @override
  String get settingsAppearanceCompactSessionViewSubtitle =>
      'Show active sessions in a more compact layout';

  @override
  String get settingsFeaturesExperiments => 'Experiments';

  @override
  String get settingsFeaturesExperimentsSubtitle =>
      'Enable experimental features that are still in development. These features may be unstable or change without notice.';

  @override
  String get settingsFeaturesExperimentalFeatures => 'Experimental Features';

  @override
  String get settingsFeaturesExperimentalFeaturesEnabled =>
      'Experimental features enabled';

  @override
  String get settingsFeaturesExperimentalFeaturesDisabled =>
      'Using stable features only';

  @override
  String get settingsFeaturesWebFeatures => 'Web Features';

  @override
  String get settingsFeaturesWebFeaturesSubtitle =>
      'Features available only in the web version of the app.';

  @override
  String get settingsFeaturesEnterToSend => 'Enter to Send';

  @override
  String get settingsFeaturesEnterToSendEnabled =>
      'Press Enter to send (Shift+Enter for a new line)';

  @override
  String get settingsFeaturesEnterToSendDisabled => 'Enter inserts a new line';

  @override
  String get settingsFeaturesCommandPalette => 'Command Palette';

  @override
  String get settingsFeaturesCommandPaletteEnabled => 'Press ⌘K to open';

  @override
  String get settingsFeaturesCommandPaletteDisabled =>
      'Quick command access disabled';

  @override
  String get settingsFeaturesMarkdownCopyV2 => 'Markdown Copy v2';

  @override
  String get settingsFeaturesMarkdownCopyV2Subtitle =>
      'Long press opens copy modal';

  @override
  String get settingsFeaturesHideInactiveSessions => 'Hide inactive sessions';

  @override
  String get settingsFeaturesHideInactiveSessionsSubtitle =>
      'Show only active chats in your list';

  @override
  String get settingsFeaturesEnhancedSessionWizard => 'Enhanced Session Wizard';

  @override
  String get settingsFeaturesEnhancedSessionWizardEnabled =>
      'Profile-first session launcher active';

  @override
  String get settingsFeaturesEnhancedSessionWizardDisabled =>
      'Using standard session launcher';

  @override
  String get settingsAccountTitle => 'Account Settings';

  @override
  String get settingsAccountStatus => 'Status';

  @override
  String get settingsAccountStatusActive => 'Active';

  @override
  String get settingsAccountStatusNotAuthenticated => 'Not Authenticated';

  @override
  String get settingsAccountAnonymousId => 'Anonymous ID';

  @override
  String get settingsAccountPublicId => 'Public ID';

  @override
  String get settingsAccountNotAvailable => 'Not available';

  @override
  String get settingsAccountLinkNewDevice => 'Link New Device';

  @override
  String get settingsAccountLinkNewDeviceSubtitle =>
      'Scan QR code to link device';

  @override
  String get settingsAccountProfile => 'Profile';

  @override
  String get settingsAccountName => 'Name';

  @override
  String get settingsAccountGithub => 'GitHub';

  @override
  String get settingsAccountTapToDisconnect => 'Tap to disconnect';

  @override
  String get settingsAccountServer => 'Server';

  @override
  String get settingsAccountBackup => 'Backup';

  @override
  String get settingsAccountBackupDescription =>
      'Your secret key is the only way to recover your account. Save it in a secure place like a password manager.';

  @override
  String get settingsAccountSecretKey => 'Secret Key';

  @override
  String get settingsAccountTapToReveal => 'Tap to reveal';

  @override
  String get settingsAccountTapToHide => 'Tap to hide';

  @override
  String get settingsAccountSecretKeyLabel => 'SECRET KEY (TAP TO COPY)';

  @override
  String get settingsAccountSecretKeyCopied =>
      'Secret key copied to clipboard. Store it in a safe place!';

  @override
  String get settingsAccountSecretKeyCopyFailed => 'Failed to copy secret key';

  @override
  String get settingsAccountPrivacy => 'Privacy';

  @override
  String get settingsAccountPrivacyDescription =>
      'Help improve the app by sharing anonymous usage data. No personal information is collected.';

  @override
  String get settingsAccountAnalytics => 'Analytics';

  @override
  String get settingsAccountAnalyticsDisabled => 'No data is shared';

  @override
  String get settingsAccountAnalyticsEnabled =>
      'Anonymous usage data is shared';

  @override
  String get settingsAccountDangerZone => 'Danger Zone';

  @override
  String get settingsAccountLogout => 'Logout';

  @override
  String get settingsAccountLogoutSubtitle => 'Sign out and clear local data';

  @override
  String get settingsServerTitle => 'Server Configuration';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsServerUrlLabel => 'Please enter a server URL';

  @override
  String get settingsServerNotValidHappyServer => 'Not a valid Happy Server';

  @override
  String get settingsServerChangeServer => 'Change Server';

  @override
  String get settingsServerContinueWithServer => 'Continue with this server?';

  @override
  String get settingsServerResetToDefault => 'Reset to Default';

  @override
  String get settingsServerResetServerDefault => 'Reset server to default?';

  @override
  String get settingsServerValidating => 'Validating...';

  @override
  String get settingsServerValidatingServer => 'Validating server...';

  @override
  String get settingsServerServerReturnedError => 'Server returned an error';

  @override
  String get settingsServerFailedToConnectToServer =>
      'Failed to connect to server';

  @override
  String get settingsServerCurrentlyUsingCustomServer =>
      'Currently using custom server';

  @override
  String get settingsServerCustomServerUrlLabel => 'Custom Server URL';

  @override
  String get settingsServerAdvancedFeatureFooter =>
      'This is an advanced feature. Only change the server if you know what you\'re doing. You will need to log out and log in again after changing servers.';

  @override
  String get settingsVoiceTitle => 'Voice Assistant';

  @override
  String get settingsVoiceLanguage => 'Language';

  @override
  String get settingsVoiceLanguageSubtitle =>
      'Choose your preferred language for voice assistant interactions. This setting syncs across all your devices.';

  @override
  String get settingsVoicePreferredLanguage => 'Preferred Language';

  @override
  String get settingsVoicePreferredLanguageSubtitle =>
      'Language used for voice assistant responses';

  @override
  String get settingsVoiceLanguageSearchPlaceholder => 'Search languages...';

  @override
  String get settingsVoiceLanguageSearchTitle => 'Languages';

  @override
  String settingsVoiceLanguageFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count languages',
      one: '1 language',
    );
    return '$_temp0 available';
  }

  @override
  String get settingsVoiceLanguageAutoDetect => 'Auto-detect';

  @override
  String get settingsProfilesTitle => 'Profiles';

  @override
  String get settingsProfilesNoProfile => 'No Profile';

  @override
  String get settingsProfilesNoProfileDescription =>
      'Use default environment settings';

  @override
  String get settingsProfilesDefaultModel => 'Default Model';

  @override
  String get settingsProfilesAddProfile => 'Add Profile';

  @override
  String get settingsProfilesProfileName => 'Profile Name';

  @override
  String get settingsProfilesEnterName => 'Enter profile name';

  @override
  String get settingsProfilesBaseUrl => 'Base URL';

  @override
  String get settingsProfilesAuthToken => 'Auth Token';

  @override
  String get settingsProfilesEnterToken => 'Enter auth token';

  @override
  String get settingsProfilesModel => 'Model';

  @override
  String get settingsProfilesTmuxSession => 'Tmux Session';

  @override
  String get settingsProfilesEnterTmuxSession => 'Enter tmux session name';

  @override
  String get settingsProfilesTmuxTempDir => 'Tmux Temp Directory';

  @override
  String get settingsProfilesEnterTmuxTempDir => 'Enter temp directory path';

  @override
  String get settingsProfilesTmuxUpdateEnvironment =>
      'Update environment automatically';

  @override
  String get settingsProfilesNameRequired => 'Profile name is required';

  @override
  String settingsProfilesDeleteConfirm(String name) {
    return 'Are you sure you want to delete the profile \"$name\"?';
  }

  @override
  String get settingsProfilesEditProfile => 'Edit Profile';

  @override
  String get settingsProfilesAddProfileTitle => 'Add New Profile';

  @override
  String get settingsProfilesDeleteTitle => 'Delete Profile';

  @override
  String settingsProfilesDeleteMessage(Object name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get settingsProfilesDeleteConfirmAction => 'Delete';

  @override
  String get settingsProfilesDeleteCancel => 'Cancel';

  @override
  String get settingsUsageTitle => 'Usage';

  @override
  String get settingsUsageToday => 'Today';

  @override
  String get settingsUsageLast7Days => 'Last 7 days';

  @override
  String get settingsUsageLast30Days => 'Last 30 days';

  @override
  String get settingsUsageTotalTokens => 'Total Tokens';

  @override
  String get settingsUsageTotalCost => 'Total Cost';

  @override
  String get settingsUsageTokens => 'Tokens';

  @override
  String get settingsUsageCost => 'Cost';

  @override
  String get settingsUsageUsageOverTime => 'Usage over time';

  @override
  String get settingsUsageByModel => 'By Model';

  @override
  String get settingsUsageNoData => 'No usage data available';

  @override
  String get settingsDeveloperTitle => 'Developer';

  @override
  String settingsDeveloperVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsDeveloperCopyDebugInfo => 'Copy Debug Info';

  @override
  String get settingsDeveloperDebugInfoCopied =>
      'Debug info copied to clipboard';

  @override
  String get errorsNetworkError => 'Network error occurred';

  @override
  String get errorsServerError => 'Server error occurred';

  @override
  String get errorsUnknownError => 'An unknown error occurred';

  @override
  String get errorsConnectionTimeout => 'Connection timed out';

  @override
  String get errorsAuthenticationFailed => 'Authentication failed';

  @override
  String get errorsPermissionDenied => 'Permission denied';

  @override
  String get errorsFileNotFound => 'File not found';

  @override
  String get errorsInvalidFormat => 'Invalid format';

  @override
  String get errorsOperationFailed => 'Operation failed';

  @override
  String get errorsTryAgain => 'Please try again';

  @override
  String get errorsContactSupport => 'Contact support if the problem persists';

  @override
  String get errorsSessionNotFound => 'Session not found';

  @override
  String get errorsVoiceSessionFailed => 'Failed to start voice session';

  @override
  String get errorsVoiceServiceUnavailable =>
      'Voice service is temporarily unavailable';

  @override
  String get errorsOauthInitializationFailed =>
      'Failed to initialize OAuth flow';

  @override
  String get errorsTokenStorageFailed =>
      'Failed to store authentication tokens';

  @override
  String get errorsOauthStateMismatch =>
      'Security validation failed. Please try again';

  @override
  String get errorsTokenExchangeFailed =>
      'Failed to exchange authorization code';

  @override
  String get errorsOauthAuthorizationDenied => 'Authorization was denied';

  @override
  String get errorsWebViewLoadFailed => 'Failed to load authentication page';

  @override
  String get errorsFailedToLoadProfile => 'Failed to load user profile';

  @override
  String get errorsUserNotFound => 'User not found';

  @override
  String get errorsSessionDeleted => 'Session has been deleted';

  @override
  String get errorsSessionDeletedDescription =>
      'This session has been permanently removed';

  @override
  String errorsFieldError(String field, String reason) {
    return '$field: $reason';
  }

  @override
  String errorsValidationError(String field, int min, int max) {
    return '$field must be between $min and $max';
  }

  @override
  String errorsRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Retry in $_temp0';
  }

  @override
  String errorsErrorWithCode(Object code, Object message) {
    return '$message (Error $code)';
  }

  @override
  String errorsDisconnectServiceFailed(Object service) {
    return 'Failed to disconnect $service';
  }

  @override
  String errorsConnectServiceFailed(Object service) {
    return 'Failed to connect $service. Please try again.';
  }

  @override
  String get errorsSearchFailed => 'Search failed. Please try again.';

  @override
  String get terminalWebBrowserRequired => 'Web Browser Required';

  @override
  String get terminalWebBrowserRequiredDescription =>
      'Terminal connection links can only be opened in a web browser for security reasons. Please use the QR code scanner or open this link on a computer.';

  @override
  String get terminalProcessingConnection => 'Processing connection...';

  @override
  String get terminalInvalidConnectionLink => 'Invalid Connection Link';

  @override
  String get terminalInvalidConnectionLinkDescription =>
      'The connection link is missing or invalid. Please check the URL and try again.';

  @override
  String get terminalConnectTerminal => 'Connect Terminal';

  @override
  String get terminalRequestDescription =>
      'A terminal is requesting to connect to your Happy Coder account. This will allow the terminal to send and receive messages securely.';

  @override
  String get terminalConnectionDetails => 'Connection Details';

  @override
  String get terminalPublicKey => 'Public Key';

  @override
  String get terminalEncryption => 'Encryption';

  @override
  String get terminalEndToEndEncrypted => 'End-to-end encrypted';

  @override
  String get terminalAcceptConnection => 'Accept Connection';

  @override
  String get terminalConnecting => 'Connecting...';

  @override
  String get terminalReject => 'Reject';

  @override
  String get terminalSecurity => 'Security';

  @override
  String get terminalSecurityFooter =>
      'This connection link was processed securely in your browser and was never sent to any server. Your private data will remain secure and only you can decrypt the messages.';

  @override
  String get terminalSecurityFooterDevice =>
      'This connection was processed securely on your device and was never sent to any server. Your private data will remain secure and only you can decrypt the messages.';

  @override
  String get terminalClientSideProcessing => 'Client-Side Processing';

  @override
  String get terminalLinkProcessedLocally =>
      'Link processed locally in browser';

  @override
  String get terminalLinkProcessedOnDevice =>
      'Link processed locally on device';

  @override
  String get sidebarSessionsTitle => 'Terminals';

  @override
  String get sidebarStatusConnected => 'Connected';

  @override
  String get sidebarStatusConnecting => 'Connecting...';

  @override
  String get sidebarStatusDisconnected => 'Disconnected';

  @override
  String get sidebarStatusError => 'Error';

  @override
  String get commandPalettePlaceholder => 'Type a command or search...';

  @override
  String get toolViewInput => 'Input';

  @override
  String get toolViewOutput => 'Output';

  @override
  String get toolViewDescription => 'Description';

  @override
  String get toolViewInputParams => 'Input Parameters';

  @override
  String get toolViewError => 'Error';

  @override
  String get toolViewCompleted => 'Tool completed successfully';

  @override
  String get toolViewNoOutput => 'No output was produced';

  @override
  String get toolViewRunning => 'Tool is running...';

  @override
  String get toolViewRawJsonDevMode => 'Raw JSON (Dev Mode)';

  @override
  String get toolNamesTask => 'Task';

  @override
  String get toolNamesTerminal => 'Terminal';

  @override
  String get toolNamesSearchFiles => 'Search Files';

  @override
  String get toolNamesSearch => 'Search';

  @override
  String get toolNamesSearchContent => 'Search Content';

  @override
  String get toolNamesListFiles => 'List Files';

  @override
  String get toolNamesPlanProposal => 'Plan proposal';

  @override
  String get toolNamesReadFile => 'Read File';

  @override
  String get toolNamesEditFile => 'Edit File';

  @override
  String get toolNamesWriteFile => 'Write File';

  @override
  String get toolNamesFetchUrl => 'Fetch URL';

  @override
  String get toolNamesReadNotebook => 'Read Notebook';

  @override
  String get toolNamesEditNotebook => 'Edit Notebook';

  @override
  String get toolNamesTodoList => 'Todo List';

  @override
  String get toolNamesWebSearch => 'Web Search';

  @override
  String get toolNamesReasoning => 'Reasoning';

  @override
  String get toolNamesApplyChanges => 'Update file';

  @override
  String get toolNamesViewDiff => 'Current file changes';

  @override
  String get toolNamesQuestion => 'Question';

  @override
  String toolDescTerminalCmd(String cmd) {
    return 'Terminal(cmd: $cmd)';
  }

  @override
  String toolDescSearchPattern(Object pattern) {
    return 'Search(pattern: $pattern)';
  }

  @override
  String toolDescSearchPath(Object basename) {
    return 'Search(path: $basename)';
  }

  @override
  String toolDescFetchUrlHost(Object host) {
    return 'Fetch URL(url: $host)';
  }

  @override
  String toolDescEditNotebookMode(Object mode, Object path) {
    return 'Edit Notebook(file: $path, mode: $mode)';
  }

  @override
  String toolDescTodoListCount(Object count) {
    return 'Todo List(count: $count)';
  }

  @override
  String toolDescWebSearchQuery(Object query) {
    return 'Web Search(query: $query)';
  }

  @override
  String toolDescGrepPattern(Object pattern) {
    return 'grep(pattern: $pattern)';
  }

  @override
  String toolDescMultiEditEdits(Object count, Object path) {
    return '$path ($count edits)';
  }

  @override
  String toolDescReadingFile(Object file) {
    return 'Reading $file';
  }

  @override
  String toolDescWritingFile(Object file) {
    return 'Writing $file';
  }

  @override
  String toolDescModifyingFile(Object file) {
    return 'Modifying $file';
  }

  @override
  String toolDescModifyingFiles(Object count) {
    return 'Modifying $count files';
  }

  @override
  String toolDescModifyingMultipleFiles(Object count, Object file) {
    return '$file and $count more';
  }

  @override
  String get toolDescShowingDiff => 'Showing changes';

  @override
  String get filesSearchPlaceholder => 'Search files...';

  @override
  String get filesDetachedHead => 'detached HEAD';

  @override
  String filesSummary(Object staged, Object unstaged) {
    return '$staged staged • $unstaged unstaged';
  }

  @override
  String get filesNotRepo => 'Not a git repository';

  @override
  String get filesNotUnderGit =>
      'This directory is not under git version control';

  @override
  String get filesSearching => 'Searching files...';

  @override
  String get filesNoFilesFound => 'No files found';

  @override
  String get filesNoFilesInProject => 'No files in project';

  @override
  String get filesTryDifferentTerm => 'Try a different search term';

  @override
  String filesSearchResults(int count) {
    return 'Search Results ($count)';
  }

  @override
  String get filesProjectRoot => 'Project root';

  @override
  String filesStagedChanges(Object count) {
    return 'Staged Changes ($count)';
  }

  @override
  String filesUnstagedChanges(Object count) {
    return 'Unstaged Changes ($count)';
  }

  @override
  String filesLoadingFile(Object fileName) {
    return 'Loading $fileName...';
  }

  @override
  String get filesBinaryFile => 'Binary File';

  @override
  String get filesCannotDisplayBinary => 'Cannot display binary file content';

  @override
  String get filesDiff => 'Diff';

  @override
  String get filesFile => 'File';

  @override
  String get filesFileEmpty => 'File is empty';

  @override
  String get filesNoChanges => 'No changes to display';

  @override
  String get profileUserProfile => 'User Profile';

  @override
  String get profileDetails => 'Details';

  @override
  String get profileFirstName => 'First Name';

  @override
  String get profileLastName => 'Last Name';

  @override
  String get profileUsername => 'Username';

  @override
  String get profileStatus => 'Status';

  @override
  String get agentPermissionModeTitle => 'PERMISSION MODE';

  @override
  String get agentPermissionModeDefault => 'Default';

  @override
  String get agentPermissionModeAcceptEdits => 'Accept Edits';

  @override
  String get agentPermissionModePlan => 'Plan Mode';

  @override
  String get agentPermissionModeBypassPermissions => 'Yolo Mode';

  @override
  String get agentPermissionModeBadgeAcceptAllEdits => 'Accept All Edits';

  @override
  String get agentPermissionModeBadgeBypassAllPermissions =>
      'Bypass All Permissions';

  @override
  String get agentPermissionModeBadgePlanMode => 'Plan Mode';

  @override
  String get agentAgentClaude => 'Claude';

  @override
  String get agentAgentCodex => 'Codex';

  @override
  String get agentAgentGemini => 'Gemini';

  @override
  String get agentModelTitle => 'MODEL';

  @override
  String get agentModelConfigureInCli => 'Configure models in CLI settings';

  @override
  String agentContextRemaining(int percent) {
    return '$percent% left';
  }

  @override
  String get agentSuggestionFileLabel => 'FILE';

  @override
  String get agentSuggestionFolderLabel => 'FOLDER';

  @override
  String get agentNoMachinesAvailable => 'No machines';

  @override
  String get updateBannerUpdateAvailable => 'Update available';

  @override
  String get updateBannerPressToApply => 'Press to apply the update';

  @override
  String get updateBannerWhatsNew => 'What\'s new';

  @override
  String get updateBannerSeeLatest => 'See the latest updates and improvements';

  @override
  String get updateBannerNativeUpdateAvailable => 'App Update Available';

  @override
  String get updateBannerTapToUpdateAppStore => 'Tap to update in App Store';

  @override
  String get updateBannerTapToUpdatePlayStore => 'Tap to update in Play Store';

  @override
  String changelogVersion(int version) {
    return 'Version $version';
  }

  @override
  String get changelogNoEntriesAvailable => 'No changelog entries available.';

  @override
  String get modalsAuthenticateTerminal => 'Authenticate Terminal';

  @override
  String get modalsPasteUrlFromTerminal =>
      'Paste the authentication URL from your terminal';

  @override
  String get modalsDeviceLinkedSuccessfully => 'Device linked successfully';

  @override
  String get modalsTerminalConnectedSuccessfully =>
      'Terminal connected successfully';

  @override
  String get modalsInvalidAuthUrl => 'Invalid authentication URL';

  @override
  String get modalsDeveloperMode => 'Developer Mode';

  @override
  String get modalsDeveloperModeEnabled => 'Developer mode enabled';

  @override
  String get modalsDeveloperModeDisabled => 'Developer mode disabled';

  @override
  String get modalsDisconnectGithub => 'Disconnect GitHub';

  @override
  String get modalsDisconnectGithubConfirm =>
      'Are you sure you want to disconnect your GitHub account?';

  @override
  String modalsDisconnectService(String service) {
    return 'Disconnect $service';
  }

  @override
  String modalsDisconnectServiceConfirm(Object service) {
    return 'Are you sure you want to disconnect $service from your account?';
  }

  @override
  String get modalsDisconnect => 'Disconnect';

  @override
  String get modalsFailedToConnectTerminal => 'Failed to connect terminal';

  @override
  String get modalsCameraPermissionsRequiredToConnectTerminal =>
      'Camera permissions are required to connect terminal';

  @override
  String get modalsFailedToLinkDevice => 'Failed to link device';

  @override
  String get navigationConnectTerminal => 'Connect Terminal';

  @override
  String get navigationLinkNewDevice => 'Link New Device';

  @override
  String get navigationRestoreWithSecretKey => 'Restore with Secret Key';

  @override
  String get navigationWhatsNew => 'What\'s New';

  @override
  String get emptyMainScreenReadyToCode => 'Ready to code?';

  @override
  String get emptyMainScreenInstallCli => 'Install the Happy CLI';

  @override
  String get emptyMainScreenRunIt => 'Run it';

  @override
  String get emptyMainScreenScanQrCode => 'Scan the QR code';

  @override
  String get emptyMainScreenOpenCamera => 'Open Camera';

  @override
  String get emptySessionsFirstTimeTitle => 'Get started with Happy';

  @override
  String get emptySessionsFirstTimeSubtitle =>
      'Connect your computer to start coding sessions from your phone.';

  @override
  String get emptySessionsFirstTimeStep1Label => 'Install CLI';

  @override
  String get emptySessionsFirstTimeStep1Detail =>
      'Run happy install on your computer';

  @override
  String get emptySessionsFirstTimeStep2Label => 'Start daemon';

  @override
  String get emptySessionsFirstTimeStep2Detail =>
      'Run happy start in your project';

  @override
  String get emptySessionsFirstTimeStep3Label => 'Scan & connect';

  @override
  String get emptySessionsFirstTimeStep3Detail =>
      'Tap the + button and scan the QR code';

  @override
  String get emptySessionsReturningTitle => 'No active sessions';

  @override
  String get emptySessionsReturningSubtitle =>
      'Your previous sessions have ended. Start a new one to keep coding.';

  @override
  String get reviewEnjoyingApp => 'Enjoying the app?';

  @override
  String get reviewFeedbackPrompt => 'We\'d love to hear your feedback!';

  @override
  String get reviewYesILoveIt => 'Yes, I love it!';

  @override
  String get reviewNotReally => 'Not really';

  @override
  String itemsCopiedToClipboard(String label) {
    return '$label copied to clipboard';
  }

  @override
  String messageSwitchedToMode(String mode) {
    return 'Switched to $mode mode';
  }

  @override
  String get messageUnknownEvent => 'Unknown event';

  @override
  String messageUsageLimitUntil(Object time) {
    return 'Usage limit reached until $time';
  }

  @override
  String get messageUnknownTime => 'unknown time';

  @override
  String get codexPermissionsYesForSession =>
      'Yes, and don\'t ask for a session';

  @override
  String get codexPermissionsStopAndExplain => 'Stop, and explain what to do';

  @override
  String get claudePermissionsYesAllowAllEdits =>
      'Yes, allow all edits during this session';

  @override
  String get claudePermissionsYesForTool =>
      'Yes, don\'t ask again for this tool';

  @override
  String get claudePermissionsNoTellClaude => 'No, and provide feedback';

  @override
  String get textSelectionSelectText => 'Select text range';

  @override
  String get textSelectionTitle => 'Select Text';

  @override
  String get textSelectionNoTextProvided => 'No text provided';

  @override
  String get textSelectionTextNotFound => 'Text not found or expired';

  @override
  String get textSelectionTextCopied => 'Text copied to clipboard';

  @override
  String get textSelectionFailedToCopy => 'Failed to copy text to clipboard';

  @override
  String get textSelectionNoTextToCopy => 'No text available to copy';

  @override
  String get markdownCodeCopied => 'Code copied';

  @override
  String get markdownCopyFailed => 'Copy failed';

  @override
  String get markdownMermaidRenderFailed => 'Failed to render mermaid diagram';

  @override
  String get artifactsTitle => 'Artifacts';

  @override
  String get artifactsCountSingular => '1 artifact';

  @override
  String artifactsCountPlural(int count) {
    return '$count artifacts';
  }

  @override
  String get artifactsEmpty => 'No artifacts yet';

  @override
  String get artifactsEmptyDescription =>
      'Create your first artifact to get started';

  @override
  String get artifactsNew => 'New Artifact';

  @override
  String get artifactsEdit => 'Edit Artifact';

  @override
  String get artifactsDelete => 'Delete';

  @override
  String get artifactsUpdateError =>
      'Failed to update artifact. Please try again.';

  @override
  String get artifactsNotFound => 'Artifact not found';

  @override
  String get artifactsDiscardChanges => 'Discard changes?';

  @override
  String get artifactsDiscardChangesDescription =>
      'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get artifactsDeleteConfirm => 'Delete artifact?';

  @override
  String get artifactsDeleteConfirmDescription =>
      'This action cannot be undone';

  @override
  String get artifactsTitleLabel => 'TITLE';

  @override
  String get artifactsTitlePlaceholder => 'Enter a title for your artifact';

  @override
  String get artifactsBodyLabel => 'CONTENT';

  @override
  String get artifactsBodyPlaceholder => 'Write your content here...';

  @override
  String get artifactsEmptyFieldsError => 'Please enter a title or content';

  @override
  String get artifactsCreateError =>
      'Failed to create artifact. Please try again.';

  @override
  String get artifactsSave => 'Save';

  @override
  String get artifactsSaving => 'Saving...';

  @override
  String get artifactsLoading => 'Loading artifacts...';

  @override
  String get artifactsError => 'Failed to load artifact';

  @override
  String get usageToday => 'Today';

  @override
  String get usageLast7Days => 'Last 7 days';

  @override
  String get usageLast30Days => 'Last 30 days';

  @override
  String get usageTotalTokens => 'Total Tokens';

  @override
  String get usageTotalCost => 'Total Cost';

  @override
  String get usageTokens => 'Tokens';

  @override
  String get usageCost => 'Cost';

  @override
  String get usageUsageOverTime => 'Usage over time';

  @override
  String get usageByModel => 'By Model';

  @override
  String get usageNoData => 'No usage data available';

  @override
  String get offlineBannerNoConnection => 'No internet connection';

  @override
  String get offlineBannerReconnecting => 'Reconnecting...';

  @override
  String offlineBannerReconnectingIn(int seconds) {
    return 'Reconnecting in ${seconds}s…';
  }

  @override
  String get offlineBannerReconnectNow => 'Reconnect now';

  @override
  String get commonVersion => 'Version';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonCopyCode => 'Copy code';

  @override
  String get commonFile => 'File';

  @override
  String get commonFolder => 'Folder';

  @override
  String get commonCmd => 'Cmd';

  @override
  String get authSubtitle => 'Scan QR code to connect';

  @override
  String get authScanQR => 'Scan QR Code';

  @override
  String get authEnterToken => 'Enter Token Manually';

  @override
  String get authServerUrlHint => 'Server URL';

  @override
  String get authTokenHint => 'Authentication Token';

  @override
  String get authConnect => 'Connect';

  @override
  String get authConnecting => 'Connecting...';

  @override
  String get authInvalidQR => 'Invalid QR code';

  @override
  String get authServerConnectionError => 'Cannot connect to server';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsNew => 'New Session';

  @override
  String get sessionsEmpty => 'No sessions yet';

  @override
  String get sessionsCreateFirst => 'Create your first session to get started';

  @override
  String get sessionsToday => 'Today';

  @override
  String get sessionsYesterday => 'Yesterday';

  @override
  String get sessionsThisWeek => 'This Week';

  @override
  String get sessionsThisMonth => 'This Month';

  @override
  String get sessionsOlder => 'Older';

  @override
  String get dateGroupToday => 'Today';

  @override
  String get dateGroupYesterday => 'Yesterday';

  @override
  String get dateGroupThisWeek => 'This Week';

  @override
  String get dateGroupThisMonth => 'This Month';

  @override
  String get dateGroupOlder => 'Older';

  @override
  String get sessionsActiveSessions => 'ACTIVE SESSIONS';

  @override
  String get sessionsNeedsAttention => 'NEEDS ATTENTION';

  @override
  String get sessionsAllSessions => 'ALL SESSIONS';

  @override
  String get sessionsArchivedLabel => 'Archived';

  @override
  String sessionsShowArchived(int count) {
    return 'Show archived ($count)';
  }

  @override
  String get sessionsHideArchived => 'Hide archived';

  @override
  String sessionsShowOlderArchived(int count) {
    return 'Show older archived ($count)';
  }

  @override
  String get sessionsHideOlderArchived => 'Hide older archived';

  @override
  String get sessionsArchive => 'Archive';

  @override
  String get sessionsArchiveSession => 'Archive Session';

  @override
  String get sessionsSimple => 'Simple';

  @override
  String get sessionsWorktree => 'Worktree';

  @override
  String get sessionsClaude => 'Claude';

  @override
  String get sessionsCodex => 'Codex';

  @override
  String get sessionsGemini => 'Gemini';

  @override
  String get sessionsPi => 'pi';

  @override
  String get sessionsOpencode => 'OpenCode';

  @override
  String get sessionsType => 'Type';

  @override
  String get sessionsAgent => 'Agent';

  @override
  String get sessionsSelectAll => 'Select All';

  @override
  String get sessionsDeselectAll => 'Deselect All';

  @override
  String get sessionsPin => 'Pin';

  @override
  String get sessionsUnpin => 'Unpin';

  @override
  String get sessionsFolders => 'Session Folders';

  @override
  String get sessionsFoldersEmpty =>
      'No folders yet. Create one to organize your sessions.';

  @override
  String get sessionsFoldersAdd => 'Add Folder';

  @override
  String get sessionsFoldersName => 'Folder name';

  @override
  String sessionsFoldersDeleteConfirm(String name) {
    return 'Delete folder \"$name\"? Sessions in this folder will become unfiled.';
  }

  @override
  String get sessionsFoldersRename => 'Rename Folder';

  @override
  String sessionsFolderActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String sessionsFolderArchivedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archived',
      one: '1 archived',
    );
    return '$_temp0';
  }

  @override
  String get sessionsViewStyleClassic => 'Classic list';

  @override
  String get sessionsViewStyleFolderCentric => 'Folder-centric';

  @override
  String get sessionsViewStyleUnreadFocus => 'Unread Focus';

  @override
  String get sessionsViewStyleBeaconGrid => 'Beacon Grid';

  @override
  String get sessionsViewStyleCommandPalette => 'Command Palette';

  @override
  String get sessionsViewStyleSwipe => 'Swipe Actions';

  @override
  String get autoArchiveTitle => 'Auto-Archive';

  @override
  String get autoArchiveSection => 'Auto-Archive';

  @override
  String get autoArchiveAfterDays => 'Archive after days';

  @override
  String get autoArchiveAfterDaysDesc => 'Archive sessions older than N days';

  @override
  String get autoArchiveIdleAfterDays => 'Archive idle after days';

  @override
  String get autoArchiveIdleAfterDaysDesc =>
      'Archive sessions with no activity for N days';

  @override
  String get autoArchiveOnClose => 'Archive on app close';

  @override
  String get autoArchiveOnCloseDesc =>
      'Automatically archive matching sessions when the app closes';

  @override
  String get autoArchiveDisabled => 'Disabled';

  @override
  String get autoArchiveDays => 'days';

  @override
  String get sessionsRecentTitle => 'Recent Sessions';

  @override
  String get sessionsRecentEmpty => 'No recent sessions';

  @override
  String get sessionsPressBackToExit => 'Press back again to exit';

  @override
  String get sessionsFailedToArchive => 'Failed to archive session';

  @override
  String get sessionsFailedToDelete => 'Failed to delete session';

  @override
  String get messageDetailTitle => 'Message';

  @override
  String get toolDetailsTitle => 'Tool Details';

  @override
  String get sessionInfoNotFound => 'Session not found';

  @override
  String get messageNotFound => 'Message not found';

  @override
  String get messageDetailContent => 'Content';

  @override
  String get messageDetailDetails => 'Message Details';

  @override
  String get messageDetailNoDetails => 'No details available';

  @override
  String get messageDetailModel => 'Model';

  @override
  String get messageDetailSent => 'Sent';

  @override
  String get messageDetailMessageId => 'Message ID';

  @override
  String get messageDetailSeq => 'Seq';

  @override
  String get messageDetailTimestamp => 'Timestamp';

  @override
  String get messageDetailDebugData => 'Debug Data';

  @override
  String get commonNA => 'N/A';

  @override
  String get messageDetailPermission => 'Permission';

  @override
  String get messageDetailStatus => 'Status';

  @override
  String get messageDetailReason => 'Reason';

  @override
  String get messageDetailInput => 'Input';

  @override
  String get messageDetailOutput => 'Output';

  @override
  String get messageDetailSubagentTools => 'Sub-agent Tools';

  @override
  String get messageDetailTool => 'Tool';

  @override
  String get messageDetailState => 'State';

  @override
  String get messageDetailAgentType => 'Agent type';

  @override
  String get messageDetailDescription => 'Description';

  @override
  String get messageDetailShare => 'Share';

  @override
  String get messageDetailBookmark => 'Bookmark';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard';

  @override
  String get accountBackupKeyLabel => 'Backup Key';

  @override
  String get accountBackupKeyHint => 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get accountEnterBackupKey => 'Please enter your backup key';

  @override
  String get commonUnsavedChangesTitle => 'Unsaved Changes';

  @override
  String get chatUnsentMessageTitle => 'Unsent Message';

  @override
  String get chatStay => 'Stay';

  @override
  String get chatLeave => 'Leave';

  @override
  String get sessionsGroupByDate => 'Group by date';

  @override
  String get pickSelectMachine => 'Select Machine';

  @override
  String get pickSelectProfile => 'Select Profile';

  @override
  String get pickSelectPath => 'Select Path';

  @override
  String get pickNoMachinesAvailable => 'No machines available';

  @override
  String get pickRecent => 'Recent';

  @override
  String get pickAllMachines => 'All Machines';

  @override
  String get chatInputHint => 'Message...';

  @override
  String get chatInputProfileTitle => 'Profile';

  @override
  String get chatInputProfileDefault => 'Default';

  @override
  String get chatInputProfileDefaultSubtitle => 'Server-configured defaults';

  @override
  String get chatEmpty => 'Start a conversation';

  @override
  String get chatSend => 'Send';

  @override
  String get chatCopyMessage => 'Copy';

  @override
  String get chatDeleteMessage => 'Delete';

  @override
  String get chatClearSession => 'Clear Session';

  @override
  String get chatConfirmClear => 'Are you sure you want to clear this session?';

  @override
  String get chatActionConfirm => 'Confirm Action';

  @override
  String get chatActionReject => 'Reject';

  @override
  String get chatActionAccept => 'Accept';

  @override
  String get chatChat => 'Chat';

  @override
  String get chatChatLoading => 'Loading...';

  @override
  String get chatFailedToLoadMessages => 'Failed to load messages';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get noLanguagesFound => 'No languages found';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerNotReachable => 'Server not reachable';

  @override
  String get settingsVoice => 'Voice';

  @override
  String get settingsLogout => 'Logout';

  @override
  String get settingsLogoutConfirm => 'Are you sure you want to logout?';

  @override
  String get settingsLogs => 'Logs';

  @override
  String get settingsVersion => 'Version';

  @override
  String get profilesDeleteTitle => 'Delete Profile';

  @override
  String get profilesFailedToSave => 'Failed to save profile';

  @override
  String profilesDuplicated(String name) {
    return 'Profile \"$name\" duplicated';
  }

  @override
  String get usageTitle => 'Usage';

  @override
  String get timePeriod => 'Time Period';

  @override
  String get totals => 'Totals';

  @override
  String get byModel => 'By Model';

  @override
  String get statistics => 'Statistics';

  @override
  String get today => 'Today';

  @override
  String get sevenDays => '7 Days';

  @override
  String get thirtyDays => '30 Days';

  @override
  String get totalTokens => 'Total Tokens';

  @override
  String get totalCost => 'Total Cost';

  @override
  String get reports => 'Reports';

  @override
  String get avgCostPerDay => 'Avg. Cost/Day';

  @override
  String get avgTokensPerDay => 'Avg. Tokens/Day';

  @override
  String get noUsageData => 'No usage data';

  @override
  String get noUsageDataSubtitle => 'Start using Happy to see your usage stats';

  @override
  String get failedToLoad => 'Failed to load usage data';

  @override
  String get claudeCodeLimits => 'Claude Code Limits';

  @override
  String get claudeLimitsTitle => 'Claude Code Limits';

  @override
  String get claudeLimitsUsage => 'Usage';

  @override
  String get codexUsageTitle => 'Codex Usage';

  @override
  String get codexUsageSubtitle =>
      'Rate limits and credits for Codex on your machines';

  @override
  String get codexUsageAccount => 'Account';

  @override
  String get codexUsageEmail => 'Email';

  @override
  String get codexUsagePlan => 'Plan';

  @override
  String get codexUsageSessionLimits => 'Usage';

  @override
  String get codexUsageCodeReview => 'Code Review';

  @override
  String get codexUsageFiveHourWindow => '5-hour window';

  @override
  String get codexUsageWeeklyWindow => 'Weekly window';

  @override
  String get codexUsagePrimaryWindow => 'Primary window';

  @override
  String get codexUsageSecondaryWindow => 'Secondary window';

  @override
  String get codexUsageCredits => 'Credits';

  @override
  String get codexUsageCreditsBalance => 'Credits Balance';

  @override
  String get codexUsageCreditsAvailable => 'Credits Available';

  @override
  String get codexUsageUnlimited => 'Unlimited';

  @override
  String get codexUsageNoMachines => 'No machines available';

  @override
  String get codexUsageSelectMachine => 'Machine';

  @override
  String get claudeLimitsResetsAt => 'Resets';

  @override
  String get claudeLimitsExtraUsage => 'Extra Usage';

  @override
  String get claudeLimitsMonthlyLimit => 'Monthly Limit';

  @override
  String get claudeLimitsUsedCredits => 'Used Credits';

  @override
  String get claudeLimitsNoMachines => 'No machines available';

  @override
  String get claudeLimitsSelectMachine => 'Machine';

  @override
  String get featuresExperiments => 'Experiments';

  @override
  String get featuresExperimentsDesc => 'Try experimental features';

  @override
  String get settingsServerResetSuccess => 'Server URL reset to default';

  @override
  String get settingsServerSaved => 'Server URL saved';

  @override
  String get settingsServerSaveVerify => 'Save & Verify';

  @override
  String get settingsOnline => 'Online';

  @override
  String get settingsOffline => 'Offline';

  @override
  String get toolViewFullContent => 'View full content';

  @override
  String get toolEdit => 'Edit';

  @override
  String get toolRead => 'Read';

  @override
  String get toolWrite => 'Write';

  @override
  String get toolBash => 'Bash';

  @override
  String get toolGlob => 'Glob';

  @override
  String get toolGrep => 'Grep';

  @override
  String get toolLs => 'List Files';

  @override
  String get toolPatch => 'Patch';

  @override
  String get toolDiff => 'Diff';

  @override
  String get toolSectionDiff => 'DIFF';

  @override
  String get toolSectionContent => 'CONTENT';

  @override
  String get toolSectionCommand => 'COMMAND';

  @override
  String get toolSectionReading => 'Reading';

  @override
  String get toolSectionWriting => 'Writing';

  @override
  String get toolSectionInput => 'INPUT';

  @override
  String get toolSectionOutput => 'OUTPUT';

  @override
  String get toolTask => 'Task';

  @override
  String get toolTodo => 'Todo';

  @override
  String get toolWebFetch => 'Web Fetch';

  @override
  String get toolWebSearch => 'Web Search';

  @override
  String get toolExitPlan => 'Exit Plan';

  @override
  String get toolAskUser => 'Ask User';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionDeny => 'Deny';

  @override
  String get permissionStop => 'Stop';

  @override
  String get permissionYes => 'Yes';

  @override
  String get permissionDefault => 'Default';

  @override
  String get permissionAcceptEdits => 'Accept Edits';

  @override
  String get permissionPlan => 'Plan Mode';

  @override
  String get permissionYolo => 'YOLO';

  @override
  String get permissionReadOnly => 'Read Only';

  @override
  String get permissionSafeYolo => 'Safe Yolo';

  @override
  String get permissionRequired => 'Permission required';

  @override
  String get permissionApproved => 'Approved';

  @override
  String get permissionDeniedLabel => 'Denied';

  @override
  String get permissionSessionOffline => 'Session offline';

  @override
  String get permissionAllEdits => 'All edits';

  @override
  String get permissionForSession => 'For session';

  @override
  String get permissionActionFailed => 'Permission action failed';

  @override
  String get permissionModeTitle => 'Permission Mode';

  @override
  String get permissionModeDefault => 'Default';

  @override
  String get permissionModeAcceptEdits => 'Accept Edits';

  @override
  String get permissionModePlan => 'Plan';

  @override
  String get permissionModeBypass => 'Yolo';

  @override
  String get permissionModeReadOnly => 'Read-only';

  @override
  String get permissionModeSafeYolo => 'Safe YOLO';

  @override
  String get permissionModeYolo => 'YOLO';

  @override
  String get permissionModeDefaultDesc => 'Ask for permissions';

  @override
  String get permissionModeAcceptEditsDesc => 'Auto-approve edits';

  @override
  String get permissionModePlanDesc => 'Plan before executing';

  @override
  String get permissionModeBypassDesc => 'Skip all permissions';

  @override
  String get permissionModeReadOnlyDesc => 'Read-only mode';

  @override
  String get permissionModeSafeYoloDesc => 'Safe YOLO mode';

  @override
  String get permissionModeYoloDesc => 'YOLO mode';

  @override
  String get voiceAssistantActive => 'Voice assistant active';

  @override
  String get voiceAssistantConnecting => 'Connecting...';

  @override
  String get voiceAssistantDefault => 'Voice';

  @override
  String get voiceAssistantTapToEnd => 'Tap to end';

  @override
  String get transcriptionInitializing => 'Setting up transcription...';

  @override
  String get transcriptionReady => 'Transcription ready';

  @override
  String get transcriptionUnavailable => 'Transcription unavailable';

  @override
  String get authClientError => 'Client Error';

  @override
  String get authServerError => 'Server Error';

  @override
  String get authCertificateError => 'Certificate Error';

  @override
  String get authConnectionFailed => 'Connection Failed';

  @override
  String get authServerSettings => 'Server Settings';

  @override
  String get authLinkAccount => 'Link Account';

  @override
  String get authTryAgain => 'Try Again';

  @override
  String get authSecretKeyLabel => 'Secret Key';

  @override
  String get authPaste => 'Paste';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get voiceAssistantError => 'Voice assistant error';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeAdaptive => 'Adaptive';

  @override
  String get appearanceThemeAdaptiveDesc => 'Match system settings';

  @override
  String get appearanceThemeLight => 'Light';

  @override
  String get appearanceThemeLightDesc => 'Always use light theme';

  @override
  String get appearanceThemeDark => 'Dark';

  @override
  String get appearanceThemeDarkDesc => 'Always use dark theme';

  @override
  String appearanceThemeApplied(String theme) {
    return '$theme theme applied';
  }

  @override
  String get appearanceThemePreview => 'Preview';

  @override
  String get appearanceThemeDarkModeActive => 'Dark mode active';

  @override
  String get appearanceThemeLightModeActive => 'Light mode active';

  @override
  String get appearanceThemeSampleContent => 'Sample content';

  @override
  String get appearanceThemeColorPrimary => 'Primary';

  @override
  String get appearanceThemeColorSecondary => 'Secondary';

  @override
  String get searchLanguages => 'Search languages';

  @override
  String get settingsBehavior => 'Behavior';

  @override
  String get settingsViewInline => 'View Inline';

  @override
  String get settingsViewInlineSubtitle => 'Show tool calls inline in chat';

  @override
  String get settingsHideToolCalls => 'Hide Tool Calls';

  @override
  String get settingsHideToolCallsSubtitle =>
      'Hide tool call rows in chat while keeping permission prompts visible';

  @override
  String get settingsExpandTodos => 'Expand Todos';

  @override
  String get settingsShowLineNumbers => 'Show Line Numbers';

  @override
  String get settingsCompactSessionView => 'Compact Session View';

  @override
  String get settingsShowFlavorIcons => 'Show Flavor Icons';

  @override
  String get settingsAvatarStyle => 'Avatar Style';

  @override
  String get settingsWrapLinesInDiffs => 'Wrap Lines in Diffs';

  @override
  String get userProfileTitle => 'User Profile';

  @override
  String get userNotFound => 'User not found';

  @override
  String get accountAccountSettings => 'Account Settings';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountBackupKey => 'Backup Key';

  @override
  String get accountShowBackupKey => 'Show Backup Key';

  @override
  String get accountCopyBackupKey => 'Copy Backup Key';

  @override
  String get accountCopyToClipboard => 'Copy to clipboard';

  @override
  String get accountRestore => 'Restore';

  @override
  String get accountRestoreAccount => 'Restore Account';

  @override
  String get accountDevices => 'Devices';

  @override
  String get accountLinkedDevices => 'Linked Devices';

  @override
  String get accountLinkNewDevice => 'Link New Device';

  @override
  String get accountConnectedServices => 'Connected Services';

  @override
  String get accountBackupKeyCopied => 'Backup key copied';

  @override
  String get accountNotConnected => 'Not connected';

  @override
  String get accountName => 'Name';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountPasteFromClipboard => 'Paste from Clipboard';

  @override
  String get accountRestoredSuccess => 'Account restored successfully';

  @override
  String get accountLinkDevice => 'Link Device';

  @override
  String get accountScanQR => 'Scan QR';

  @override
  String get accountShowQR => 'Show QR';

  @override
  String get accountEnterUrl => 'Enter URL';

  @override
  String get accountApproveLinking => 'Approve Linking';

  @override
  String get accountUnlinkDevice => 'Unlink Device';

  @override
  String get accountUnlink => 'Unlink';

  @override
  String get accountFailedToUnlink => 'Failed to unlink device';

  @override
  String get accountScanHint => 'New device: tap \"Link or Restore Account\"';

  @override
  String get accountThisDevice => 'This Device';

  @override
  String get settingsCertificates => 'Certificates';

  @override
  String get settingsUserCaCertificates => 'User CA Certificates';

  @override
  String get settingsNoUserCertificates => 'No user certificates installed';

  @override
  String get chatOnline => 'Online';

  @override
  String get chatConversationCleared => 'Conversation cleared';

  @override
  String get chatMoreOptions => 'More options';

  @override
  String get settingsClaudeCode => 'Claude Code';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsTextToSpeech => 'Text-to-Speech';

  @override
  String get settingsGitHub => 'GitHub';

  @override
  String get settingsDeveloperEnabled => 'Enabled';

  @override
  String get featuresTitle => 'Features';

  @override
  String get devLogsTitle => 'Logs';

  @override
  String devLogsCount(int count) {
    return 'Logs ($count)';
  }

  @override
  String devLogsCountFiltered(int count) {
    return 'Logs ($count filtered)';
  }

  @override
  String get devLogsEmpty => 'No logs yet';

  @override
  String get devLogsClearFilter => 'Clear Filter';

  @override
  String get devLogsNoLogsToCopy => 'No logs to copy';

  @override
  String get devLogsClearTitle => 'Clear Logs';

  @override
  String get devLogsClearAction => 'Clear';

  @override
  String get devLogsSearchTitle => 'Search Logs';

  @override
  String get devLogsSearchHint => 'Enter search term...';

  @override
  String get devLogsAllLevels => 'All Levels';

  @override
  String get devLogsLevelDebug => 'Debug';

  @override
  String get devLogsLevelInfo => 'Info';

  @override
  String get devLogsLevelWarning => 'Warning';

  @override
  String get devLogsLevelError => 'Error';

  @override
  String get devLogsLogEntryCopied => 'Log entry copied';

  @override
  String get devLogsCopyEntry => 'Copy Entry';

  @override
  String get devLogsAddTestLog => 'Add Test Log';

  @override
  String get devLogsCopyAllLogs => 'Copy All Logs';

  @override
  String get devLogsFilterByLevel => 'Filter by Level';

  @override
  String get devLogsSearchLogs => 'Search Logs';

  @override
  String get networkInspectorClearTitle => 'Clear Request Log';

  @override
  String get networkInspectorEntryCopied => 'Entry copied';

  @override
  String get developerTitle => 'Developer';

  @override
  String get developerClearCache => 'Clear Cache';

  @override
  String get developerResetSettings => 'Reset Settings';

  @override
  String get developerModeTitle => 'Developer Mode';

  @override
  String get developerModeEnabledDesc => 'Enabled - Debug tools are visible';

  @override
  String get developerNotYetImplemented => 'Not yet implemented';

  @override
  String get developerClearCacheAction => 'Clear';

  @override
  String get developerCacheCleared => 'Cache cleared';

  @override
  String get developerResetAction => 'Reset';

  @override
  String get developerSettingsReset => 'Settings reset';

  @override
  String get developerSectionDebugTools => 'Debug Tools';

  @override
  String get developerSectionTesting => 'Testing';

  @override
  String get developerSectionCacheStorage => 'Cache & Storage';

  @override
  String get developerSectionSync => 'Sync';

  @override
  String get developerSectionBuildInfo => 'Build Info';

  @override
  String get developerNetworkInspector => 'Network Inspector';

  @override
  String get developerLogsDesc => 'View application logs';

  @override
  String get developerEncryptionDebug => 'Encryption Debug';

  @override
  String get developerSessionDebug => 'Session Debug';

  @override
  String get developerTestNotifications => 'Test Notifications';

  @override
  String get developerTestSentryException => 'Test Sentry (Exception)';

  @override
  String get developerTestSentryUnhandled => 'Test Sentry (Unhandled)';

  @override
  String get developerTestSentryUnhandledDesc => 'Throw an unhandled error';

  @override
  String get developerClearCacheDesc => 'Clear cached data';

  @override
  String get developerResetSettingsDesc => 'Reset all settings to defaults';

  @override
  String get developerForceSyncSettings => 'Re-sync Settings';

  @override
  String get developerForceSyncSettingsDesc =>
      'Re-fetch settings from the server';

  @override
  String get developerForceSyncSettingsConfirm =>
      'Are you sure you want to re-sync settings from the server?';

  @override
  String get developerForceSyncSettingsAction => 'Re-sync';

  @override
  String get developerForceSyncSettingsSuccess => 'Settings re-synced';

  @override
  String get developerForceSyncSettingsError => 'Failed to re-sync settings';

  @override
  String get developerAppVersion => 'App Version';

  @override
  String get developerBuildNumber => 'Build Number';

  @override
  String get developerFlutterVersion => 'Flutter Version';

  @override
  String get developerDartVersion => 'Dart Version';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesNone => 'None';

  @override
  String get profilesDefaultDescription => 'Use default configuration';

  @override
  String get profilesCustomTitle => 'Custom Profiles';

  @override
  String get profilesProfileName => 'Profile Name';

  @override
  String get profilesAddProfile => 'Add Profile';

  @override
  String get profilesEditProfile => 'Edit Profile';

  @override
  String get profilesDeleteProfile => 'Delete Profile';

  @override
  String get profilesNameHint => 'e.g. MiniMax, Kimi Code, DeepSeek';

  @override
  String get profilesNameRequired => 'Name is required';

  @override
  String get profilesDescriptionLabel => 'Description (optional)';

  @override
  String get profilesEnvVarsTitle => 'Environment Variables';

  @override
  String get profilesEnvKeyLabel => 'Key';

  @override
  String get profilesEnvKeyHint => 'VARIABLE_NAME';

  @override
  String get profilesEnvValueLabel => 'Value';

  @override
  String get profilesScriptTitle => 'Startup Shell Script';

  @override
  String get profilesScriptLabel => 'Bash script';

  @override
  String get profilesImportTitle => 'Import from Shell Script';

  @override
  String get profilesImportButton => 'Import';

  @override
  String get profilesImportLabel => 'Shell script content';

  @override
  String get profilesImportParsed => 'Parsed environment variables';

  @override
  String get profilesImportLabelShort => 'Import from script';

  @override
  String get profilesQuickSetup => 'Quick Setup';

  @override
  String get profilesWizardTitle => 'New AI Profile';

  @override
  String get profilesWizardStep1 => 'Choose Provider';

  @override
  String get profilesWizardStep1Subtitle => 'Select your AI provider';

  @override
  String get profilesWizardStep2 => 'Configure';

  @override
  String get profilesWizardStep2Subtitle => 'Enter API key and settings';

  @override
  String get profilesWizardStep3 => 'Review';

  @override
  String get profilesWizardStep3Subtitle => 'Confirm your settings';

  @override
  String get profilesWizardSelectProvider => 'Select a provider to get started';

  @override
  String get profilesWizardBaseUrl => 'Base URL';

  @override
  String get profilesWizardModel => 'Model';

  @override
  String get profilesWizardSmallFastModel => 'Small Fast Model';

  @override
  String get profilesWizardTimeout => 'Timeout (ms)';

  @override
  String get profilesWizardTimeoutHelp => 'Optional - defaults to 300000ms';

  @override
  String get changelogTitle => 'What\'s New';

  @override
  String get changelogOpenGitHub => 'Open GitHub Releases';

  @override
  String get serverTitle => 'Server';

  @override
  String get voiceTitle => 'Voice';

  @override
  String get voiceLanguageTitle => 'Voice Language';

  @override
  String get voiceTtsTitle => 'Text-to-Speech';

  @override
  String get voiceTtsSubtitle => 'Read assistant messages aloud';

  @override
  String get voiceTestTts => 'Test TTS';

  @override
  String get voiceTestTtsSubtitle => 'Tap to hear a test phrase';

  @override
  String get voiceSelectEngineHint => 'Select the TTS engine.';

  @override
  String get voiceDefaultEngine => 'Default Engine';

  @override
  String get voiceDefaultEngineSubtitle => 'Use system default';

  @override
  String get voiceSelectLanguageTitle => 'Select Language';

  @override
  String voiceLanguagesCount(int count) {
    return '$count languages available';
  }

  @override
  String get claudeConnectTitle => 'Connect Claude API';

  @override
  String get claudeConnectTerminalTitle => 'Connect Claude';

  @override
  String get claudeConnectManualLabel => 'MANUAL API KEY ENTRY';

  @override
  String get claudeConnectApiKeyLabel => 'API Key';

  @override
  String get claudeConnectApiKeyHint => 'sk-ant-...';

  @override
  String get claudeConnectBaseUrlLabel => 'Base URL (optional)';

  @override
  String get claudeConnectBaseUrlHint => 'https://api.anthropic.com';

  @override
  String get claudeConnectButton => 'Connect';

  @override
  String get sessionFilesTitle => 'Files';

  @override
  String get sessionFilesNotFound => 'Session not found';

  @override
  String get sessionFilesEmpty => 'No files yet';

  @override
  String get sessionInfoCopied => 'Copied to clipboard';

  @override
  String get sessionInfoUpdateCommandCopied => 'Update command copied';

  @override
  String get sessionInfoCliOutdated => 'CLI Version Outdated';

  @override
  String get sessionInfoSectionDetails => 'Session Details';

  @override
  String get sessionInfoLabelSessionId => 'Session ID';

  @override
  String get sessionInfoLabelCreated => 'Created';

  @override
  String get sessionInfoLabelLastUpdated => 'Last Updated';

  @override
  String get sessionInfoLabelSequence => 'Sequence';

  @override
  String get sessionInfoSectionQuickActions => 'Quick Actions';

  @override
  String get sessionInfoActionViewMachine => 'View Machine';

  @override
  String get sessionInfoActionArchive => 'Archive Session';

  @override
  String get sessionInfoActionDelete => 'Delete Session';

  @override
  String get sessionInfoSectionMetadata => 'Metadata';

  @override
  String get sessionInfoLabelHost => 'Host';

  @override
  String get sessionInfoLabelPath => 'Path';

  @override
  String get sessionInfoLabelMachineId => 'Machine ID';

  @override
  String get sessionInfoLabelCliVersion => 'CLI Version';

  @override
  String get sessionInfoLabelAiProvider => 'AI Provider';

  @override
  String get sessionInfoLabelClaudeSessionId => 'Claude Code Session ID';

  @override
  String get sessionInfoLabelProcessId => 'Process ID';

  @override
  String get sessionInfoLabelHappyHome => 'Happy Home';

  @override
  String get sessionInfoLabelOs => 'OS';

  @override
  String get sessionInfoActionCopyMetadata => 'Copy Metadata';

  @override
  String get sessionInfoSectionAgentState => 'Agent State';

  @override
  String get sessionInfoLabelControlledByUser => 'Controlled by user';

  @override
  String get sessionInfoLabelPendingRequests => 'Pending requests';

  @override
  String get sessionInfoSectionActivity => 'Activity';

  @override
  String get sessionInfoLabelThinking => 'Thinking';

  @override
  String get sessionInfoLabelThinkingSince => 'Thinking since';

  @override
  String get sessionInfoSectionTools => 'Tools';

  @override
  String get sessionInfoActive => 'Active';

  @override
  String get sessionInfoInactive => 'Inactive';

  @override
  String get commonId => 'ID';

  @override
  String get commonCreated => 'Created';

  @override
  String get commonUpdated => 'Updated';

  @override
  String get commonSequence => 'Sequence';

  @override
  String get artifactsContentLabel => 'CONTENT';

  @override
  String get artifactsDetail => 'Artifact';

  @override
  String get artifactsStatus => 'Status';

  @override
  String get artifactsDraft => 'Draft';

  @override
  String get artifactsFailedToDelete => 'Failed to delete artifact';

  @override
  String get artifactsFailedToSave => 'Failed to save artifact';

  @override
  String get artifactsFailedToCreate => 'Failed to create artifact';

  @override
  String get artifactsSearchHint => 'Search artifacts...';

  @override
  String get artifactsNoResults => 'No matching artifacts';

  @override
  String get machineHomeDir => 'Home Dir';

  @override
  String get machineInfo => 'Info';

  @override
  String get machineRunning => 'Running';

  @override
  String get machineStopped => 'Stopped';

  @override
  String get machineRemoveMachine => 'Remove Machine';

  @override
  String get machineOnline => 'Online';

  @override
  String get machineOffline => 'Offline';

  @override
  String get machineConnectedNow => 'Connected now';

  @override
  String machineLastSeenAt(String time) {
    return 'Last seen $time';
  }

  @override
  String machineSessions(int count) {
    return 'Sessions ($count)';
  }

  @override
  String get terminalSelectMachineHint => 'Select machine';

  @override
  String get terminalSelectMachineError => 'Please select a machine';

  @override
  String get terminalIdLabel => 'TERMINAL / SESSION ID';

  @override
  String get terminalIdHint => 'e.g. main, dev, 1234';

  @override
  String get terminalDisconnect => 'Disconnect';

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalSendCommand => 'Send command';

  @override
  String get commonClear => 'Clear';

  @override
  String get sessionsClearSearch => 'Clear search';

  @override
  String get commonUnknown => 'unknown';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonGoHome => 'Go Home';

  @override
  String get commonPressBackAgainToExit => 'Press back again to exit';

  @override
  String get commonUnsavedChanges => 'Unsaved Changes';

  @override
  String get commonLeave => 'Leave';

  @override
  String get commonStay => 'Stay';

  @override
  String get commonUnsentMessage => 'Unsent Message';

  @override
  String get commonOperationInProgress => 'Operation In Progress';

  @override
  String get terminalEnterCommand => 'Enter command...';

  @override
  String get commandSearchHint => 'Search commands...';

  @override
  String get commandCategorySessions => 'Sessions';

  @override
  String get commandCategoryNavigation => 'Navigation';

  @override
  String get commandCategoryRecent => 'Recent';

  @override
  String get commandNewSessionTitle => 'New Session';

  @override
  String get commandNewSessionSubtitle => 'Start a new chat session';

  @override
  String get commandViewSessionsTitle => 'View All Sessions';

  @override
  String get commandViewSessionsSubtitle => 'Browse your chat history';

  @override
  String get commandSettingsTitle => 'Settings';

  @override
  String get commandSettingsSubtitle => 'Configure your preferences';

  @override
  String get commandAccountTitle => 'Account';

  @override
  String get commandAccountSubtitle => 'Manage your account';

  @override
  String get commandConnectDeviceTitle => 'Connect Device';

  @override
  String get commandConnectDeviceSubtitle => 'Connect a new device via web';

  @override
  String get commandArtifactsTitle => 'Artifacts';

  @override
  String get commandArtifactsSubtitle => 'Browse your artifacts';

  @override
  String get commandTerminalTitle => 'Terminal';

  @override
  String get commandTerminalSubtitle => 'Access terminal sessions';

  @override
  String networkInspectorTitle(int count) {
    return 'Network Inspector ($count)';
  }

  @override
  String get networkInspectorCopyAll => 'Copy all';

  @override
  String get networkInspectorNoRequests => 'No requests yet';

  @override
  String get networkInspectorLabelRequests => 'Requests';

  @override
  String get networkInspectorLabelSent => '↑ Sent';

  @override
  String get networkInspectorLabelReceived => '↓ Received';

  @override
  String get networkInspectorLabelDuration => 'Duration';

  @override
  String get networkInspectorLabelSentBody => 'Sent (body)';

  @override
  String get networkInspectorLabelReceivedBody => 'Received (body)';

  @override
  String developerSentToSentry(String eventId) {
    return 'Sent to Sentry: $eventId';
  }

  @override
  String get chatHowCanIHelpToday => 'How can I help you today?';

  @override
  String get chatSuggestionWriteCode => 'Write code';

  @override
  String get chatSuggestionDebugIssue => 'Debug an issue';

  @override
  String get chatSuggestionExplainCode => 'Explain code';

  @override
  String get chatSuggestionReviewPr => 'Review PR';

  @override
  String get pickRecentPaths => 'Recent Paths';

  @override
  String get pickSuggestedPaths => 'Suggested Paths';

  @override
  String get pickProfileNone => 'None';

  @override
  String get pickProfileNoneDesc => 'Use default configuration';

  @override
  String get pickProfileBuiltInSection => 'BUILT-IN';

  @override
  String get pickProfileCustomSection => 'CUSTOM';

  @override
  String get pickProfileCustomDescription => 'Custom profile';

  @override
  String get agentFallbackDescription => 'Agent';

  @override
  String get agentNoMessages => 'No messages yet';

  @override
  String get agentFallbackTask => 'Task';

  @override
  String get agentsListTitle => 'Agents';

  @override
  String get agentsListEmpty => 'No agents running';

  @override
  String subAgentBannerRunning(int running, int total) {
    return '$running of $total sub-agents running';
  }

  @override
  String subAgentBannerComplete(int total) {
    return '$total sub-agents finished';
  }

  @override
  String subAgentBannerError(int error, int total) {
    return '$error of $total sub-agents failed';
  }

  @override
  String get subAgentBannerTapToOpen => 'Tap to view';

  @override
  String get subAgentBannerIcon => 'Sub-agents';

  @override
  String get fileViewerNoContent => 'No content available';

  @override
  String get artifactsJustNow => 'Just now';

  @override
  String get artifactsYesterday => 'Yesterday';

  @override
  String artifactsMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String artifactsHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String artifactsDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get userFallbackName => 'this user';

  @override
  String get commandCategoryRecentSessions => 'Recent Sessions';

  @override
  String get featuresSectionExperiments => 'Experiments';

  @override
  String get featuresSectionDisplay => 'Display';

  @override
  String get featuresCompactMode => 'Compact Mode';

  @override
  String get featuresShowLineNumbers => 'Show Line Numbers';

  @override
  String get featuresWrapLinesInDiffs => 'Wrap Lines in Diffs';

  @override
  String get serverCheckingConnection => 'Checking connection...';

  @override
  String get serverConnected => 'Connected';

  @override
  String get serverConnectionFailed => 'Connection failed';

  @override
  String get serverVerifyingServer => 'Verifying server...';

  @override
  String get serverCustomUrlSectionLabel => 'CUSTOM SERVER URL';

  @override
  String get machinesNoMachines => 'No machines';

  @override
  String get voiceAutoDetect => 'Auto-detect';

  @override
  String get accountBackupKeyCopiedToClipboard =>
      'Backup key copied to clipboard';

  @override
  String get accountBackupKeyDialogContent =>
      'Save this key in a safe place. You can use it to restore your account.';

  @override
  String get accountInvalidKeyFormat =>
      'Invalid key format. Use XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';

  @override
  String get accountLinkedDevicesSubtitle =>
      'Manage devices linked to your account';

  @override
  String get accountLinkNewDeviceSubtitle =>
      'Generate QR code for another device';

  @override
  String get accountRestoreAccountSubtitle => 'Recover account from backup key';

  @override
  String get accountRestoreInstruction =>
      'Enter your backup key to restore your account.';

  @override
  String get accountScanInstruction =>
      'Point your camera at the QR code displayed on the new device';

  @override
  String get accountShowBackupKeySubtitle => 'View your account recovery key';

  @override
  String get accountShowQRInstructions =>
      '1. Open Happy on the new device\n2. Tap \"Link or Restore Account\"\n3. Scan this QR code';

  @override
  String get accountUnlinkConfirm =>
      'Are you sure you want to unlink this device?';

  @override
  String get artifactsEmptySubtitle =>
      'Create your first artifact using the + button.';

  @override
  String get artifactsEnterContent => 'Enter new content';

  @override
  String get artifactsEnterTitle => 'Enter a new title';

  @override
  String get artifactsEnterTitleOrContent => 'Please enter a title or content.';

  @override
  String get artifactsNoResultsSubtitle => 'Try a different search term.';

  @override
  String get authConnectionError =>
      'Connection failed. Please check your server URL and try again.';

  @override
  String get authDeviceLinkedSuccess => 'Device linked successfully!';

  @override
  String get authErrorDetailsCopied => 'Error details copied';

  @override
  String get authFailedToLinkDevice => 'Failed to link device';

  @override
  String get authInvalidKey =>
      'Invalid key. Use backup key (11 groups), base64, base64url, or 64-char hex.';

  @override
  String get authPleaseEnterSecretKey => 'Please enter a secret key';

  @override
  String get authProcessingDeviceLink => 'Processing device link...';

  @override
  String get authSecretKeyHint => 'Backup key / base64 / hex';

  @override
  String get authSecretKeyInstruction =>
      'Enter backup key (11 groups like XXXXX-XXXXX...), base64/base64url, or 64-char hex key.';

  @override
  String get authServerUrlSaved => 'Server URL saved and applied.';

  @override
  String get authSignInFirst =>
      'Please sign in first to approve device linking';

  @override
  String get authSignInWithSecretKey => 'Sign In with Secret Key';

  @override
  String get authSecretKeyReassurance =>
      'We\'ll never ask for this in email or support chats. Only enter it here.';

  @override
  String get authSecretKeyReassuranceTitle => 'Your key stays private';

  @override
  String get authContinueToKeyInput => 'Enter Secret Key';

  @override
  String get authSomethingWentWrong =>
      'Something went wrong. Please sign in again.';

  @override
  String get authWaitingForApproval => 'Waiting for approval...';

  @override
  String get authApprovalFailedTitle => 'Scan not completed';

  @override
  String get authApprovalFailedBody =>
      'This can happen if the desktop app closed or the request timed out. Try scanning the QR code again.';

  @override
  String get chatBeginningOfConversation => 'Beginning of conversation';

  @override
  String get chatFailedToDeleteSession => 'Failed to delete session';

  @override
  String get chatLastSeenJustNow => 'Last seen just now';

  @override
  String get chatPermissionRequired => 'Permission required';

  @override
  String get chatSuggestionDebugIssueDesc => 'Find and fix a bug in your code';

  @override
  String get chatSuggestionExplainCodeDesc => 'Understand how something works';

  @override
  String get chatSuggestionReviewPrDesc => 'Get feedback on your changes';

  @override
  String get chatSuggestionWriteCodeDesc => 'Generate a function or component';

  @override
  String get chatUnsentMessageContent =>
      'You have an unsent message. Are you sure you want to leave?';

  @override
  String get claudeCodeLimitsSubtitle =>
      'Rate limits for Claude Code on your machines';

  @override
  String get claudeConnectCliInfo =>
      'API key management is handled via the CLI. Run: happy connect claude';

  @override
  String get claudeConnectDisclaimer =>
      'Your API key is stored locally on this device only.';

  @override
  String get claudeConnectManualDesc =>
      'Alternatively, enter your Anthropic API key directly.';

  @override
  String get claudeConnectTerminalSubtitle =>
      'Run the following command in your terminal:';

  @override
  String get claudeLimitsNoMachinesSubtitle =>
      'Connect a machine to check Claude Code limits';

  @override
  String get claudeLimitsNotAvailable => 'Claude Code limits not available';

  @override
  String get claudeLimitsNotAvailableSubtitle =>
      'Make sure Claude Code is installed and authenticated on the selected machine';

  @override
  String get codexUsageNoMachinesSubtitle =>
      'Connect a machine to inspect local Codex usage';

  @override
  String get codexUsageNotAvailable => 'Codex usage not available';

  @override
  String get codexUsageNotAvailableSubtitle =>
      'Make sure Codex has run on the selected machine and Python 3 is available';

  @override
  String get commonOperationInProgressConfirm =>
      'An operation is in progress. Are you sure you want to leave?';

  @override
  String get commonUnsavedChangesContent =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get commonUnsavedChangesMessage =>
      'You have unsaved changes. Are you sure you want to leave?';

  @override
  String get commonUnsentMessageConfirm =>
      'You have an unsent message. Are you sure you want to leave?';

  @override
  String get developerClearCacheConfirm =>
      'Are you sure you want to clear all cached data?';

  @override
  String get developerEncryptionDebugDesc =>
      'View encryption keys and certificates';

  @override
  String get developerModeDisabledDesc => 'Disabled';

  @override
  String get developerNetworkInspectorDesc => 'View API requests and responses';

  @override
  String get developerResetSettingsConfirm =>
      'Are you sure you want to reset all settings to defaults?';

  @override
  String get developerSessionDebugDesc =>
      'View active sessions and connections';

  @override
  String get developerTestNotificationsDesc => 'Send a test push notification';

  @override
  String get developerTestSentryExceptionDesc =>
      'Capture a test exception via Sentry';

  @override
  String get devLogsClearConfirm => 'Are you sure you want to clear all logs?';

  @override
  String get devLogsEmptyDesc => 'Logs will appear here as they are generated';

  @override
  String get devLogsOnlyAvailableInDevMode =>
      'Logs are only available when Developer Mode is enabled.\n\nGo to Settings and enable Developer Mode to view logs.';

  @override
  String get featuresAlwaysShowContextSize => 'Always Show Context Size';

  @override
  String get featuresAlwaysShowContextSizeDesc => 'Show context window usage';

  @override
  String get featuresCompactModeDesc => 'Reduce spacing in chat messages';

  @override
  String get featuresEnhancedSessionWizard => 'Enhanced Session Wizard';

  @override
  String get featuresEnhancedSessionWizardDesc =>
      'Use the improved session creation flow';

  @override
  String get featuresExperimentalTitle => 'Experimental Features';

  @override
  String get featuresHideInactiveSessions => 'Hide Inactive Sessions';

  @override
  String get featuresHideInactiveSessionsDesc =>
      'Hide sessions not used recently';

  @override
  String get featuresShowLineNumbersDesc =>
      'Display line numbers in code blocks';

  @override
  String get featuresWrapLinesInDiffsDesc => 'Wrap long lines in diff views';

  @override
  String get fileViewerContentError => 'The file content could not be loaded.';

  @override
  String get machineLastKnownStatus => 'Last Known Status';

  @override
  String get networkInspectorClearConfirm =>
      'Are you sure you want to clear all requests?';

  @override
  String get networkInspectorCopyInstruction =>
      'Copy the log and send it to developers to investigate network usage.';

  @override
  String get networkInspectorNoRequestsSubtitle =>
      'HTTP requests will appear here as they happen.';

  @override
  String get permissionExpiredNoPending =>
      'Permission expired \\u2014 no longer pending';

  @override
  String get permissionExpiredRestarted =>
      'Permission expired \\u2014 session was restarted';

  @override
  String get pickPathHint => 'Enter path (e.g. /home/user/projects)';

  @override
  String get pickProfileChooseBackend =>
      'Choose an AI backend profile for your session.';

  @override
  String get profilesAddProfileSubtitle =>
      'Start from scratch with empty configuration';

  @override
  String get profilesDescriptionHint =>
      'e.g. MiniMax via OpenAI-compatible API';

  @override
  String get profilesEnvVarsEmpty =>
      'No environment variables. Tap Add to set one.';

  @override
  String get profilesEnvVarsHint =>
      'Set ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, ANTHROPIC_MODEL, etc.';

  @override
  String get profilesImportHint =>
      'Paste the contents of a shell script containing export statements (e.g., setup-hunter-alpha.sh)';

  @override
  String get profilesImportNoVars =>
      'No environment variables found in the script.';

  @override
  String get profilesQuickSetupHint =>
      'Select a provider to pre-fill configuration';

  @override
  String get profilesScriptDescription =>
      'Runs before each session starts. Use to export variables or configure the environment.';

  @override
  String get profilesWizardReviewHint =>
      'Review your settings and tap Save to create the profile.';

  @override
  String get profilesWizardSubtitle =>
      'Step-by-step setup with guided configuration';

  @override
  String get serverCurrentlyUsingCustomUrl =>
      'Currently using a custom server URL.';

  @override
  String get serverUrlCannotBeEmpty => 'Server URL cannot be empty';

  @override
  String get sessionFilesEmptySubtitle =>
      'Files modified during the session will appear here.';

  @override
  String get sessionsArchiveConfirm =>
      'This will stop the running session. Are you sure?';

  @override
  String get sessionsDeleteConfirm =>
      'This will permanently delete the session and all its messages.';

  @override
  String get sessionsGroupByFolder => 'Group by folder';

  @override
  String get sessionsNewDialogPlaceholder => 'New session dialog would go here';

  @override
  String get sessionsNoSearchResults => 'No sessions match your search';

  @override
  String get settingsClaudeDisconnected => 'Claude disconnected';

  @override
  String get settingsCompactSessionViewSubtitle =>
      'Use smaller cards for sessions';

  @override
  String get settingsConfigureVoice => 'Configure ElevenLabs voice';

  @override
  String get settingsConfigureVoiceAssistant => 'Configure voice assistant';

  @override
  String get settingsDeveloperOptions => 'Developer Options';

  @override
  String get settingsDeveloperTapToEnable => 'Open developer options';

  @override
  String get settingsGitHubDisconnected => 'GitHub disconnected';

  @override
  String get settingsNotConnected => 'Not connected';

  @override
  String get settingsServerResetConfirm =>
      'Reset the server URL to the default? This cannot be undone.';

  @override
  String get settingsShowFlavorIconsSubtitle =>
      'Show AI provider icons in avatars';

  @override
  String get settingsTextToSpeechSubtitle => 'Read assistant messages aloud';

  @override
  String get settingsUserCertificatesInstalled =>
      'User certificates are installed';

  @override
  String get settingsVoiceSettings => 'Voice Settings';

  @override
  String get terminalConnect => 'Connect Terminal';

  @override
  String get terminalConnected => 'Terminal connected.';

  @override
  String get terminalConnectInfo =>
      'Connect to a terminal session running on one of your machines.';

  @override
  String get terminalDisconnectConfirm =>
      'Are you sure you want to disconnect from the terminal?';

  @override
  String get terminalIdError => 'Please enter a terminal or session ID';

  @override
  String get terminalNoMachines =>
      'No machines connected. Start the Happy CLI on a machine first.';

  @override
  String get terminalOutputPending => '[output pending]';

  @override
  String get voiceSelectLanguageHint => 'Select the language for voice output.';

  @override
  String get featuresMarkdownCopyV2 => 'Markdown Copy V2';

  @override
  String get featuresMarkdownCopyV2Desc => 'Use improved markdown copying';

  @override
  String artifactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artifacts',
      one: '1 artifact',
    );
    return '$_temp0';
  }

  @override
  String authErrorLinkingDevice(String error) {
    return 'Error linking device: $error';
  }

  @override
  String chatLastSeenMinutes(int minutes) {
    return 'Last seen ${minutes}m ago';
  }

  @override
  String chatLastSeenHours(int hours) {
    return 'Last seen ${hours}h ago';
  }

  @override
  String chatLastSeenDays(int days) {
    return 'Last seen ${days}d ago';
  }

  @override
  String chatFailedToClear(String error) {
    return 'Failed to clear: $error';
  }

  @override
  String devLogsCopied(int count) {
    return '$count log entries copied';
  }

  @override
  String machineRemoveConfirm(String name) {
    return 'Are you sure you want to remove \"$name\"?';
  }

  @override
  String machineDeleteFailed(int statusCode) {
    return 'Failed to delete machine ($statusCode)';
  }

  @override
  String sessionsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String sessionsArchiveNConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Archive $count sessions?',
      one: 'Archive 1 session?',
    );
    return '$_temp0';
  }

  @override
  String sessionsArchivePartialFail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0 failed to archive';
  }

  @override
  String sessionsDeleteNConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count sessions?',
      one: 'Delete 1 session?',
    );
    return '$_temp0 This cannot be undone.';
  }

  @override
  String sessionsDeletePartialFail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0 failed to delete';
  }

  @override
  String accountLastActive(String platform, String time) {
    return '$platform • Last active $time';
  }

  @override
  String profilesDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String settingsFailedToDisconnect(String error) {
    return 'Failed to disconnect: $error';
  }

  @override
  String settingsConnectedAs(String login) {
    return 'Connected as @$login';
  }

  @override
  String settingsFailedToStartOAuth(String error) {
    return 'Failed to start OAuth: $error';
  }

  @override
  String appearanceThemeBasedOnDevice(String mode) {
    return 'Based on your device\'s $mode appearance setting.';
  }

  @override
  String get smartFeaturesTitle => 'Smart Features';

  @override
  String get smartFeaturesSection => 'On-device AI';

  @override
  String get smartFeaturesEnabled => 'Enable Smart Features';

  @override
  String get smartFeaturesEnabledDesc =>
      'Enable on-device AI features for smarter session ranking and auto-generated tags';

  @override
  String get smartFeaturesStatus => 'Status';

  @override
  String get smartFeaturesReady => 'Model ready';

  @override
  String get smartFeaturesUnavailable => 'Model not loaded';

  @override
  String get smartFeaturesUnavailableDesc =>
      'Download the on-device AI model below to power session ranking and auto-tags. Until then, simple heuristics are used.';

  @override
  String get smartFeaturesModelSection => 'On-device model';

  @override
  String get smartFeaturesModelNotDownloaded => 'Not downloaded';

  @override
  String get smartFeaturesModelReady => 'Downloaded and ready';

  @override
  String get smartFeaturesDownloadModel => 'Download model';

  @override
  String smartFeaturesDownloadModelDesc(String size) {
    return 'Downloads the Gemma model ($size). Wi-Fi strongly recommended.';
  }

  @override
  String smartFeaturesDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get smartFeaturesDownloadFailed => 'Download failed. Tap to retry.';

  @override
  String get smartFeaturesLoadingModel => 'Loading model…';

  @override
  String get semanticSearchTitle => 'Semantic Search';

  @override
  String get semanticSearchDesc =>
      'Rank sessions by semantic similarity to your query';

  @override
  String get autoTagsTitle => 'Auto Tags';

  @override
  String get autoTagsDesc =>
      'Automatically generate tags for sessions based on content';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsEmptyTitle => 'Your friend list is empty';

  @override
  String get friendsEmptySubtitle =>
      'Add friends to see when they are online and share sessions.';

  @override
  String get friendsFindFriends => 'Find friends';

  @override
  String get friendsSearchHint => 'Search by username or email';

  @override
  String get tabsProviders => 'Providers';

  @override
  String get providersTitle => 'Providers';

  @override
  String get providersUsageSectionTitle => 'Usage';

  @override
  String get providersAddAccount => 'Add account';

  @override
  String get providersAddAccountFailed => 'Failed to save account';

  @override
  String get providersRemoveAccount => 'Remove account';

  @override
  String get providersRemoveAccountFailed => 'Failed to remove account';

  @override
  String get providersLongPressToRemove => 'Long-press to remove';

  @override
  String providersDeleteConfirmMessage(String name) {
    return 'Are you sure you want to remove $name?';
  }

  @override
  String get providersEmptyTitle => 'No provider accounts';

  @override
  String get providersEmptySubtitle =>
      'Add your Kimi or MiniMax account to track usage.';

  @override
  String get providersNoUsageData => 'No usage data available';

  @override
  String get providersSubscription => 'Subscription';

  @override
  String get providersTypeLabel => 'Provider';

  @override
  String get providersAccountNameLabel => 'Account name';

  @override
  String get providersAccountNameHint => 'Optional';

  @override
  String get providersKimiApiKeyLabel => 'API key';

  @override
  String get providersKimiApiKeyHint => 'Paste your Kimi Coding Plan API key';

  @override
  String get providersKimiBaseUrlLabel => 'Base URL';

  @override
  String get providersKimiBaseUrlHint => 'https://api.kimi.com/coding/v1';

  @override
  String get providersMiniMaxCookieLabel => 'Cookie';

  @override
  String get providersMiniMaxCookieHint => 'Paste your MiniMax cookie';

  @override
  String get providersMiniMaxGroupIdLabel => 'Group ID';

  @override
  String get providersMiniMaxGroupIdHint => 'Paste your MiniMax Group ID';

  @override
  String get providersNotImplemented => 'This provider is not yet supported.';

  @override
  String providersResetsIn(String time) {
    return 'Resets in $time';
  }
}
