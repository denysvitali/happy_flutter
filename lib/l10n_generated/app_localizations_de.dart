// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Happy';

  @override
  String get appSubtitle => 'Mobilclient für Claude Code & Codex';

  @override
  String get appVersion => 'Version';

  @override
  String get appLoading => 'Wird geladen...';

  @override
  String get appRetry => 'Wiederholen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonContinue => 'Fortfahren';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonSaveAs => 'Speichern unter';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonSuccess => 'Erfolg';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonCopied => 'Kopiert';

  @override
  String get commonLogout => 'Abmelden';

  @override
  String get commonDiscard => 'Verwerfen';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonScanning => 'Scannen...';

  @override
  String get commonUrlPlaceholder => 'https://beispiel.com';

  @override
  String get commonHome => 'Startseite';

  @override
  String get commonMessage => 'Nachricht';

  @override
  String get commonFiles => 'Dateien';

  @override
  String get commonFileViewer => 'Dateibetrachter';

  @override
  String get commonLoading => 'Wird geladen...';

  @override
  String get commonDeleteConfirmTitle => 'Löschen bestätigen';

  @override
  String get commonDeleteConfirmMessage =>
      'Sind Sie sicher, dass Sie dies löschen möchten?';

  @override
  String get tabsInbox => 'Posteingang';

  @override
  String get tabsSessions => 'Terminals';

  @override
  String get tabsSettings => 'Einstellungen';

  @override
  String get inboxEmptyTitle => 'Posteingang leer';

  @override
  String get inboxEmptyDescription =>
      'Verbinden Sie sich mit Freunden, um das Freigeben von Sitzungen zu starten';

  @override
  String get inboxUpdates => 'Updates';

  @override
  String statusConnected(String time) {
    return 'Verbunden';
  }

  @override
  String get statusConnecting => 'Verbinden';

  @override
  String get statusDisconnected => 'Getrennt';

  @override
  String get statusError => 'Fehler';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusActiveNow => 'Jetzt aktiv';

  @override
  String get statusUnknown => 'Unbekannt';

  @override
  String get statusPermissionRequired => 'Berechtigung erforderlich';

  @override
  String statusLastSeen(Object time) {
    return 'Zuletzt gesehen $time';
  }

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minuten',
      one: '1 Minute',
    );
    return 'vor $_temp0';
  }

  @override
  String timeHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return 'vor $_temp0';
  }

  @override
  String get authTitle => 'Authentifizieren';

  @override
  String get authAccessDenied => 'Zugriff verweigert';

  @override
  String get authAuthenticationFailed => 'Authentifizierung fehlgeschlagen';

  @override
  String get authEnterSecretKey =>
      'Bitte geben Sie einen geheimen Schlüssel ein';

  @override
  String get authInvalidSecretKey =>
      'Ungültiger geheimer Schlüssel. Bitte überprüfen und erneut versuchen.';

  @override
  String get authRestoreAccount => 'Konto wiederherstellen';

  @override
  String get authEnterUrlManually => 'URL manuell eingeben';

  @override
  String get authPasteAuthUrl =>
      'Fügen Sie die Authentifizierungs-URL von Ihrem Terminal ein';

  @override
  String get authAuthenticateTerminal => 'Terminal authentifizieren';

  @override
  String get authAuthenticateWithUrlPaste =>
      'Terminal mit URL-Einfügen authentifizieren';

  @override
  String get authCameraPermissionsRequired =>
      'Kameraberechtigungen erforderlich, um QR-Codes zu scannen';

  @override
  String get authExchangingTokens => 'Token werden ausgetauscht...';

  @override
  String get authClaudeAuthSuccess => 'Erfolgreich mit Claude verbunden';

  @override
  String get welcomeTitle => 'Mobiler Codex und Claude Code Client';

  @override
  String get welcomeSubtitle =>
      'Ende-zu-Ende-verschlüsselt und Ihr Konto wird nur auf Ihrem Gerät gespeichert.';

  @override
  String get welcomeCreateAccount => 'Konto erstellen';

  @override
  String get welcomeLinkOrRestoreAccount =>
      'Konto verknüpfen oder wiederherstellen';

  @override
  String get welcomeLoginWithMobileApp => 'Mit mobiler App anmelden';

  @override
  String get sessionTitle => 'Sitzungen';

  @override
  String get sessionNewSession => 'Neue Sitzung';

  @override
  String get sessionStartNewToGetStarted =>
      'Starten Sie eine neue Sitzung, um zu beginnen';

  @override
  String get sessionNoSessionsYet => 'Noch keine Sitzungen';

  @override
  String get sessionActiveSessions => 'Aktiv';

  @override
  String get sessionHistory => 'Verlauf';

  @override
  String get sessionMachine => 'Maschine';

  @override
  String get sessionSelectMachine => 'Maschine auswählen';

  @override
  String get sessionPath => 'Pfad';

  @override
  String get sessionPathHint => 'Pfad eingeben';

  @override
  String get sessionInputPlaceholder => 'Nachricht eingeben ...';

  @override
  String get sessionStartSession => 'Sitzung starten';

  @override
  String get sessionStarting => 'Sitzung wird gestartet...';

  @override
  String get sessionStarted => 'Sitzung gestartet';

  @override
  String get sessionStartedMessage =>
      'Die Sitzung wurde erfolgreich gestartet.';

  @override
  String get sessionFailedToStart =>
      'Sitzungsstart fehlgeschlagen. Stellen Sie sicher, dass der Daemon auf der Zielmaschine ausgeführt wird.';

  @override
  String get sessionTimeout =>
      'Sitzungsstart timed out. Die Maschine ist möglicherweise langsam oder der Daemon reagiert nicht.';

  @override
  String get sessionNotConnectedToServer =>
      'Nicht mit dem Server verbunden. Überprüfen Sie Ihre Internetverbindung.';

  @override
  String get sessionNoMachineSelected =>
      'Bitte wählen Sie eine Maschine aus, um die Sitzung zu starten';

  @override
  String get sessionNoPathSelected =>
      'Bitte wählen Sie ein Verzeichnis aus, um die Sitzung zu starten';

  @override
  String get sessionTypeTitle => 'Sitzungstyp';

  @override
  String get sessionTypeSimple => 'Einfach';

  @override
  String get sessionTypeWorktree => 'Worktree';

  @override
  String get sessionTypeComingSoon => 'Demnächst';

  @override
  String newSessionTitle(String directory) {
    return 'Neue Sitzung starten';
  }

  @override
  String get newSessionNoMachinesFound =>
      'Keine Maschinen gefunden. Starten Sie zuerst eine Happy-Sitzung auf Ihrem Computer.';

  @override
  String get newSessionAllMachinesOffline =>
      'Alle Maschinen scheinen offline zu sein';

  @override
  String get newSessionMachineDetails => 'Maschinendetails anzeigen →';

  @override
  String get newSessionDirectoryDoesNotExist => 'Verzeichnis nicht gefunden';

  @override
  String newSessionCreateDirectoryConfirm(Object directory) {
    return 'Das Verzeichnis $directory existiert nicht. Möchten Sie es erstellen?';
  }

  @override
  String get newSessionSessionSpawningFailed =>
      'Sitzungserstellung fehlgeschlagen - keine Sitzungs-ID zurückgegeben.';

  @override
  String sessionHistoryTitle(int count) {
    return 'Sitzungsverlauf';
  }

  @override
  String get sessionHistoryEmpty => 'Keine Sitzungen gefunden';

  @override
  String get sessionHistoryToday => 'Heute';

  @override
  String get sessionHistoryYesterday => 'Gestern';

  @override
  String sessionHistoryDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tagen',
      one: '1 Tag',
    );
    return 'vor $_temp0';
  }

  @override
  String get sessionHistoryViewAll => 'Alle Sitzungen anzeigen';

  @override
  String sessionInfoTitle(String currentVersion, String requiredVersion) {
    return 'Sitzungsinformationen';
  }

  @override
  String get sessionInfoHappySessionId => 'Happy-Sitzungs-ID';

  @override
  String get sessionInfoClaudeCodeSessionId => 'Claude Code-Sitzungs-ID';

  @override
  String get sessionInfoAiProvider => 'KI-Anbieter';

  @override
  String get sessionInfoConnectionStatus => 'Verbindungsstatus';

  @override
  String get sessionInfoCreated => 'Erstellt';

  @override
  String get sessionInfoLastUpdated => 'Zuletzt aktualisiert';

  @override
  String get sessionInfoSequence => 'Sequenz';

  @override
  String get sessionInfoMetadata => 'Metadaten';

  @override
  String get sessionInfoHost => 'Host';

  @override
  String get sessionInfoPath => 'Pfad';

  @override
  String get sessionInfoOperatingSystem => 'Betriebssystem';

  @override
  String get sessionInfoProcessId => 'Prozess-ID';

  @override
  String get sessionInfoCliVersion => 'CLI-Version';

  @override
  String get sessionInfoAgentState => 'Agent-Status';

  @override
  String get sessionInfoControlledByUser => 'Vom Benutzer gesteuert';

  @override
  String get sessionInfoPendingRequests => 'Ausstehende Anfragen';

  @override
  String get sessionInfoActivity => 'Aktivität';

  @override
  String get sessionInfoThinking => 'Denkt';

  @override
  String get sessionInfoThinkingSince => 'Denkt seit';

  @override
  String get sessionInfoCliVersionOutdated => 'CLI-Update erforderlich';

  @override
  String sessionInfoCliVersionOutdatedMessage(
    Object currentVersion,
    Object requiredVersion,
  ) {
    return 'Version $currentVersion installiert. Aktualisieren Sie auf $requiredVersion oder höher';
  }

  @override
  String get sessionInfoUpdateCliInstructions =>
      'Bitte führen Sie npm install -g happy-coder@latest aus';

  @override
  String get sessionInfoQuickActions => 'Schnellaktionen';

  @override
  String get sessionInfoViewMachine => 'Maschine anzeigen';

  @override
  String get sessionInfoViewMachineSubtitle =>
      'Maschinendetails und Sitzungen anzeigen';

  @override
  String get sessionInfoKillSession => 'Sitzung beenden';

  @override
  String get sessionInfoKillSessionConfirm =>
      'Sind Sie sicher, dass Sie diese Sitzung beenden möchten?';

  @override
  String get sessionInfoKillSessionSubtitle => 'Sitzung sofort beenden';

  @override
  String get sessionInfoArchiveSession => 'Sitzung archivieren';

  @override
  String get sessionInfoArchiveSessionConfirm =>
      'Sind Sie sicher, dass Sie diese Sitzung archivieren möchten?';

  @override
  String get sessionInfoArchiveSessionSubtitle =>
      'Diese Sitzung archivieren und stoppen';

  @override
  String get sessionInfoDeleteSession => 'Sitzung löschen';

  @override
  String get sessionInfoDeleteSessionSubtitle =>
      'Diese Sitzung dauerhaft entfernen';

  @override
  String get sessionInfoDeleteSessionConfirm => 'Sitzung dauerhaft löschen?';

  @override
  String get sessionInfoDeleteSessionWarning =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Alle Nachrichten und Daten, die mit dieser Sitzung verbunden sind, werden dauerhaft gelöscht.';

  @override
  String get sessionInfoCopySessionId => 'Sitzungs-ID kopieren';

  @override
  String get sessionInfoCopyMetadata => 'Metadaten kopieren';

  @override
  String get sessionInfoSessionIdCopied =>
      'Sitzungs-ID in Zwischenablage kopiert';

  @override
  String get sessionInfoMetadataCopied => 'Metadaten in Zwischenablage kopiert';

  @override
  String get sessionInfoCopyFailed =>
      'Kopieren in Zwischenablage fehlgeschlagen';

  @override
  String get sessionInfoHappyHome => 'Happy Home';

  @override
  String get sessionInfoFailedToKillSession =>
      'Sitzungsbeendigung fehlgeschlagen';

  @override
  String get sessionInfoFailedToArchiveSession =>
      'Sitzungsarchivierung fehlgeschlagen';

  @override
  String get sessionInfoFailedToDeleteSession =>
      'Sitzungslöschung fehlgeschlagen';

  @override
  String get sessionInfoSessionDeleted => 'Sitzung erfolgreich gelöscht';

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
  String get chatStartConversation => 'Gespräch starten';

  @override
  String get chatSendMessageToBegin => 'Senden Sie eine Nachricht zum Beginnen';

  @override
  String get chatSessionSettings => 'Sitzungseinstellungen';

  @override
  String get chatDeleteSession => 'Sitzung löschen';

  @override
  String get chatDeleteSessionConfirm =>
      'Sind Sie sicher, dass Sie diese Sitzung löschen möchten?';

  @override
  String get chatFailedToSend => 'Nachricht senden fehlgeschlagen';

  @override
  String get chatThinking => 'Claude denkt nach...';

  @override
  String chatToolRunning(Object toolName) {
    return 'Wird ausgeführt: $toolName';
  }

  @override
  String settingsTitle(String login) {
    return 'Einstellungen';
  }

  @override
  String get settingsConnectedAccounts => 'Verbundene Konten';

  @override
  String get settingsConnectAccount => 'Konto verbinden';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsMachines => 'Maschinen';

  @override
  String get settingsFeatures => 'Funktionen';

  @override
  String get settingsSocial => 'Soziales';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsAccountSubtitle => 'Kontodetails verwalten';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsAppearanceSubtitle => 'Anpassen, wie die App aussieht';

  @override
  String get settingsVoiceAssistant => 'Sprachassistent';

  @override
  String get settingsVoiceAssistantSubtitle =>
      'Sprachinteraktionseinstellungen konfigurieren';

  @override
  String get settingsFeaturesTitle => 'Funktionen';

  @override
  String get settingsFeaturesSubtitle =>
      'App-Funktionen aktivieren oder deaktivieren';

  @override
  String get settingsDeveloper => 'Entwickler';

  @override
  String get settingsDeveloperTools => 'Entwicklertools';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsAboutFooter =>
      'Happy Coder ist ein mobiler Client für Codex und Claude Code. Er ist vollständig Ende-zu-Ende-verschlüsselt und Ihr Konto wird nur auf Ihrem Gerät gespeichert. Nicht verbunden mit Anthropic.';

  @override
  String get settingsWhatsNew => 'Neuigkeiten';

  @override
  String get settingsWhatsNewSubtitle =>
      'Die neuesten Updates und Verbesserungen ansehen';

  @override
  String get settingsReportIssue => 'Problem melden';

  @override
  String get settingsPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get settingsTermsOfService => 'Nutzungsbedingungen';

  @override
  String get settingsEula => 'EULA';

  @override
  String get settingsSupportUs => 'Unterstützen Sie uns';

  @override
  String get settingsSupportUsSubtitlePro =>
      'Vielen Dank für Ihre Unterstützung!';

  @override
  String get settingsSupportUsSubtitle => 'Projektentwicklung unterstützen';

  @override
  String get settingsScanQrCodeToAuthenticate =>
      'QR-Code scannen zur Authentifizierung';

  @override
  String settingsGithubConnected(Object login) {
    return 'Verbunden als @$login';
  }

  @override
  String get settingsConnectGithubAccount => 'Verbinden Sie Ihr GitHub-Konto';

  @override
  String get settingsUsage => 'Nutzung';

  @override
  String get settingsUsageSubtitle => 'API-Nutzung und -Kosten anzeigen';

  @override
  String get settingsProfiles => 'Profile';

  @override
  String get settingsProfilesSubtitle =>
      'Umgebungsvariablenprofile für Sitzungen verwalten';

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsSignOutConfirm =>
      'Sind Sie sicher, dass Sie sich abmelden möchten? Stellen Sie sicher, dass Sie Ihren geheimen Schlüssel gesichert haben!';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSubtitle =>
      'Wählen Sie Ihre bevorzugte Sprache für die App-Benutzeroberfläche';

  @override
  String get settingsLanguageCurrent => 'Aktuelle Sprache';

  @override
  String get settingsLanguageAutomatic => 'Automatisch';

  @override
  String get settingsLanguageAutomaticSubtitle =>
      'Von Geräteeinstellungen erkennen';

  @override
  String get settingsLanguageNeedsRestart => 'Sprache geändert';

  @override
  String get settingsLanguageNeedsRestartMessage =>
      'Die App muss neu gestartet werden, um die neue Spracheinstellung anzuwenden.';

  @override
  String get settingsLanguageRestartNow => 'Jetzt neu starten';

  @override
  String get settingsLanguageSearchPlaceholder => 'Sprachen suchen...';

  @override
  String get settingsAppearanceTheme => 'Design';

  @override
  String get settingsAppearanceThemeSubtitle =>
      'Wählen Sie Ihr bevorzugtes Farbschema';

  @override
  String get settingsAppearanceThemeAdaptive => 'Adaptiv';

  @override
  String get settingsAppearanceThemeAdaptiveSubtitle =>
      'Systemeinstellungen entsprechen';

  @override
  String get settingsAppearanceThemeLight => 'Hell';

  @override
  String get settingsAppearanceThemeLightSubtitle =>
      'Immer helles Design verwenden';

  @override
  String get settingsAppearanceThemeDark => 'Dunkel';

  @override
  String get settingsAppearanceThemeDarkSubtitle =>
      'Immer dunkles Design verwenden';

  @override
  String get settingsAppearanceDisplay => 'Anzeige';

  @override
  String get settingsAppearanceDisplaySubtitle => 'Layout und Abstand steuern';

  @override
  String get settingsAppearanceInlineToolCalls => 'Inline-Tool-Aufrufe';

  @override
  String get settingsAppearanceInlineToolCallsSubtitle =>
      'Tool-Aufrufe direkt in Chat-Nachrichten anzeigen';

  @override
  String get settingsAppearanceExpandTodoLists => 'Todo-Listen erweitern';

  @override
  String get settingsAppearanceExpandTodoListsSubtitle =>
      'Alle Todos anzeigen anstatt nur Änderungen';

  @override
  String get settingsAppearanceShowLineNumbersInDiffs =>
      'Zeilennummern in Diffs anzeigen';

  @override
  String get settingsAppearanceShowLineNumbersInDiffsSubtitle =>
      'Zeilennummern in Code-Diffs anzeigen';

  @override
  String get settingsAppearanceShowLineNumbersInToolViews =>
      'Zeilennummern in Tool-Ansichten anzeigen';

  @override
  String get settingsAppearanceShowLineNumbersInToolViewsSubtitle =>
      'Zeilennummern in Tool-View-Diffs anzeigen';

  @override
  String get settingsAppearanceWrapLinesInDiffs => 'Zeilen in Diffs umbrechen';

  @override
  String get settingsAppearanceWrapLinesInDiffsSubtitle =>
      'Lange Zeilen umbrechen anstatt horizontal zu scrollen';

  @override
  String get settingsAppearanceAlwaysShowContextSize =>
      'Kontextgröße immer anzeigen';

  @override
  String get settingsAppearanceAlwaysShowContextSizeSubtitle =>
      'Kontextnutzung anzeigen, auch wenn nicht in der Nähe des Limits';

  @override
  String get settingsAppearanceAvatarStyle => 'Avatar-Stil';

  @override
  String get settingsAppearanceAvatarStyleSubtitle =>
      'Sitzungsavatar-Erscheinung wählen';

  @override
  String get settingsAppearanceAvatarStylePixelated => 'Pixeliert';

  @override
  String get settingsAppearanceAvatarStyleGradient => 'Verlauf';

  @override
  String get settingsAppearanceAvatarStyleBrutalist => 'Brutalistisch';

  @override
  String get settingsAppearanceShowFlavorIcons =>
      'KI-Anbieter-Symbole anzeigen';

  @override
  String get settingsAppearanceShowFlavorIconsSubtitle =>
      'KI-Anbieter-Symbole auf Sitzungsavatars anzeigen';

  @override
  String get settingsAppearanceCompactSessionView => 'Kompakte Sitzungsansicht';

  @override
  String get settingsAppearanceCompactSessionViewSubtitle =>
      'Aktive Sitzungen in einem kompakteren Layout anzeigen';

  @override
  String get settingsFeaturesExperiments => 'Experimente';

  @override
  String get settingsFeaturesExperimentsSubtitle =>
      'Experimentelle Funktionen aktivieren, die sich noch in der Entwicklung befinden. Diese Funktionen können instabil sein oder sich ohne Vorankündigung ändern.';

  @override
  String get settingsFeaturesExperimentalFeatures =>
      'Experimentelle Funktionen';

  @override
  String get settingsFeaturesExperimentalFeaturesEnabled =>
      'Experimentelle Funktionen aktiviert';

  @override
  String get settingsFeaturesExperimentalFeaturesDisabled =>
      'Nur stabile Funktionen verwenden';

  @override
  String get settingsFeaturesWebFeatures => 'Web-Funktionen';

  @override
  String get settingsFeaturesWebFeaturesSubtitle =>
      'Funktionen, die nur in der Web-Version der App verfügbar sind.';

  @override
  String get settingsFeaturesEnterToSend => 'Enter zum Senden';

  @override
  String get settingsFeaturesEnterToSendEnabled =>
      'Enter drücken zum Senden (Shift+Enter für neue Zeile)';

  @override
  String get settingsFeaturesEnterToSendDisabled =>
      'Enter fügt eine neue Zeile ein';

  @override
  String get settingsFeaturesCommandPalette => 'Befehlspalette';

  @override
  String get settingsFeaturesCommandPaletteEnabled =>
      'Drücken Sie ⌘K zum Öffnen';

  @override
  String get settingsFeaturesCommandPaletteDisabled =>
      'Schneller Befehlszugriff deaktiviert';

  @override
  String get settingsFeaturesMarkdownCopyV2 => 'Markdown kopieren v2';

  @override
  String get settingsFeaturesMarkdownCopyV2Subtitle =>
      'Langes Drücken öffnet das Kopiermodal';

  @override
  String get settingsFeaturesHideInactiveSessions =>
      'Inaktive Sitzungen ausblenden';

  @override
  String get settingsFeaturesHideInactiveSessionsSubtitle =>
      'Nur aktive Chats in Ihrer Liste anzeigen';

  @override
  String get settingsFeaturesEnhancedSessionWizard =>
      'Verbesserter Sitzungsassistent';

  @override
  String get settingsFeaturesEnhancedSessionWizardEnabled =>
      'Profilbasierter Sitzungsstarter aktiv';

  @override
  String get settingsFeaturesEnhancedSessionWizardDisabled =>
      'Standard-Sitzungsstarter verwenden';

  @override
  String get settingsAccountTitle => 'Kontoeinstellungen';

  @override
  String get settingsAccountStatus => 'Status';

  @override
  String get settingsAccountStatusActive => 'Aktiv';

  @override
  String get settingsAccountStatusNotAuthenticated => 'Nicht authentifiziert';

  @override
  String get settingsAccountAnonymousId => 'Anonyme ID';

  @override
  String get settingsAccountPublicId => 'Öffentliche ID';

  @override
  String get settingsAccountNotAvailable => 'Nicht verfügbar';

  @override
  String get settingsAccountLinkNewDevice => 'Neues Gerät verknüpfen';

  @override
  String get settingsAccountLinkNewDeviceSubtitle =>
      'QR-Code scannen, um Gerät zu verknüpfen';

  @override
  String get settingsAccountProfile => 'Profil';

  @override
  String get settingsAccountName => 'Name';

  @override
  String get settingsAccountGithub => 'GitHub';

  @override
  String get settingsAccountTapToDisconnect => 'Tippen zum Trennen';

  @override
  String get settingsAccountServer => 'Server';

  @override
  String get settingsAccountBackup => 'Sicherung';

  @override
  String get settingsAccountBackupDescription =>
      'Ihr geheimer Schlüssel ist der einzige Weg, um Ihr Konto wiederherzustellen. Bewahren Sie ihn an einem sicheren Ort wie einem Passwort-Manager auf.';

  @override
  String get settingsAccountSecretKey => 'Geheimer Schlüssel';

  @override
  String get settingsAccountTapToReveal => 'Tippen zum Anzeigen';

  @override
  String get settingsAccountTapToHide => 'Tippen zum Ausblenden';

  @override
  String get settingsAccountSecretKeyLabel =>
      'GEHEIMER SCHLÜSSEL (TIPPEN ZUM KOPIEREN)';

  @override
  String get settingsAccountSecretKeyCopied =>
      'Geheimer Schlüssel in Zwischenablage kopiert. Bewahren Sie ihn an einem sicheren Ort auf!';

  @override
  String get settingsAccountSecretKeyCopyFailed =>
      'Kopieren des geheimen Schlüssels fehlgeschlagen';

  @override
  String get settingsAccountPrivacy => 'Datenschutz';

  @override
  String get settingsAccountPrivacyDescription =>
      'Helfen Sie, die App zu verbessern, indem Sie anonyme Nutzungsdaten teilen. Es werden keine persönlichen Informationen gesammelt.';

  @override
  String get settingsAccountAnalytics => 'Analytik';

  @override
  String get settingsAccountAnalyticsDisabled =>
      'Es werden keine Daten geteilt';

  @override
  String get settingsAccountAnalyticsEnabled =>
      'Anonyme Nutzungsdaten werden geteilt';

  @override
  String get settingsAccountDangerZone => 'Gefahrenzone';

  @override
  String get settingsAccountLogout => 'Abmelden';

  @override
  String get settingsAccountLogoutSubtitle =>
      'Abmelden und lokale Daten löschen';

  @override
  String get settingsServerTitle => 'Serverkonfiguration';

  @override
  String get settingsServerUrl => 'Server-URL';

  @override
  String get settingsServerUrlLabel => 'Bitte geben Sie die Server-URL ein';

  @override
  String get settingsServerNotValidHappyServer => 'Kein gültiger Happy-Server';

  @override
  String get settingsServerChangeServer => 'Server ändern';

  @override
  String get settingsServerContinueWithServer =>
      'Mit diesem Server fortfahren?';

  @override
  String get settingsServerResetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get settingsServerResetServerDefault =>
      'Server auf Standard zurücksetzen?';

  @override
  String get settingsServerValidating => 'Wird validiert...';

  @override
  String get settingsServerValidatingServer => 'Server wird validiert...';

  @override
  String get settingsServerServerReturnedError =>
      'Server hat einen Fehler zurückgegeben';

  @override
  String get settingsServerFailedToConnectToServer =>
      'Verbindung zum Server fehlgeschlagen';

  @override
  String get settingsServerCurrentlyUsingCustomServer =>
      'Derzeit wird ein benutzerdefinierter Server verwendet';

  @override
  String get settingsServerCustomServerUrlLabel =>
      'Benutzerdefinierte Server-URL';

  @override
  String get settingsServerAdvancedFeatureFooter =>
      'Dies ist eine erweiterte Funktion. Ändern Sie den Server nur, wenn Sie wissen, was Sie tun. Sie müssen sich ab- und wieder anmelden, nachdem Sie die Server geändert haben.';

  @override
  String get settingsVoiceTitle => 'Sprachassistent';

  @override
  String get settingsVoiceLanguage => 'Sprache';

  @override
  String get settingsVoiceLanguageSubtitle =>
      'Wählen Sie Ihre bevorzugte Sprache für Sprachassistent-Interaktionen. Diese Einstellung wird auf allen Ihren Geräten synchronisiert.';

  @override
  String get settingsVoicePreferredLanguage => 'Bevorzugte Sprache';

  @override
  String get settingsVoicePreferredLanguageSubtitle =>
      'Sprache, die für Sprachassistent-Antworten verwendet wird';

  @override
  String get settingsVoiceLanguageSearchPlaceholder => 'Sprachen suchen...';

  @override
  String get settingsVoiceLanguageSearchTitle => 'Sprachen';

  @override
  String settingsVoiceLanguageFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sprachen',
      one: '1 Sprache',
    );
    return '$_temp0 verfügbar';
  }

  @override
  String get settingsVoiceLanguageAutoDetect => 'Automatisch erkennen';

  @override
  String get settingsProfilesTitle => 'Profile';

  @override
  String get settingsProfilesNoProfile => 'Kein Profil';

  @override
  String get settingsProfilesNoProfileDescription =>
      'Standard-Umgebungseinstellungen verwenden';

  @override
  String get settingsProfilesDefaultModel => 'Standardmodell';

  @override
  String get settingsProfilesAddProfile => 'Profil hinzufügen';

  @override
  String get settingsProfilesProfileName => 'Profilname';

  @override
  String get settingsProfilesEnterName => 'Profilnamen eingeben';

  @override
  String get settingsProfilesBaseUrl => 'Basis-URL';

  @override
  String get settingsProfilesAuthToken => 'Authentifizierungstoken';

  @override
  String get settingsProfilesEnterToken => 'Authentifizierungstoken eingeben';

  @override
  String get settingsProfilesModel => 'Modell';

  @override
  String get settingsProfilesTmuxSession => 'Tmux-Sitzung';

  @override
  String get settingsProfilesEnterTmuxSession => 'Tmux-Sitzungsnamen eingeben';

  @override
  String get settingsProfilesTmuxTempDir => 'Tmux-Temp-Verzeichnis';

  @override
  String get settingsProfilesEnterTmuxTempDir =>
      'Temporären Verzeichnispfad eingeben';

  @override
  String get settingsProfilesTmuxUpdateEnvironment =>
      'Umgebung automatisch aktualisieren';

  @override
  String get settingsProfilesNameRequired => 'Profilname ist erforderlich';

  @override
  String settingsProfilesDeleteConfirm(String name) {
    return 'Sind Sie sicher, dass Sie das Profil \"$name\" löschen möchten?';
  }

  @override
  String get settingsProfilesEditProfile => 'Profil bearbeiten';

  @override
  String get settingsProfilesAddProfileTitle => 'Neues Profil hinzufügen';

  @override
  String get settingsProfilesDeleteTitle => 'Profil löschen';

  @override
  String settingsProfilesDeleteMessage(Object name) {
    return 'Sind Sie sicher, dass Sie \"$name\" löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get settingsProfilesDeleteConfirmAction => 'Löschen';

  @override
  String get settingsProfilesDeleteCancel => 'Abbrechen';

  @override
  String get settingsUsageTitle => 'Nutzung';

  @override
  String get settingsUsageToday => 'Heute';

  @override
  String get settingsUsageLast7Days => 'Letzte 7 Tage';

  @override
  String get settingsUsageLast30Days => 'Letzte 30 Tage';

  @override
  String get settingsUsageTotalTokens => 'Gesamte Tokens';

  @override
  String get settingsUsageTotalCost => 'Gesamtkosten';

  @override
  String get settingsUsageTokens => 'Tokens';

  @override
  String get settingsUsageCost => 'Kosten';

  @override
  String get settingsUsageUsageOverTime => 'Nutzung über die Zeit';

  @override
  String get settingsUsageByModel => 'Nach Modell';

  @override
  String get settingsUsageNoData => 'Keine Nutzungsdaten verfügbar';

  @override
  String get settingsDeveloperTitle => 'Entwickler';

  @override
  String settingsDeveloperVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsDeveloperCopyDebugInfo => 'Debug-Info kopieren';

  @override
  String get settingsDeveloperDebugInfoCopied =>
      'Debug-Info in Zwischenablage kopiert';

  @override
  String get errorsNetworkError => 'Netzwerkfehler aufgetreten';

  @override
  String get errorsServerError => 'Serverfehler aufgetreten';

  @override
  String get errorsUnknownError => 'Ein unbekannter Fehler ist aufgetreten';

  @override
  String get errorsConnectionTimeout => 'Verbindung timed out';

  @override
  String get errorsAuthenticationFailed => 'Authentifizierung fehlgeschlagen';

  @override
  String get errorsPermissionDenied => 'Berechtigung verweigert';

  @override
  String get errorsFileNotFound => 'Datei nicht gefunden';

  @override
  String get errorsInvalidFormat => 'Ungültiges Format';

  @override
  String get errorsOperationFailed => 'Operation fehlgeschlagen';

  @override
  String get errorsTryAgain => 'Bitte erneut versuchen';

  @override
  String get errorsContactSupport =>
      'Kontaktieren Sie den Support, falls das Problem weiterhin besteht';

  @override
  String get errorsSessionNotFound => 'Sitzung nicht gefunden';

  @override
  String get errorsVoiceSessionFailed =>
      'Starten der Sprachsitzung fehlgeschlagen';

  @override
  String get errorsVoiceServiceUnavailable =>
      'Sprachdienst vorübergehend nicht verfügbar';

  @override
  String get errorsOauthInitializationFailed =>
      'Initialisierung des OAuth-Flows fehlgeschlagen';

  @override
  String get errorsTokenStorageFailed =>
      'Speichern der Authentifizierungstoken fehlgeschlagen';

  @override
  String get errorsOauthStateMismatch =>
      'Sicherheitsvalidierung fehlgeschlagen. Bitte erneut versuchen';

  @override
  String get errorsTokenExchangeFailed =>
      'Austausch des Autorisierungscodes fehlgeschlagen';

  @override
  String get errorsOauthAuthorizationDenied => 'Autorisierung verweigert';

  @override
  String get errorsWebViewLoadFailed =>
      'Laden der Authentifizierungsseite fehlgeschlagen';

  @override
  String get errorsFailedToLoadProfile =>
      'Laden des Benutzerprofils fehlgeschlagen';

  @override
  String get errorsUserNotFound => 'Benutzer nicht gefunden';

  @override
  String get errorsSessionDeleted => 'Sitzung wurde gelöscht';

  @override
  String get errorsSessionDeletedDescription =>
      'Diese Sitzung wurde dauerhaft entfernt';

  @override
  String errorsFieldError(String field, String reason) {
    return '$field: $reason';
  }

  @override
  String errorsValidationError(String field, int min, int max) {
    return '$field muss zwischen $min und $max liegen';
  }

  @override
  String errorsRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds Sekunden',
      one: '1 Sekunde',
    );
    return 'Wiederholen in $_temp0';
  }

  @override
  String errorsErrorWithCode(Object code, Object message) {
    return '$message (Fehler $code)';
  }

  @override
  String errorsDisconnectServiceFailed(Object service) {
    return 'Trennen von $service fehlgeschlagen';
  }

  @override
  String errorsConnectServiceFailed(Object service) {
    return 'Verbinden von $service fehlgeschlagen. Bitte erneut versuchen.';
  }

  @override
  String get errorsFailedToLoadFriends =>
      'Laden der Freundesliste fehlgeschlagen';

  @override
  String get errorsFailedToAcceptRequest =>
      'Annehmen der Freundschaftsanfrage fehlgeschlagen';

  @override
  String get errorsFailedToRejectRequest =>
      'Ablehnen der Freundschaftsanfrage fehlgeschlagen';

  @override
  String get errorsFailedToRemoveFriend =>
      'Entfernen des Freundes fehlgeschlagen';

  @override
  String get errorsSearchFailed =>
      'Suche fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get errorsFailedToSendRequest =>
      'Senden der Freundschaftsanfrage fehlgeschlagen';

  @override
  String get terminalWebBrowserRequired => 'Webbrowser erforderlich';

  @override
  String get terminalWebBrowserRequiredDescription =>
      'Terminal-Verbindungslinks können aus Sicherheitsgründen nur in einem Webbrowser geöffnet werden. Bitte verwenden Sie den QR-Code-Scanner oder öffnen Sie diesen Link auf einem Computer.';

  @override
  String get terminalProcessingConnection => 'Verbindung wird verarbeitet...';

  @override
  String get terminalInvalidConnectionLink => 'Ungültiger Verbindungslink';

  @override
  String get terminalInvalidConnectionLinkDescription =>
      'Der Verbindungslink fehlt oder ist ungültig. Bitte überprüfen Sie die URL und versuchen Sie es erneut.';

  @override
  String get terminalConnectTerminal => 'Terminal verbinden';

  @override
  String get terminalRequestDescription =>
      'Ein Terminal möchte sich mit Ihrem Happy Coder-Konto verbinden. Dies ermöglicht dem Terminal, Nachrichten sicher zu senden und zu empfangen.';

  @override
  String get terminalConnectionDetails => 'Verbindungsdetails';

  @override
  String get terminalPublicKey => 'Öffentlicher Schlüssel';

  @override
  String get terminalEncryption => 'Verschlüsselung';

  @override
  String get terminalEndToEndEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get terminalAcceptConnection => 'Verbindung akzeptieren';

  @override
  String get terminalConnecting => 'Verbinden...';

  @override
  String get terminalReject => 'Ablehnen';

  @override
  String get terminalSecurity => 'Sicherheit';

  @override
  String get terminalSecurityFooter =>
      'Dieser Verbindungslink wurde sicher in Ihrem Browser verarbeitet und wurde nie an einen Server gesendet. Ihre privaten Daten bleiben sicher und nur Sie können die Nachrichten entschlüsseln.';

  @override
  String get terminalSecurityFooterDevice =>
      'Diese Verbindung wurde sicher auf Ihrem Gerät verarbeitet und wurde nie an einen Server gesendet. Ihre privaten Daten bleiben sicher und nur Sie können die Nachrichten entschlüsseln.';

  @override
  String get terminalClientSideProcessing => 'Clientseitige Verarbeitung';

  @override
  String get terminalLinkProcessedLocally =>
      'Link lokal im Browser verarbeitet';

  @override
  String get terminalLinkProcessedOnDevice =>
      'Link lokal auf dem Gerät verarbeitet';

  @override
  String get sidebarSessionsTitle => 'Terminals';

  @override
  String get sidebarStatusConnected => 'Verbunden';

  @override
  String get sidebarStatusConnecting => 'Verbinden...';

  @override
  String get sidebarStatusDisconnected => 'Getrennt';

  @override
  String get sidebarStatusError => 'Fehler';

  @override
  String get commandPalettePlaceholder => 'Befehl eingeben oder suchen...';

  @override
  String get toolViewInput => 'Eingabe';

  @override
  String get toolViewOutput => 'Ausgabe';

  @override
  String get toolViewDescription => 'Beschreibung';

  @override
  String get toolViewInputParams => 'Eingabeparameter';

  @override
  String get toolViewError => 'Fehler';

  @override
  String get toolViewCompleted => 'Tool erfolgreich abgeschlossen';

  @override
  String get toolViewNoOutput => 'Keine Ausgabe produziert';

  @override
  String get toolViewRunning => 'Tool wird ausgeführt...';

  @override
  String get toolViewRawJsonDevMode => 'Rohe JSON (Dev-Modus)';

  @override
  String get toolNamesTask => 'Aufgabe';

  @override
  String get toolNamesTerminal => 'Terminal';

  @override
  String get toolNamesSearchFiles => 'Dateien suchen';

  @override
  String get toolNamesSearch => 'Suchen';

  @override
  String get toolNamesSearchContent => 'Inhalt suchen';

  @override
  String get toolNamesListFiles => 'Dateien auflisten';

  @override
  String get toolNamesPlanProposal => 'Vorschlag';

  @override
  String get toolNamesReadFile => 'Datei lesen';

  @override
  String get toolNamesEditFile => 'Datei bearbeiten';

  @override
  String get toolNamesWriteFile => 'Datei schreiben';

  @override
  String get toolNamesFetchUrl => 'URL abrufen';

  @override
  String get toolNamesReadNotebook => 'Notizbuch lesen';

  @override
  String get toolNamesEditNotebook => 'Notizbuch bearbeiten';

  @override
  String get toolNamesTodoList => 'Todo-Liste';

  @override
  String get toolNamesWebSearch => 'Websuche';

  @override
  String get toolNamesReasoning => 'Argumentation';

  @override
  String get toolNamesApplyChanges => 'Datei aktualisieren';

  @override
  String get toolNamesViewDiff => 'Aktuelle Dateiänderungen';

  @override
  String get toolNamesQuestion => 'Frage';

  @override
  String toolDescTerminalCmd(String cmd) {
    return 'Terminal(cmd: $cmd)';
  }

  @override
  String toolDescSearchPattern(Object pattern) {
    return 'Suchen(Muster: $pattern)';
  }

  @override
  String toolDescSearchPath(Object basename) {
    return 'Suchen(Pfad: $basename)';
  }

  @override
  String toolDescFetchUrlHost(Object host) {
    return 'URL abrufen(url: $host)';
  }

  @override
  String toolDescEditNotebookMode(Object mode, Object path) {
    return 'Notizbuch bearbeiten(Datei: $path, Modus: $mode)';
  }

  @override
  String toolDescTodoListCount(Object count) {
    return 'Todo-Liste(Anzahl: $count)';
  }

  @override
  String toolDescWebSearchQuery(Object query) {
    return 'Websuche(Abfrage: $query)';
  }

  @override
  String toolDescGrepPattern(Object pattern) {
    return 'grep(Muster: $pattern)';
  }

  @override
  String toolDescMultiEditEdits(Object count, Object path) {
    return '$path ($count Bearbeitungen)';
  }

  @override
  String toolDescReadingFile(Object file) {
    return 'Lese $file';
  }

  @override
  String toolDescWritingFile(Object file) {
    return 'Schreibe $file';
  }

  @override
  String toolDescModifyingFile(Object file) {
    return 'Ändere $file';
  }

  @override
  String toolDescModifyingFiles(Object count) {
    return 'Ändere $count Dateien';
  }

  @override
  String toolDescModifyingMultipleFiles(Object count, Object file) {
    return '$file und $count weitere';
  }

  @override
  String get toolDescShowingDiff => 'Zeige Änderungen';

  @override
  String get filesSearchPlaceholder => 'Dateien suchen...';

  @override
  String get filesDetachedHead => 'Detached HEAD';

  @override
  String filesSummary(Object staged, Object unstaged) {
    return '$staged bereitgestellt • $unstaged nicht bereitgestellt';
  }

  @override
  String get filesNotRepo => 'Kein Git-Repository';

  @override
  String get filesNotUnderGit =>
      'Dieses Verzeichnis ist nicht unter Git-Versionskontrolle';

  @override
  String get filesSearching => 'Dateien werden gesucht...';

  @override
  String get filesNoFilesFound => 'Keine Dateien gefunden';

  @override
  String get filesNoFilesInProject => 'Keine Dateien im Projekt';

  @override
  String get filesTryDifferentTerm => 'Versuchen Sie einen anderen Suchbegriff';

  @override
  String filesSearchResults(int count) {
    return 'Suchergebnisse ($count)';
  }

  @override
  String get filesProjectRoot => 'Projektstamm';

  @override
  String filesStagedChanges(Object count) {
    return 'Bereitgestellte Änderungen ($count)';
  }

  @override
  String filesUnstagedChanges(Object count) {
    return 'Nicht bereitgestellte Änderungen ($count)';
  }

  @override
  String filesLoadingFile(Object fileName) {
    return 'Lade $fileName...';
  }

  @override
  String get filesBinaryFile => 'Binärdatei';

  @override
  String get filesCannotDisplayBinary =>
      'Binäredateiinhalt kann nicht angezeigt werden';

  @override
  String get filesDiff => 'Diff';

  @override
  String get filesFile => 'Datei';

  @override
  String get filesFileEmpty => 'Datei ist leer';

  @override
  String get filesNoChanges => 'Keine Änderungen anzuzeigen';

  @override
  String get profileUserProfile => 'Benutzerprofil';

  @override
  String get profileDetails => 'Details';

  @override
  String get profileFirstName => 'Vorname';

  @override
  String get profileLastName => 'Nachname';

  @override
  String get profileUsername => 'Benutzername';

  @override
  String get profileStatus => 'Status';

  @override
  String get agentPermissionModeTitle => 'BERECHTIGUNGSMODUS';

  @override
  String get agentPermissionModeDefault => 'Standard';

  @override
  String get agentPermissionModeAcceptEdits => 'Bearbeitungen akzeptieren';

  @override
  String get agentPermissionModePlan => 'Planmodus';

  @override
  String get agentPermissionModeBypassPermissions => 'Yolo-Modus';

  @override
  String get agentPermissionModeBadgeAcceptAllEdits =>
      'Alle Bearbeitungen akzeptieren';

  @override
  String get agentPermissionModeBadgeBypassAllPermissions =>
      'Alle Berechtigungen umgehen';

  @override
  String get agentPermissionModeBadgePlanMode => 'Planmodus';

  @override
  String get agentAgentClaude => 'Claude';

  @override
  String get agentAgentCodex => 'Codex';

  @override
  String get agentAgentGemini => 'Gemini';

  @override
  String get agentModelTitle => 'MODELL';

  @override
  String get agentModelConfigureInCli =>
      'Modelle in CLI-Einstellungen konfigurieren';

  @override
  String agentContextRemaining(int percent) {
    return '$percent% verbleibend';
  }

  @override
  String get agentSuggestionFileLabel => 'DATEI';

  @override
  String get agentSuggestionFolderLabel => 'ORDNER';

  @override
  String get agentNoMachinesAvailable => 'Keine Maschinen verfügbar';

  @override
  String get updateBannerUpdateAvailable => 'Update verfügbar';

  @override
  String get updateBannerPressToApply =>
      'Drücken Sie, um das Update anzuwenden';

  @override
  String get updateBannerWhatsNew => 'Was ist neu';

  @override
  String get updateBannerSeeLatest =>
      'Die neuesten Updates und Verbesserungen ansehen';

  @override
  String get updateBannerNativeUpdateAvailable => 'App-Update verfügbar';

  @override
  String get updateBannerTapToUpdateAppStore =>
      'Tippen Sie zum Update im App Store';

  @override
  String get updateBannerTapToUpdatePlayStore =>
      'Tippen Sie zum Update im Play Store';

  @override
  String changelogVersion(int version) {
    return 'Version $version';
  }

  @override
  String get changelogNoEntriesAvailable =>
      'Keine Changelog-Einträge verfügbar.';

  @override
  String get modalsAuthenticateTerminal => 'Terminal authentifizieren';

  @override
  String get modalsPasteUrlFromTerminal =>
      'Fügen Sie die Authentifizierungs-URL von Ihrem Terminal ein';

  @override
  String get modalsDeviceLinkedSuccessfully => 'Gerät erfolgreich verknüpft';

  @override
  String get modalsTerminalConnectedSuccessfully =>
      'Terminal erfolgreich verbunden';

  @override
  String get modalsInvalidAuthUrl => 'Ungültige Authentifizierungs-URL';

  @override
  String get modalsDeveloperMode => 'Entwicklermodus';

  @override
  String get modalsDeveloperModeEnabled => 'Entwicklermodus aktiviert';

  @override
  String get modalsDeveloperModeDisabled => 'Entwicklermodus deaktiviert';

  @override
  String get modalsDisconnectGithub => 'GitHub trennen';

  @override
  String get modalsDisconnectGithubConfirm =>
      'Sind Sie sicher, dass Sie Ihr GitHub-Konto trennen möchten?';

  @override
  String modalsDisconnectService(String service) {
    return '$service trennen';
  }

  @override
  String modalsDisconnectServiceConfirm(Object service) {
    return 'Sind Sie sicher, dass Sie $service von Ihrem Konto trennen möchten?';
  }

  @override
  String get modalsDisconnect => 'Trennen';

  @override
  String get modalsFailedToConnectTerminal =>
      'Verbinden des Terminals fehlgeschlagen';

  @override
  String get modalsCameraPermissionsRequiredToConnectTerminal =>
      'Kameraberechtigungen erforderlich, um das Terminal zu verbinden';

  @override
  String get modalsFailedToLinkDevice => 'Verknüpfen des Geräts fehlgeschlagen';

  @override
  String get navigationConnectTerminal => 'Terminal verbinden';

  @override
  String get navigationLinkNewDevice => 'Neues Gerät verknüpfen';

  @override
  String get navigationRestoreWithSecretKey =>
      'Mit geheimem Schlüssel wiederherstellen';

  @override
  String get navigationWhatsNew => 'Was ist neu';

  @override
  String get navigationFriends => 'Freunde';

  @override
  String get emptyMainScreenReadyToCode => 'Bereit zum Programmieren?';

  @override
  String get emptyMainScreenInstallCli => 'Installieren Sie das Happy-CLI';

  @override
  String get emptyMainScreenRunIt => 'Führen Sie es aus';

  @override
  String get emptyMainScreenScanQrCode => 'QR-Code scannen';

  @override
  String get emptyMainScreenOpenCamera => 'Kamera öffnen';

  @override
  String get reviewEnjoyingApp => 'Gefällt Ihnen die App?';

  @override
  String get reviewFeedbackPrompt => 'Wir freuen uns über Ihr Feedback!';

  @override
  String get reviewYesILoveIt => 'Ja, ich liebe es!';

  @override
  String get reviewNotReally => 'Nicht wirklich';

  @override
  String itemsCopiedToClipboard(String label) {
    return '$label in Zwischenablage kopiert';
  }

  @override
  String messageSwitchedToMode(String mode) {
    return 'Gewechselt zu $mode-Modus';
  }

  @override
  String get messageUnknownEvent => 'Unbekanntes Ereignis';

  @override
  String messageUsageLimitUntil(Object time) {
    return 'Nutzungsgrenze erreicht bis $time';
  }

  @override
  String get messageUnknownTime => 'unbekannte Zeit';

  @override
  String get codexPermissionsYesForSession =>
      'Ja, und nicht für eine Sitzung fragen';

  @override
  String get codexPermissionsStopAndExplain =>
      'Stoppen und erklären, was zu tun ist';

  @override
  String get claudePermissionsYesAllowAllEdits =>
      'Ja, alle Bearbeitungen während dieser Sitzung erlauben';

  @override
  String get claudePermissionsYesForTool =>
      'Ja, für dieses Tool nicht erneut fragen';

  @override
  String get claudePermissionsNoTellClaude => 'Nein, und Feedback geben';

  @override
  String get textSelectionSelectText => 'Textbereich auswählen';

  @override
  String get textSelectionTitle => 'Text auswählen';

  @override
  String get textSelectionNoTextProvided => 'Kein Text bereitgestellt';

  @override
  String get textSelectionTextNotFound => 'Text nicht gefunden oder abgelaufen';

  @override
  String get textSelectionTextCopied => 'Text in Zwischenablage kopiert';

  @override
  String get textSelectionFailedToCopy =>
      'Kopieren des Textes in Zwischenablage fehlgeschlagen';

  @override
  String get textSelectionNoTextToCopy => 'Kein Text zum Kopieren verfügbar';

  @override
  String get markdownCodeCopied => 'Code kopiert';

  @override
  String get markdownCopyFailed => 'Kopieren fehlgeschlagen';

  @override
  String get markdownMermaidRenderFailed =>
      'Rendern des Mermaid-Diagramms fehlgeschlagen';

  @override
  String get artifactsTitle => 'Artefakte';

  @override
  String get artifactsCountSingular => '1 Artefakt';

  @override
  String artifactsCountPlural(int count) {
    return '$count Artefakte';
  }

  @override
  String get artifactsEmpty => 'Noch keine Artefakte';

  @override
  String get artifactsEmptyDescription =>
      'Erstellen Sie Ihr erstes Artefakt, um zu beginnen';

  @override
  String get artifactsNew => 'Neues Artefakt';

  @override
  String get artifactsEdit => 'Artefakt bearbeiten';

  @override
  String get artifactsDelete => 'Löschen';

  @override
  String get artifactsUpdateError =>
      'Aktualisieren des Artefakts fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get artifactsNotFound => 'Artefakt nicht gefunden';

  @override
  String get artifactsDiscardChanges => 'Änderungen verwerfen?';

  @override
  String get artifactsDiscardChangesDescription =>
      'Sie haben nicht gespeicherte Änderungen. Sind Sie sicher, dass Sie sie verwerfen möchten?';

  @override
  String get artifactsDeleteConfirm => 'Artefakt löschen?';

  @override
  String get artifactsDeleteConfirmDescription =>
      'Diese Aktion kann nicht rückgängig gemacht werden';

  @override
  String get artifactsTitleLabel => 'TITEL';

  @override
  String get artifactsTitlePlaceholder => 'Titel für Ihr Artefakt eingeben';

  @override
  String get artifactsBodyLabel => 'INHALT';

  @override
  String get artifactsBodyPlaceholder => 'Schreiben Sie Ihren Inhalt hier...';

  @override
  String get artifactsEmptyFieldsError =>
      'Bitte geben Sie einen Titel oder Inhalt ein';

  @override
  String get artifactsCreateError =>
      'Erstellen des Artefakts fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get artifactsSave => 'Speichern';

  @override
  String get artifactsSaving => 'Speichern...';

  @override
  String get artifactsLoading => 'Artefakte werden geladen...';

  @override
  String get artifactsError => 'Laden des Artefakts fehlgeschlagen';

  @override
  String get friendsTitle => 'Freunde';

  @override
  String get friendsManageFriends =>
      'Verwalten Sie Ihre Freunde und Verbindungen';

  @override
  String get friendsSearchTitle => 'Freunde finden';

  @override
  String get friendsPendingRequests => 'Freundschaftsanfragen';

  @override
  String get friendsMyFriends => 'Meine Freunde';

  @override
  String get friendsNoFriendsYet => 'Sie haben noch keine Freunde';

  @override
  String get friendsFindFriends => 'Freunde finden';

  @override
  String get friendsRemove => 'Entfernen';

  @override
  String get friendsPendingRequest => 'Ausstehend';

  @override
  String friendsSentOn(String date) {
    return 'Gesendet am $date';
  }

  @override
  String get friendsAccept => 'Akzeptieren';

  @override
  String get friendsReject => 'Ablehnen';

  @override
  String get friendsAddFriend => 'Freund hinzufügen';

  @override
  String get friendsAlreadyFriends => 'Bereits Freunde';

  @override
  String get friendsRequestPending => 'Anfrage ausstehend';

  @override
  String get friendsSearchInstructions =>
      'Geben Sie einen Benutzernamen ein, um nach Freunden zu suchen';

  @override
  String get friendsSearchPlaceholder => 'Benutzername eingeben...';

  @override
  String get friendsSearching => 'Suchen...';

  @override
  String get friendsUserNotFound => 'Benutzer nicht gefunden';

  @override
  String get friendsNoUserFound =>
      'Kein Benutzer mit diesem Benutzernamen gefunden';

  @override
  String get friendsCheckUsername =>
      'Bitte überprüfen Sie den Benutzernamen und versuchen Sie es erneut';

  @override
  String get friendsHowToFind => 'Wie man Freunde findet';

  @override
  String get friendsFindInstructions =>
      'Suchen Sie nach Freunden nach ihrem Benutzernamen. Sowohl Sie als auch Ihr Freund müssen GitHub verbunden haben, um Freundschaftsanfragen zu senden.';

  @override
  String get friendsRequestSent => 'Freundschaftsanfrage gesendet!';

  @override
  String get friendsRequestAccepted => 'Freundschaftsanfrage akzeptiert!';

  @override
  String get friendsRequestRejected => 'Freundschaftsanfrage abgelehnt';

  @override
  String get friendsFriendRemoved => 'Freund entfernt';

  @override
  String get friendsConfirmRemove => 'Freund entfernen';

  @override
  String get friendsConfirmRemoveMessage =>
      'Sind Sie sicher, dass Sie diesen Freund entfernen möchten?';

  @override
  String get friendsCannotAddYourself =>
      'Sie können keine Freundschaftsanfrage an sich selbst senden';

  @override
  String get friendsBothMustHaveGithub =>
      'Beide Benutzer müssen GitHub verbunden haben, um Freunde zu werden';

  @override
  String get friendsStatusNone => 'Nicht verbunden';

  @override
  String get friendsStatusRequested => 'Anfrage gesendet';

  @override
  String get friendsStatusPending => 'Anfrage ausstehend';

  @override
  String get friendsStatusFriend => 'Freunde';

  @override
  String get friendsStatusRejected => 'Abgelehnt';

  @override
  String get friendsAcceptRequest => 'Anfrage akzeptieren';

  @override
  String get friendsRemoveFriend => 'Freund entfernen';

  @override
  String friendsRemoveFriendConfirm(Object name) {
    return 'Sind Sie sicher, dass Sie $name als Freund entfernen möchten?';
  }

  @override
  String friendsRequestSentDescription(Object name) {
    return 'Ihre Freundschaftsanfrage wurde an $name gesendet';
  }

  @override
  String get friendsRequestFriendship => 'Freundschaft anfragen';

  @override
  String get friendsCancelRequest => 'Freundschaftsanfrage canceln';

  @override
  String friendsCancelRequestConfirm(Object name) {
    return 'Ihre Freundschaftsanfrage an $name canceln?';
  }

  @override
  String get friendsDenyRequest => 'Freundschaft ablehnen';

  @override
  String friendsNowFriendsWith(Object name) {
    return 'Sie sind jetzt befreundet mit $name';
  }

  @override
  String feedFriendRequestFrom(String name) {
    return '$name hat Ihnen eine Freundschaftsanfrage gesendet';
  }

  @override
  String get feedFriendRequestGeneric => 'Neue Freundschaftsanfrage';

  @override
  String feedFriendAccepted(Object name) {
    return 'Sie sind jetzt befreundet mit $name';
  }

  @override
  String get feedFriendAcceptedGeneric => 'Freundschaftsanfrage akzeptiert';

  @override
  String get usageToday => 'Heute';

  @override
  String get usageLast7Days => 'Letzte 7 Tage';

  @override
  String get usageLast30Days => 'Letzte 30 Tage';

  @override
  String get usageTotalTokens => 'Gesamte Tokens';

  @override
  String get usageTotalCost => 'Gesamtkosten';

  @override
  String get usageTokens => 'Tokens';

  @override
  String get usageCost => 'Kosten';

  @override
  String get usageUsageOverTime => 'Nutzung über die Zeit';

  @override
  String get usageByModel => 'Nach Modell';

  @override
  String get usageNoData => 'Keine Nutzungsdaten verfügbar';

  @override
  String get offlineBannerNoConnection => 'No internet connection';

  @override
  String get offlineBannerReconnecting => 'Reconnecting...';
}
