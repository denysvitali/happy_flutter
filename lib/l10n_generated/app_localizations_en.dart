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
  String get commonCancel => 'Cancel';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonAdd => 'Add';

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
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonOptional => 'optional';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String get tabsSettings => 'Settings';

  @override
  String get tabsLoops => 'Loops';

  @override
  String get statusConnected => 'Connected';

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
  String get statusUnknown => 'Unknown';

  @override
  String get statusPermissionRequired => 'Permission required';

  @override
  String get authAccessDenied => 'Access denied';

  @override
  String get authAuthenticationFailed => 'Authentication failed';

  @override
  String get welcomeCreateAccount => 'Create account';

  @override
  String get welcomeLinkOrRestoreAccount => 'Link or restore account';

  @override
  String get sessionTitle => 'Sessions';

  @override
  String get sessionNewSession => 'New Session';

  @override
  String get sessionNoSessionsYet => 'No sessions yet';

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
  String get chatStopCurrentTask => 'Stop current task';

  @override
  String get chatStopAgentProcess => 'Stop agent process';

  @override
  String get chatStopAgentProcessConfirmTitle => 'Stop agent process?';

  @override
  String get chatStopAgentProcessConfirmBody =>
      'This terminates the session\'s process or pod. The conversation is kept and can be restarted by sending another message.';

  @override
  String get chatStopAgentProcessSuccess => 'Agent process stopped';

  @override
  String get chatStopAgentProcessFailure =>
      'Could not stop the agent process. It may still be running.';

  @override
  String get newSessionPhaseCheckingMachine => 'Checking machine…';

  @override
  String get newSessionPhaseSavingPreferences => 'Saving preferences…';

  @override
  String get newSessionPhasePreparingWorktree => 'Creating worktree…';

  @override
  String get newSessionPhaseSchedulingContainer =>
      'Scheduling container and preparing repository…';

  @override
  String get newSessionPhaseStartingAgent => 'Starting agent…';

  @override
  String get newSessionPhaseFinalizing => 'Finalizing session…';

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
  String get newSessionTitle => 'New Session';

  @override
  String get newSessionNoMachinesFound =>
      'No machines found. Start a Happy session on your computer first.';

  @override
  String get newSessionMachineUnreachable =>
      'Machine is unreachable. Make sure the Happy daemon is running and try again.';

  @override
  String get newSessionDaemonOutdated =>
      'This machine\'s Happy daemon is outdated. Update Happy on the machine, restart the daemon, and try again.';

  @override
  String get newSessionCouldNotStartSession =>
      'Could not start session. Please try again.';

  @override
  String get newSessionRepositoryUrl => 'Git repository';

  @override
  String get newSessionRepositoryRequired => 'A git repository is required';

  @override
  String get newSessionGitRef => 'Branch or ref';

  @override
  String get newSessionGitRefHint => 'main';

  @override
  String get newSessionGitRefRequired => 'A branch or git ref is required';

  @override
  String get newSessionKubernetesUnavailable =>
      'This daemon cannot create Kubernetes pods';

  @override
  String get newSessionSpawnLocal => 'Local';

  @override
  String get newSessionSpawnKubernetes => 'Kubernetes';

  @override
  String get newSessionRepositoryUrlHint => 'https://github.com/org/repo.git';

  @override
  String get newSessionReadyToCreate => 'Ready to create session';

  @override
  String get sessionPodSection => 'Kubernetes pod';

  @override
  String get sessionPod => 'Session pod';

  @override
  String get sessionPodScheduling => 'Scheduling';

  @override
  String get sessionPodReady => 'Ready';

  @override
  String get sessionPodPaused => 'Paused';

  @override
  String get sessionPodArchived => 'Archived';

  @override
  String get sessionPodFailed => 'Failed';

  @override
  String get sessionPodLoadFailed =>
      'Could not load the pod state. Check that the daemon is online and up to date.';

  @override
  String get sessionPodLogs => 'Logs';

  @override
  String get sessionPodLogsEmpty => 'No pod logs are available yet.';

  @override
  String get sessionPodLogsTruncated =>
      'Showing the most recent pod log lines.';

  @override
  String get sessionPodPause => 'Pause';

  @override
  String get sessionPodResume => 'Resume';

  @override
  String get sessionPodKill => 'Kill pod';

  @override
  String get claudeAuthTitle => 'Claude Code authentication';

  @override
  String get claudeAuthSharedCredentials => 'Shared Claude Code credentials';

  @override
  String get claudeAuthSharedCredentialsHelp =>
      'Authenticate once with your Claude subscription and share it with all session pods.';

  @override
  String get claudeAuthInstructions =>
      'Start authentication, sign in to Claude Code in your browser, then paste the authorization response below.';

  @override
  String get claudeAuthAuthenticated =>
      'Claude Code is authenticated. New session pods will use the shared credentials.';

  @override
  String get claudeAuthOpenLink => 'Open sign-in link';

  @override
  String get claudeAuthResponse => 'Authorization response';

  @override
  String get claudeAuthResponseHint =>
      'Paste the complete response from Claude';

  @override
  String get claudeAuthBegin => 'Authenticate';

  @override
  String get claudeAuthAgain => 'Authenticate again';

  @override
  String get claudeAuthComplete => 'Complete';

  @override
  String get sessionHistoryTitle => 'Sessions';

  @override
  String get sessionInfoTitle => 'Session Info';

  @override
  String get sessionInfoThinking => 'Thinking';

  @override
  String get sessionInfoMetadataCopied => 'Metadata copied to clipboard';

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
  String get machineLastKnownPid => 'Last Known PID';

  @override
  String get machineCliVersion => 'CLI Version';

  @override
  String get machineCompatibilityTitle => 'Happy update recommended';

  @override
  String machineCompatibilityMessage(
    String currentVersion,
    String requiredVersion,
  ) {
    return 'Version $currentVersion is installed. Update to $requiredVersion or later for the latest remote features.';
  }

  @override
  String get machineCompatibilityAction => 'Copy update command';

  @override
  String get machineCompatibilityCopied => 'Update command copied';

  @override
  String get machineHost => 'Host';

  @override
  String get machineMachineId => 'Machine ID';

  @override
  String get machineUsername => 'Username';

  @override
  String get machinePlatform => 'Platform';

  @override
  String get machineArchitecture => 'Architecture';

  @override
  String get machineShowLess => 'Show less';

  @override
  String get chatStartConversation => 'Start a conversation';

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
  String get settingsTitle => 'Settings';

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
  String get settingsHubToolsTitle => 'Agents & Tools';

  @override
  String get workflowPresetsTitle => 'Workflow presets';

  @override
  String get workflowPresetsDescription =>
      'Presets update existing app settings and can be adjusted later.';

  @override
  String get workflowPresetFocusTitle => 'Focus';

  @override
  String get workflowPresetFocusSubtitle =>
      'Quiet chat, compact sessions, unread-first navigation';

  @override
  String get workflowPresetVoiceTitle => 'Voice';

  @override
  String get workflowPresetVoiceSubtitle =>
      'Speech on, inline context, mission-control browsing';

  @override
  String get workflowPresetLowNoiseTitle => 'Low noise';

  @override
  String get workflowPresetLowNoiseSubtitle =>
      'Hide tool chatter and inactive work by default';

  @override
  String get workflowPresetDebugTitle => 'Debug';

  @override
  String get workflowPresetDebugSubtitle =>
      'Show internals, tool calls, todos, and developer logging';

  @override
  String get workflowPresetActiveSuffix => '- Active';

  @override
  String get workflowPresetAppliedSnack => 'preset applied';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAccountSubtitle => 'Manage your account details';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsFeaturesSubtitle => 'Enable or disable app features';

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsReportIssue => 'Report an Issue';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsTermsOfService => 'Terms of Service';

  @override
  String get settingsUsage => 'Usage';

  @override
  String get settingsUsageSubtitle => 'View your API usage and costs';

  @override
  String get settingsProfiles => 'Profiles';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirm =>
      'Are you sure you want to sign out? Make sure you have backed up your secret key!';

  @override
  String get settingsAccountDangerZone => 'Danger Zone';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsServerUrlLabel => 'Please enter a server URL';

  @override
  String get settingsServerResetToDefault => 'Reset to Default';

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
  String get commandPaletteSemanticsLabel => 'Command palette';

  @override
  String get commandPaletteNoResults => 'No commands found';

  @override
  String get commandPaletteTryDifferentSearch => 'Try a different search term';

  @override
  String get toolStateApprovalNeeded => 'Approval needed';

  @override
  String get toolStateRunning => 'Running';

  @override
  String get toolStateDone => 'Done';

  @override
  String get toolStateFailed => 'Failed';

  @override
  String get toolStateQueued => 'Queued';

  @override
  String get toolStateCanceled => 'Canceled';

  @override
  String get toolStateStopped => 'Stopped';

  @override
  String get toolOutputExpandHint => 'Expand tool output';

  @override
  String get toolOutputCollapseHint => 'Collapse tool output';

  @override
  String get toolOutputShowMore => 'Show more';

  @override
  String get toolOutputShowLess => 'Show less';

  @override
  String get toolDetailsOpenHint => 'Open tool details';

  @override
  String get toolDetailsView => 'View tool details';

  @override
  String get toolDetailsButtonHint =>
      'Use the details button to view input & output';

  @override
  String get agentAgentClaude => 'Claude';

  @override
  String get agentAgentCodex => 'Codex';

  @override
  String get agentAgentGemini => 'Gemini';

  @override
  String desktopUpdateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get desktopUpdateDownload => 'Download';

  @override
  String get desktopUpdateDownloading => 'Downloading update…';

  @override
  String desktopUpdateDownloadingProgress(int progress) {
    return 'Downloading update… $progress%';
  }

  @override
  String get desktopUpdateReady => 'Update installed — restart to apply';

  @override
  String get desktopUpdateRestart => 'Restart now';

  @override
  String get changelogNoEntriesAvailable => 'No changelog entries available.';

  @override
  String get emptySessionsFirstTimeTitle => 'Connect your computer';

  @override
  String get emptySessionsFirstTimeSubtitle =>
      'Link Happy to a computer, then start coding from anywhere.';

  @override
  String get emptySessionsFirstTimeStep1Label => 'Install Happy CLI';

  @override
  String get emptySessionsFirstTimeStep1Detail =>
      'npm install -g happy-coder@latest';

  @override
  String get emptySessionsFirstTimeStep2Label => 'Link your account';

  @override
  String get emptySessionsFirstTimeStep2Detail =>
      'Run happy auth login --method mobile';

  @override
  String get emptySessionsFirstTimeStep3Label => 'Keep your computer available';

  @override
  String get emptySessionsFirstTimeStep3Detail => 'Run happy daemon install';

  @override
  String get sessionsConnectComputer => 'Connect computer';

  @override
  String get emptySessionsOfflineTitle => 'Computer offline';

  @override
  String get emptySessionsOfflineSubtitle =>
      'Bring a linked computer online, then refresh to start a session.';

  @override
  String get sessionsViewComputers => 'View computers';

  @override
  String get sessionsStartSession => 'Start session';

  @override
  String get emptySessionsReturningTitle => 'No active sessions';

  @override
  String get emptySessionsReturningSubtitle =>
      'Your previous sessions have ended. Start a new one to keep coding.';

  @override
  String get textSelectionFailedToCopy => 'Failed to copy text to clipboard';

  @override
  String get artifactsTitle => 'Artifacts';

  @override
  String get artifactsEmpty => 'No artifacts yet';

  @override
  String get artifactsNew => 'New Artifact';

  @override
  String get artifactsEdit => 'Edit Artifact';

  @override
  String get artifactsDeleteConfirm => 'Delete artifact?';

  @override
  String get artifactsTitleLabel => 'TITLE';

  @override
  String get offlineBannerNoConnection => 'No internet connection';

  @override
  String get offlineBannerLiveUpdatesDisconnected =>
      'Live updates disconnected';

  @override
  String get offlineBannerServiceUnavailable =>
      'Service connection unavailable';

  @override
  String offlineBannerReconnectingIn(int seconds) {
    return 'Reconnecting in ${seconds}s…';
  }

  @override
  String get offlineBannerReconnectNow => 'Reconnect now';

  @override
  String a11yConnectionStatusBanner(String status) {
    return 'Connection status. $status';
  }

  @override
  String a11ySettingsRow(String title, String subtitle) {
    return '$title. $subtitle';
  }

  @override
  String a11yTabWithBadge(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new items',
      one: '1 new item',
    );
    return '$label, $_temp0';
  }

  @override
  String a11yEmptyState(String title, String subtitle) {
    return '$title. $subtitle';
  }

  @override
  String a11yErrorState(String message) {
    return 'Error. $message';
  }

  @override
  String get a11ySettingsRowOn => 'On';

  @override
  String get a11ySettingsRowOff => 'Off';

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
  String get authConnecting => 'Connecting...';

  @override
  String get authInvalidQR => 'Invalid QR code';

  @override
  String get authServerConnectionError => 'Cannot connect to server';

  @override
  String get sessionsNew => 'New Session';

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
  String get sessionsGrok => 'Grok';

  @override
  String get sessionsAgent => 'Agent';

  @override
  String get sessionsNoSessionSelected => 'No session selected';

  @override
  String get sessionsNoSessionSelectedHint =>
      'Choose a session from the list to open its chat, or start a new one.';

  @override
  String get sessionsResizeSidebar => 'Resize the session list';

  @override
  String paneWidthPixels(int width) {
    return '$width pixels wide';
  }

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
  String get sessionsViewStyleFolderCentric => 'Folder-centric';

  @override
  String get sessionsViewStyleUnreadFocus => 'Unread Focus';

  @override
  String get sessionsViewStyleMissionControl => 'Mission Control';

  @override
  String get missionControlFocusQueue => 'Focus queue';

  @override
  String get missionControlFilterAll => 'All';

  @override
  String get missionControlWorkspacePulse => 'Workspace pulse';

  @override
  String get missionControlReview => 'Review';

  @override
  String missionControlNewCount(int count) {
    return '$count new';
  }

  @override
  String get missionControlStatBlocked => 'blocked';

  @override
  String get missionControlStatError => 'error';

  @override
  String get missionControlStatUnread => 'unread';

  @override
  String get missionControlStatWorking => 'working';

  @override
  String get missionControlStatIdle => 'idle';

  @override
  String get missionControlMarkRead => 'Mark read';

  @override
  String get missionControlTriage => 'Session actions';

  @override
  String get missionControlPinToTop => 'Pin to top';

  @override
  String get missionControlUnpin => 'Unpin';

  @override
  String get missionControlSnooze => 'Snooze 1 hour';

  @override
  String get missionControlUnsnooze => 'Unsnooze';

  @override
  String get missionControlMuteWorkspace => 'Workspace muted';

  @override
  String get missionControlUnmuteWorkspace => 'Workspace unmuted';

  @override
  String get missionControlMutedLabel => 'muted';

  @override
  String missionControlSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String missionControlMoreActions(int count) {
    return '… +$count more';
  }

  @override
  String missionControlQuietWorkspaces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quiet workspaces',
      one: '1 quiet workspace',
    );
    return '$_temp0';
  }

  @override
  String missionControlSilent(String duration) {
    return '$duration silent';
  }

  @override
  String get missionControlAllClear => 'All clear';

  @override
  String get missionControlLiveWire => 'Live wire';

  @override
  String missionControlLiveWireEmpty(int count) {
    return 'Watching $count streams…';
  }

  @override
  String get missionControlWireSent => 'You';

  @override
  String get missionControlWireDone => 'Finished';

  @override
  String get missionControlWireJoined => 'Started';

  @override
  String get missionControlPeekQuickLook => 'Quick look';

  @override
  String get missionControlPeekOpenChat => 'Open chat';

  @override
  String get missionControlPeekStop => 'Stop';

  @override
  String get missionControlPeekStopRequested => 'Stop requested';

  @override
  String get missionControlPeekStopFailed =>
      'Could not stop the agent. Try again.';

  @override
  String get missionControlPeekNoMessages =>
      'No cached messages yet — open the chat to load them.';

  @override
  String get missionControlPeekYou => 'You';

  @override
  String get missionControlPeekAgent => 'Agent';

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
  String get autoArchiveIdleNever => 'Never';

  @override
  String get autoArchiveIdle30Min => '30 min';

  @override
  String get autoArchiveIdle2Hours => '2 hours';

  @override
  String get autoArchiveIdle8Hours => '8 hours';

  @override
  String get autoArchiveIdle1Day => '1 day';

  @override
  String get autoArchiveIdle7Days => '7 days';

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
  String get webSearchQueriesLabel => 'Queries';

  @override
  String get webSearchNoResultsNote =>
      'Search completed — result pages are not included in the transcript.';

  @override
  String get messageFocusSelectText => 'Select text';

  @override
  String get messageFocusSpeak => 'Speak';

  @override
  String get messageFocusStopSpeaking => 'Stop';

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
  String get chatInputHint => 'Message...';

  @override
  String get chatComposerExpand => 'Expand editor';

  @override
  String get chatComposerCollapse => 'Collapse editor';

  @override
  String get chatComposerFullscreenTitle => 'Compose message';

  @override
  String chatComposerCharacterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
    );
    return '$_temp0';
  }

  @override
  String get chatInputProfileTitle => 'Profile';

  @override
  String get chatInputProfileDefault => 'Default';

  @override
  String get chatInputProfileDefaultSubtitle => 'Server-configured defaults';

  @override
  String get chatSend => 'Send';

  @override
  String get chatQueueNextTurn => 'Queue for next turn';

  @override
  String get chatNextTurn => 'Queue';

  @override
  String get chatUpdateCurrentTurn => 'Update current turn';

  @override
  String get chatUpdateCurrentTurnShort => 'Update';

  @override
  String get chatActiveTurnDeliveryHint =>
      'Update changes the running turn; Queue starts afterward.';

  @override
  String get chatQueuedForNextTurn => 'Queued for next turn';

  @override
  String get chatSending => 'Sending';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatCopyMessage => 'Copy';

  @override
  String get chatChat => 'Chat';

  @override
  String get chatFailedToLoadMessages => 'Failed to load messages';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsServerNotReachable => 'Server not reachable';

  @override
  String get settingsVoice => 'Voice';

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
  String get grokUsageTitle => 'Grok Usage';

  @override
  String get grokUsageSubtitle =>
      'Monthly billing allowance for Grok Build on your machines';

  @override
  String get grokUsageAccount => 'Account';

  @override
  String get grokUsageEmail => 'Email';

  @override
  String get grokUsageBillingPeriod => 'Billing period';

  @override
  String get grokUsageMonthlyAllowance => 'Monthly allowance';

  @override
  String get grokUsageMonthlyLimit => 'Included credits';

  @override
  String get grokUsageOnDemandCap => 'Pay-as-you-go cap';

  @override
  String get grokUsageOnDemandDisabled => 'Disabled';

  @override
  String get grokUsageNoMachines => 'No machines available';

  @override
  String get grokUsageSelectMachine => 'Machine';

  @override
  String get grokUsageNoMachinesSubtitle =>
      'Connect a machine to inspect local Grok Build usage';

  @override
  String get grokUsageNotAvailable => 'Grok usage not available';

  @override
  String get grokUsageNotAvailableSubtitle =>
      'Make sure Grok Build is signed in on the selected machine';

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
  String codexUsageResetsAt(String time) {
    return 'Resets $time';
  }

  @override
  String get codexUsageLimitResets => 'Usage limit resets';

  @override
  String get codexUsageResetsAvailable => 'Available resets';

  @override
  String get codexUsageLimitReset => 'Full reset';

  @override
  String get codexUsageDoesNotExpire => 'Does not expire';

  @override
  String codexUsageExpiresInDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left · $date',
      one: '1 day left · $date',
      zero: 'Less than 1 day left · $date',
    );
    return '$_temp0';
  }

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
  String get claudeLimitsExtraUsage => 'Extra Usage';

  @override
  String get claudeLimitsMonthlyLimit => 'Monthly Limit';

  @override
  String get claudeLimitsUsedCredits => 'Used Credits';

  @override
  String get claudeLocalUsageSection => 'Token Usage';

  @override
  String get claudeLocalUsageTotal => 'Total tokens';

  @override
  String get claudeLocalUsageMessages => 'Messages';

  @override
  String get claudeLocalUsageSessions => 'Sessions';

  @override
  String get claudeLocalUsageToolCalls => 'Tool calls';

  @override
  String get claudeLocalUsageNoData => 'No local usage yet';

  @override
  String get claudeLocalUsageNoDataSubtitle =>
      'Start a Claude Code session to see token stats';

  @override
  String get claudeLocalUsageLast30Days => 'Last 30 days';

  @override
  String get claudeLocalUsageRequiresUpdate =>
      'Update your machine daemon to see local usage';

  @override
  String get claudeLocalUsageRefresh => 'Refresh';

  @override
  String get claudeLocalUsageFailed => 'Could not load local usage';

  @override
  String get claudeLocalUsageLifetime => 'Lifetime';

  @override
  String get claudeLimitsNoMachines => 'No machines available';

  @override
  String get claudeLimitsSelectMachine => 'Machine';

  @override
  String get settingsServerResetSuccess => 'Server URL reset to default';

  @override
  String get settingsServerSaved => 'Server URL saved';

  @override
  String get settingsServerSaveVerify => 'Save & Verify';

  @override
  String get toolViewFullContent => 'View full content';

  @override
  String get toolSectionDiff => 'DIFF';

  @override
  String get toolSectionContent => 'CONTENT';

  @override
  String get toolSectionReading => 'Reading';

  @override
  String get toolSectionWriting => 'Writing';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionDeny => 'Deny';

  @override
  String get permissionStop => 'Stop';

  @override
  String get permissionAppliedOnce => 'Permission approved for this request';

  @override
  String get permissionAppliedForSession =>
      'Permission approved for this session';

  @override
  String get permissionDenialApplied => 'Permission denied';

  @override
  String get permissionYes => 'Yes';

  @override
  String get permissionYolo => 'YOLO';

  @override
  String get permissionReadOnly => 'Read Only';

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
  String get permissionActionInProgress => 'Permission action in progress';

  @override
  String get permissionMoreApprovalOptions => 'More approval options';

  @override
  String get permissionHideApprovalOptions => 'Hide approval options';

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
  String get errorNotFound => 'Not found';

  @override
  String get voiceAssistantError => 'Voice assistant error';

  @override
  String get appearanceTheme => 'Theme';

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
  String get settingsShowFlavorIcons => 'Show Flavor Icons';

  @override
  String get settingsAvatarStyle => 'Avatar Style';

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
  String get chatOnline => 'Online';

  @override
  String get chatStatusStopping => 'Stopping';

  @override
  String get chatStatusAgentFailed => 'Agent failed';

  @override
  String get chatStatusWillRestart => 'Will restart';

  @override
  String get chatStatusReconnecting => 'Reconnecting';

  @override
  String get chatStatusConnecting => 'Connecting';

  @override
  String get chatStatusApprovalNeeded => 'Approval needed';

  @override
  String get chatStatusWorkingOnSubtasks => 'Working on sub-tasks';

  @override
  String get chatStatusThinking => 'Thinking';

  @override
  String get chatActivityThinking => 'Thinking…';

  @override
  String get chatActivityStopping => 'Stopping…';

  @override
  String get chatActivityStopUnconfirmed =>
      'Stop not confirmed — still running';

  @override
  String get chatActivityStop => 'Stop';

  @override
  String get chatStatusRetryQueued => 'Retry queued';

  @override
  String get chatStatusNotDelivered => 'Not delivered';

  @override
  String get chatStatusSentSlow => 'Sent (slow)';

  @override
  String get chatSendSending => 'Sending';

  @override
  String get chatSendSendingSemantic => 'Message sending';

  @override
  String get chatSendRetryQueuedSemantic => 'Message retry queued';

  @override
  String get chatSendDelivered => 'Delivered';

  @override
  String get chatSendDeliveredSlow => 'Delivered — slow';

  @override
  String get chatSendDeliveredSemantic => 'Message delivered';

  @override
  String get chatSendDeliveredSlowSemantic =>
      'Message delivered after a slow send';

  @override
  String get chatSendNotDeliveredSemantic => 'Message not delivered';

  @override
  String get chatSendNotDeliveredRetrySemantic =>
      'Message not delivered — tap to retry';

  @override
  String get chatSendFailedRetry => 'Failed — tap to retry';

  @override
  String get chatClearFailedSafe =>
      'Could not clear the conversation. Try again.';

  @override
  String get chatLifecycleFailedTitle => 'Session agent stopped';

  @override
  String get chatLifecycleRecoverableMessage =>
      'The agent process stopped. Sending a message will try to restart it before delivery.';

  @override
  String get chatLifecycleBlockedMessage =>
      'The agent process stopped and cannot be restored. Start a new session to continue.';

  @override
  String get chatConversationCleared => 'Conversation cleared';

  @override
  String chatModelChanged(String from, String to) {
    return 'Model changed: $from → $to';
  }

  @override
  String get chatMoreOptions => 'More options';

  @override
  String get settingsClaudeCode => 'Claude Code';

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
  String get profilesEnvAddRow => 'Add variable';

  @override
  String get profilesEnvRemoveRow => 'Remove variable';

  @override
  String get profilesEnvShowValue => 'Show value';

  @override
  String get profilesEnvHideValue => 'Hide value';

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
  String get profilesCompatibleAgents => 'Compatible agents';

  @override
  String get profilesCompatibleAgentsHint =>
      'Choose which agents can use this profile';

  @override
  String get profilesCodexProviderEnvHint =>
      'Codex sessions can use the provider definitions below. Environment variables remain available for advanced or legacy configurations.';

  @override
  String get profilesCodexProvidersTitle => 'Codex providers';

  @override
  String get profilesCodexProvidersHint =>
      'Add model_providers entries for Codex-compatible gateways. Keys stay in the environment variable named below.';

  @override
  String get profilesCodexDefaultProviderLabel =>
      'Default provider ID (optional)';

  @override
  String get profilesCodexDefaultProviderHint =>
      'Uses the first provider when empty';

  @override
  String get profilesCodexProviderIdLabel => 'Provider ID';

  @override
  String get profilesCodexProviderIdHint => 'e.g. llm-proxy';

  @override
  String get profilesCodexProviderIdInvalid =>
      'Use only letters, numbers, hyphens, and underscores';

  @override
  String get profilesCodexProviderNameLabel => 'Display name (optional)';

  @override
  String get profilesCodexProviderNameHint => 'e.g. LLM Proxy';

  @override
  String get profilesCodexProviderBaseUrlLabel => 'Base URL';

  @override
  String get profilesCodexProviderBaseUrlHint => 'https://gateway.example/v1';

  @override
  String get profilesCodexProviderEnvKeyLabel => 'API key environment variable';

  @override
  String get profilesCodexProviderEnvKeyHint => 'LLM_PROXY_API_KEY';

  @override
  String get profilesCodexProviderEnvKeyInvalid =>
      'Use an uppercase environment variable name';

  @override
  String get profilesCodexProviderWireApiLabel => 'Wire API';

  @override
  String get profilesCodexProviderResponses => 'Responses API';

  @override
  String get profilesCodexProviderChat => 'Chat Completions';

  @override
  String get profilesCodexProviderAdd => 'Add provider';

  @override
  String get profilesCodexProviderRemove => 'Remove provider';

  @override
  String get profilesCodexProvidersEmpty => 'No Codex providers configured';

  @override
  String get profilesModelsTitle => 'Models';

  @override
  String get profilesModelsHint =>
      'Models available when this profile is selected';

  @override
  String get profilesModelLabel => 'Model identifier';

  @override
  String get profilesModelAdd => 'Add model';

  @override
  String get profilesModelRemove => 'Remove';

  @override
  String get profilesModelsEmpty => 'No models configured';

  @override
  String get profilesContextWindowTitle => 'Context window';

  @override
  String get profilesContextWindowHint =>
      'Token limit for this profile\'s Claude-compatible models. 1M requires Claude Code\'s extended window.';

  @override
  String get profilesContextWindowDefault => 'Provider default';

  @override
  String get profilesContextWindow1M => '1M tokens';

  @override
  String get profilesAtLeastOneAgent => 'Select at least one agent';

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
  String get voiceUseOfflineTitle => 'Use offline voice';

  @override
  String get voiceUseOfflineSubtitle =>
      'High-quality on-device TTS via sherpa-onnx. Falls back to system TTS while the model downloads or if generation fails.';

  @override
  String get voiceTestTtsPhrase => 'Hello! Text to speech is working.';

  @override
  String get voiceOfflineVoicesTitle => 'Offline voices';

  @override
  String get voiceDictationModelsTitle => 'Dictation models';

  @override
  String get voiceInstalledLabel => 'installed';

  @override
  String get voiceDownloadStatusReady => 'ready';

  @override
  String get voiceDownloadStatusDownloading => 'downloading…';

  @override
  String get voiceDownloadStatusFailed => 'download failed';

  @override
  String get voiceDownloadStatusNotDownloaded => 'not downloaded';

  @override
  String get voiceDownloadFailedRetrySuffix => ' · download failed, tap retry';

  @override
  String get voiceDownloadNotDownloadedSuffix => ' · not downloaded';

  @override
  String get voiceSelectLanguageTitle => 'Select Language';

  @override
  String voiceLanguagesCount(int count) {
    return '$count languages available';
  }

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
  String get sessionInfoActionExportDebug => 'Export Debug Info';

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
  String get sessionInfoDebugExportCopied => 'Debug info copied to clipboard';

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
  String get sessionSandboxEnforced => 'Sandboxed';

  @override
  String get sessionSandboxNotEnforced => 'Not sandboxed';

  @override
  String get sessionSandboxOff => 'Sandbox off';

  @override
  String sessionSandboxEnforcedTooltip(String backend) {
    return 'Isolation enforced by $backend';
  }

  @override
  String get sessionSandboxNotEnforcedTooltip =>
      'Sandboxing was requested but not enforced';

  @override
  String get sessionSandboxOffTooltip =>
      'Sandboxing was not requested for this session';

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
  String get terminalIdLabel => 'WORKING DIRECTORY';

  @override
  String get terminalIdHint => '/path/to/project';

  @override
  String get terminalDisconnect => 'Close';

  @override
  String get terminalTitle => 'Run command';

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
  String get commandCategoryGeneral => 'General';

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
  String get commandArtifactsTitle => 'Artifacts';

  @override
  String get commandArtifactsSubtitle => 'Browse your artifacts';

  @override
  String get commandTerminalTitle => 'Run command';

  @override
  String get commandTerminalSubtitle => 'Run a command on a connected machine';

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
  String get chatSuggestionWriteCodePrompt =>
      'Build this feature with production-ready code: ';

  @override
  String get chatSuggestionDebugIssuePrompt =>
      'Investigate and fix this issue. Start by reproducing it: ';

  @override
  String get chatSuggestionExplainCodePrompt =>
      'Explain how this code works, including the key data flow: ';

  @override
  String get chatSuggestionReviewPrPrompt =>
      'Review the current changes for correctness, regressions, and missing tests.';

  @override
  String get chatCapabilityFiles => '@ files';

  @override
  String get chatCapabilityCommands => '/ commands';

  @override
  String get chatCapabilityVoice => 'Voice input';

  @override
  String get chatWorkspaceTitle => 'Session workspace';

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
  String get relativeJustNow => 'Just now';

  @override
  String get relativeYesterday => 'Yesterday';

  @override
  String relativeMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String relativeMinutesCompact(int n) {
    return '${n}m';
  }

  @override
  String relativeHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String relativeHoursCompact(int n) {
    return '${n}h';
  }

  @override
  String relativeDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String relativeDaysCompact(int n) {
    return '${n}d';
  }

  @override
  String dateTimeToday(String time) {
    return 'Today at $time';
  }

  @override
  String dateTimeYesterday(String time) {
    return 'Yesterday at $time';
  }

  @override
  String get commandCategoryRecentSessions => 'Recent Sessions';

  @override
  String commandSessionFallback(String id) {
    return 'Session $id';
  }

  @override
  String get commandSwitchToSession => 'Switch to session';

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
  String get authLinkRequestTitle => 'Approve device linking?';

  @override
  String authLinkRequestBody(String requestType, String fingerprint) {
    return 'A $requestType is asking for access to your account. Only approve a request you initiated.\n\nSecurity fingerprint:\n$fingerprint';
  }

  @override
  String get authLinkRequestTerminal => 'terminal';

  @override
  String get authLinkRequestAccount => 'device';

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
  String get commonUnsavedChangesContent =>
      'You have unsaved changes. Are you sure you want to leave?';

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
  String get profilesSelectToEdit => 'Select a profile to edit';

  @override
  String get profilesImportedFallbackName => 'Imported Profile';

  @override
  String get profilesCopySuffix => ' (Copy)';

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
  String get settingsConfigureVoiceAssistant => 'Configure voice assistant';

  @override
  String get settingsDeveloperOptions => 'Developer Options';

  @override
  String get settingsDeveloperTapToEnable => 'Open developer options';

  @override
  String get settingsServerResetConfirm =>
      'Reset the server URL to the default? This cannot be undone.';

  @override
  String get settingsShowFlavorIconsSubtitle =>
      'Show AI provider icons in avatars';

  @override
  String get settingsTextToSpeechSubtitle => 'Read assistant messages aloud';

  @override
  String get settingsVoiceSettings => 'Voice Settings';

  @override
  String get terminalConnect => 'Run command';

  @override
  String get terminalConnected =>
      'Commands run independently. Shell state is not preserved.';

  @override
  String get terminalConnectInfo =>
      'Run one-off shell commands on a linked machine. This is not an interactive terminal.';

  @override
  String get terminalCommandFailed =>
      'Command failed. Check the machine connection and try again.';

  @override
  String get terminalDisconnectConfirm => 'Close the command runner?';

  @override
  String get terminalIdError => 'Please enter a working directory';

  @override
  String get terminalNoMachines =>
      'No machines connected. Start the Happy CLI on a machine first.';

  @override
  String get terminalNoMachineConnected => 'No machine is connected.';

  @override
  String get terminalOutputTruncated => 'Output was truncated by the machine.';

  @override
  String terminalOutputTruncatedBytes(String size) {
    return 'Output was truncated by the machine ($size total).';
  }

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
  String appearanceThemeBasedOnDevice(String mode) {
    return 'Based on your device\'s $mode appearance setting.';
  }

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
  String get providersConnectedAccounts => 'Connected accounts';

  @override
  String get providersBuiltInLimits => 'Built-in limits';

  @override
  String providersAccountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connected accounts',
      one: '1 connected account',
      zero: 'No connected accounts',
    );
    return '$_temp0';
  }

  @override
  String providersAttentionSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts need attention',
      one: '1 account needs attention',
      zero: 'All usage checks are healthy',
    );
    return '$_temp0';
  }

  @override
  String get providersUpdatingUsage => 'Updating usage…';

  @override
  String get providersUsageStale => 'Usage may be stale';

  @override
  String get providersHealthy => 'Healthy';

  @override
  String get providersNeedsAttention => 'Needs attention';

  @override
  String get providersAddAccount => 'Add account';

  @override
  String get providersAddAccountFailed => 'Failed to save account';

  @override
  String get providersRemoveAccountFailed => 'Failed to remove account';

  @override
  String providersSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String providersDeleteConfirmMessage(String name) {
    return 'Are you sure you want to remove $name?';
  }

  @override
  String providersDeleteSelectedConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Are you sure you want to remove $count accounts?',
      one: 'Are you sure you want to remove 1 account?',
    );
    return '$_temp0';
  }

  @override
  String get providersEmptyTitle => 'No provider accounts';

  @override
  String get providersEmptySubtitle =>
      'Add your Kimi, MiniMax, or Z.AI account to track usage.';

  @override
  String get providersNoUsageData => 'No usage data available';

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
  String get providersMiniMaxApiKeyLabel => 'API key';

  @override
  String get providersMiniMaxApiKeyHint => 'Paste your MiniMax API key';

  @override
  String get providersZaiApiKeyLabel => 'API key';

  @override
  String get providersZaiApiKeyHint => 'Paste your Z.AI console API key';

  @override
  String get providersZaiBaseUrlLabel => 'Base URL';

  @override
  String get providersZaiBaseUrlHint => 'https://api.z.ai';

  @override
  String get providersGrokAccessTokenLabel => 'Access token';

  @override
  String get providersGrokAccessTokenHint =>
      'Paste the access_token from ~/.grok/auth.json';

  @override
  String get providersGrokBaseUrlLabel => 'Base URL';

  @override
  String get providersGrokBaseUrlHint => 'https://cli-chat-proxy.grok.com/v1';

  @override
  String get providersQwenApiKeyLabel => 'API key';

  @override
  String get providersQwenApiKeyHint =>
      'Paste your Qwen Cloud API key (sk-sp-…)';

  @override
  String get providersQwenBaseUrlLabel => 'Base URL';

  @override
  String get providersQwenBaseUrlHint => 'https://home.qwencloud.com';

  @override
  String get providersNotImplemented => 'This provider is not yet supported.';

  @override
  String get providersRenameAccount => 'Rename account';

  @override
  String get providersRenameAccountFailed => 'Failed to rename account';

  @override
  String providersResetsIn(String time) {
    return 'Resets in $time';
  }

  @override
  String get loopsTitle => 'Loops';

  @override
  String get loopsEmptyTitle => 'No loops scheduled';

  @override
  String get loopsEmptyDescription =>
      'Type /loop in chat to schedule a recurring prompt.';

  @override
  String get allLoopsTitle => 'All loops';

  @override
  String get allLoopsScheduledTab => 'Scheduled';

  @override
  String allLoopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active loops',
      one: '1 active loop',
      zero: 'No active loops',
    );
    return '$_temp0';
  }

  @override
  String allLoopsPausedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paused loops',
      one: '1 paused loop',
      zero: '0 paused',
    );
    return '$_temp0';
  }

  @override
  String allLoopsAcrossSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return 'across $_temp0';
  }

  @override
  String get allLoopsEmptyTitle => 'No loops scheduled';

  @override
  String get allLoopsEmptyDescription =>
      'Type /loop in any session to schedule a recurring prompt.';

  @override
  String get allLoopsFilterAll => 'All';

  @override
  String get allLoopsNoActiveTitle => 'No active loops';

  @override
  String get allLoopsNoActiveDescription =>
      'Paused and expired loops are still available under All.';

  @override
  String get allLoopsNoPausedTitle => 'No paused loops';

  @override
  String get allLoopsNoPausedDescription =>
      'Pause an active loop to keep it here without deleting it.';

  @override
  String get allLoopsShowAll => 'Show all loops';

  @override
  String allLoopsGroupLoopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loops',
      one: '1 loop',
    );
    return '$_temp0';
  }

  @override
  String allLoopsGroupLabel(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loops',
      one: '1 loop',
    );
    return '$name, $_temp0';
  }

  @override
  String get allLoopsViewPerSession => 'View per session';

  @override
  String get loopsCreateTitle => 'New loop';

  @override
  String get loopsIntervalLabel => 'Cron expression';

  @override
  String get loopsIntervalHint => 'e.g. */5 * * * * — every 5 minutes';

  @override
  String get loopsPromptLabel => 'Prompt';

  @override
  String get loopsPromptHint => 'What should Claude do each time?';

  @override
  String get loopsRecurringLabel => 'Recurring';

  @override
  String get loopsCancelButton => 'Cancel';

  @override
  String get loopsScheduleButton => 'Schedule';

  @override
  String get loopsPauseButton => 'Pause';

  @override
  String get loopsResumeButton => 'Resume';

  @override
  String get loopsDeleteButton => 'Delete';

  @override
  String get loopsDeleteConfirmTitle => 'Delete loop';

  @override
  String loopsDeleteConfirmMessage(String id) {
    return 'Delete loop $id? This cannot be undone.';
  }

  @override
  String loopsFireCount(int count) {
    return 'Fired $count times';
  }

  @override
  String loopsLastFired(String time) {
    return 'Last fired $time';
  }

  @override
  String get loopsNeverFired => 'Never fired';

  @override
  String get loopsJustNow => 'just now';

  @override
  String loopsSecondsAgo(int n) {
    return '$n seconds ago';
  }

  @override
  String loopsMinutesAgo(int n) {
    return '$n minutes ago';
  }

  @override
  String loopsHoursAgo(int n) {
    return '$n hours ago';
  }

  @override
  String loopsDaysAgo(int n) {
    return '$n days ago';
  }

  @override
  String get loopsExpired => 'Expired';

  @override
  String loopsExpiresInHours(int hours) {
    return 'Expires in $hours hours';
  }

  @override
  String loopsExpiresInDays(int days) {
    return 'Expires in $days days';
  }

  @override
  String get loopsStatusActive => 'Active';

  @override
  String get loopsStatusPaused => 'Paused';

  @override
  String get loopsStatusExpired => 'Expired';

  @override
  String loopsScheduleEveryMinutes(String n) {
    return 'Every $n minutes';
  }

  @override
  String loopsScheduleEveryHours(String n) {
    return 'Every $n hours';
  }

  @override
  String get loopsScheduleDaily9am => 'Daily at 9:00 AM';

  @override
  String get loopsAddLoop => 'Add loop';

  @override
  String loopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loops',
      one: '1 loop',
      zero: 'No loops',
    );
    return '$_temp0';
  }

  @override
  String loopsBadgeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loops',
      one: '1 loop',
    );
    return '$_temp0';
  }

  @override
  String get loopsLoadFailed => 'Couldn\'t load loops';

  @override
  String get loopsScheduleFailed => 'Failed to schedule loop';

  @override
  String loopsLoopScheduled(String id) {
    return 'Loop $id scheduled';
  }

  @override
  String loopsLoopCancelled(String id) {
    return 'Loop $id cancelled';
  }

  @override
  String get loopsLoopCancelFailed => 'Failed to cancel loop';

  @override
  String get loopsLoopPauseFailed => 'Failed to pause loop';

  @override
  String get loopsLoopResumeFailed => 'Failed to resume loop';

  @override
  String get loopsValidationRequiredInterval => 'Cron expression is required';

  @override
  String get loopsValidationRequiredPrompt => 'Prompt is required';

  @override
  String get loopsValidationInvalidCron =>
      'Cron expression is invalid (expected 5 fields)';

  @override
  String get chatAttachImage => 'Attach image';

  @override
  String get chatAttachFromGallery => 'Photo library';

  @override
  String get chatAttachFromCamera => 'Camera';

  @override
  String get chatRemoveAttachment => 'Remove attachment';

  @override
  String chatAttachmentLimit(int max) {
    return 'Up to $max images per message';
  }

  @override
  String get chatImageAddFailed =>
      'Couldn\'t add that image. Please try a JPEG or PNG under 5 MB';

  @override
  String get chatImagePayloadTooLarge =>
      'Those images are too large to send together. Remove one and try again';

  @override
  String get chatImageNotCached => 'Image (not available offline)';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonMore => 'More';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get settingsMcpServers => 'MCP Servers';

  @override
  String get settingsMcpServersSubtitle =>
      'Manage Claude Code MCP servers on your machines';

  @override
  String get mcpServersTitle => 'MCP Servers';

  @override
  String get mcpAddServer => 'Add server';

  @override
  String mcpEnableTrustTitle(String name) {
    return 'Enable $name?';
  }

  @override
  String mcpEnableTrustBody(
    String target,
    String scope,
    String project,
    String secrets,
  ) {
    return 'Review this server before allowing it to provide tools to the agent.\n\nTarget: $target\nScope: $scope\nProject: $project\nSecret names: $secrets';
  }

  @override
  String get mcpEnableServer => 'Enable server';

  @override
  String get mcpEnabledWithUndo => 'MCP server enabled';

  @override
  String get mcpNoProject => 'All projects in this scope';

  @override
  String get mcpNoSecrets => 'None';

  @override
  String get mcpEditTitle => 'Edit MCP server';

  @override
  String get mcpMachineSection => 'Machine';

  @override
  String get mcpProjectSection => 'Project';

  @override
  String get mcpProjectHelper =>
      'Choose a project to also manage its project-scoped servers.';

  @override
  String get mcpProjectNone => 'All machines scopes only';

  @override
  String get mcpProjectRequired => 'Select a project directory for this scope';

  @override
  String get mcpNoServersTitle => 'No MCP servers';

  @override
  String get mcpNoServersSubtitle =>
      'Add a server to make new tools available to Claude Code on this machine.';

  @override
  String get mcpSaveFailed => 'Couldn\'t save the MCP server';

  @override
  String mcpToggleFailed(String name) {
    return 'Couldn\'t change $name';
  }

  @override
  String get mcpDeleteTitle => 'Delete MCP server';

  @override
  String mcpDeleteConfirm(String name, String scope) {
    return 'Remove $name from the $scope scope on this machine?';
  }

  @override
  String mcpDeleteFailed(String name) {
    return 'Couldn\'t delete $name';
  }

  @override
  String get mcpScopeUser => 'User — ~/.claude.json';

  @override
  String get mcpScopeUserSettings => 'User settings — ~/.claude/settings.json';

  @override
  String get mcpScopeLocal => 'Project (private) — ~/.claude.json';

  @override
  String get mcpScopeProject => 'Project (shared) — .mcp.json';

  @override
  String get mcpScopeProjectSettings =>
      'Project settings — .claude/settings.json';

  @override
  String get mcpScopeLocalSettings =>
      'Project settings (local) — .claude/settings.local.json';

  @override
  String get mcpScopeHelper =>
      'Scope decides which file on the machine the server is written to.';

  @override
  String get mcpBadgeNeedsAuth => 'Needs auth';

  @override
  String get mcpBadgeShadowed => 'Shadowed';

  @override
  String get mcpBadgeAwaitingApproval => 'Not approved';

  @override
  String get mcpSourceFiles => 'Configuration files';

  @override
  String get mcpApproveAllEnabled =>
      'Shared project servers are auto-approved on this machine.';

  @override
  String get mcpIdentitySection => 'Identity';

  @override
  String get mcpTransportSection => 'Transport';

  @override
  String get mcpProcessSection => 'Process';

  @override
  String get mcpEndpointSection => 'Endpoint';

  @override
  String get mcpFieldName => 'Name';

  @override
  String get mcpFieldScope => 'Scope';

  @override
  String get mcpFieldProject => 'Project directory';

  @override
  String get mcpFieldCommand => 'Command';

  @override
  String get mcpFieldArgs => 'Arguments';

  @override
  String get mcpFieldEnv => 'Environment';

  @override
  String get mcpFieldUrl => 'URL';

  @override
  String get mcpFieldHeaders => 'Headers';

  @override
  String get mcpNameHelper =>
      'Letters, numbers, spaces, dot, dash, underscore.';

  @override
  String get mcpNameLockedHelper =>
      'Name and scope identify the server and cannot be changed. Delete and re-add to move it.';

  @override
  String get mcpNameRequired => 'Enter a server name';

  @override
  String get mcpNameInvalid =>
      'Use only letters, numbers, spaces, dot, dash, underscore';

  @override
  String get mcpCommandHelper =>
      'Executable to run, e.g. npx or an absolute path.';

  @override
  String get mcpCommandRequired => 'Enter a command';

  @override
  String get mcpArgsHelper => 'One argument per line.';

  @override
  String get mcpEnvHelper =>
      'Values stay masked. Add, replace, or remove environment variables.';

  @override
  String get mcpHeadersHelper =>
      'Values stay masked. Add, replace, or remove request headers.';

  @override
  String get mcpSecretAdd => 'Add secret';

  @override
  String get mcpSecretReplace => 'Replace secret';

  @override
  String get mcpSecretKey => 'Name';

  @override
  String get mcpSecretKeyRequired => 'Enter a name';

  @override
  String get mcpSecretKeyExists => 'That name already exists';

  @override
  String get mcpSecretValue => 'New value';

  @override
  String get mcpSecretValueRequired => 'Enter a value';

  @override
  String get mcpSecretReplacementReady => 'Replacement ready';

  @override
  String get mcpSecretStored => 'Stored securely';

  @override
  String get mcpSecretRemove => 'Remove secret';

  @override
  String get mcpUrlRequired => 'Enter a URL';

  @override
  String get mcpUrlInvalid => 'Enter a full URL including https://';

  @override
  String get sandboxTitle => 'Sandbox';

  @override
  String get sandboxMachineSection => 'Machine';

  @override
  String get sandboxProjectSection => 'Project';

  @override
  String get sandboxUnavailableTitle => 'Sandboxing unavailable';

  @override
  String get sandboxMachineDisabled =>
      'Sandboxing is turned off for this machine. Sessions run with full access to the file system.';

  @override
  String get sandboxExplainer =>
      'Sandboxed sessions see this project directory and the public internet. Everything else on the machine — your home directory, SSH keys, other projects — is not there.';

  @override
  String get sandboxEnabledForProject => 'Sandbox this project';

  @override
  String get sandboxFollowsMachine => 'Following the machine default';

  @override
  String get sandboxFoldersSection => 'Extra folders';

  @override
  String get sandboxNoFolders => 'No extra folders';

  @override
  String get sandboxNoFoldersSubtitle =>
      'Sessions can only reach the project directory itself. Add a folder if this project needs one.';

  @override
  String get sandboxAddFolder => 'Add folder';

  @override
  String get sandboxFolderPath => 'Absolute path';

  @override
  String get sandboxFolderPathHint => '/home/you/go/pkg/mod';

  @override
  String get sandboxFolderPathRequired => 'Enter an absolute path';

  @override
  String get sandboxModeReadWrite => 'Read and write';

  @override
  String get sandboxModeReadOnly => 'Read only';

  @override
  String get sandboxRemoveFolder => 'Remove folder';

  @override
  String sandboxRemoveFolderConfirm(String path) {
    return 'Sessions in this project will no longer reach $path.';
  }

  @override
  String get sandboxSaveFailed => 'Could not save the sandbox policy';

  @override
  String get sandboxNetworkPublic =>
      'Network: public internet only — the local network, other machines and localhost are refused.';

  @override
  String get sandboxNetworkAllowlist =>
      'Network: only the hosts allowed below.';

  @override
  String get sandboxNetworkNone => 'Network: no egress at all.';

  @override
  String get settingsSandbox => 'Sandbox';

  @override
  String get settingsSandboxSubtitle =>
      'Choose what a project\'s sessions can reach on your machines';

  @override
  String get settingsSandboxUnavailable =>
      'Connect or update a machine daemon that supports sandboxing';

  @override
  String sessionActivityRunningTool(String tool) {
    return 'Running $tool';
  }

  @override
  String sessionActivityToolApproval(String tool) {
    return '$tool needs approval';
  }

  @override
  String get sessionActivityWorking => 'Working…';

  @override
  String get sessionsArchivePending => 'Archive pending';

  @override
  String get sessionsArchivesSoon => 'Archives in <1m';

  @override
  String sessionsArchivesInMinutes(int minutes) {
    return 'Archives in ${minutes}m';
  }

  @override
  String get codeBlockTitle => 'Code';

  @override
  String get codeBlockOpenFullScreen => 'Open full screen';

  @override
  String get codeBlockEnableWrap => 'Wrap long lines';

  @override
  String get codeBlockDisableWrap => 'Scroll long lines';

  @override
  String codeBlockShowAllLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count more lines',
      one: 'Show 1 more line',
    );
    return '$_temp0';
  }

  @override
  String codeBlockHiddenLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more lines',
      one: '1 more line',
    );
    return '$_temp0';
  }

  @override
  String codeBlockTruncated(int displayed, int total) {
    return 'Showing $displayed of $total characters';
  }

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonDismissError => 'Dismiss error';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String get devCopyPushToken => 'Copy push token';

  @override
  String get profilesDuplicateProfile => 'Duplicate Profile';

  @override
  String get profilesShowApiKey => 'Show API key';

  @override
  String get profilesHideApiKey => 'Hide API key';

  @override
  String get serverUrlClear => 'Clear server URL';

  @override
  String get sftpParentFolder => 'Parent folder';

  @override
  String get chatCopyThinking => 'Copy thinking';

  @override
  String get chatScrollToLatest => 'Scroll to latest message';

  @override
  String get tasksMarkComplete => 'Mark complete';

  @override
  String get tasksMarkIncomplete => 'Mark incomplete';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get tasksEmptyTitle => 'No active tasks';

  @override
  String get tasksEmptySubtitle =>
      'Tasks from your sessions will appear here, grouped by priority.';

  @override
  String get tasksPriorityCritical => 'Critical';

  @override
  String get tasksPriorityHigh => 'High';

  @override
  String get tasksPriorityMedium => 'Medium';

  @override
  String get tasksPriorityLow => 'Low';

  @override
  String get artifactsSourceSessions => 'Source sessions';

  @override
  String get artifactsSourceSessionsSubtitle =>
      'Open the conversations that produced or updated this artifact.';

  @override
  String get workflowRefreshWarning =>
      'Could not refresh. Showing saved progress.';

  @override
  String get workflowsTitle => 'Workflows';

  @override
  String workflowsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workflows',
      one: '1 workflow',
    );
    return '$_temp0';
  }

  @override
  String get workflowsUnavailableTitle => 'Workflows unavailable';

  @override
  String get workflowsUnavailableSubtitle =>
      'This machine does not support workflow history yet. Update the Happy CLI to use it.';

  @override
  String get workflowsEmptyTitle => 'No workflows yet';

  @override
  String get workflowsEmptySubtitle =>
      'Workflow runs will appear here when an agent starts one.';

  @override
  String get workflowsLoadFailedTitle => 'Could not load workflows';

  @override
  String get workflowLoadFailedSafe =>
      'Workflow data is unavailable right now. Try again.';

  @override
  String get workflowNotFoundSafe => 'This workflow run is unavailable.';

  @override
  String get workflowRunFailedSafe => 'This workflow run failed unexpectedly.';

  @override
  String get workflowAgentFailedSafe => 'This agent step failed unexpectedly.';

  @override
  String get workflowErrorTitle => 'Error';

  @override
  String get workflowTitle => 'Workflow';

  @override
  String get connectionDiagnosticsTitle => 'Connection diagnostics';

  @override
  String get connectionDiagnosticsNetwork => 'Network';

  @override
  String get connectionDiagnosticsLiveUpdates => 'Live updates';

  @override
  String get connectionDiagnosticsLastDisconnect => 'Last disconnect';

  @override
  String get connectionDiagnosticsNoDisconnect => 'No disconnect recorded';

  @override
  String get connectionDiagnosticsDisconnectedFor => 'Disconnected for';

  @override
  String get connectionDiagnosticsReconnectAttempt => 'Reconnect attempt';

  @override
  String get connectionDiagnosticsService => 'Service';

  @override
  String get connectionDiagnosticsCheckingService => 'Checking…';

  @override
  String get connectionDiagnosticsServiceDegradedSafe =>
      'Some services are degraded';

  @override
  String get connectionDiagnosticsServiceUnavailable => 'Service unavailable';

  @override
  String get connectionDiagnosticsAuthenticationRequired =>
      'Authentication required';

  @override
  String get connectionDiagnosticsTimedOut => 'Connection timed out';

  @override
  String get connectionDiagnosticsConnectionClosed => 'Connection closed';

  @override
  String connectionDiagnosticsElapsedSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String connectionDiagnosticsElapsedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String connectionDiagnosticsElapsedHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
      zero: '',
    );
    return '$_temp0 $_temp1';
  }

  @override
  String get settingsHealthStatus => 'Status';

  @override
  String get settingsHealthSyncReady => 'Sync ready';

  @override
  String get settingsHealthSyncAttention => 'Sync needs attention';

  @override
  String get settingsHealthApplyingUpdates =>
      'Connected and applying the latest updates';

  @override
  String get settingsHealthReady =>
      'Ready for sessions, messages, and settings updates';

  @override
  String get settingsHealthOffline =>
      'Offline. Updates will resume when the network returns';

  @override
  String get settingsHealthLoading =>
      'Connected, waiting for initial data to finish loading';

  @override
  String get settingsHealthReconnecting => 'Reconnecting to live updates';

  @override
  String get settingsHealthNoMachines => 'No machines linked yet';

  @override
  String settingsHealthMachinesOnline(int online, int total) {
    return '$online online of $total linked';
  }

  @override
  String settingsHealthSessionsOnline(int online, int total) {
    return '$online online of $total total';
  }

  @override
  String get settingsHealthAccountRecovery => 'Account and recovery';

  @override
  String get settingsHealthAccountRecoverySubtitle =>
      'Backup key, linked devices, restore, and services';

  @override
  String get settingsHealthSocketGeneration => 'Socket generation';

  @override
  String get settingsHealthLastSocketEvent => 'Last socket event age';

  @override
  String get settingsHealthNoSocketEvent => 'No event recorded';

  @override
  String get settingsHealthOutbox => 'Message outbox';

  @override
  String settingsHealthOutboxCounts(int pending, int failed) {
    return '$pending pending, $failed failed';
  }

  @override
  String get settingsHealthSyncDomains => 'Sync domains';

  @override
  String get settingsHealthCopyDiagnostics => 'Copy diagnostics';

  @override
  String get settingsHealthDomainSessions => 'Sessions';

  @override
  String get settingsHealthDomainMessages => 'Messages';

  @override
  String get settingsHealthDomainMachines => 'Machines';

  @override
  String get settingsHealthDomainSettings => 'Settings';

  @override
  String get settingsHealthDomainProfile => 'Profile';

  @override
  String get settingsHealthDomainArtifacts => 'Artifacts';

  @override
  String get settingsHealthDomainGitStatus => 'Git status';

  @override
  String get settingsHealthDomainFriendRequests => 'Friend requests';

  @override
  String get settingsHealthDomainLoops => 'Loops';

  @override
  String get settingsHealthDomainWorkflows => 'Workflows';

  @override
  String get settingsHealthDomainSyncing => 'Syncing now';

  @override
  String get settingsHealthDomainQueued => 'Update queued';

  @override
  String get settingsHealthDomainNoFreshness => 'No completed refresh recorded';

  @override
  String settingsHealthDomainFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String settingsHealthDomainUpdated(String elapsed) {
    return 'Updated $elapsed ago';
  }

  @override
  String settingsHealthDomainState(String state, int revision) {
    return '$state · revision $revision';
  }

  @override
  String get settingsHealthFailureDecrypt => 'Encrypted data could not be read';

  @override
  String get settingsHealthFailureInterrupted => 'Refresh was interrupted';

  @override
  String get settingsHealthFailureInvalidData => 'Invalid response data';

  @override
  String get remoteFeatureErrorOffline => 'The selected machine is offline.';

  @override
  String get remoteFeatureErrorUnsupported =>
      'This feature requires a newer Happy daemon.';

  @override
  String get remoteFeatureErrorTemporary =>
      'The machine could not complete the request. Try again.';

  @override
  String get remoteFeatureErrorRejected =>
      'The machine rejected the request. Check the values and try again.';

  @override
  String get remoteFeatureErrorUnknown => 'The request could not be completed.';

  @override
  String get accountRevealBackupKeyTitle => 'Reveal backup key?';

  @override
  String get accountRevealBackupKeyWarning =>
      'Anyone who sees this key can access your account. Make sure nobody can see your screen.';

  @override
  String get accountRevealAction => 'Reveal';

  @override
  String get accountCopyBackupKeyTitle => 'Copy backup key?';

  @override
  String get accountCopyBackupKeyWarning =>
      'The key grants full account access. It will be cleared from the clipboard after 60 seconds.';

  @override
  String get accountCopyKeyAction => 'Copy key';

  @override
  String get accountClipboardExpiry => 'Clipboard clears in 60s.';

  @override
  String get accountSwitchTitle => 'Switch account?';

  @override
  String accountSwitchWarning(String fingerprint) {
    return 'This will replace the account on this device with account $fingerprint. Unsaved drafts and pending sends may not carry over.';
  }

  @override
  String get accountSwitchAction => 'Switch account';

  @override
  String get accountShowBackupKeyAction => 'Show backup key';

  @override
  String get accountHideBackupKeyAction => 'Hide backup key';

  @override
  String get accountRestoreServiceError =>
      'The restore service could not complete the request.';

  @override
  String accountRestoreRejectedCode(int code) {
    return 'The restore service rejected the key (code $code).';
  }

  @override
  String get accountRestoreGenericError =>
      'Could not restore the account. Check your connection and try again.';

  @override
  String tasksOpenSession(String task, String session) {
    return '$task, from $session. Open session';
  }

  @override
  String get goalLoopsTitle => 'Goal loops';

  @override
  String get goalLoopsNewButton => 'New goal loop';

  @override
  String get goalLoopsCreateTitle => 'Start a goal loop';

  @override
  String get goalLoopsCreateSubtitle =>
      'The agent works towards the goal in repeated sessions, each starting with an empty context, until it reports the goal reached.';

  @override
  String get goalLoopsGoalLabel => 'Goal';

  @override
  String get goalLoopsGoalHint =>
      'Get the integration test suite passing on CI';

  @override
  String get goalLoopsGoalHelper =>
      'Say what \"done\" means. A goal the agent can check for itself is one it can stop on.';

  @override
  String get goalLoopsDirectoryHelper =>
      'Each iteration runs here and keeps its notes in the progress file.';

  @override
  String get goalLoopsAdvanced => 'Advanced';

  @override
  String get goalLoopsModelLabel => 'Model';

  @override
  String get goalLoopsModelHint => 'opus:max or gpt-5.5:high';

  @override
  String get goalLoopsModelHelper =>
      'Leave blank to use the agent\'s default model. The same model is used for every iteration.';

  @override
  String goalLoopsMaxIterations(int count) {
    return 'Stop after $count iterations';
  }

  @override
  String get goalLoopsMaxIterationsHelper =>
      'A safety net for a goal that can never be reached. The loop normally stops on its own well before this.';

  @override
  String get goalLoopsProgressFileLabel => 'Progress file';

  @override
  String get goalLoopsProgressFileHelper =>
      'The loop\'s only memory between iterations. Created for you if it does not exist.';

  @override
  String get goalLoopsInstructionsLabel => 'Extra instructions';

  @override
  String get goalLoopsInstructionsHint =>
      'Never push to main. Run mise run test before claiming anything passes.';

  @override
  String get goalLoopsInstructionsHelper =>
      'Added to every iteration\'s prompt.';

  @override
  String get goalLoopsStartButton => 'Start loop';

  @override
  String get goalLoopsActiveSection => 'Working';

  @override
  String get goalLoopsFinishedSection => 'Stopped';

  @override
  String get goalLoopsEmptyTitle => 'No goal loops';

  @override
  String get goalLoopsEmptyMessage =>
      'A goal loop keeps restarting an agent with a fresh context until its goal is reached.';

  @override
  String goalLoopsIterationProgress(int done, int max) {
    return '$done of $max iterations';
  }

  @override
  String get goalLoopsIterating => 'Working now';

  @override
  String get goalLoopsOpenSession => 'Open session';

  @override
  String get goalLoopsResumeButton => 'Resume loop';

  @override
  String get goalLoopsDeleteConfirmMessage =>
      'Delete this goal loop? The progress file is left on disk.';

  @override
  String get goalLoopsStatusRunning => 'Working';

  @override
  String get goalLoopsStatusComplete => 'Reached';

  @override
  String get goalLoopsStatusBlocked => 'Needs you';

  @override
  String get goalLoopsStatusStalled => 'Stalled';

  @override
  String get goalLoopsStatusExhausted => 'Out of iterations';
}
