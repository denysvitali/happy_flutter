import 'package:flutter/material.dart';

/// Stub AppLocalizations class for CI compatibility
/// TODO: Replace with proper generated localizations
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
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

  // Settings
  String get settingsTitle => 'Settings';
  String get settingsAppearance => 'Appearance';
  String get settingsTheme => 'Theme';
  String get settingsThemeLight => 'Light';
  String get settingsThemeDark => 'Dark';
  String get settingsThemeSystem => 'System';
  String get settingsLanguage => 'Language';
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

  // Errors
  String get errorGeneric => 'Something went wrong';
  String get errorNetwork => 'Network error. Please check your connection.';
  String get errorServer => 'Server error. Please try again later.';
  String get errorNotFound => 'Not found';
  String get voiceAssistantError => 'Voice assistant error';
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
