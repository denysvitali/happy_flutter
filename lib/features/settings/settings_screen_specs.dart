part of 'settings_screen.dart';

// ─── Per-section registry specs ─────────────────────────────────────────────
//
// Each factory below expresses one hub section as data
// (`SettingsSectionSpec`), which `buildSettingsSection` in
// settings_section_registry.dart turns into the same widget tree the
// old hand-written `_buildXSection` methods produced. Building specs
// per build call is intentional: titles/subtitles come from `l10n`
// and row values from the watched settings snapshot.

extension _HubSectionSpecs on _SettingsScreenState {
  SettingsSectionSpec _appearanceSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(title: l10n.settingsAppearance, rows: [
      CustomWidgetRowSpec(
        searchTerms: ['theme', 'light', 'dark', 'adaptive'],
        build: (_) => InlineThemePicker(
          currentMode: settings.themeMode,
          onChanged: (mode) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('themeMode', mode),
        ),
      ),
      ToggleRowSpec(
        icon: Icons.emoji_emotions_outlined,
        title: l10n.settingsShowFlavorIcons,
        subtitle: l10n.settingsShowFlavorIconsSubtitle,
        value: settings.showFlavorIcons,
        onChanged: (value) => ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('showFlavorIcons', value),
      ),
      ActionNavRowSpec(
        icon: Icons.account_circle_outlined,
        title: l10n.settingsAvatarStyle,
        subtitle: _avatarStyleLabel(settings.avatarStyle),
        onTap: () => _showAvatarStyleDialog(context, settings.avatarStyle),
      ),
    ]);
  }

  SettingsSectionSpec _behaviorSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(title: l10n.settingsBehavior, rows: [
      ToggleRowSpec(
        icon: Icons.open_in_new_outlined,
        title: l10n.settingsViewInline,
        subtitle: l10n.settingsViewInlineSubtitle,
        value: settings.viewInline,
        onChanged: (value) => ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('viewInline', value),
      ),
      ToggleRowSpec(
        icon: Icons.visibility_off_outlined,
        title: l10n.settingsHideToolCalls,
        subtitle: l10n.settingsHideToolCallsSubtitle,
        value: settings.hideToolCalls,
        onChanged: (value) => ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('hideToolCalls', value),
      ),
      ToggleRowSpec(
        icon: Icons.check_box_outlined,
        title: l10n.settingsExpandTodos,
        value: settings.expandTodos,
        onChanged: (value) => ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('expandTodos', value),
      ),
    ]);
  }

  SettingsSectionSpec _sessionsSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(title: l10n.settingsSessions, rows: [
      ActionNavRowSpec(
        icon: Icons.view_agenda_outlined,
        title: l10n.settingsSessionsViewStyle,
        subtitle: _sessionsViewStyleLabel(l10n, settings.sessionsViewStyle),
        onTap: () => _showSessionsViewStyleDialog(
          context,
          sessionsViewStyle: settings.sessionsViewStyle,
        ),
      ),
      NavRouteRowSpec(
        icon: Icons.folder_outlined,
        title: l10n.sessionsFolders,
        subtitle: l10n.sessionsFolders,
        route: 'sessions-folders',
      ),
      NavRouteRowSpec(
        icon: Icons.auto_awesome_outlined,
        title: l10n.autoArchiveTitle,
        subtitle: l10n.autoArchiveSection,
        route: 'sessions-auto-archive',
      ),
    ]);
  }

  SettingsSectionSpec _voiceSectionSpec(
    AppLocalizations l10n,
    _HubSettings settings,
  ) {
    return SettingsSectionSpec(title: l10n.settingsVoice, rows: [
      ToggleRowSpec(
        icon: Icons.volume_up_outlined,
        title: l10n.settingsTextToSpeech,
        subtitle: l10n.settingsTextToSpeechSubtitle,
        value: settings.ttsEnabled,
        onChanged: (value) => ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('ttsEnabled', value),
      ),
      NavRouteRowSpec(
        icon: Icons.record_voice_over,
        title: l10n.settingsVoiceSettings,
        subtitle: l10n.settingsConfigureVoiceAssistant,
        route: 'voice',
      ),
    ]);
  }

  /// Agents & tools — distinct section title so it no longer reads
  /// identically to the Features row right under it.
  SettingsSectionSpec _toolsSectionSpec(AppLocalizations l10n) {
    final allProfiles = effectiveProfiles(
      ref.watch(settingsNotifierProvider.select((s) => s.profiles)),
    );
    final selectedProfileId = ref.watch(
      settingsNotifierProvider.select((s) => s.lastUsedProfile),
    );
    return SettingsSectionSpec(title: l10n.settingsHubToolsTitle, rows: [
      CustomWidgetRowSpec(
        searchTerms: [l10n.settingsProfiles, 'profiles', 'model'],
        build: (rowContext) => ProfileSwitcherTile(
          profiles: allProfiles,
          selectedProfileId: selectedProfileId,
          title: l10n.settingsProfiles,
          onTap: () => rowContext.pushNamed('profiles'),
        ),
      ),
      NavRouteRowSpec(
        icon: Icons.analytics,
        title: l10n.settingsUsage,
        subtitle: l10n.settingsUsageSubtitle,
        route: 'usage',
      ),
      NavRouteRowSpec(
        icon: Icons.science,
        title: l10n.settingsFeatures,
        subtitle: l10n.settingsFeaturesSubtitle,
        route: 'features',
      ),
    ]);
  }

  SettingsSectionSpec _developerSectionSpec({
    required bool developerModeEnabled,
  }) {
    final l10n = AppLocalizations.of(context);
    return SettingsSectionSpec(title: l10n.settingsDeveloper, rows: [
      NavRouteRowSpec(
        icon: Icons.build,
        title: l10n.settingsDeveloperOptions,
        subtitle: developerModeEnabled
            ? l10n.settingsDeveloperEnabled
            : l10n.settingsDeveloperTapToEnable,
        route: 'developer',
      ),
    ]);
  }
}

/// Infrastructure — machines, MCP servers and sandbox rows keep today's
/// gate (hidden while no machines exist); the server row stays visible
/// either way so a custom server stays configurable without machines.
/// The title falls back to "Server" when only the server row remains.
SettingsSectionSpec _infrastructureSectionSpec(
  AppLocalizations l10n, {
  required int machineTotal,
  required String? firstMachineSubtitle,
  required bool sandboxAvailable,
  required String? sandboxReason,
}) {
  final hasMachines = machineTotal > 0;
  return SettingsSectionSpec(
    title: hasMachines ? l10n.settingsMachines : l10n.settingsServer,
    rows: [
      if (hasMachines)
        NavRouteRowSpec(
          icon: Icons.computer_outlined,
          title: l10n.settingsMachines,
          subtitle: firstMachineSubtitle,
          route: 'machines',
        ),
      // MCP servers are account-level configuration, not machine-scoped,
      // so this row stays visible even with no machines linked.
      NavRouteRowSpec(
        icon: Icons.extension_outlined,
        title: l10n.settingsMcpServers,
        subtitle: l10n.settingsMcpServersSubtitle,
        route: 'mcp-servers',
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

// About section — 4 URL-launching rows (GitHub, issues, privacy, terms).
SettingsSectionSpec _aboutSectionSpec(AppLocalizations l10n) {
  return SettingsSectionSpec(title: l10n.settingsAbout, rows: [
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
  ]);
}
