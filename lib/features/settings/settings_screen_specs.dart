part of 'settings_screen.dart';

// ─── Per-section registry specs ─────────────────────────────────────────────
//
// Each factory below expresses one hub section as data
// (`SettingsSectionSpec`), which `buildSettingsSection` in
// settings_section_registry.dart turns into widgets. Every setting has
// exactly one home:
//
//   Appearance       — how the app looks everywhere
//   Chat             — how a conversation renders
//   Sessions         — how the session list is laid out and kept tidy
//   Agents           — what new agent sessions start with
//   Voice            — one row; read-aloud, voices and dictation inside
//   Machines & server — where sessions run and which server syncs them
//   About / Developer — app information and diagnostics
//
// Account (backup, devices, sign out) is a separate block in
// widgets/account_settings_section.dart.

extension _HubSectionSpecs on _SettingsScreenState {
  SettingsNotifier get _settingsNotifier =>
      ref.read(settingsNotifierProvider.notifier);

  void _set(String key, Object value) =>
      unawaited(_settingsNotifier.updateSetting(key, value));

  SettingsSectionSpec _appearanceSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(
      title: l10n.settingsAppearance,
      rows: [
        CustomWidgetRowSpec(
          searchTerms: ['theme', 'light', 'dark', 'adaptive'],
          build: (_) => InlineThemePicker(
            currentMode: settings.themeMode,
            onChanged: (mode) => _set('themeMode', mode),
          ),
        ),
        ActionNavRowSpec(
          icon: Icons.account_circle_outlined,
          title: l10n.settingsAvatarStyle,
          subtitle: _avatarStyleLabel(settings.avatarStyle),
          onTap: () => _showAvatarStyleDialog(context, settings.avatarStyle),
        ),
        ToggleRowSpec(
          icon: Icons.emoji_emotions_outlined,
          title: l10n.settingsShowFlavorIcons,
          subtitle: l10n.settingsShowFlavorIconsSubtitle,
          value: settings.showFlavorIcons,
          onChanged: (value) => _set('showFlavorIcons', value),
        ),
      ],
    );
  }

  /// Everything that changes how a single conversation renders.
  SettingsSectionSpec _chatSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(
      title: l10n.settingsChat,
      rows: [
        ToggleRowSpec(
          icon: Icons.visibility_off_outlined,
          title: l10n.settingsHideToolCalls,
          subtitle: l10n.settingsHideToolCallsSubtitle,
          value: settings.hideToolCalls,
          onChanged: (value) => _set('hideToolCalls', value),
        ),
        ToggleRowSpec(
          icon: Icons.check_box_outlined,
          title: l10n.settingsExpandTodos,
          value: settings.expandTodos,
          onChanged: (value) => _set('expandTodos', value),
        ),
        ToggleRowSpec(
          icon: Icons.numbers_rounded,
          title: l10n.featuresShowLineNumbers,
          subtitle: l10n.featuresShowLineNumbersDesc,
          value: settings.showLineNumbers,
          onChanged: (value) => _set('showLineNumbers', value),
        ),
      ],
    );
  }

  /// The session list: its layout, density and housekeeping.
  SettingsSectionSpec _sessionsSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(
      title: l10n.settingsSessions,
      rows: [
        ActionNavRowSpec(
          icon: SessionsViewStyle.fromWire(settings.sessionsViewStyle).icon,
          title: l10n.settingsSessionsViewStyle,
          subtitle: _sessionsViewStyleLabel(l10n, settings.sessionsViewStyle),
          onTap: () => _showSessionsViewStyleDialog(
            context,
            sessionsViewStyle: settings.sessionsViewStyle,
          ),
        ),
        ToggleRowSpec(
          icon: Icons.filter_alt_outlined,
          title: l10n.featuresHideInactiveSessions,
          subtitle: l10n.featuresHideInactiveSessionsDesc,
          value: settings.hideInactiveSessions,
          onChanged: (value) => _set('hideInactiveSessions', value),
        ),
        NavRouteRowSpec(
          icon: Icons.folder_outlined,
          title: l10n.sessionsFolders,
          subtitle: l10n.settingsSessionFoldersSubtitle,
          route: 'sessions-folders',
        ),
        NavRouteRowSpec(
          icon: Icons.inventory_2_outlined,
          title: l10n.autoArchiveTitle,
          subtitle: l10n.settingsAutoArchiveSubtitle,
          route: 'sessions-auto-archive',
        ),
      ],
    );
  }

  /// What new agent sessions start with.
  SettingsSectionSpec _agentsSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    // Stored rows only: built-in presets are creation-time suggestions and
    // must never appear as pre-populated profile rows.
    final allProfiles = ref.watch(
      settingsNotifierProvider.select((s) => s.profiles),
    );
    final selectedProfileId = ref.watch(
      settingsNotifierProvider.select((s) => s.lastUsedProfile),
    );
    return SettingsSectionSpec(
      title: l10n.settingsAgents,
      rows: [
        CustomWidgetRowSpec(
          searchTerms: [l10n.settingsProfiles, 'profiles', 'model', 'agent'],
          build: (rowContext) => ProfileSwitcherTile(
            profiles: allProfiles,
            selectedProfileId: selectedProfileId,
            title: l10n.settingsProfiles,
            onTap: () => rowContext.pushNamed('profiles'),
          ),
        ),
        ToggleRowSpec(
          icon: Icons.speed_outlined,
          title: l10n.featuresCodexFastMode,
          subtitle: l10n.featuresCodexFastModeDesc,
          value: settings.codexFastMode,
          onChanged: (value) => _set('codexFastMode', value),
        ),
        NavRouteRowSpec(
          icon: Icons.extension_outlined,
          title: l10n.settingsMcpServers,
          subtitle: l10n.settingsMcpServersSubtitle,
          route: 'mcp-servers',
        ),
      ],
    );
  }

  /// One row: the Voice screen owns read-aloud, voices and dictation.
  SettingsSectionSpec _voiceSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(
      title: l10n.settingsVoice,
      rows: [
        NavRouteRowSpec(
          icon: Icons.record_voice_over_outlined,
          title: l10n.settingsVoiceSettings,
          subtitle: settings.ttsEnabled
              ? l10n.settingsVoiceSubtitleOn
              : l10n.settingsVoiceSubtitleOff,
          route: 'voice',
        ),
      ],
    );
  }

  SettingsSectionSpec _developerSectionSpec(
    AppLocalizations l10n, {
    required bool developerModeEnabled,
  }) {
    return SettingsSectionSpec(
      title: l10n.settingsDeveloper,
      rows: [
        NavRouteRowSpec(
          icon: Icons.build_outlined,
          title: l10n.settingsDeveloperOptions,
          subtitle: developerModeEnabled
              ? l10n.settingsDeveloperEnabled
              : l10n.settingsDeveloperTapToEnable,
          route: 'developer',
        ),
      ],
    );
  }
}

/// Machines & server — where sessions run and which server syncs them.
/// Machine and sandbox rows need at least one linked machine; the server
/// row stays so a custom server is configurable before any machine exists.
SettingsSectionSpec _machinesSectionSpec(
  AppLocalizations l10n, {
  required int machineTotal,
  required int machinesOnline,
  required bool sandboxAvailable,
  required String? sandboxReason,
}) {
  final hasMachines = machineTotal > 0;
  return SettingsSectionSpec(
    title: l10n.settingsMachinesAndServer,
    rows: [
      NavRouteRowSpec(
        icon: Icons.computer_outlined,
        title: l10n.settingsMachines,
        subtitle: hasMachines
            ? l10n.settingsHealthMachinesOnline(machinesOnline, machineTotal)
            : l10n.settingsHealthNoMachines,
        route: 'machines',
      ),
      if (hasMachines)
        NavRouteRowSpec(
          icon: Icons.shield_outlined,
          title: l10n.settingsSandbox,
          subtitle: sandboxAvailable
              ? l10n.settingsSandboxSubtitle
              : sandboxReason ?? l10n.settingsSandboxUnavailable,
          route: 'sandbox',
          enabled: sandboxAvailable,
        ),
      // Plain sync MMKV read at build time; the richer verify/save/reset
      // editor lives behind the 'server-settings' route.
      NavRouteRowSpec(
        icon: Icons.cloud_outlined,
        title: l10n.settingsServerUrl,
        subtitle: getServerUrl(),
        route: 'server-settings',
      ),
    ],
  );
}

/// About — app version, release notes and project links.
SettingsSectionSpec _aboutSectionSpec(
  AppLocalizations l10n, {
  required String? appVersion,
}) {
  return SettingsSectionSpec(
    title: l10n.settingsAbout,
    rows: [
      NavRouteRowSpec(
        icon: Icons.new_releases_outlined,
        title: l10n.changelogTitle,
        subtitle: appVersion == null
            ? null
            : '${l10n.settingsVersion} $appVersion',
        route: 'changelog',
      ),
      UrlLaunchRowSpec(
        icon: Icons.code,
        title: l10n.settingsGitHub,
        url: AppConfig.githubUrl,
        subtitle: AppConfig.githubSlug,
      ),
      UrlLaunchRowSpec(
        icon: Icons.bug_report_outlined,
        title: l10n.settingsReportIssue,
        url: AppConfig.githubIssuesUrl,
      ),
      UrlLaunchRowSpec(
        icon: Icons.privacy_tip_outlined,
        title: l10n.settingsPrivacyPolicy,
        url: AppConfig.privacyUrl,
      ),
      UrlLaunchRowSpec(
        icon: Icons.gavel_outlined,
        title: l10n.settingsTermsOfService,
        url: AppConfig.termsUrl,
      ),
    ],
  );
}
