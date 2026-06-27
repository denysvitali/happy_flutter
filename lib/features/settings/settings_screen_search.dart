part of 'settings_screen.dart';

extension _SettingsScreenSearch on _SettingsScreenState {
  List<_SettingsSearchSection> _buildSearchSections(
    BuildContext context, {
    required ({
      String themeMode,
      bool showFlavorIcons,
      String avatarStyle,
      bool viewInline,
      bool hideToolCalls,
      bool expandTodos,
      bool ttsEnabled,
      bool developerModeEnabled,
      bool toolCallDebugEnabled,
      String sessionsViewStyle,
      bool compactSessionView,
      bool hideInactiveSessions,
    })
    settings,
    required ({int total, int online}) sessionStats,
    required ({int total, int online, String? firstSubtitle}) machineStats,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      _searchSection(
        widget: SettingsHealthSection(
          sessionTotal: sessionStats.total,
          onlineSessions: sessionStats.online,
          machineTotal: machineStats.total,
          onlineMachines: machineStats.online,
        ),
        terms: [
          'status',
          'health',
          'sync',
          'sessions',
          'machines',
          'account',
          'profile',
          'ready',
          'online',
        ],
      ),
      _searchSection(
        widget: WorkflowPresetsSection(
          viewInline: settings.viewInline,
          hideToolCalls: settings.hideToolCalls,
          expandTodos: settings.expandTodos,
          showFlavorIcons: settings.showFlavorIcons,
          ttsEnabled: settings.ttsEnabled,
          developerModeEnabled: settings.developerModeEnabled,
          toolCallDebugEnabled: settings.toolCallDebugEnabled,
          sessionsViewStyle: settings.sessionsViewStyle,
          compactSessionView: settings.compactSessionView,
          hideInactiveSessions: settings.hideInactiveSessions,
        ),
        terms: [
          'workflow',
          'preset',
          'focus',
          'voice',
          'low noise',
          'debug',
          'apply',
        ],
      ),
      _searchSection(
        widget: _buildAppearanceSection(
          context,
          themeMode: settings.themeMode,
          showFlavorIcons: settings.showFlavorIcons,
          avatarStyle: settings.avatarStyle,
          ref: ref,
        ),
        terms: [
          l10n.settingsAppearance,
          'theme',
          l10n.settingsShowFlavorIcons,
          l10n.settingsAvatarStyle,
          settings.avatarStyle,
        ],
      ),
      _searchSection(
        widget: _buildBehaviorSection(
          context,
          viewInline: settings.viewInline,
          hideToolCalls: settings.hideToolCalls,
          expandTodos: settings.expandTodos,
          ref: ref,
        ),
        terms: [
          l10n.settingsBehavior,
          l10n.settingsViewInline,
          l10n.settingsHideToolCalls,
          l10n.settingsExpandTodos,
          'tool calls',
          'todos',
        ],
      ),
      _searchSection(
        widget: _buildVoiceSection(
          context,
          ttsEnabled: settings.ttsEnabled,
          ref: ref,
        ),
        terms: [
          l10n.settingsVoice,
          l10n.settingsTextToSpeech,
          l10n.settingsVoiceSettings,
          'tts',
          'speech',
        ],
      ),
      _searchSection(
        widget: _buildAccountSection(context),
        terms: [
          l10n.settingsAccount,
          l10n.accountAccountSettings,
          'backup',
          'restore',
          'devices',
        ],
      ),
      _searchSection(
        widget: _buildToolsSection(
          context,
          profiles: ref.watch(
            settingsNotifierProvider.select((s) => s.profiles),
          ),
          selectedProfileId: ref.watch(
            settingsNotifierProvider.select((s) => s.lastUsedProfile),
          ),
        ),
        terms: [
          l10n.settingsFeatures,
          l10n.settingsProfiles,
          l10n.settingsUsage,
          'usage',
        ],
      ),
      _searchSection(
        widget: _buildSessionsSection(
          context,
          sessionsViewStyle: settings.sessionsViewStyle,
        ),
        terms: [
          l10n.settingsSessions,
          l10n.settingsSessionsViewStyle,
          l10n.sessionsFolders,
          l10n.autoArchiveTitle,
          'folder',
          'archive',
        ],
      ),
      if (machineStats.total > 0)
        _searchSection(
          widget: _buildMachinesSection(
            context,
            machineCount: machineStats.total,
            firstMachineSubtitle: machineStats.firstSubtitle,
          ),
          terms: [
            l10n.settingsMachines,
            'machine',
            'computer',
            'host',
            machineStats.firstSubtitle,
          ],
        ),
      _searchSection(
        widget: const _ServerSection(),
        terms: [
          l10n.settingsServer,
          l10n.settingsServerUrl,
          'custom server',
          'url',
          getServerUrl(),
        ],
      ),
      _searchSection(
        widget: _buildDeveloperSection(
          context,
          developerModeEnabled: settings.developerModeEnabled,
        ),
        terms: [
          l10n.settingsDeveloper,
          l10n.settingsDeveloperOptions,
          'debug',
          'logs',
        ],
      ),
      _searchSection(
        widget: _buildAboutSection(context),
        terms: [
          l10n.settingsAbout,
          l10n.settingsGitHub,
          l10n.settingsReportIssue,
          l10n.settingsPrivacyPolicy,
          l10n.settingsTermsOfService,
          'github',
          'privacy',
          'terms',
        ],
      ),
    ];
  }

  _SettingsSearchSection _searchSection({
    required Widget widget,
    required Iterable<String?> terms,
  }) {
    return _SettingsSearchSection(
      widget: widget,
      searchText: _normalizeSearch(terms.whereType<String>().join(' ')),
    );
  }

  List<_SettingsSearchSection> _filterSections(
    List<_SettingsSearchSection> sections,
    String query,
  ) {
    final normalized = _normalizeSearch(query);
    if (normalized.isEmpty) return sections;
    final terms = normalized.split(' ');
    return sections
        .where((section) => terms.every(section.searchText.contains))
        .toList();
  }

  String _normalizeSearch(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _SettingsSearchSection {
  const _SettingsSearchSection({
    required this.widget,
    required this.searchText,
  });

  final Widget widget;
  final String searchText;
}
