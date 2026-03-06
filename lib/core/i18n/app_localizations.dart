import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Stub AppLocalizations class for CI compatibility
/// Replace with proper generated localizations (pending implementation)
/// v2 - force re-analysis
class AppLocalizations {

  AppLocalizations(this.locale);
  final Locale locale;

  /// Localizations delegate
  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// Supported locales
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
  ];

  /// Get the AppLocalizations instance for the given context.
  /// Always returns a non-null instance.
  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (localizations != null) {
      return localizations;
    }
    // Return default instance with English locale
    return AppLocalizations(const Locale('en'));
  }

  // Common
  String get commonCancel => 'Cancel';
  String get commonCopy => 'Copy';
  String get commonCreate => 'Create';
  String get commonDelete => 'Delete';
  String get commonSave => 'Save';
  String get commonVersion => 'Version';
  String get commonBack => 'Back';
  String get commonContinue => 'Continue';
  String get commonDone => 'Done';
  String get commonEdit => 'Edit';
  String get commonClose => 'Close';
  String get commonConfirm => 'Confirm';
  String get commonError => 'Error';
  String get commonLoading => 'Loading...';
  String get commonRetry => 'Retry';
  String get commonSearch => 'Search';
  String get commonSettings => 'Settings';

  // Auth
  String get authTitle => 'Happy';
  String get authSubtitle => 'Scan QR code to connect';
  String get authScanQR => 'Scan QR Code';
  String get authEnterToken => 'Enter Token Manually';
  String get authServerUrlHint => 'Server URL';
  String get authTokenHint => 'Authentication Token';
  String get authConnect => 'Connect';
  String get authConnecting => 'Connecting...';
  String get authInvalidQR => 'Invalid QR code';
  String get authConnectionError =>
      'Connection failed. Please check your server URL and try again.';
  String get authServerConnectionError => 'Cannot connect to server';

  // Sessions
  String get sessionsTitle => 'Sessions';
  String get sessionsNew => 'New Session';
  String get sessionsEmpty => 'No sessions yet';
  String get sessionsCreateFirst => 'Create your first session to get started';
  String get sessionsToday => 'Today';
  String get sessionsYesterday => 'Yesterday';
  String get sessionsThisWeek => 'This Week';
  String get sessionsThisMonth => 'This Month';
  String get sessionsOlder => 'Older';

  // Session Screen (missing properties)
  String get sessionHistoryTitle => 'Sessions';
  String get sessionActiveSessions => 'Active';
  String get sessionHistory => 'History';
  String get sessionNoSessionsYet => 'No sessions yet';
  String get sessionNewSession => 'New Session';
  String get sessionMachine => 'Machine';
  String get sessionSelectMachine => 'Select Machine';
  String get sessionPath => 'Path';
  String get sessionPathHint => 'Enter path';

  // Date Groups
  String get dateGroupToday => 'Today';
  String get dateGroupYesterday => 'Yesterday';
  String get dateGroupLastSevenDays => 'Last 7 Days';
  String get dateGroupOlder => 'Older';

  // Empty State
  String get emptyMainScreenInstallCli => '1. Install the Happy CLI';
  String get emptyMainScreenRunIt => '2. Run it in your project directory';
  String get emptyMainScreenScanQrCode => '3. Scan the QR code to connect';

  // New Session Dialog
  String get newSessionTitle => 'New Session';
  String get newSessionNoMachinesFound => 'No machines found';

  // Sessions (extended)
  String get sessionsActiveSessions => 'ACTIVE SESSIONS';
  String get sessionsArchive => 'Archive';
  String get sessionsArchiveSession => 'Archive Session';
  String get sessionsArchiveConfirm =>
      'This will stop the running session. Are you sure?';
  String get sessionsDeleteConfirm =>
      'This will permanently delete the session and all its messages.';
  String sessionsCount(int count) =>
      count == 1 ? '1 session' : '$count sessions';
  String get sessionsSimple => 'Simple';
  String get sessionsWorktree => 'Worktree';
  String get sessionsClaude => 'Claude';
  String get sessionsCodex => 'Codex';
  String get sessionsGemini => 'Gemini';

  // Multi-select
  String sessionsSelectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';
  String get sessionsSelectAll => 'Select All';
  String get sessionsDeselectAll => 'Deselect All';
  String sessionsDeleteNConfirm(int count) =>
      'Delete ${count == 1 ? '1 session' : '$count sessions'}?'
      ' This cannot be undone.';
  String sessionsDeletePartialFail(int count) =>
      '${count == 1 ? '1 session' : '$count sessions'}'
      ' failed to delete';

  // Recent Sessions screen
  String get sessionsRecentTitle => 'Recent Sessions';
  String get sessionsRecentEmpty => 'No recent sessions';
  String get sessionsPressBackToExit => 'Press back again to exit';
  String get sessionsFailedToArchive => 'Failed to archive session';
  String get sessionsFailedToDelete => 'Failed to delete session';

  // Message & Session Info screens
  String get messageDetailTitle => 'Message';
  String get toolDetailsTitle => 'Tool Details';
  String get sessionInfoTitle => 'Session Info';
  String get sessionInfoNotFound => 'Session not found';
  String get messageNotFound => 'Message not found';
  String get commonCopiedToClipboard => 'Copied to clipboard';
  String get accountBackupKeyDialogContent =>
      'Save this key in a safe place.'
      ' You can use it to restore your account.';
  String get accountRestoreInstruction =>
      'Enter your backup key to restore your account.';
  String get accountBackupKeyLabel => 'Backup Key';
  String get accountBackupKeyHint => 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';
  String get accountEnterBackupKey => 'Please enter your backup key';
  String get accountInvalidKeyFormat =>
      'Invalid key format. Use XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';
  String get commonUnsavedChangesTitle => 'Unsaved Changes';
  String get commonUnsavedChangesContent =>
      'You have unsaved changes. Are you sure you want to leave?';
  String get chatUnsentMessageTitle => 'Unsent Message';
  String get chatUnsentMessageContent =>
      'You have an unsent message. Are you sure you want to leave?';
  String get chatStay => 'Stay';
  String get chatLeave => 'Leave';

  // Grouping toggle
  String get sessionsGroupByDate => 'Group by date';
  String get sessionsGroupByFolder =>
      'Group by folder';

  // Pick Screens
  String get pickSelectMachine => 'Select Machine';
  String get pickSelectProfile => 'Select Profile';
  String get pickSelectPath => 'Select Path';

  // Tabs
  String get tabsInbox => 'Inbox';
  String get tabsSettings => 'Settings';
  String get inboxEmptyTitle => 'Inbox Empty';
  String get inboxEmptyDescription => 'Your inbox is empty';

  // Chat
  String get chatInputHint => 'Message...';
  String get chatEmpty => 'Start a conversation';
  String get chatSend => 'Send';
  String get chatCopyMessage => 'Copy';
  String get chatDeleteMessage => 'Delete';
  String get chatClearSession => 'Clear Session';
  String get chatConfirmClear => 'Are you sure you want to clear this session?';
  String get chatActionConfirm => 'Confirm Action';
  String get chatActionReject => 'Reject';
  String get chatActionAccept => 'Accept';
  String get chatChat => 'Chat';
  String get chatChatLoading => 'Loading...';
  String get chatDeleteSession => 'Delete Session';
  String get chatDeleteSessionConfirm =>
      'Are you sure you want to delete this session?';
  String get chatFailedToSend => 'Failed to send message';
  String get chatSendMessageToBegin => 'Send a message to begin';
  String get chatSessionSettings => 'Session Settings';
  String get chatStartConversation => 'Start a conversation';

  // Settings
  String get settingsTitle => 'Settings';
  String get settingsAppearance => 'Appearance';
  String get settingsTheme => 'Theme';
  String get settingsThemeLight => 'Light';
  String get settingsThemeDark => 'Dark';
  String get settingsThemeSystem => 'System';
  String get settingsLanguage => 'Language';
  String get settingsLanguageAutomatic => 'Automatic';
  String get settingsLanguageAutomaticSubtitle => 'Use device language';
  String get settingsLanguageNeedsRestart => 'Language Changed';
  String get settingsLanguageNeedsRestartMessage =>
      'The app needs to restart to apply the new language setting.';
  String get noLanguagesFound => 'No languages found';
  String get settingsServer => 'Server';
  String get settingsServerUrl => 'Server URL';
  String get settingsServerNotReachable => 'Server not reachable';
  String get settingsVoice => 'Voice';
  String get settingsVoiceLanguage => 'Voice Language';
  String get settingsAccount => 'Account';
  String get settingsLogout => 'Logout';
  String get settingsLogoutConfirm => 'Are you sure you want to logout?';
  String get settingsDeveloper => 'Developer';
  String get settingsLogs => 'Logs';
  String get settingsVersion => 'Version';
  String get settingsProfiles => 'AI Profiles';
  String get settingsProfilesSubtitle => 'Manage AI profiles';
  String get profilesDeleteTitle => 'Delete Profile';
  String profilesDeleteConfirm(String name) =>
      'Are you sure you want to delete "$name"?';
  String get profilesFailedToSave => 'Failed to save profile';
  String get settingsUsage => 'Usage';
  String get settingsUsageSubtitle => 'View usage statistics';

  // Usage Screen
  String get usageTitle => 'Usage';
  String get timePeriod => 'Time Period';
  String get totals => 'Totals';
  String get byModel => 'By Model';
  String get statistics => 'Statistics';
  String get today => 'Today';
  String get sevenDays => '7 Days';
  String get thirtyDays => '30 Days';
  String get totalTokens => 'Total Tokens';
  String get totalCost => 'Total Cost';
  String get reports => 'Reports';
  String get avgCostPerDay => 'Avg. Cost/Day';
  String get avgTokensPerDay => 'Avg. Tokens/Day';
  String get noUsageData => 'No usage data';
  String get noUsageDataSubtitle => 'Start using Happy to see your usage stats';
  String get failedToLoad => 'Failed to load usage data';

  String get settingsFeatures => 'Features';
  String get featuresExperiments => 'Experiments';
  String get featuresExperimentsDesc => 'Try experimental features';
  String get settingsServerUrlLabel => 'Server URL';
  String get settingsServerResetSuccess => 'Server URL reset to default';
  String get settingsServerResetToDefault => 'Reset to Default';
  String get settingsServerSaved => 'Server URL saved';
  String get settingsServerSaveVerify => 'Save & Verify';
  String get settingsSignOut => 'Sign Out';
  String get settingsSignOutConfirm => 'Are you sure you want to sign out?';
  String get settingsOnline => 'Online';
  String get settingsOffline => 'Offline';

  // Tools
  String get toolEdit => 'Edit';
  String get toolRead => 'Read';
  String get toolWrite => 'Write';
  String get toolBash => 'Bash';
  String get toolGlob => 'Glob';
  String get toolGrep => 'Grep';
  String get toolLs => 'List Files';
  String get toolPatch => 'Patch';
  String get toolDiff => 'Diff';
  String get toolTask => 'Task';
  String get toolTodo => 'Todo';
  String get toolWebFetch => 'Web Fetch';
  String get toolWebSearch => 'Web Search';
  String get toolExitPlan => 'Exit Plan';
  String get toolAskUser => 'Ask User';

  // Permissions
  String get permissionDefault => 'Default';
  String get permissionAcceptEdits => 'Accept Edits';
  String get permissionPlan => 'Plan Mode';
  String get permissionYolo => 'Yolo Mode';
  String get permissionReadOnly => 'Read Only';
  String get permissionSafeYolo => 'Safe Yolo';

  // Voice Assistant
  String get voiceAssistantActive => 'Voice assistant active';
  String get voiceAssistantConnecting => 'Connecting...';
  String get voiceAssistantDefault => 'Voice';
  String get voiceAssistantTapToEnd => 'Tap to end';

  // Sidebar
  String get sidebarStatusConnected => 'Connected';
  String get sidebarStatusConnecting => 'Connecting...';
  String get sidebarStatusDisconnected => 'Disconnected';
  String get sidebarStatusError => 'Error';
  String get sidebarSessionsTitle => 'Sessions';

  // Auth
  String get authAccessDenied => 'Access Denied';
  String get authClientError => 'Client Error';
  String get authServerError => 'Server Error';
  String get authCertificateError => 'Certificate Error';
  String get authAuthenticationFailed => 'Authentication Failed';
  String get authConnectionFailed => 'Connection Failed';
  String get appTitle => 'Happy';
  String get appSubtitle => 'Your AI coding assistant';
  String get welcomeCreateAccount => 'Create Account';
  String get welcomeLinkOrRestoreAccount => 'Link or Restore Account';
  String get authServerSettings => 'Server Settings';
  String get authSomethingWentWrong =>
      'Something went wrong. Please sign in again.';
  String get authSignInFirst =>
      'Please sign in first to approve device linking';
  String get authDeviceLinkedSuccess =>
      'Device linked successfully!';
  String get authFailedToLinkDevice =>
      'Failed to link device';
  String authErrorLinkingDevice(String error) =>
      'Error linking device: $error';
  String get authProcessingDeviceLink =>
      'Processing device link...';
  String get authLinkAccount => 'Link Account';
  String get authWaitingForApproval =>
      'Waiting for approval...';
  String get authTryAgain => 'Try Again';
  String get authSignInWithSecretKey =>
      'Sign In with Secret Key';
  String get authSecretKeyInstruction =>
      'Enter backup key (11 groups like '
      'XXXXX-XXXXX...), base64/base64url, '
      'or 64-char hex key.';
  String get authSecretKeyLabel => 'Secret Key';
  String get authSecretKeyHint =>
      'Backup key / base64 / hex';
  String get authPleaseEnterSecretKey =>
      'Please enter a secret key';
  String get authInvalidKey =>
      'Invalid key. Use backup key (11 groups), '
      'base64, base64url, or 64-char hex.';
  String get authPaste => 'Paste';
  String get authSignIn => 'Sign In';
  String get authServerUrlSaved =>
      'Server URL saved and applied.';
  String get authErrorDetailsCopied =>
      'Error details copied';

  // Errors
  String get errorGeneric => 'Something went wrong';
  String get errorNetwork => 'Network error. Please check your connection.';
  String get errorServer => 'Server error. Please try again later.';
  String get errorNotFound => 'Not found';
  String get voiceAssistantError => 'Voice assistant error';

  // Appearance Theme
  String get appearanceTheme => 'Theme';
  String get appearanceThemeAdaptive => 'Adaptive';
  String get appearanceThemeAdaptiveDesc => 'Match system settings';
  String get appearanceThemeLight => 'Light';
  String get appearanceThemeLightDesc => 'Always use light theme';
  String get appearanceThemeDark => 'Dark';
  String get appearanceThemeDarkDesc => 'Always use dark theme';
  String appearanceThemeApplied(String theme) => '$theme theme applied';

  // Language Search
  String get searchLanguages => 'Search languages';

  // Behavior Settings
  String get settingsBehavior => 'Behavior';
  String get settingsViewInline => 'View Inline';
  String get settingsViewInlineSubtitle => 'Show tool calls inline in chat';
  String get settingsExpandTodos => 'Expand Todos';
  String get settingsShowLineNumbers => 'Show Line Numbers';

  // Appearance Settings
  String get settingsCompactSessionView => 'Compact Session View';
  String get settingsCompactSessionViewSubtitle =>
      'Use smaller cards for sessions';
  String get settingsShowFlavorIcons => 'Show Flavor Icons';
  String get settingsShowFlavorIconsSubtitle =>
      'Show AI provider icons in avatars';
  String get settingsAvatarStyle => 'Avatar Style';
  String get settingsWrapLinesInDiffs => 'Wrap Lines in Diffs';

  // Zen (Todo)
  String get zenTitle => 'Zen';
  String get zenNewTask => 'New Task';
  String get zenAddTask => 'Add Task';
  String get zenDescriptionHint => 'What needs to be done?';
  String get zenPriorityLabel => 'Priority';
  String get zenStatusLabel => 'Status';
  String get zenCreatedLabel => 'Created';
  String get zenCompletedLabel => 'Completed';
  String get zenMarkDone => 'Mark Done';
  String get zenTaskTitle => 'Task';
  String get zenTaskNotFound => 'Task not found';
  String get zenDeleteTitle => 'Delete Task';
  String get zenDeleteConfirm => 'Are you sure you want to delete this task?';
  String get zenEmptyTitle => 'No Tasks Yet';
  String get zenEmptySubtitle => 'Tap + to add your first task.';
  String get zenSectionActive => 'Active';
  String get zenSectionCompleted => 'Completed';

  // User Profile
  String get userProfileTitle => 'User Profile';
  String get userNotFound => 'User not found';
  String get friendsStatusFriends => 'Friends';
  String get friendsStatusRequestSent => 'Request Sent';
  String get friendsStatusWantsToConnect => 'Wants to Connect';
  String get friendsCancelRequest => 'Cancel Request';
  String get friendsAcceptRequest => 'Accept Request';
  String get friendsDenyRequest => 'Deny Request';
  String get friendsAddFriendAction => 'Add Friend';
  String friendsCancelRequestConfirm(String name) =>
      'Cancel friend request to $name?';
  String get friendsFailedToAdd => 'Failed to add friend';
  String get friendsFailedToUpdate => 'Failed to update friendship';

  // Friends
  String get friendsTitle => 'Friends';
  String get friendsTabFriends => 'Friends';
  String get friendsTabRequests => 'Requests';
  String get friendsAddFriend => 'Find Friends';
  String get friendsEmptyTitle => 'No Friends Yet';
  String get friendsEmptySubtitle =>
      'Search for people to connect with.';
  String get friendsNoRequests => 'No Incoming Requests';
  String get friendsRemoveTitle => 'Remove Friend';
  String friendsRemoveConfirm(String name) =>
      'Remove $name from your friends?';
  String get friendsRemoveAction => 'Remove';
  String get friendsRemoved => 'Friend removed';
  String get friendsWantsToConnect => 'Wants to connect';
  String get friendsAccept => 'Accept';
  String get friendsReject => 'Reject';
  String get friendsRequestAccepted => 'Request accepted';
  String get friendsRequestRejected => 'Request rejected';
  String get friendsRequestSent => 'Friend request sent';
  String get friendsSearchFailed => 'Search failed';
  String get friendsActionFailed => 'Action failed';
  String get friendsSearchByUsername => 'Search by username';

  // Account & Other
  String get accountAccountSettings => 'Account Settings';
  String get accountProfile => 'Profile';
  String get accountBackupKey => 'Backup Key';
  String get accountShowBackupKey => 'Show Backup Key';
  String get accountShowBackupKeySubtitle =>
      'View your account recovery key';
  String get accountCopyBackupKey => 'Copy Backup Key';
  String get accountCopyToClipboard => 'Copy to clipboard';
  String get accountRestore => 'Restore';
  String get accountRestoreAccount => 'Restore Account';
  String get accountRestoreAccountSubtitle =>
      'Recover account from backup key';
  String get accountDevices => 'Devices';
  String get accountLinkedDevices => 'Linked Devices';
  String get accountLinkedDevicesSubtitle =>
      'Manage devices linked to your account';
  String get accountLinkNewDevice => 'Link New Device';
  String get accountLinkNewDeviceSubtitle =>
      'Generate QR code for another device';
  String get accountConnectedServices => 'Connected Services';
  String get accountBackupKeyCopied => 'Backup key copied';
  String get accountBackupKeyCopiedToClipboard =>
      'Backup key copied to clipboard';
  String get accountNotConnected => 'Not connected';
  String get accountName => 'Name';
  String get accountEmail => 'Email';
  String get accountPasteFromClipboard => 'Paste from Clipboard';
  String get accountRestoredSuccess => 'Account restored successfully';
  String get accountLinkDevice => 'Link Device';
  String get accountScanQR => 'Scan QR';
  String get accountShowQR => 'Show QR';
  String get accountEnterUrl => 'Enter URL';
  String get accountApproveLinking => 'Approve Linking';
  String get accountUnlinkDevice => 'Unlink Device';
  String get accountUnlinkConfirm =>
      'Are you sure you want to unlink this device?';
  String get accountUnlink => 'Unlink';
  String get accountFailedToUnlink => 'Failed to unlink device';
  String get settingsCertificates => 'Certificates';
  String get settingsUserCaCertificates => 'User CA Certificates';
  String get settingsUserCertificatesInstalled =>
      'User certificates are installed';
  String get settingsNoUserCertificates => 'No user certificates installed';
  String get settingsAbout => 'About';
  String get settingsPrivacyPolicy => 'Privacy Policy';
  String get settingsTermsOfService => 'Terms of Service';

  // Chat (extended)
  String get chatPermissionRequired =>
      'Permission required';
  String get chatThinking => 'Thinking...';
  String get chatOnline => 'Online';
  String get chatLastSeenJustNow =>
      'Last seen just now';
  String chatLastSeenMinutes(int minutes) =>
      'Last seen ${minutes}m ago';
  String chatLastSeenHours(int hours) =>
      'Last seen ${hours}h ago';
  String chatLastSeenDays(int days) =>
      'Last seen ${days}d ago';
  String get chatBeginningOfConversation =>
      'Beginning of conversation';
  String get chatConversationCleared => 'Conversation cleared';
  String chatFailedToClear(String error) =>
      'Failed to clear: $error';
  String get chatFailedToDeleteSession =>
      'Failed to delete session';
  String get chatMoreOptions => 'More options';

  // Settings (extended)
  String get settingsConnectedAccounts =>
      'Connected Accounts';
  String get settingsClaudeCode => 'Claude Code';
  String get settingsConnected => 'Connected';
  String get settingsNotConnected =>
      'Not connected';
  String get settingsClaudeDisconnected =>
      'Claude disconnected';
  String settingsFailedToDisconnect(String error) =>
      'Failed to disconnect: $error';
  String settingsConnectedAs(String login) =>
      'Connected as @$login';
  String get settingsGitHubDisconnected =>
      'GitHub disconnected';
  String settingsFailedToStartOAuth(String error) =>
      'Failed to start OAuth: $error';
  String get settingsVoiceSettings =>
      'Voice Settings';
  String get settingsConfigureVoice =>
      'Configure ElevenLabs voice';
  String get settingsSocial => 'Social';
  String get settingsFindFriends => 'Find Friends';
  String get settingsFindFriendsSubtitle =>
      'Search and send friend requests';
  String get settingsOpenInbox => 'Open Inbox';
  String get settingsOpenInboxSubtitle =>
      'View updates and requests';
  String get settingsMachines => 'Machines';
  String get settingsDeveloperOptions =>
      'Developer Options';
  String get settingsDeveloperEnabled => 'Enabled';
  String get settingsDeveloperTapToEnable =>
      'Tap 10 times to enable';
  String get settingsAccountSubtitle =>
      'Backup key, devices, services';
  String get settingsWhatsNew => "What's New";
  String get settingsWhatsNewSubtitle =>
      'Latest improvements and updates';

  // Features Settings
  String get featuresTitle => 'Features';
  String get featuresExperimentalTitle =>
      'Experimental Features';
  String get featuresEnhancedSessionWizard =>
      'Enhanced Session Wizard';
  String get featuresEnhancedSessionWizardDesc =>
      'Use the improved session creation flow';
  String get featuresHideInactiveSessions =>
      'Hide Inactive Sessions';
  String get featuresHideInactiveSessionsDesc =>
      'Hide sessions not used recently';
  String get featuresMarkdownCopyV2 =>
      'Markdown Copy V2';
  String get featuresMarkdownCopyV2Desc =>
      'Use improved markdown copying';

  // Developer Logs Screen
  String get devLogsTitle => 'Logs';
  String devLogsCount(int count) => 'Logs ($count)';
  String devLogsCountFiltered(int count) => 'Logs ($count filtered)';
  String get devLogsEmpty => 'No logs yet';
  String get devLogsEmptyDesc =>
      'Logs will appear here as they are generated';
  String get devLogsClearFilter => 'Clear Filter';
  String get devLogsNoLogsToCopy => 'No logs to copy';
  String devLogsCopied(int count) =>
      '$count log entries copied';
  String get devLogsClearTitle => 'Clear Logs';
  String get devLogsClearConfirm =>
      'Are you sure you want to clear all logs?';
  String get devLogsClearAction => 'Clear';
  String get devLogsSearchTitle => 'Search Logs';
  String get devLogsSearchHint => 'Enter search term...';
  String get devLogsAllLevels => 'All Levels';
  String get devLogsLevelDebug => 'Debug';
  String get devLogsLevelInfo => 'Info';
  String get devLogsLevelWarning => 'Warning';
  String get devLogsLevelError => 'Error';
  String get devLogsLogEntryCopied => 'Log entry copied';
  String get devLogsCopyEntry => 'Copy Entry';
  String get devLogsOnlyAvailableInDevMode =>
      'Logs are only available when Developer Mode is enabled.\n\n'
      'Go to Settings and enable Developer Mode to view logs.';

  // Network Inspector Screen
  String get networkInspectorClearTitle => 'Clear Request Log';
  String get networkInspectorClearConfirm =>
      'Are you sure you want to clear all requests?';

  // Developer Settings
  String get developerTitle => 'Developer';
  String get developerClearCache => 'Clear Cache';
  String get developerResetSettings => 'Reset Settings';
  String get developerModeTitle => 'Developer Mode';
  String get developerModeEnabledDesc => 'Enabled - Debug tools are visible';
  String get developerModeDisabledDesc =>
      'Disabled - Tap 10 times to enable';
  String get developerNotYetImplemented => 'Not yet implemented';
  String get developerClearCacheConfirm =>
      'Are you sure you want to clear all cached data?';
  String get developerClearCacheAction => 'Clear';
  String get developerCacheCleared => 'Cache cleared';
  String get developerResetSettingsConfirm =>
      'Are you sure you want to reset all settings to defaults?';
  String get developerResetAction => 'Reset';
  String get developerSettingsReset => 'Settings reset';
  String get developerSectionDebugTools => 'Debug Tools';
  String get developerSectionTesting => 'Testing';
  String get developerSectionCacheStorage => 'Cache & Storage';
  String get developerSectionBuildInfo => 'Build Info';
  String get developerNetworkInspector => 'Network Inspector';
  String get developerNetworkInspectorDesc =>
      'View API requests and responses';
  String get developerLogsDesc => 'View application logs';
  String get developerEncryptionDebug => 'Encryption Debug';
  String get developerEncryptionDebugDesc =>
      'View encryption keys and certificates';
  String get developerSessionDebug => 'Session Debug';
  String get developerSessionDebugDesc =>
      'View active sessions and connections';
  String get developerTestNotifications => 'Test Notifications';
  String get developerTestNotificationsDesc =>
      'Send a test push notification';
  String get developerTestSentryException => 'Test Sentry (Exception)';
  String get developerTestSentryExceptionDesc =>
      'Capture a test exception via Sentry';
  String get developerTestSentryUnhandled => 'Test Sentry (Unhandled)';
  String get developerTestSentryUnhandledDesc => 'Throw an unhandled error';
  String get developerClearCacheDesc => 'Clear cached data';
  String get developerResetSettingsDesc => 'Reset all settings to defaults';
  String get developerAppVersion => 'App Version';
  String get developerBuildNumber => 'Build Number';
  String get developerFlutterVersion => 'Flutter Version';
  String get developerDartVersion => 'Dart Version';

  // Profiles Settings
  String get profilesTitle => 'Profiles';
  String get profilesProfileName => 'Profile Name';
  String get profilesAddProfile => 'Add Profile';
  String get profilesEditProfile => 'Edit Profile';
  String get profilesDeleteProfile => 'Delete Profile';
  String get profilesNameHint => 'e.g. MiniMax, Kimi Code, DeepSeek';
  String get profilesNameRequired => 'Name is required';
  String get profilesDescriptionLabel => 'Description (optional)';
  String get profilesDescriptionHint =>
      'e.g. MiniMax via OpenAI-compatible API';
  String get profilesEnvVarsTitle => 'Environment Variables';
  String get profilesEnvVarsHint =>
      'Set ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, '
      'ANTHROPIC_MODEL, etc.';
  String get profilesEnvVarsEmpty =>
      'No environment variables. Tap Add to set one.';
  String get profilesEnvKeyLabel => 'Key';
  String get profilesEnvKeyHint => 'VARIABLE_NAME';
  String get profilesEnvValueLabel => 'Value';
  String get profilesScriptTitle => 'Startup Shell Script';
  String get profilesScriptDescription =>
      'Runs before each session starts. '
      'Use to export variables or configure the environment.';
  String get profilesScriptLabel => 'Bash script';
  String get commonOptional => '(optional)';

  // Changelog
  String get changelogTitle => "What's New";
  String get changelogOpenGitHub => 'Open GitHub Releases';

  // Server Settings
  String get serverTitle => 'Server';

  // Voice Settings
  String get voiceTitle => 'Voice';
  String get voiceLanguageTitle => 'Voice Language';
  String get voiceTtsTitle => 'Text-to-Speech';
  String get voiceTtsSubtitle => 'Read assistant messages aloud';
  String get voiceTestTts => 'Test TTS';
  String get voiceTestTtsSubtitle => 'Tap to hear a test phrase';
  String get voiceSelectEngineHint => 'Select the TTS engine.';
  String get voiceDefaultEngine => 'Default Engine';
  String get voiceDefaultEngineSubtitle => 'Use system default';
  String get voiceSelectLanguageHint =>
      'Select the language for voice output.';
  String get voiceSelectLanguageTitle => 'Select Language';
  String voiceLanguagesCount(int count) => '$count languages available';

  // Claude Connect
  String get claudeConnectTitle => 'Connect Claude API';
  String get claudeConnectTerminalTitle => 'Connect Claude';
  String get claudeConnectTerminalSubtitle =>
      'Run the following command in your terminal:';
  String get claudeConnectManualLabel => 'MANUAL API KEY ENTRY';
  String get claudeConnectManualDesc =>
      'Alternatively, enter your Anthropic API key directly.';
  String get claudeConnectApiKeyLabel => 'API Key';
  String get claudeConnectApiKeyHint => 'sk-ant-...';
  String get claudeConnectBaseUrlLabel => 'Base URL (optional)';
  String get claudeConnectBaseUrlHint => 'https://api.anthropic.com';
  String get claudeConnectButton => 'Connect';
  String get claudeConnectDisclaimer =>
      'Your API key is stored locally on this device only.';
  String get claudeConnectCliInfo =>
      'API key management is handled via the CLI. '
      'Run: happy connect claude';

  // Session Files
  String get sessionFilesTitle => 'Files';

  // Artifacts
  String get artifactsTitle => 'Artifacts';
  String get artifactsNew => 'New Artifact';
  String get artifactsEdit => 'Edit Artifact';
  String get artifactsEnterTitleOrContent =>
      'Please enter a title or content.';
  String get artifactsTitleLabel => 'TITLE';
  String get artifactsEnterTitle =>
      'Enter a new title';
  String get artifactsContentLabel => 'CONTENT';
  String get artifactsEnterContent =>
      'Enter new content';
  String get artifactsDetail => 'Artifact';
  String get artifactsStatus => 'Status';
  String get artifactsDraft => 'Draft';
  String get artifactsDeleteConfirm =>
      'Are you sure you want to delete this artifact?';
  String get artifactsFailedToDelete => 'Failed to delete artifact';
  String get artifactsFailedToSave => 'Failed to save artifact';
  String get artifactsFailedToCreate => 'Failed to create artifact';

  // Machine Detail
  String machineRemoveConfirm(String name) =>
      'Are you sure you want to remove "$name"?';
  String machineDeleteFailed(int statusCode) =>
      'Failed to delete machine ($statusCode)';
  String get machineHost => 'Host';
  String get machineMachineId => 'Machine ID';
  String get machineUsername => 'Username';
  String get machinePlatform => 'Platform';
  String get machineArchitecture => 'Architecture';
  String get machineCliVersion => 'CLI Version';
  String get machineHomeDir => 'Home Dir';
  String get machineLastSeen => 'Last Seen';
  String get machineStatus => 'Status';
  String get machineLastKnownStatus =>
      'Last Known Status';
  String get machineLastKnownPid =>
      'Last Known PID';

  // Terminal
  String get terminalConnectInfo =>
      'Connect to a terminal session running on one of your machines.';
  String get terminalNoMachines =>
      'No machines connected. Start the Happy CLI on a machine first.';
  String get terminalSelectMachineHint => 'Select machine';
  String get terminalSelectMachineError => 'Please select a machine';
  String get terminalIdLabel => 'TERMINAL / SESSION ID';
  String get terminalIdHint => 'e.g. main, dev, 1234';
  String get terminalIdError =>
      'Please enter a terminal or session ID';
  String get terminalConnected =>
      'Terminal connected.';
  String get terminalOutputPending =>
      '[output pending]';
  String get terminalDisconnect => 'Disconnect';
  String get terminalDisconnectConfirm =>
      'Are you sure you want to disconnect '
      'from the terminal?';
  String get terminalTitle => 'Terminal';
  String get terminalConnect =>
      'Connect Terminal';

  // Common (extended)
  String get commonUnknown => 'unknown';
  String get commonPressBackAgainToExit => 'Press back again to exit';
  String authError(String error) =>
      'Error: $error';

  // Back button confirmation
  String get commonUnsavedChanges => 'Unsaved Changes';
  String get commonUnsavedChangesMessage =>
      'You have unsaved changes. Are you sure you want to leave?';
  String get commonLeave => 'Leave';
  String get commonStay => 'Stay';
  String get commonUnsentMessage => 'Unsent Message';
  String get commonUnsentMessageConfirm =>
      'You have an unsent message. Are you sure you want to leave?';
  String get commonOperationInProgress => 'Operation In Progress';
  String get commonOperationInProgressConfirm =>
      'An operation is in progress. Are you sure you want to leave?';
}

/// Localizations delegate
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// Extension to easily access localizations from BuildContext
extension AppLocalizationsX on BuildContext {
  /// Get the AppLocalizations instance
  AppLocalizations get l10n => AppLocalizations.of(this);
}
