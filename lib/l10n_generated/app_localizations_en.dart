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
  String get tabsInbox => 'Inbox';

  @override
  String get tabsSessions => 'Terminals';

  @override
  String get tabsSettings => 'Settings';

  @override
  String get inboxEmptyTitle => 'Empty Inbox';

  @override
  String get inboxEmptyDescription =>
      'Connect with friends to start sharing sessions';

  @override
  String get inboxUpdates => 'Updates';

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
  String newSessionTitle(String directory) {
    return 'Start New Session';
  }

  @override
  String get newSessionNoMachinesFound =>
      'No machines found. Start a Happy session on your computer first.';

  @override
  String get newSessionAllMachinesOffline => 'All machines appear offline';

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
  String sessionHistoryTitle(int count) {
    return 'Session History';
  }

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
  String sessionInfoTitle(String currentVersion, String requiredVersion) {
    return 'Session Info';
  }

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
  String settingsTitle(String login) {
    return 'Settings';
  }

  @override
  String get settingsConnectedAccounts => 'Connected Accounts';

  @override
  String get settingsConnectAccount => 'Connect account';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsMachines => 'Machines';

  @override
  String get settingsFeatures => 'Features';

  @override
  String get settingsSocial => 'Social';

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
  String get errorsFailedToLoadFriends => 'Failed to load friends list';

  @override
  String get errorsFailedToAcceptRequest => 'Failed to accept friend request';

  @override
  String get errorsFailedToRejectRequest => 'Failed to reject friend request';

  @override
  String get errorsFailedToRemoveFriend => 'Failed to remove friend';

  @override
  String get errorsSearchFailed => 'Search failed. Please try again.';

  @override
  String get errorsFailedToSendRequest => 'Failed to send friend request';

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
  String get navigationFriends => 'Friends';

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
  String get friendsTitle => 'Friends';

  @override
  String get friendsManageFriends => 'Manage your friends and connections';

  @override
  String get friendsSearchTitle => 'Find Friends';

  @override
  String get friendsPendingRequests => 'Friend Requests';

  @override
  String get friendsMyFriends => 'My Friends';

  @override
  String get friendsNoFriendsYet => 'You don\'t have any friends yet';

  @override
  String get friendsFindFriends => 'Find Friends';

  @override
  String get friendsRemove => 'Remove';

  @override
  String get friendsPendingRequest => 'Pending';

  @override
  String friendsSentOn(String date) {
    return 'Sent on $date';
  }

  @override
  String get friendsAccept => 'Accept';

  @override
  String get friendsReject => 'Reject';

  @override
  String get friendsAddFriend => 'Add Friend';

  @override
  String get friendsAlreadyFriends => 'Already Friends';

  @override
  String get friendsRequestPending => 'Request Pending';

  @override
  String get friendsSearchInstructions =>
      'Enter a username to search for friends';

  @override
  String get friendsSearchPlaceholder => 'Enter username...';

  @override
  String get friendsSearching => 'Searching...';

  @override
  String get friendsUserNotFound => 'User not found';

  @override
  String get friendsNoUserFound => 'No user found with that username';

  @override
  String get friendsCheckUsername => 'Please check the username and try again';

  @override
  String get friendsHowToFind => 'How to Find Friends';

  @override
  String get friendsFindInstructions =>
      'Search for friends by their username. Both you and your friend need to have GitHub connected to send friend requests.';

  @override
  String get friendsRequestSent => 'Friend request sent!';

  @override
  String get friendsRequestAccepted => 'Friend request accepted!';

  @override
  String get friendsRequestRejected => 'Friend request rejected';

  @override
  String get friendsFriendRemoved => 'Friend removed';

  @override
  String get friendsConfirmRemove => 'Remove Friend';

  @override
  String get friendsConfirmRemoveMessage =>
      'Are you sure you want to remove this friend?';

  @override
  String get friendsCannotAddYourself =>
      'You cannot send a friend request to yourself';

  @override
  String get friendsBothMustHaveGithub =>
      'Both users must have GitHub connected to become friends';

  @override
  String get friendsStatusNone => 'Not connected';

  @override
  String get friendsStatusRequested => 'Request sent';

  @override
  String get friendsStatusPending => 'Request pending';

  @override
  String get friendsStatusFriend => 'Friends';

  @override
  String get friendsStatusRejected => 'Rejected';

  @override
  String get friendsAcceptRequest => 'Accept Request';

  @override
  String get friendsRemoveFriend => 'Remove Friend';

  @override
  String friendsRemoveFriendConfirm(Object name) {
    return 'Are you sure you want to remove $name as a friend?';
  }

  @override
  String friendsRequestSentDescription(Object name) {
    return 'Your friend request has been sent to $name';
  }

  @override
  String get friendsRequestFriendship => 'Request friendship';

  @override
  String get friendsCancelRequest => 'Cancel friendship request';

  @override
  String friendsCancelRequestConfirm(Object name) {
    return 'Cancel your friendship request to $name?';
  }

  @override
  String get friendsDenyRequest => 'Deny friendship';

  @override
  String friendsNowFriendsWith(Object name) {
    return 'You are now friends with $name';
  }

  @override
  String feedFriendRequestFrom(String name) {
    return '$name sent you a friend request';
  }

  @override
  String get feedFriendRequestGeneric => 'New friend request';

  @override
  String feedFriendAccepted(Object name) {
    return 'You are now friends with $name';
  }

  @override
  String get feedFriendAcceptedGeneric => 'Friend request accepted';

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
}
