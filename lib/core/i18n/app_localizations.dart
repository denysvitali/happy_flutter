import 'package:flutter/material.dart';

/// Stub AppLocalizations class for CI compatibility
/// TODO: Replace with proper generated localizations
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations != null) {
      return localizations;
    }
    return AppLocalizations(Localizations.localeOf(context));
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
  String get authConnectionError => 'Connection failed. Please check your server URL and try again.';
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
  String get chatDeleteSessionConfirm => 'Are you sure you want to delete this session?';
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
  String get settingsUsage => 'Usage';
  String get settingsUsageSubtitle => 'View usage statistics';
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

  // Account & Other
  String get accountAccountSettings => 'Account Settings';
  String get settingsCertificates => 'Certificates';
  String get settingsUserCaCertificates => 'User CA Certificates';
  String get settingsUserCertificatesInstalled =>
      'User certificates are installed';
  String get settingsNoUserCertificates => 'No user certificates installed';
  String get settingsAbout => 'About';
  String get settingsPrivacyPolicy => 'Privacy Policy';
  String get settingsTermsOfService => 'Terms of Service';
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
