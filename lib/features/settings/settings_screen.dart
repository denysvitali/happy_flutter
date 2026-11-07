import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/package_info_cache.dart';
import 'settings_section_registry.dart';
import 'widgets/account_settings_section.dart';
import 'widgets/inline_theme_picker.dart';
import 'widgets/legacy_outbox_recovery_tile.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_switcher_tile.dart';
import 'widgets/settings_health_section.dart';
import 'widgets/settings_search_widgets.dart';
import '../sessions/widgets/sessions_view_style.dart';

part 'settings_screen_search.dart';
part 'settings_screen_specs.dart';

// ─── Settings Screen ─────────────────────────────────────────────────────────

/// Watched slice of [Settings] the hub specs read from.
typedef _HubSettings = ({
  String themeMode,
  bool showFlavorIcons,
  String avatarStyle,
  bool hideToolCalls,
  bool expandTodos,
  bool showLineNumbers,
  bool ttsEnabled,
  bool developerModeEnabled,
  String sessionsViewStyle,
  bool hideInactiveSessions,
  bool codexFastMode,
});

/// Machine summary feeding the Machines & server section.
typedef _HubMachineStats = ({
  int total,
  int online,
  bool sandboxAvailable,
  String? sandboxReason,
});

/// Settings hub screen.
///
/// Content is one ordered list of `SettingsHubEntry`s (see
/// settings_section_registry.dart): spec-built sections plus two static
/// blocks (status, account). Search filters the entries on data before
/// widgets are built. Each setting appears in exactly one section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    unawaited(_loadAppVersion());
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfoCache.get();
      if (!mounted) return;
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Version is informational; the About row renders without it.
    }
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
          hideToolCalls: s.hideToolCalls,
          expandTodos: s.expandTodos,
          showLineNumbers: s.showLineNumbers,
          ttsEnabled: s.ttsEnabled,
          developerModeEnabled: s.developerModeEnabled,
          sessionsViewStyle: s.sessionsViewStyle,
          hideInactiveSessions: s.hideInactiveSessions,
          codexFastMode: s.codexFastMode,
        ),
      ),
    );
    final profile = ref.watch(profileNotifierProvider);
    // Select only machine counts and sandbox availability to avoid
    // rebuilding this screen when unrelated machine fields change.
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
          machineStats: machineStats,
        );
        final tokens = settingsSearchTokens(_searchQuery);
        final blocks = _visibleHubBlocks(context, entries, tokens);

        final children = <Widget>[
          // Display-only: the Account section is the one way into account
          // and device management.
          ProfileHeader(profile: profile),
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
        children.add(const LegacyOutboxRecoveryTile());
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
    'agent' => 'Agent',
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
                        'agent',
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
      // Eight layouts with descriptions exceed a phone's half-height
      // sheet; let the list scroll instead of overflowing.
      isScrollControlled: true,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.settingsSessionsViewStyle),
                  subtitle: Text(l10n.settingsSessionsViewStyleSubtitle),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: RadioGroup<String>(
                      groupValue: sessionsViewStyle,
                      onChanged: (value) =>
                          Navigator.of(dialogContext).pop(value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final style in SessionsViewStyle.values)
                            RadioListTile<String>(
                              value: style.wire,
                              secondary: Icon(style.icon),
                              title: Text(style.label(l10n)),
                              subtitle: Text(style.description(l10n)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.settingsSignOut,
      content: l10n.settingsSignOutConfirm,
      confirmLabel: l10n.settingsSignOut,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    unawaited(ref.read(authStateNotifierProvider.notifier).signOut());
  }

  String _sessionsViewStyleLabel(AppLocalizations l10n, String value) {
    return SessionsViewStyle.fromWire(value).label(l10n);
  }
}
