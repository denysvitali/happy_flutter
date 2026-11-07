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
    required _HubMachineStats machineStats,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      const StaticBlockEntry(
        widget: SettingsHealthSection(),
        searchTerms: [
          'status',
          'health',
          'sync',
          'connection',
          'diagnostics',
          'online',
          'offline',
        ],
      ),
      SpecSectionEntry(_appearanceSectionSpec(l10n, settings)),
      SpecSectionEntry(_chatSectionSpec(l10n, settings)),
      SpecSectionEntry(_sessionsSectionSpec(l10n, settings)),
      SpecSectionEntry(_agentsSectionSpec(l10n, settings)),
      SpecSectionEntry(_voiceSectionSpec(l10n, settings)),
      SpecSectionEntry(
        _machinesSectionSpec(
          l10n,
          machineTotal: machineStats.total,
          machinesOnline: machineStats.online,
          sandboxAvailable: machineStats.sandboxAvailable,
          sandboxReason: machineStats.sandboxReason,
        ),
      ),
      StaticBlockEntry(
        widget: AccountSettingsSection(
          onSignOut: () => _confirmSignOut(context),
        ),
        searchTerms: accountSettingsSearchTerms,
      ),
      SpecSectionEntry(_aboutSectionSpec(l10n, appVersion: _appVersion)),
      SpecSectionEntry(
        _developerSectionSpec(
          l10n,
          developerModeEnabled: settings.developerModeEnabled,
        ),
      ),
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
