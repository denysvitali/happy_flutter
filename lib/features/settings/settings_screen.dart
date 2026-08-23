import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/machine.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_tokens.dart';
import 'settings_section_registry.dart';
import 'widgets/danger_zone.dart';
import 'widgets/inline_theme_picker.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_switcher_tile.dart';
import 'widgets/settings_health_section.dart';
import 'widgets/settings_search_widgets.dart';
import 'widgets/workflow_presets_section.dart';

part 'settings_screen_search.dart';
part 'settings_screen_specs.dart';

// ─── Settings Screen ─────────────────────────────────────────────────────────

/// Watched slice of [Settings] the hub specs read from.
typedef _HubSettings = ({
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
});

/// Session totals feeding the status block.
typedef _HubSessionStats = ({int total, int online});

/// Machine summary feeding the status block and infrastructure section.
typedef _HubMachineStats = ({
  int total,
  int online,
  String? firstSubtitle,
  bool sandboxAvailable,
  String? sandboxReason,
});

/// Settings hub screen.
///
/// Content is one ordered list of `SettingsHubEntry`s (see
/// settings_section_registry.dart): spec-built sections plus two static
/// blocks (status, workflow presets). Search filters the entries on
/// data before widgets are built.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      settingsNotifierProvider.select(
        (s) => (
          themeMode: s.themeMode,
          showFlavorIcons: s.showFlavorIcons,
          avatarStyle: s.avatarStyle,
          viewInline: s.viewInline,
          hideToolCalls: s.hideToolCalls,
          expandTodos: s.expandTodos,
          ttsEnabled: s.ttsEnabled,
          developerModeEnabled: s.developerModeEnabled,
          toolCallDebugEnabled: s.toolCallDebugEnabled,
          sessionsViewStyle: s.sessionsViewStyle,
          compactSessionView: s.compactSessionView,
          hideInactiveSessions: s.hideInactiveSessions,
        ),
      ),
    );
    final profile = ref.watch(profileNotifierProvider);
    final sessionStats = ref.watch(
      sessionsNotifierProvider.select(
        (sessions) => (
          total: sessions.length,
          online: sessions.values
              .where((session) => session.presence == 'online')
              .length,
        ),
      ),
    );
    // Select only the machine count and first machine's display name/host to
    // avoid rebuilding this screen when unrelated machine fields change.
    final machineStats = ref.watch(
      machinesNotifierProvider.select((machines) {
        final values = machines.values.toList(growable: false);
        final online = values.where((machine) => machine.isOnline).toList();
        final sandboxAvailable = online.any(
          (machine) => machine.metadata?.sandboxAvailable ?? false,
        );
        final reasonSources = online.isEmpty ? values : online;
        final sandboxReason = reasonSources
            .map((machine) => machine.metadata?.sandboxReason)
            .whereType<String>()
            .where((reason) => reason.trim().isNotEmpty)
            .firstOrNull;
        return (
          total: values.length,
          online: online.length,
          firstSubtitle: values.isEmpty
              ? null
              : values.first.metadata?.displayName ??
                    values.first.metadata?.host,
          sandboxAvailable: sandboxAvailable,
          sandboxReason: sandboxReason,
        );
      }),
    );
    final l10n = AppLocalizations.of(context);

    final body = LayoutBuilder(
      builder: (context, constraints) {
        const maxContentWidth = AppBreakpoint.contentMax;
        final horizontalPadding =
            constraints.maxWidth > maxContentWidth + AppSpacing.xl * 2
            ? (constraints.maxWidth - maxContentWidth) / 2
            : AppSpacing.lg;

        final entries = _buildHubEntries(
          context,
          settings: settings,
          sessionStats: sessionStats,
          machineStats: machineStats,
        );
        final tokens = settingsSearchTokens(_searchQuery);
        final blocks = _visibleHubBlocks(context, entries, tokens);

        final children = <Widget>[
          ProfileHeader(
            profile: profile,
            onTap: () => context.pushNamed('account'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSearchField(
            controller: _searchController,
            query: _searchQuery,
          ),
          const SizedBox(height: AppSpacing.lg),
        ];
        if (tokens.isNotEmpty && blocks.isEmpty) {
          children.add(const SettingsNoSearchResults());
        }
        for (var i = 0; i < blocks.length; i++) {
          children.add(blocks[i]);
          if (i < blocks.length - 1) {
            children.add(const SizedBox(height: AppSpacing.lg));
          }
        }
        if (tokens.isEmpty) {
          children
            ..add(const SizedBox(height: AppSpacing.xl))
            ..add(DangerZone(onSignOut: () => _confirmSignOut(context)));
        }
        children.add(const SizedBox(height: AppSpacing.xxxl));

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.md,
            horizontalPadding,
            AppSpacing.xxxl,
          ),
          children: children,
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: body,
    );
  }

  String _avatarStyleLabel(String style) => switch (style) {
    'gradient' => 'Gradient',
    'pixelated' => 'Pixelated',
    'brutalist' => 'Brutalist',
    'geometric' => 'Geometric',
    'rings' => 'Rings',
    'constellation' => 'Constellation',
    'wave' => 'Wave',
    'neon' => 'Neon',
    'bloom' => 'Bloom',
    'prism' => 'Prism',
    _ => style,
  };

  void _showAvatarStyleDialog(BuildContext context, String currentAvatarStyle) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10nDialog.settingsAvatarStyle),
          content: RadioGroup<String>(
            groupValue: currentAvatarStyle,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('avatarStyle', value);
              Navigator.pop(dialogContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [
                        'gradient',
                        'pixelated',
                        'brutalist',
                        'geometric',
                        'rings',
                        'constellation',
                        'wave',
                        'neon',
                        'bloom',
                        'prism',
                      ]
                      .map(
                        (style) => RadioListTile(
                          title: Text(_avatarStyleLabel(style)),
                          value: style,
                        ),
                      )
                      .toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSessionsViewStyleDialog(
    BuildContext context, {
    required String sessionsViewStyle,
  }) async {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.settingsSessionsViewStyle),
                subtitle: Text(l10n.settingsSessionsViewStyleSubtitle),
              ),
              RadioGroup<String>(
                groupValue: sessionsViewStyle,
                onChanged: (value) => Navigator.of(dialogContext).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'mission_control',
                      title: Text(l10n.sessionsViewStyleMissionControl),
                    ),
                    RadioListTile<String>(
                      value: 'folder',
                      title: Text(l10n.sessionsViewStyleFolderCentric),
                    ),
                    RadioListTile<String>(
                      value: 'unread_focus',
                      title: Text(l10n.sessionsViewStyleUnreadFocus),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == sessionsViewStyle) {
      return;
    }
    if (!context.mounted) return;
    await notifier.updateSetting('sessionsViewStyle', selected);
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10nDialog.settingsSignOut),
          content: Text(l10nDialog.settingsSignOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(authStateNotifierProvider.notifier).signOut();
              },
              child: Text(l10nDialog.settingsSignOut),
            ),
          ],
        );
      },
    );
  }

  String _sessionsViewStyleLabel(AppLocalizations l10n, String value) {
    return switch (value) {
      'folder' => l10n.sessionsViewStyleFolderCentric,
      'unread_focus' => l10n.sessionsViewStyleUnreadFocus,
      _ => l10n.sessionsViewStyleMissionControl,
    };
  }
}
