// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Happy';

  @override
  String get appSubtitle => 'Client mobile pour Claude Code & Codex';

  @override
  String get appVersion => 'Version';

  @override
  String get appLoading => 'Chargement...';

  @override
  String get appRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSaveAs => 'Enregistrer sous';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonSuccess => 'Succès';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonLogout => 'Déconnexion';

  @override
  String get commonDiscard => 'Ignorer';

  @override
  String get commonOptional => 'optionnel';

  @override
  String get commonScanning => 'Scan en cours...';

  @override
  String get commonUrlPlaceholder => 'https://exemple.com';

  @override
  String get commonHome => 'Accueil';

  @override
  String get commonMessage => 'Message';

  @override
  String get commonFiles => 'Fichiers';

  @override
  String get commonFileViewer => 'Visionneuse de fichiers';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonDeleteConfirmTitle => 'Confirmer la suppression';

  @override
  String get commonDeleteConfirmMessage =>
      'Êtes-vous sûr de vouloir supprimer ceci ?';

  @override
  String get tabsInbox => 'Boîte de réception';

  @override
  String get tabsSessions => 'Terminaux';

  @override
  String get tabsSettings => 'Paramètres';

  @override
  String get inboxEmptyTitle => 'Boîte de réception vide';

  @override
  String get inboxEmptyDescription =>
      'Connectez-vous avec des amis pour commencer à partager des sessions';

  @override
  String get inboxUpdates => 'Mises à jour';

  @override
  String statusConnected(String time) {
    return 'Connecté';
  }

  @override
  String get statusConnecting => 'Connexion';

  @override
  String get statusDisconnected => 'Déconnecté';

  @override
  String get statusError => 'Erreur';

  @override
  String get statusOnline => 'En ligne';

  @override
  String get statusOffline => 'Hors ligne';

  @override
  String get statusActiveNow => 'Actif maintenant';

  @override
  String get statusUnknown => 'Inconnu';

  @override
  String get statusPermissionRequired => 'Permission requise';

  @override
  String statusLastSeen(Object time) {
    return 'Dernière connexion $time';
  }

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return 'il y a $_temp0';
  }

  @override
  String timeHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return 'il y a $_temp0';
  }

  @override
  String get authTitle => 'S\'authentifier';

  @override
  String get authAccessDenied => 'Accès refusé';

  @override
  String get authAuthenticationFailed => 'Échec de l\'authentification';

  @override
  String get authEnterSecretKey => 'Veuillez entrer une clé secrète';

  @override
  String get authInvalidSecretKey =>
      'Clé secrète invalide. Veuillez vérifier et réessayer.';

  @override
  String get authRestoreAccount => 'Restaurer le compte';

  @override
  String get authEnterUrlManually => 'Entrer l\'URL manuellement';

  @override
  String get authPasteAuthUrl =>
      'Collez l\'URL d\'authentification de votre terminal';

  @override
  String get authAuthenticateTerminal => 'Authentifier le terminal';

  @override
  String get authAuthenticateWithUrlPaste =>
      'Authentifier le terminal avec collage d\'URL';

  @override
  String get authCameraPermissionsRequired =>
      'Les permissions de caméra sont requises pour scanner les codes QR';

  @override
  String get authExchangingTokens => 'Échange de jetons...';

  @override
  String get authClaudeAuthSuccess => 'Connexion réussie à Claude';

  @override
  String get welcomeTitle => 'Client mobile Codex et Claude Code';

  @override
  String get welcomeSubtitle =>
      'Cryptage de bout en bout et votre compte est stocké uniquement sur votre appareil.';

  @override
  String get welcomeCreateAccount => 'Créer un compte';

  @override
  String get welcomeLinkOrRestoreAccount => 'Lier ou restaurer un compte';

  @override
  String get welcomeLoginWithMobileApp =>
      'Connexion avec l\'application mobile';

  @override
  String get sessionTitle => 'Sessions';

  @override
  String get sessionNewSession => 'Nouvelle session';

  @override
  String get sessionStartNewToGetStarted =>
      'Démarrez une nouvelle session pour commencer';

  @override
  String get sessionNoSessionsYet => 'Pas encore de sessions';

  @override
  String get sessionActiveSessions => 'Actif';

  @override
  String get sessionHistory => 'Historique';

  @override
  String get sessionMachine => 'Machine';

  @override
  String get sessionSelectMachine => 'Sélectionner une machine';

  @override
  String get sessionPath => 'Chemin';

  @override
  String get sessionPathHint => 'Entrer le chemin';

  @override
  String get sessionInitialMessage => 'Initial message';

  @override
  String get sessionInitialMessageHint => 'What would you like to work on?';

  @override
  String get sessionInputPlaceholder => 'Tapez un message ...';

  @override
  String get sessionStartSession => 'Démarrer la session';

  @override
  String get sessionStarting => 'Démarrage de la session...';

  @override
  String get sessionStarted => 'Session démarrée';

  @override
  String get sessionStartedMessage => 'La session a été démarrée avec succès.';

  @override
  String get sessionFailedToStart =>
      'Échec du démarrage de la session. Assurez-vous que le démon fonctionne sur la machine cible.';

  @override
  String get sessionTimeout =>
      'Le démarrage de la session a expiré. La machine peut être lente ou le démon ne répond pas.';

  @override
  String get sessionNotConnectedToServer =>
      'Non connecté au serveur. Vérifiez votre connexion Internet.';

  @override
  String get sessionNoMachineSelected =>
      'Veuillez sélectionner une machine pour démarrer la session';

  @override
  String get sessionNoPathSelected =>
      'Veuillez sélectionner un répertoire pour démarrer la session';

  @override
  String get sessionTypeTitle => 'Type de session';

  @override
  String get sessionTypeSimple => 'Simple';

  @override
  String get sessionTypeWorktree => 'Worktree';

  @override
  String get sessionTypeComingSoon => 'Bientôt disponible';

  @override
  String newSessionTitle(String directory) {
    return 'Démarrer une nouvelle session';
  }

  @override
  String get newSessionNoMachinesFound =>
      'Aucune machine trouvée. Démarrez d\'abord une session Happy sur votre ordinateur.';

  @override
  String get newSessionAllMachinesOffline =>
      'Toutes les machines semblent être hors ligne';

  @override
  String get newSessionMachineDetails => 'Voir les détails de la machine →';

  @override
  String get newSessionDirectoryDoesNotExist => 'Répertoire non trouvé';

  @override
  String newSessionCreateDirectoryConfirm(Object directory) {
    return 'Le répertoire $directory n\'existe pas. Voulez-vous le créer ?';
  }

  @override
  String get newSessionSessionSpawningFailed =>
      'Échec de la création de la session - aucun ID de session retourné.';

  @override
  String sessionHistoryTitle(int count) {
    return 'Historique des sessions';
  }

  @override
  String get sessionHistoryEmpty => 'Aucune session trouvée';

  @override
  String get sessionHistoryToday => 'Aujourd\'hui';

  @override
  String get sessionHistoryYesterday => 'Hier';

  @override
  String sessionHistoryDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return 'il y a $_temp0';
  }

  @override
  String get sessionHistoryViewAll => 'Voir toutes les sessions';

  @override
  String sessionInfoTitle(String currentVersion, String requiredVersion) {
    return 'Informations sur la session';
  }

  @override
  String get sessionInfoHappySessionId => 'ID de session Happy';

  @override
  String get sessionInfoClaudeCodeSessionId => 'ID de session Claude Code';

  @override
  String get sessionInfoAiProvider => 'Fournisseur IA';

  @override
  String get sessionInfoConnectionStatus => 'État de la connexion';

  @override
  String get sessionInfoCreated => 'Créé';

  @override
  String get sessionInfoLastUpdated => 'Dernière mise à jour';

  @override
  String get sessionInfoSequence => 'Séquence';

  @override
  String get sessionInfoMetadata => 'Métadonnées';

  @override
  String get sessionInfoHost => 'Hôte';

  @override
  String get sessionInfoPath => 'Chemin';

  @override
  String get sessionInfoOperatingSystem => 'Système d\'exploitation';

  @override
  String get sessionInfoProcessId => 'ID de processus';

  @override
  String get sessionInfoCliVersion => 'Version CLI';

  @override
  String get sessionInfoAgentState => 'État de l\'agent';

  @override
  String get sessionInfoControlledByUser => 'Contrôlé par l\'utilisateur';

  @override
  String get sessionInfoPendingRequests => 'Requêtes en attente';

  @override
  String get sessionInfoActivity => 'Activité';

  @override
  String get sessionInfoThinking => 'Réflexion';

  @override
  String get sessionInfoThinkingSince => 'Réflexion depuis';

  @override
  String get sessionInfoCliVersionOutdated => 'Mise à jour CLI requise';

  @override
  String sessionInfoCliVersionOutdatedMessage(
    Object currentVersion,
    Object requiredVersion,
  ) {
    return 'Version $currentVersion installée. Mettez à jour vers $requiredVersion ou version ultérieure';
  }

  @override
  String get sessionInfoUpdateCliInstructions =>
      'Veuillez exécuter npm install -g happy-coder@latest';

  @override
  String get sessionInfoQuickActions => 'Actions rapides';

  @override
  String get sessionInfoViewMachine => 'Voir la machine';

  @override
  String get sessionInfoViewMachineSubtitle =>
      'Voir les détails de la machine et les sessions';

  @override
  String get sessionInfoKillSession => 'Terminer la session';

  @override
  String get sessionInfoKillSessionConfirm =>
      'Êtes-vous sûr de vouloir terminer cette session ?';

  @override
  String get sessionInfoKillSessionSubtitle =>
      'Terminer immédiatement la session';

  @override
  String get sessionInfoArchiveSession => 'Archiver la session';

  @override
  String get sessionInfoArchiveSessionConfirm =>
      'Êtes-vous sûr de vouloir archiver cette session ?';

  @override
  String get sessionInfoArchiveSessionSubtitle =>
      'Archiver cette session et l\'arrêter';

  @override
  String get sessionInfoDeleteSession => 'Supprimer la session';

  @override
  String get sessionInfoDeleteSessionSubtitle =>
      'Supprimer définitivement cette session';

  @override
  String get sessionInfoDeleteSessionConfirm =>
      'Supprimer la session définitivement ?';

  @override
  String get sessionInfoDeleteSessionWarning =>
      'Cette action ne peut pas être annulée. Tous les messages et données associés à cette session seront définitivement supprimés.';

  @override
  String get sessionInfoCopySessionId => 'Copier l\'ID de session';

  @override
  String get sessionInfoCopyMetadata => 'Copier les métadonnées';

  @override
  String get sessionInfoSessionIdCopied =>
      'ID de session copié dans le presse-papiers';

  @override
  String get sessionInfoMetadataCopied =>
      'Métadonnées copiées dans le presse-papiers';

  @override
  String get sessionInfoCopyFailed =>
      'Échec de la copie dans le presse-papiers';

  @override
  String get sessionInfoHappyHome => 'Happy Home';

  @override
  String get sessionInfoFailedToKillSession =>
      'Échec de la terminaison de la session';

  @override
  String get sessionInfoFailedToArchiveSession =>
      'Échec de l\'archivage de la session';

  @override
  String get sessionInfoFailedToDeleteSession =>
      'Échec de la suppression de la session';

  @override
  String get sessionInfoSessionDeleted => 'Session supprimée avec succès';

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
  String get chatStartConversation => 'Démarrer une conversation';

  @override
  String get chatSendMessageToBegin => 'Envoyez un message pour commencer';

  @override
  String get chatSessionSettings => 'Paramètres de session';

  @override
  String get chatDeleteSession => 'Supprimer la session';

  @override
  String get chatDeleteSessionConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette session ?';

  @override
  String get chatFailedToSend => 'Échec de l\'envoi du message';

  @override
  String get chatThinking => 'Claude réfléchit...';

  @override
  String chatToolRunning(Object toolName) {
    return 'Exécution : $toolName';
  }

  @override
  String settingsTitle(String login) {
    return 'Paramètres';
  }

  @override
  String get settingsConnectedAccounts => 'Comptes connectés';

  @override
  String get settingsConnectAccount => 'Connecter un compte';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsMachines => 'Machines';

  @override
  String get settingsFeatures => 'Fonctionnalités';

  @override
  String get settingsSocial => 'Social';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsAccountSubtitle => 'Gérer les détails de votre compte';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAppearanceSubtitle =>
      'Personnaliser l\'apparence de l\'application';

  @override
  String get settingsVoiceAssistant => 'Assistant vocal';

  @override
  String get settingsVoiceAssistantSubtitle =>
      'Configurer les préférences d\'interaction vocale';

  @override
  String get settingsFeaturesTitle => 'Fonctionnalités';

  @override
  String get settingsFeaturesSubtitle =>
      'Activer ou désactiver les fonctionnalités de l\'application';

  @override
  String get settingsDeveloper => 'Développeur';

  @override
  String get settingsDeveloperTools => 'Outils de développeur';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsAboutFooter =>
      'Happy Coder est un client mobile pour Codex et Claude Code. Il est entièrement crypté de bout en bout et votre compte est stocké uniquement sur votre appareil. Non affilié à Anthropic.';

  @override
  String get settingsWhatsNew => 'Nouveautés';

  @override
  String get settingsWhatsNewSubtitle =>
      'Voir les dernières mises à jour et améliorations';

  @override
  String get settingsReportIssue => 'Signaler un problème';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsTermsOfService => 'Conditions d\'utilisation';

  @override
  String get settingsEula => 'CLUF';

  @override
  String get settingsSupportUs => 'Soutenez-nous';

  @override
  String get settingsSupportUsSubtitlePro => 'Merci pour votre soutien !';

  @override
  String get settingsSupportUsSubtitle => 'Soutenir le développement du projet';

  @override
  String get settingsScanQrCodeToAuthenticate =>
      'Scannez le code QR pour vous authentifier';

  @override
  String settingsGithubConnected(Object login) {
    return 'Connecté en tant que @$login';
  }

  @override
  String get settingsConnectGithubAccount => 'Connectez votre compte GitHub';

  @override
  String get settingsUsage => 'Utilisation';

  @override
  String get settingsUsageSubtitle =>
      'Voir votre utilisation et vos coûts d\'API';

  @override
  String get settingsProfiles => 'Profils';

  @override
  String get settingsProfilesSubtitle =>
      'Gérer les profils de variables d\'environnement pour les sessions';

  @override
  String get settingsSignOut => 'Déconnexion';

  @override
  String get settingsSignOutConfirm =>
      'Êtes-vous sûr de vouloir vous déconnecter ? Assurez-vous d\'avoir sauvegardé votre clé secrète !';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSubtitle =>
      'Choisissez votre langue préférée pour l\'interface de l\'application';

  @override
  String get settingsLanguageCurrent => 'Langue actuelle';

  @override
  String get settingsLanguageAutomatic => 'Automatique';

  @override
  String get settingsLanguageAutomaticSubtitle =>
      'Détecter les paramètres de l\'appareil';

  @override
  String get settingsLanguageNeedsRestart => 'Langue modifiée';

  @override
  String get settingsLanguageNeedsRestartMessage =>
      'L\'application doit redémarrer pour appliquer le nouveau paramètre de langue.';

  @override
  String get settingsLanguageRestartNow => 'Redémarrer maintenant';

  @override
  String get settingsLanguageSearchPlaceholder => 'Rechercher des langues...';

  @override
  String get settingsAppearanceTheme => 'Thème';

  @override
  String get settingsAppearanceThemeSubtitle =>
      'Choisissez votre schéma de couleurs préféré';

  @override
  String get settingsAppearanceThemeAdaptive => 'Adaptatif';

  @override
  String get settingsAppearanceThemeAdaptiveSubtitle =>
      'Correspondre aux paramètres système';

  @override
  String get settingsAppearanceThemeLight => 'Clair';

  @override
  String get settingsAppearanceThemeLightSubtitle =>
      'Toujours utiliser le thème clair';

  @override
  String get settingsAppearanceThemeDark => 'Sombre';

  @override
  String get settingsAppearanceThemeDarkSubtitle =>
      'Toujours utiliser le thème sombre';

  @override
  String get settingsAppearanceDisplay => 'Affichage';

  @override
  String get settingsAppearanceDisplaySubtitle =>
      'Contrôler la mise en page et l\'espacement';

  @override
  String get settingsAppearanceInlineToolCalls => 'Appels d\'outils en ligne';

  @override
  String get settingsAppearanceInlineToolCallsSubtitle =>
      'Afficher les appels d\'outils directement dans les messages de chat';

  @override
  String get settingsAppearanceExpandTodoLists =>
      'Développer les listes de tâches';

  @override
  String get settingsAppearanceExpandTodoListsSubtitle =>
      'Afficher toutes les tâches au lieu des seuls changements';

  @override
  String get settingsAppearanceShowLineNumbersInDiffs =>
      'Afficher les numéros de ligne dans les diffs';

  @override
  String get settingsAppearanceShowLineNumbersInDiffsSubtitle =>
      'Afficher les numéros de ligne dans les diffs de code';

  @override
  String get settingsAppearanceShowLineNumbersInToolViews =>
      'Afficher les numéros de ligne dans les vues d\'outils';

  @override
  String get settingsAppearanceShowLineNumbersInToolViewsSubtitle =>
      'Afficher les numéros de ligne dans les diffs des vues d\'outils';

  @override
  String get settingsAppearanceWrapLinesInDiffs =>
      'Ajuster les lignes dans les diffs';

  @override
  String get settingsAppearanceWrapLinesInDiffsSubtitle =>
      'Ajuster les longues lignes au lieu du défilement horizontal';

  @override
  String get settingsAppearanceAlwaysShowContextSize =>
      'Toujours afficher la taille du contexte';

  @override
  String get settingsAppearanceAlwaysShowContextSizeSubtitle =>
      'Afficher l\'utilisation du contexte même lorsqu\'il n\'est pas près de la limite';

  @override
  String get settingsAppearanceAvatarStyle => 'Style d\'avatar';

  @override
  String get settingsAppearanceAvatarStyleSubtitle =>
      'Choisir l\'apparence de l\'avatar de session';

  @override
  String get settingsAppearanceAvatarStylePixelated => 'Pixelisé';

  @override
  String get settingsAppearanceAvatarStyleGradient => 'Dégradé';

  @override
  String get settingsAppearanceAvatarStyleBrutalist => 'Brutaliste';

  @override
  String get settingsAppearanceShowFlavorIcons =>
      'Afficher les icônes des fournisseurs IA';

  @override
  String get settingsAppearanceShowFlavorIconsSubtitle =>
      'Afficher les icônes des fournisseurs IA sur les avatars de session';

  @override
  String get settingsAppearanceCompactSessionView =>
      'Vue compacte des sessions';

  @override
  String get settingsAppearanceCompactSessionViewSubtitle =>
      'Afficher les sessions actives dans une mise en page plus compacte';

  @override
  String get settingsFeaturesExperiments => 'Expériences';

  @override
  String get settingsFeaturesExperimentsSubtitle =>
      'Activer les fonctionnalités expérimentales encore en développement. Ces fonctionnalités peuvent être instables ou changer sans préavis.';

  @override
  String get settingsFeaturesExperimentalFeatures =>
      'Fonctionnalités expérimentales';

  @override
  String get settingsFeaturesExperimentalFeaturesEnabled =>
      'Fonctionnalités expérimentales activées';

  @override
  String get settingsFeaturesExperimentalFeaturesDisabled =>
      'Utilisation des fonctionnalités stables uniquement';

  @override
  String get settingsFeaturesWebFeatures => 'Fonctionnalités Web';

  @override
  String get settingsFeaturesWebFeaturesSubtitle =>
      'Fonctionnalités disponibles uniquement dans la version Web de l\'application.';

  @override
  String get settingsFeaturesEnterToSend => 'Entrée pour envoyer';

  @override
  String get settingsFeaturesEnterToSendEnabled =>
      'Appuyez sur Entrée pour envoyer (Maj+Entrée pour nouvelle ligne)';

  @override
  String get settingsFeaturesEnterToSendDisabled =>
      'Entrée insère une nouvelle ligne';

  @override
  String get settingsFeaturesCommandPalette => 'Palette de commandes';

  @override
  String get settingsFeaturesCommandPaletteEnabled =>
      'Appuyez sur ⌘K pour ouvrir';

  @override
  String get settingsFeaturesCommandPaletteDisabled =>
      'Accès rapide aux commandes désactivé';

  @override
  String get settingsFeaturesMarkdownCopyV2 => 'Copier Markdown v2';

  @override
  String get settingsFeaturesMarkdownCopyV2Subtitle =>
      'Appui long ouvre le modal de copie';

  @override
  String get settingsFeaturesHideInactiveSessions =>
      'Masquer les sessions inactives';

  @override
  String get settingsFeaturesHideInactiveSessionsSubtitle =>
      'Afficher uniquement les chats actifs dans votre liste';

  @override
  String get settingsFeaturesEnhancedSessionWizard =>
      'Assistant de session amélioré';

  @override
  String get settingsFeaturesEnhancedSessionWizardEnabled =>
      'Lanceur de session basé sur le profil actif';

  @override
  String get settingsFeaturesEnhancedSessionWizardDisabled =>
      'Utilisation du lanceur de session standard';

  @override
  String get settingsAccountTitle => 'Paramètres du compte';

  @override
  String get settingsAccountStatus => 'État';

  @override
  String get settingsAccountStatusActive => 'Actif';

  @override
  String get settingsAccountStatusNotAuthenticated => 'Non authentifié';

  @override
  String get settingsAccountAnonymousId => 'ID anonyme';

  @override
  String get settingsAccountPublicId => 'ID public';

  @override
  String get settingsAccountNotAvailable => 'Non disponible';

  @override
  String get settingsAccountLinkNewDevice => 'Lier un nouvel appareil';

  @override
  String get settingsAccountLinkNewDeviceSubtitle =>
      'Scannez le code QR pour lier l\'appareil';

  @override
  String get settingsAccountProfile => 'Profil';

  @override
  String get settingsAccountName => 'Nom';

  @override
  String get settingsAccountGithub => 'GitHub';

  @override
  String get settingsAccountTapToDisconnect => 'Appuyez pour déconnecter';

  @override
  String get settingsAccountServer => 'Serveur';

  @override
  String get settingsAccountBackup => 'Sauvegarde';

  @override
  String get settingsAccountBackupDescription =>
      'Votre clé secrète est le seul moyen de récupérer votre compte. Conservez-la dans un endroit sûr comme un gestionnaire de mots de passe.';

  @override
  String get settingsAccountSecretKey => 'Clé secrète';

  @override
  String get settingsAccountTapToReveal => 'Appuyez pour révéler';

  @override
  String get settingsAccountTapToHide => 'Appuyez pour masquer';

  @override
  String get settingsAccountSecretKeyLabel =>
      'CLÉ SECRÈTE (APPUYEZ POUR COPIER)';

  @override
  String get settingsAccountSecretKeyCopied =>
      'Clé secrète copiée dans le presse-papiers. Conservez-la dans un lieu sûr !';

  @override
  String get settingsAccountSecretKeyCopyFailed =>
      'Échec de la copie de la clé secrète';

  @override
  String get settingsAccountPrivacy => 'Confidentialité';

  @override
  String get settingsAccountPrivacyDescription =>
      'Aidez à améliorer l\'application en partageant des données d\'utilisation anonymes. Aucune information personnelle n\'est collectée.';

  @override
  String get settingsAccountAnalytics => 'Analytique';

  @override
  String get settingsAccountAnalyticsDisabled =>
      'Aucune donnée n\'est partagée';

  @override
  String get settingsAccountAnalyticsEnabled =>
      'Des données d\'utilisation anonymes sont partagées';

  @override
  String get settingsAccountDangerZone => 'Zone de danger';

  @override
  String get settingsAccountLogout => 'Déconnexion';

  @override
  String get settingsAccountLogoutSubtitle =>
      'Se déconnecter et effacer les données locales';

  @override
  String get settingsServerTitle => 'Configuration du serveur';

  @override
  String get settingsServerUrl => 'URL du serveur';

  @override
  String get settingsServerUrlLabel => 'Veuillez entrer l\'URL du serveur';

  @override
  String get settingsServerNotValidHappyServer =>
      'N\'est pas un serveur Happy valide';

  @override
  String get settingsServerChangeServer => 'Changer de serveur';

  @override
  String get settingsServerContinueWithServer => 'Continuer avec ce serveur ?';

  @override
  String get settingsServerResetToDefault => 'Réinitialiser par défaut';

  @override
  String get settingsServerResetServerDefault =>
      'Réinitialiser le serveur par défaut ?';

  @override
  String get settingsServerValidating => 'Validation...';

  @override
  String get settingsServerValidatingServer => 'Validation du serveur...';

  @override
  String get settingsServerServerReturnedError =>
      'Le serveur a renvoyé une erreur';

  @override
  String get settingsServerFailedToConnectToServer =>
      'Échec de la connexion au serveur';

  @override
  String get settingsServerCurrentlyUsingCustomServer =>
      'Utilisation d\'un serveur personnalisé';

  @override
  String get settingsServerCustomServerUrlLabel =>
      'URL du serveur personnalisé';

  @override
  String get settingsServerAdvancedFeatureFooter =>
      'C\'est une fonctionnalité avancée. Ne changez le serveur que si vous savez ce que vous faites. Vous devrez vous déconnecter et vous reconnecter après avoir changé de serveur.';

  @override
  String get settingsVoiceTitle => 'Assistant vocal';

  @override
  String get settingsVoiceLanguage => 'Langue';

  @override
  String get settingsVoiceLanguageSubtitle =>
      'Choisissez votre langue préférée pour les interactions avec l\'assistant vocal. Ce paramètre se synchronise sur tous vos appareils.';

  @override
  String get settingsVoicePreferredLanguage => 'Langue préférée';

  @override
  String get settingsVoicePreferredLanguageSubtitle =>
      'Langue utilisée pour les réponses de l\'assistant vocal';

  @override
  String get settingsVoiceLanguageSearchPlaceholder =>
      'Rechercher des langues...';

  @override
  String get settingsVoiceLanguageSearchTitle => 'Langues';

  @override
  String settingsVoiceLanguageFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count langues',
      one: '1 langue',
    );
    return '$_temp0 disponible(s)';
  }

  @override
  String get settingsVoiceLanguageAutoDetect => 'Détection automatique';

  @override
  String get settingsProfilesTitle => 'Profils';

  @override
  String get settingsProfilesNoProfile => 'Aucun profil';

  @override
  String get settingsProfilesNoProfileDescription =>
      'Utiliser les paramètres d\'environnement par défaut';

  @override
  String get settingsProfilesDefaultModel => 'Modèle par défaut';

  @override
  String get settingsProfilesAddProfile => 'Ajouter un profil';

  @override
  String get settingsProfilesProfileName => 'Nom du profil';

  @override
  String get settingsProfilesEnterName => 'Entrez le nom du profil';

  @override
  String get settingsProfilesBaseUrl => 'URL de base';

  @override
  String get settingsProfilesAuthToken => 'Jeton d\'authentification';

  @override
  String get settingsProfilesEnterToken =>
      'Entrez le jeton d\'authentification';

  @override
  String get settingsProfilesModel => 'Modèle';

  @override
  String get settingsProfilesTmuxSession => 'Session Tmux';

  @override
  String get settingsProfilesEnterTmuxSession =>
      'Entrez le nom de la session tmux';

  @override
  String get settingsProfilesTmuxTempDir => 'Répertoire temporaire Tmux';

  @override
  String get settingsProfilesEnterTmuxTempDir =>
      'Entrez le chemin du répertoire temporaire';

  @override
  String get settingsProfilesTmuxUpdateEnvironment =>
      'Mettre à jour l\'environnement automatiquement';

  @override
  String get settingsProfilesNameRequired => 'Le nom du profil est requis';

  @override
  String settingsProfilesDeleteConfirm(String name) {
    return 'Êtes-vous sûr de vouloir supprimer le profil \"$name\" ?';
  }

  @override
  String get settingsProfilesEditProfile => 'Modifier le profil';

  @override
  String get settingsProfilesAddProfileTitle => 'Ajouter un nouveau profil';

  @override
  String get settingsProfilesDeleteTitle => 'Supprimer le profil';

  @override
  String settingsProfilesDeleteMessage(Object name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ? Cette action ne peut pas être annulée.';
  }

  @override
  String get settingsProfilesDeleteConfirmAction => 'Supprimer';

  @override
  String get settingsProfilesDeleteCancel => 'Annuler';

  @override
  String get settingsUsageTitle => 'Utilisation';

  @override
  String get settingsUsageToday => 'Aujourd\'hui';

  @override
  String get settingsUsageLast7Days => '7 derniers jours';

  @override
  String get settingsUsageLast30Days => '30 derniers jours';

  @override
  String get settingsUsageTotalTokens => 'Jetons totaux';

  @override
  String get settingsUsageTotalCost => 'Coût total';

  @override
  String get settingsUsageTokens => 'Jetons';

  @override
  String get settingsUsageCost => 'Coût';

  @override
  String get settingsUsageUsageOverTime => 'Utilisation au fil du temps';

  @override
  String get settingsUsageByModel => 'Par modèle';

  @override
  String get settingsUsageNoData => 'Aucune donnée d\'utilisation disponible';

  @override
  String get settingsDeveloperTitle => 'Développeur';

  @override
  String settingsDeveloperVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsDeveloperCopyDebugInfo => 'Copier les infos de débogage';

  @override
  String get settingsDeveloperDebugInfoCopied =>
      'Infos de débogage copiées dans le presse-papiers';

  @override
  String get errorsNetworkError => 'Erreur réseau survenue';

  @override
  String get errorsServerError => 'Erreur de serveur survenue';

  @override
  String get errorsUnknownError => 'Une erreur inconnue est survenue';

  @override
  String get errorsConnectionTimeout => 'Connexion expirée';

  @override
  String get errorsAuthenticationFailed => 'Échec de l\'authentification';

  @override
  String get errorsPermissionDenied => 'Permission refusée';

  @override
  String get errorsFileNotFound => 'Fichier non trouvé';

  @override
  String get errorsInvalidFormat => 'Format invalide';

  @override
  String get errorsOperationFailed => 'Échec de l\'opération';

  @override
  String get errorsTryAgain => 'Veuillez réessayer';

  @override
  String get errorsContactSupport =>
      'Contactez le support si le problème persiste';

  @override
  String get errorsSessionNotFound => 'Session non trouvée';

  @override
  String get errorsVoiceSessionFailed =>
      'Échec du démarrage de la session vocale';

  @override
  String get errorsVoiceServiceUnavailable =>
      'Le service vocal est temporairement indisponible';

  @override
  String get errorsOauthInitializationFailed =>
      'Échec de l\'initialisation du flux OAuth';

  @override
  String get errorsTokenStorageFailed =>
      'Échec du stockage des jetons d\'authentification';

  @override
  String get errorsOauthStateMismatch =>
      'Échec de la validation de sécurité. Veuillez réessayer';

  @override
  String get errorsTokenExchangeFailed =>
      'Échuc de l\'échange du code d\'autorisation';

  @override
  String get errorsOauthAuthorizationDenied => 'Autorisation refusée';

  @override
  String get errorsWebViewLoadFailed =>
      'Échec du chargement de la page d\'authentification';

  @override
  String get errorsFailedToLoadProfile =>
      'Échec du chargement du profil utilisateur';

  @override
  String get errorsUserNotFound => 'Utilisateur non trouvé';

  @override
  String get errorsSessionDeleted => 'La session a été supprimée';

  @override
  String get errorsSessionDeletedDescription =>
      'Cette session a été définitivement supprimée';

  @override
  String errorsFieldError(String field, String reason) {
    return '$field : $reason';
  }

  @override
  String errorsValidationError(String field, int min, int max) {
    return '$field doit être entre $min et $max';
  }

  @override
  String errorsRetryIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '1 seconde',
    );
    return 'Réessayer dans $_temp0';
  }

  @override
  String errorsErrorWithCode(Object code, Object message) {
    return '$message (Erreur $code)';
  }

  @override
  String errorsDisconnectServiceFailed(Object service) {
    return 'Échec de la déconnexion de $service';
  }

  @override
  String errorsConnectServiceFailed(Object service) {
    return 'Échec de la connexion à $service. Veuillez réessayer.';
  }

  @override
  String get errorsFailedToLoadFriends =>
      'Échec du chargement de la liste d\'amis';

  @override
  String get errorsFailedToAcceptRequest =>
      'Échec de l\'acceptation de la demande d\'ami';

  @override
  String get errorsFailedToRejectRequest =>
      'Échec du rejet de la demande d\'ami';

  @override
  String get errorsFailedToRemoveFriend => 'Échec de la suppression de l\'ami';

  @override
  String get errorsSearchFailed => 'Échec de la recherche. Veuillez réessayer.';

  @override
  String get errorsFailedToSendRequest =>
      'Échuc de l\'envoi de la demande d\'ami';

  @override
  String get terminalWebBrowserRequired => 'Navigateur Web requis';

  @override
  String get terminalWebBrowserRequiredDescription =>
      'Les liens de connexion au terminal ne peuvent être ouverts que dans un navigateur Web pour des raisons de sécurité. Veuillez utiliser le scanner de code QR ou ouvrir ce lien sur un ordinateur.';

  @override
  String get terminalProcessingConnection => 'Traitement de la connexion...';

  @override
  String get terminalInvalidConnectionLink => 'Lien de connexion invalide';

  @override
  String get terminalInvalidConnectionLinkDescription =>
      'Le lien de connexion est manquant ou invalide. Veuillez vérifier l\'URL et réessayer.';

  @override
  String get terminalConnectTerminal => 'Connecter le terminal';

  @override
  String get terminalRequestDescription =>
      'Un terminal demande à se connecter à votre compte Happy Coder. Cela permettra au terminal d\'envoyer et de recevoir des messages en toute sécurité.';

  @override
  String get terminalConnectionDetails => 'Détails de la connexion';

  @override
  String get terminalPublicKey => 'Clé publique';

  @override
  String get terminalEncryption => 'Cryptage';

  @override
  String get terminalEndToEndEncrypted => 'Cryptage de bout en bout';

  @override
  String get terminalAcceptConnection => 'Accepter la connexion';

  @override
  String get terminalConnecting => 'Connexion...';

  @override
  String get terminalReject => 'Rejeter';

  @override
  String get terminalSecurity => 'Sécurité';

  @override
  String get terminalSecurityFooter =>
      'Ce lien de connexion a été traité en toute sécurité dans votre navigateur et n\'a jamais été envoyé à un serveur. Vos données privées resteront sécurisées et seul vous pouvez déchiffrer les messages.';

  @override
  String get terminalSecurityFooterDevice =>
      'Cette connexion a été traitée en toute sécurité sur votre appareil et n\'a jamais été envoyée à un serveur. Vos données privées resteront sécurisées et seul vous pouvez déchiffrer les messages.';

  @override
  String get terminalClientSideProcessing => 'Traitement côté client';

  @override
  String get terminalLinkProcessedLocally =>
      'Lien traité localement dans le navigateur';

  @override
  String get terminalLinkProcessedOnDevice =>
      'Lien traité localement sur l\'appareil';

  @override
  String get sidebarSessionsTitle => 'Terminaux';

  @override
  String get sidebarStatusConnected => 'Connecté';

  @override
  String get sidebarStatusConnecting => 'Connexion...';

  @override
  String get sidebarStatusDisconnected => 'Déconnecté';

  @override
  String get sidebarStatusError => 'Erreur';

  @override
  String get commandPalettePlaceholder => 'Tapez une commande ou recherchez...';

  @override
  String get toolViewInput => 'Entrée';

  @override
  String get toolViewOutput => 'Sortie';

  @override
  String get toolViewDescription => 'Description';

  @override
  String get toolViewInputParams => 'Paramètres d\'entrée';

  @override
  String get toolViewError => 'Erreur';

  @override
  String get toolViewCompleted => 'Outil terminé avec succès';

  @override
  String get toolViewNoOutput => 'Aucune sortie produite';

  @override
  String get toolViewRunning => 'L\'outil est en cours d\'exécution...';

  @override
  String get toolViewRawJsonDevMode => 'JSON brut (mode dev)';

  @override
  String get toolNamesTask => 'Tâche';

  @override
  String get toolNamesTerminal => 'Terminal';

  @override
  String get toolNamesSearchFiles => 'Rechercher des fichiers';

  @override
  String get toolNamesSearch => 'Rechercher';

  @override
  String get toolNamesSearchContent => 'Rechercher du contenu';

  @override
  String get toolNamesListFiles => 'Lister les fichiers';

  @override
  String get toolNamesPlanProposal => 'Proposition de plan';

  @override
  String get toolNamesReadFile => 'Lire le fichier';

  @override
  String get toolNamesEditFile => 'Modifier le fichier';

  @override
  String get toolNamesWriteFile => 'Écrire le fichier';

  @override
  String get toolNamesFetchUrl => 'Récupérer l\'URL';

  @override
  String get toolNamesReadNotebook => 'Lire le carnet';

  @override
  String get toolNamesEditNotebook => 'Modifier le carnet';

  @override
  String get toolNamesTodoList => 'Liste de tâches';

  @override
  String get toolNamesWebSearch => 'Recherche Web';

  @override
  String get toolNamesReasoning => 'Raisonnement';

  @override
  String get toolNamesApplyChanges => 'Mettre à jour le fichier';

  @override
  String get toolNamesViewDiff => 'Modifications du fichier actuel';

  @override
  String get toolNamesQuestion => 'Question';

  @override
  String toolDescTerminalCmd(String cmd) {
    return 'Terminal(cmd: $cmd)';
  }

  @override
  String toolDescSearchPattern(Object pattern) {
    return 'Rechercher(motif: $pattern)';
  }

  @override
  String toolDescSearchPath(Object basename) {
    return 'Rechercher(chemin: $basename)';
  }

  @override
  String toolDescFetchUrlHost(Object host) {
    return 'Récupérer l\'URL(url: $host)';
  }

  @override
  String toolDescEditNotebookMode(Object mode, Object path) {
    return 'Modifier le carnet(fichier: $path, mode: $mode)';
  }

  @override
  String toolDescTodoListCount(Object count) {
    return 'Liste de tâches(compte: $count)';
  }

  @override
  String toolDescWebSearchQuery(Object query) {
    return 'Recherche Web(requête: $query)';
  }

  @override
  String toolDescGrepPattern(Object pattern) {
    return 'grep(motif: $pattern)';
  }

  @override
  String toolDescMultiEditEdits(Object count, Object path) {
    return '$path ($count modifications)';
  }

  @override
  String toolDescReadingFile(Object file) {
    return 'Lecture de $file';
  }

  @override
  String toolDescWritingFile(Object file) {
    return 'Écriture de $file';
  }

  @override
  String toolDescModifyingFile(Object file) {
    return 'Modification de $file';
  }

  @override
  String toolDescModifyingFiles(Object count) {
    return 'Modification de $count fichiers';
  }

  @override
  String toolDescModifyingMultipleFiles(Object count, Object file) {
    return '$file et $count autres';
  }

  @override
  String get toolDescShowingDiff => 'Affichage des modifications';

  @override
  String get filesSearchPlaceholder => 'Rechercher des fichiers...';

  @override
  String get filesDetachedHead => 'HEAD détaché';

  @override
  String filesSummary(Object staged, Object unstaged) {
    return '$staged indexés • $unstaged non indexés';
  }

  @override
  String get filesNotRepo => 'Pas un dépôt git';

  @override
  String get filesNotUnderGit =>
      'Ce répertoire n\'est pas sous contrôle de version git';

  @override
  String get filesSearching => 'Recherche de fichiers...';

  @override
  String get filesNoFilesFound => 'Aucun fichier trouvé';

  @override
  String get filesNoFilesInProject => 'Aucun fichier dans le projet';

  @override
  String get filesTryDifferentTerm => 'Essayez un terme de recherche différent';

  @override
  String filesSearchResults(int count) {
    return 'Résultats de recherche ($count)';
  }

  @override
  String get filesProjectRoot => 'Racine du projet';

  @override
  String filesStagedChanges(Object count) {
    return 'Modifications indexées ($count)';
  }

  @override
  String filesUnstagedChanges(Object count) {
    return 'Modifications non indexées ($count)';
  }

  @override
  String filesLoadingFile(Object fileName) {
    return 'Chargement de $fileName...';
  }

  @override
  String get filesBinaryFile => 'Fichier binaire';

  @override
  String get filesCannotDisplayBinary =>
      'Impossible d\'afficher le contenu du fichier binaire';

  @override
  String get filesDiff => 'Diff';

  @override
  String get filesFile => 'Fichier';

  @override
  String get filesFileEmpty => 'Le fichier est vide';

  @override
  String get filesNoChanges => 'Aucune modification à afficher';

  @override
  String get profileUserProfile => 'Profil utilisateur';

  @override
  String get profileDetails => 'Détails';

  @override
  String get profileFirstName => 'Prénom';

  @override
  String get profileLastName => 'Nom';

  @override
  String get profileUsername => 'Nom d\'utilisateur';

  @override
  String get profileStatus => 'État';

  @override
  String get agentPermissionModeTitle => 'MODE D\'AUTORISATION';

  @override
  String get agentPermissionModeDefault => 'Par défaut';

  @override
  String get agentPermissionModeAcceptEdits => 'Accepter les modifications';

  @override
  String get agentPermissionModePlan => 'Mode plan';

  @override
  String get agentPermissionModeBypassPermissions => 'Mode Yolo';

  @override
  String get agentPermissionModeBadgeAcceptAllEdits =>
      'Accepter toutes les modifications';

  @override
  String get agentPermissionModeBadgeBypassAllPermissions =>
      'Passer toutes les autorisations';

  @override
  String get agentPermissionModeBadgePlanMode => 'Mode plan';

  @override
  String get agentAgentClaude => 'Claude';

  @override
  String get agentAgentCodex => 'Codex';

  @override
  String get agentAgentGemini => 'Gemini';

  @override
  String get agentModelTitle => 'MODÈLE';

  @override
  String get agentModelConfigureInCli =>
      'Configurez les modèles dans les paramètres CLI';

  @override
  String agentContextRemaining(int percent) {
    return '$percent% restant';
  }

  @override
  String get agentSuggestionFileLabel => 'FICHIER';

  @override
  String get agentSuggestionFolderLabel => 'DOSSIER';

  @override
  String get agentNoMachinesAvailable => 'Aucune machine disponible';

  @override
  String get updateBannerUpdateAvailable => 'Mise à jour disponible';

  @override
  String get updateBannerPressToApply =>
      'Appuyez pour appliquer la mise à jour';

  @override
  String get updateBannerWhatsNew => 'Nouveautés';

  @override
  String get updateBannerSeeLatest =>
      'Voir les dernières mises à jour et améliorations';

  @override
  String get updateBannerNativeUpdateAvailable =>
      'Mise à jour de l\'application disponible';

  @override
  String get updateBannerTapToUpdateAppStore =>
      'Appuyez pour mettre à jour sur l\'App Store';

  @override
  String get updateBannerTapToUpdatePlayStore =>
      'Appuyez pour mettre à jour sur le Play Store';

  @override
  String changelogVersion(int version) {
    return 'Version $version';
  }

  @override
  String get changelogNoEntriesAvailable =>
      'Aucune entrée de journal des modifications disponible.';

  @override
  String get modalsAuthenticateTerminal => 'Authentifier le terminal';

  @override
  String get modalsPasteUrlFromTerminal =>
      'Collez l\'URL d\'authentification de votre terminal';

  @override
  String get modalsDeviceLinkedSuccessfully => 'Appareil lié avec succès';

  @override
  String get modalsTerminalConnectedSuccessfully =>
      'Terminal connecté avec succès';

  @override
  String get modalsInvalidAuthUrl => 'URL d\'authentification invalide';

  @override
  String get modalsDeveloperMode => 'Mode développeur';

  @override
  String get modalsDeveloperModeEnabled => 'Mode développeur activé';

  @override
  String get modalsDeveloperModeDisabled => 'Mode développeur désactivé';

  @override
  String get modalsDisconnectGithub => 'Déconnecter GitHub';

  @override
  String get modalsDisconnectGithubConfirm =>
      'Êtes-vous sûr de vouloir déconnecter votre compte GitHub ?';

  @override
  String modalsDisconnectService(String service) {
    return 'Déconnecter $service';
  }

  @override
  String modalsDisconnectServiceConfirm(Object service) {
    return 'Êtes-vous sûr de vouloir déconnecter $service de votre compte ?';
  }

  @override
  String get modalsDisconnect => 'Déconnecter';

  @override
  String get modalsFailedToConnectTerminal =>
      'Échec de la connexion au terminal';

  @override
  String get modalsCameraPermissionsRequiredToConnectTerminal =>
      'Les permissions de caméra sont requises pour connecter le terminal';

  @override
  String get modalsFailedToLinkDevice => 'Échec de la liaison de l\'appareil';

  @override
  String get navigationConnectTerminal => 'Connecter le terminal';

  @override
  String get navigationLinkNewDevice => 'Lier un nouvel appareil';

  @override
  String get navigationRestoreWithSecretKey => 'Restaurer avec la clé secrète';

  @override
  String get navigationWhatsNew => 'Nouveautés';

  @override
  String get navigationFriends => 'Amis';

  @override
  String get emptyMainScreenReadyToCode => 'Prêt à coder ?';

  @override
  String get emptyMainScreenInstallCli => 'Installez le CLI Happy';

  @override
  String get emptyMainScreenRunIt => 'Exécutez-le';

  @override
  String get emptyMainScreenScanQrCode => 'Scannez le code QR';

  @override
  String get emptyMainScreenOpenCamera => 'Ouvrir la caméra';

  @override
  String get reviewEnjoyingApp => 'Vous aimez l\'application ?';

  @override
  String get reviewFeedbackPrompt => 'Nous aimerions avoir vos commentaires !';

  @override
  String get reviewYesILoveIt => 'Oui, j\'adore !';

  @override
  String get reviewNotReally => 'Pas vraiment';

  @override
  String itemsCopiedToClipboard(String label) {
    return '$label copié dans le presse-papiers';
  }

  @override
  String messageSwitchedToMode(String mode) {
    return 'Passé en mode $mode';
  }

  @override
  String get messageUnknownEvent => 'Événement inconnu';

  @override
  String messageUsageLimitUntil(Object time) {
    return 'Limite d\'utilisation atteinte jusqu\'à $time';
  }

  @override
  String get messageUnknownTime => 'heure inconnue';

  @override
  String get codexPermissionsYesForSession =>
      'Oui, et ne pas demander pour une session';

  @override
  String get codexPermissionsStopAndExplain =>
      'Arrêter, et expliquer quoi faire';

  @override
  String get claudePermissionsYesAllowAllEdits =>
      'Oui, autoriser toutes les modifications pendant cette session';

  @override
  String get claudePermissionsYesForTool =>
      'Oui, ne pas demander à nouveau pour cet outil';

  @override
  String get claudePermissionsNoTellClaude =>
      'Non, et fournir des commentaires';

  @override
  String get textSelectionSelectText => 'Sélectionner la plage de texte';

  @override
  String get textSelectionTitle => 'Sélectionner le texte';

  @override
  String get textSelectionNoTextProvided => 'Aucun texte fourni';

  @override
  String get textSelectionTextNotFound => 'Texte non trouvé ou expiré';

  @override
  String get textSelectionTextCopied => 'Texte copié dans le presse-papiers';

  @override
  String get textSelectionFailedToCopy =>
      'Échec de la copie du texte dans le presse-papiers';

  @override
  String get textSelectionNoTextToCopy => 'Aucun texte disponible à copier';

  @override
  String get markdownCodeCopied => 'Code copié';

  @override
  String get markdownCopyFailed => 'Échec de la copie';

  @override
  String get markdownMermaidRenderFailed =>
      'Échec du rendu du diagramme mermaid';

  @override
  String get artifactsTitle => 'Artefacts';

  @override
  String get artifactsCountSingular => '1 artefact';

  @override
  String artifactsCountPlural(int count) {
    return '$count artefacts';
  }

  @override
  String get artifactsEmpty => 'Pas encore d\'artefacts';

  @override
  String get artifactsEmptyDescription =>
      'Créez votre premier artefact pour commencer';

  @override
  String get artifactsNew => 'Nouvel artefact';

  @override
  String get artifactsEdit => 'Modifier l\'artefact';

  @override
  String get artifactsDelete => 'Supprimer';

  @override
  String get artifactsUpdateError =>
      'Échec de la mise à jour de l\'artefact. Veuillez réessayer.';

  @override
  String get artifactsNotFound => 'Artefact non trouvé';

  @override
  String get artifactsDiscardChanges => 'Ignorer les modifications ?';

  @override
  String get artifactsDiscardChangesDescription =>
      'Vous avez des modifications non enregistrées. Êtes-vous sûr de vouloir les ignorer ?';

  @override
  String get artifactsDeleteConfirm => 'Supprimer l\'artefact ?';

  @override
  String get artifactsDeleteConfirmDescription =>
      'Cette action ne peut pas être annulée';

  @override
  String get artifactsTitleLabel => 'TITRE';

  @override
  String get artifactsTitlePlaceholder => 'Entrez un titre pour votre artefact';

  @override
  String get artifactsBodyLabel => 'CONTENU';

  @override
  String get artifactsBodyPlaceholder => 'Écrivez votre contenu ici...';

  @override
  String get artifactsEmptyFieldsError =>
      'Veuillez entrer un titre ou un contenu';

  @override
  String get artifactsCreateError =>
      'Échec de la création de l\'artefact. Veuillez réessayer.';

  @override
  String get artifactsSave => 'Enregistrer';

  @override
  String get artifactsSaving => 'Enregistrement...';

  @override
  String get artifactsLoading => 'Chargement des artefacts...';

  @override
  String get artifactsError => 'Échec du chargement de l\'artefact';

  @override
  String get friendsTitle => 'Amis';

  @override
  String get friendsManageFriends => 'Gérez vos amis et connexions';

  @override
  String get friendsSearchTitle => 'Trouver des amis';

  @override
  String get friendsPendingRequests => 'Demandes d\'ami';

  @override
  String get friendsMyFriends => 'Mes amis';

  @override
  String get friendsNoFriendsYet => 'Vous n\'avez pas encore d\'amis';

  @override
  String get friendsFindFriends => 'Trouver des amis';

  @override
  String get friendsRemove => 'Supprimer';

  @override
  String get friendsPendingRequest => 'En attente';

  @override
  String friendsSentOn(String date) {
    return 'Envoyé le $date';
  }

  @override
  String get friendsAccept => 'Accepter';

  @override
  String get friendsReject => 'Rejeter';

  @override
  String get friendsAddFriend => 'Ajouter un ami';

  @override
  String get friendsAlreadyFriends => 'Déjà amis';

  @override
  String get friendsRequestPending => 'Demande en attente';

  @override
  String get friendsSearchInstructions =>
      'Entrez un nom d\'utilisateur pour rechercher des amis';

  @override
  String get friendsSearchPlaceholder => 'Entrez le nom d\'utilisateur...';

  @override
  String get friendsSearching => 'Recherche...';

  @override
  String get friendsUserNotFound => 'Utilisateur non trouvé';

  @override
  String get friendsNoUserFound =>
      'Aucun utilisateur trouvé avec ce nom d\'utilisateur';

  @override
  String get friendsCheckUsername =>
      'Veuillez vérifier le nom d\'utilisateur et réessayer';

  @override
  String get friendsHowToFind => 'Comment trouver des amis';

  @override
  String get friendsFindInstructions =>
      'Recherchez des amis par leur nom d\'utilisateur. Vous et votre ami devez avoir GitHub connecté pour envoyer des demandes d\'ami.';

  @override
  String get friendsRequestSent => 'Demande d\'ami envoyée !';

  @override
  String get friendsRequestAccepted => 'Demande d\'ami acceptée !';

  @override
  String get friendsRequestRejected => 'Demande d\'ami rejetée';

  @override
  String get friendsFriendRemoved => 'Ami supprimé';

  @override
  String get friendsConfirmRemove => 'Supprimer l\'ami';

  @override
  String get friendsConfirmRemoveMessage =>
      'Êtes-vous sûr de vouloir supprimer cet ami ?';

  @override
  String get friendsCannotAddYourself =>
      'Vous ne pouvez pas vous envoyer une demande d\'ami';

  @override
  String get friendsBothMustHaveGithub =>
      'Les deux utilisateurs doivent avoir GitHub connecté pour devenir amis';

  @override
  String get friendsStatusNone => 'Non connecté';

  @override
  String get friendsStatusRequested => 'Demande envoyée';

  @override
  String get friendsStatusPending => 'Demande en attente';

  @override
  String get friendsStatusFriend => 'Amis';

  @override
  String get friendsStatusRejected => 'Rejeté';

  @override
  String get friendsAcceptRequest => 'Accepter la demande';

  @override
  String get friendsRemoveFriend => 'Supprimer l\'ami';

  @override
  String friendsRemoveFriendConfirm(Object name) {
    return 'Êtes-vous sûr de vouloir supprimer $name de vos amis ?';
  }

  @override
  String friendsRequestSentDescription(Object name) {
    return 'Votre demande d\'ami a été envoyée à $name';
  }

  @override
  String get friendsRequestFriendship => 'Demander l\'amitié';

  @override
  String get friendsCancelRequest => 'Annuler la demande d\'amitié';

  @override
  String friendsCancelRequestConfirm(Object name) {
    return 'Annuler votre demande d\'amitié à $name ?';
  }

  @override
  String get friendsDenyRequest => 'Refuser l\'amitié';

  @override
  String friendsNowFriendsWith(Object name) {
    return 'Vous êtes maintenant ami avec $name';
  }

  @override
  String feedFriendRequestFrom(String name) {
    return '$name vous a envoyé une demande d\'ami';
  }

  @override
  String get feedFriendRequestGeneric => 'Nouvelle demande d\'ami';

  @override
  String feedFriendAccepted(Object name) {
    return 'Vous êtes maintenant ami avec $name';
  }

  @override
  String get feedFriendAcceptedGeneric => 'Demande d\'ami acceptée';

  @override
  String get usageToday => 'Aujourd\'hui';

  @override
  String get usageLast7Days => '7 derniers jours';

  @override
  String get usageLast30Days => '30 derniers jours';

  @override
  String get usageTotalTokens => 'Jetons totaux';

  @override
  String get usageTotalCost => 'Coût total';

  @override
  String get usageTokens => 'Jetons';

  @override
  String get usageCost => 'Coût';

  @override
  String get usageUsageOverTime => 'Utilisation au fil du temps';

  @override
  String get usageByModel => 'Par modèle';

  @override
  String get usageNoData => 'Aucune donnée d\'utilisation disponible';

  @override
  String get offlineBannerNoConnection => 'No internet connection';

  @override
  String get offlineBannerReconnecting => 'Reconnecting...';
}
