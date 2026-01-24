import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Simple localization delegate that provides fallback translations
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true; // Support all locales
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// Simple localization class providing basic translations.
///
/// This is a placeholder implementation. For production apps,
/// consider using flutter_gen or intl package with code generation.
class AppLocalizations {
  final Locale _locale;

  AppLocalizations(this._locale);

  /// Get the current locale
  Locale get locale => _locale;

  /// Convenience accessor for l10n from BuildContext
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizations(const Locale('en'));
  }

  // ==========================================================================
  // Common
  // ==========================================================================
  String get commonCancel => _translate('common.cancel', 'Cancel');
  String get commonCopy => _translate('common.copy', 'Copy');
  String get commonCreate => _translate('common.create', 'Create');
  String get commonDelete => _translate('common.delete', 'Delete');
  String get commonSave => _translate('common.save', 'Save');
  String get commonVersion => _translate('common.version', 'Version');

  // ==========================================================================
  // App
  // ==========================================================================
  String get appTitle => _translate('app.title', 'Happy');
  String get appSubtitle => _translate('app.subtitle', 'Mobile client for Claude Code');

  // ==========================================================================
  // Auth
  // ==========================================================================
  String get authAccessDenied => _translate('auth.accessDenied', 'Access denied');
  String get authAuthenticationFailed => _translate('auth.authenticationFailed', 'Authentication failed');
  String get authCertificateError => _translate('auth.certificateError', 'Certificate error');
  String get authClientError => _translate('auth.clientError', 'Client error');
  String get authConnectionFailed => _translate('auth.connectionFailed', 'Connection failed');
  String get authServerConnectionError => _translate('auth.serverConnectionError', 'Server connection error');
  String get authServerError => _translate('auth.serverError', 'Server error');
  String get authServerSettings => _translate('auth.serverSettings', 'Server settings');
  String get welcomeCreateAccount => _translate('welcome.createAccount', 'Create Account');
  String get welcomeLinkOrRestoreAccount => _translate('welcome.linkOrRestoreAccount', 'Link or Restore Account');

  // ==========================================================================
  // Sessions
  // ==========================================================================
  String get sessionHistoryTitle => _translate('session.historyTitle', 'Sessions');
  String get sessionActiveSessions => _translate('session.activeSessions', 'Active');
  String get sessionNoSessionsYet => _translate('session.noSessionsYet', 'No sessions yet');
  String get sessionStartNewToGetStarted => _translate('session.startNewToGetStarted', 'Start a new session to get started');
  String get sessionNewSession => _translate('session.newSession', 'New Session');
  String get sessionMachine => _translate('session.machine', 'Machine');
  String get sessionSelectMachine => _translate('session.selectMachine', 'Select a machine');
  String get sessionPath => _translate('session.path', 'Path');
  String get sessionPathHint => _translate('session.pathHint', 'Enter path');
  String get emptyMainScreenInstallCli => _translate('emptyMainScreen.installCli', 'Install the Happy CLI');
  String get emptyMainScreenRunIt => _translate('emptyMainScreen.runIt', 'Run it');
  String get emptyMainScreenScanQrCode => _translate('emptyMainScreen.scanQrCode', 'Scan the QR code');

  // ==========================================================================
  // Chat
  // ==========================================================================
  String get chatChat => _translate('chat.chat', 'Chat');
  String get chatChatLoading => _translate('chat.chatLoading', 'Loading...');
  String get chatStartConversation => _translate('chat.startConversation', 'Start a conversation');
  String get chatSendMessageToBegin => _translate('chat.sendMessageToBegin', 'Send a message to begin');
  String get chatSessionSettings => _translate('chat.sessionSettings', 'Session settings');
  String get chatDeleteSession => _translate('chat.deleteSession', 'Delete session');
  String get chatDeleteSessionConfirm => _translate('chat.deleteSessionConfirm', 'Are you sure you want to delete this session?');
  String get chatFailedToSend => _translate('chat.failedToSend', 'Failed to send message');

  // ==========================================================================
  // Settings
  // ==========================================================================
  String get settingsTitle => _translate('settings.title', 'Settings');
  String get settingsAppearance => _translate('settings.appearance', 'Appearance');
  String get settingsBehavior => _translate('settings.behavior', 'Behavior');
  String get settingsVoice => _translate('settings.voice', 'Voice');
  String get settingsProfiles => _translate('settings.profiles', 'Profiles');
  String get settingsProfilesSubtitle => _translate('settings.profilesSubtitle', 'Manage AI profiles');
  String get settingsUsage => _translate('settings.usage', 'Usage');
  String get settingsUsageSubtitle => _translate('settings.usageSubtitle', 'View token usage');
  String get settingsFeatures => _translate('settings.features', 'Features');
  String get settingsAccount => _translate('settings.account', 'Account');
  String get accountAccountSettings => _translate('account.accountSettings', 'Account settings');
  String get settingsCertificates => _translate('settings.certificates', 'Certificates');
  String get settingsServer => _translate('settings.server', 'Server');
  String get settingsDeveloper => _translate('settings.developer', 'Developer');
  String get settingsAbout => _translate('settings.about', 'About');
  String get settingsSignOut => _translate('settings.signOut', 'Sign out');
  String get settingsSignOutConfirm => _translate('settings.signOutConfirm', 'Are you sure you want to sign out?');
  String get settingsLanguage => _translate('settings.language', 'Language');
  String get settingsLanguageAutomatic => _translate('settings.languageAutomatic', 'Automatic');
  String get settingsLanguageAutomaticSubtitle => _translate('settings.languageAutomaticSubtitle', 'Use system language');
  String get settingsServerUrl => _translate('settings.serverUrl', 'Server URL');
  String get settingsServerUrlLabel => _translate('settings.serverUrlLabel', 'Enter server URL');
  String get settingsServerResetToDefault => _translate('settings.serverResetToDefault', 'Reset to default');
  String get settingsServerResetSuccess => _translate('settings.serverResetSuccess', 'Server URL reset to default');
  String get settingsServerSaved => _translate('settings.serverSaved', 'Server URL saved');
  String get settingsServerNotReachable => _translate('settings.serverNotReachable', 'Server is not reachable');
  String get settingsServerSaveVerify => _translate('settings.serverSaveVerify', 'Save & Verify');
  String get settingsUserCaCertificates => _translate('settings.userCaCertificates', 'User CA Certificates');
  String get settingsUserCertificatesInstalled => _translate('settings.userCertificatesInstalled', 'Certificates installed');
  String get settingsNoUserCertificates => _translate('settings.noUserCertificates', 'No certificates installed');
  String get settingsVersion => _translate('settings.version', '1.0.0');
  String get settingsPrivacyPolicy => _translate('settings.privacyPolicy', 'Privacy Policy');
  String get settingsTermsOfService => _translate('settings.termsOfService', 'Terms of Service');

  // ==========================================================================
  // Inbox
  // ==========================================================================
  String get inboxEmptyTitle => _translate('inbox.emptyTitle', 'Empty Inbox');
  String get inboxEmptyDescription => _translate('inbox.emptyDescription', 'Connect with friends to start sharing sessions');

  // ==========================================================================
  // Tabs
  // ==========================================================================
  String get tabsInbox => _translate('tabs.inbox', 'Inbox');
  String get tabsSessions => _translate('tabs.sessions', 'Terminals');
  String get tabsSettings => _translate('tabs.settings', 'Settings');

  // ==========================================================================
  // Appearance
  // ==========================================================================
  String get appearanceTheme => _translate('appearance.theme', 'Theme');
  String get appearanceThemeLight => _translate('appearance.themeLight', 'Light');
  String get appearanceThemeDark => _translate('appearance.themeDark', 'Dark');
  String get appearanceThemeAdaptive => _translate('appearance.themeAdaptive', 'System');

  // ==========================================================================
  // Settings Options
  // ==========================================================================
  String get settingsCompactSessionView => _translate('settings.compactSessionView', 'Compact session view');
  String get settingsCompactSessionViewSubtitle => _translate('settings.compactSessionViewSubtitle', 'Show smaller session cards');
  String get settingsShowFlavorIcons => _translate('settings.showFlavorIcons', 'Show flavor icons');
  String get settingsShowFlavorIconsSubtitle => _translate('settings.showFlavorIconsSubtitle', 'Display icons for different AI providers');
  String get settingsAvatarStyle => _translate('settings.avatarStyle', 'Avatar style');
  String get settingsViewInline => _translate('settings.viewInline', 'View files inline');
  String get settingsViewInlineSubtitle => _translate('settings.viewInlineSubtitle', 'Show file content in chat');
  String get settingsExpandTodos => _translate('settings.expandTodos', 'Expand todos');
  String get settingsShowLineNumbers => _translate('settings.showLineNumbers', 'Show line numbers');
  String get settingsWrapLinesInDiffs => _translate('settings.wrapLinesInDiffs', 'Wrap lines in diffs');

  // ==========================================================================
  // Features
  // ==========================================================================
  String get featuresExperiments => _translate('features.experiments', 'Experiments');
  String get featuresExperimentsDesc => _translate('features.experimentsDesc', 'Try experimental features');

  // ==========================================================================
  // New Session
  // ==========================================================================
  String get newSessionTitle => _translate('newSession.title', 'New Session');
  String get newSessionNoMachinesFound => _translate('newSession.noMachinesFound', 'No machines found');

  String _translate(String key, String defaultValue) {
    // Simple placeholder translation - in a real app, this would load from ARB files or JSON
    return defaultValue;
  }
}

/// Extension to access l10n safely on BuildContext
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
