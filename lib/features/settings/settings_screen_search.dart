part of 'settings_screen.dart';

// ─── Hub assembly + search ──────────────────────────────────────────────────
//
// The hub is one ordered list of `SettingsHubEntry`s. Search filtering
// runs against spec data BEFORE any widget is built, so each keystroke
// only constructs the blocks and rows that survived the query.

extension _HubSearch on _SettingsScreenState {
  /// Ordered top-to-bottom hub content.
  List<SettingsHubEntry> _buildHubEntries(
    BuildContext context, {
    required _HubSettings settings,
    required _HubSessionStats sessionStats,
    required _HubMachineStats machineStats,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      StaticBlockEntry(
        widget: SettingsHealthSection(
          sessionTotal: sessionStats.total,
          onlineSessions: sessionStats.online,
          machineTotal: machineStats.total,
          onlineMachines: machineStats.online,
        ),
        searchTerms: [
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
      StaticBlockEntry(
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
        searchTerms: [
          'workflow',
          'preset',
          'focus',
          'voice',
          'low noise',
          'debug',
          'apply',
        ],
      ),
      SpecSectionEntry(_appearanceSectionSpec(l10n, settings)),
      SpecSectionEntry(_behaviorSectionSpec(l10n, settings)),
      SpecSectionEntry(_sessionsSectionSpec(l10n, settings)),
      SpecSectionEntry(_voiceSectionSpec(l10n, settings)),
      SpecSectionEntry(_toolsSectionSpec(l10n)),
      SpecSectionEntry(
        _infrastructureSectionSpec(
          l10n,
          machineTotal: machineStats.total,
          firstMachineSubtitle: machineStats.firstSubtitle,
          sandboxAvailable: machineStats.sandboxAvailable,
          sandboxReason: machineStats.sandboxReason,
        ),
      ),
      SpecSectionEntry(
        _developerSectionSpec(
          developerModeEnabled: settings.developerModeEnabled,
        ),
      ),
      SpecSectionEntry(_aboutSectionSpec(l10n)),
    ];
  }

  /// Builds only the blocks that survive [tokens].
  List<Widget> _visibleHubBlocks(
    BuildContext context,
    List<SettingsHubEntry> entries,
    List<String> tokens,
  ) {
    final blocks = <Widget>[];
    for (final entry in entries) {
      final widget = entry.buildFor(context, tokens);
      if (widget != null) {
        blocks.add(widget);
      }
    }
    return blocks;
  }
}
