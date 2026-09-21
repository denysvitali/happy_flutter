import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/settings_section.dart';
import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/env_secrets.dart';
import '../../core/utils/shell_script_parser.dart';
import 'profile_editor_screen.dart';
import 'widgets/profile_badge.dart';
import '../../core/utils/snack.dart';

/// Profiles screen - AI backend profiles management in Settings.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  String? _selectedProfileId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customProfiles = ref.watch(
      settingsNotifierProvider.select((s) => s.profiles),
    );
    final settings = ref.watch(
      settingsNotifierProvider.select(
        (s) => (s.lastUsedAgent, s.lastUsedProfilesByAgent, s.lastUsedProfile),
      ),
    );
    final selectedAgent = settings.$1 ?? 'claude';
    final selectedProfileId = resolveSelectedProfileIdForAgent(
      ref.read(settingsNotifierProvider),
      selectedAgent,
    );
    // Stored rows only — shipped presets are suggestions at creation time
    // (wizard/editor prefill), never auto-populated rows. Everything listed
    // here lives in Settings.profiles and is deletable.
    final allProfiles = customProfiles;
    final claudeProfiles = allProfiles
        .where((profile) => profile.compatibility.supportsAgent('claude'))
        .toList();
    final codexProfiles = allProfiles
        .where((profile) => profile.compatibility.supportsAgent('codex'))
        .toList();
    final agyProfiles = allProfiles
        .where((profile) => profile.compatibility.supportsAgent('agy'))
        .toList();

    final isWide = MasterDetailScaffold.isWide(context);

    // If the currently-selected profile no longer exists (deleted or
    // built-in customisation reset), drop the selection so the empty
    // state is shown instead of an editor with stale state.
    if (_selectedProfileId != null &&
        !allProfiles.any((p) => p.id == _selectedProfileId)) {
      _selectedProfileId = null;
    }

    final master = ListView(
      padding: AppScreenPadding.settings,
      children: [
        SettingsSection(
          title: l10n.profilesTitle,
          uppercase: false,
          children: [
            _buildProfileRow(
              context: context,
              profile: null,
              isSelected: selectedProfileId == null,
              onTap: () {
                final current = ref.read(settingsNotifierProvider);
                final notifier = ref.read(settingsNotifierProvider.notifier);
                unawaited(
                  notifier.updateSetting(
                    'lastUsedProfilesByAgent',
                    current.lastUsedProfilesWithAgent(selectedAgent, null),
                  ),
                );
                unawaited(
                  notifier.updateSetting('lastUsedAgent', selectedAgent),
                );
                unawaited(notifier.updateSetting('lastUsedProfile', null));
              },
            ),
          ],
        ),
        if (allProfiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: AppEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: l10n.profilesEmptyTitle,
              subtitle: l10n.profilesEmptySubtitle,
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.profilesAddProfile),
                onPressed: () => _showAddProfileMenu(context),
              ),
            ),
          ),
        _buildAgentSection(
          context: context,
          title: l10n.settingsClaudeCode,
          profiles: claudeProfiles,
          agent: 'claude',
          isWide: isWide,
        ),
        _buildAgentSection(
          context: context,
          title: l10n.sessionsCodex,
          profiles: codexProfiles,
          agent: 'codex',
          isWide: isWide,
        ),
        _buildAgentSection(
          context: context,
          title: l10n.sessionsAgy,
          profiles: agyProfiles,
          agent: 'agy',
          isWide: isWide,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: l10n.profilesImportTitle,
            onPressed: () => _showImportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.profilesAddProfile,
            onPressed: () => _showAddProfileMenu(context),
          ),
        ],
      ),
      body: isWide
          ? MasterDetailScaffold(
              hasSelection: _selectedProfileId != null,
              master: master,
              detail: _selectedProfileId == null
                  ? const SizedBox.shrink()
                  : ProfileEditorScreen(
                      key: ValueKey(_selectedProfileId),
                      profileId: _selectedProfileId,
                      embedded: true,
                      onClose: () => setState(() => _selectedProfileId = null),
                    ),
              emptyDetail: TabletDetailEmpty(
                icon: Icons.person_outline,
                message: l10n.profilesSelectToEdit,
              ),
            )
          : master,
    );
  }

  Widget _buildAgentSection({
    required BuildContext context,
    required String title,
    required List<AIBackendProfile> profiles,
    required String agent,
    required bool isWide,
  }) {
    if (profiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: SettingsSection(
        title: title,
        children: [
          ...profiles.map((profile) {
            final selectedProfileId = resolveSelectedProfileIdForAgent(
              ref.read(settingsNotifierProvider),
              agent,
            );
            final isSelected = selectedProfileId == profile.id;
            return _buildProfileRow(
              context: context,
              profile: profile,
              isSelected: isSelected,
              isInlineSelected: isWide && _selectedProfileId == profile.id,
              onTap: () {
                if (isWide) {
                  setState(() => _selectedProfileId = profile.id);
                  return;
                }
                final settings = ref.read(settingsNotifierProvider);
                final notifier = ref.read(settingsNotifierProvider.notifier);
                unawaited(
                  notifier.updateSetting(
                    'lastUsedProfilesByAgent',
                    settings.lastUsedProfilesWithAgent(agent, profile.id),
                  ),
                );
                unawaited(notifier.updateSetting('lastUsedAgent', agent));
                unawaited(
                  notifier.updateSetting('lastUsedProfile', profile.id),
                );
              },
              onEdit: isWide
                  ? () => setState(() => _selectedProfileId = profile.id)
                  : () => context.pushNamed('profile-editor', extra: profile),
              onDuplicate: () => _duplicateProfile(context, ref, profile),
              onDelete: () => _confirmDeleteProfile(context, ref, profile),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required BuildContext context,
    required AIBackendProfile? profile,
    required bool isSelected,
    required VoidCallback onTap,
    bool isInlineSelected = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onDuplicate,
  }) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isPresetRow = profile != null && isBuiltInPresetId(profile.id);
    final iconColor = profile == null
        ? cs.onSurfaceVariant
        : isPresetRow
        ? colorForProfile(profile.id)
        : cs.primary;
    final icon = profile == null
        ? Icons.remove
        : isPresetRow
        ? _iconForProfile(profile.id)
        : Icons.person_outline;
    final hasActions =
        onEdit != null || onDuplicate != null || onDelete != null;

    final row = SettingsRow(
      icon: icon,
      iconColor: iconColor,
      title: profile?.name ?? l10n.profilesNone,
      subtitle: profile?.description ?? l10n.profilesDefaultDescription,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile != null)
            ProfilePill(
              label: isPresetRow
                  ? l10n.profilesBadgeBuiltIn
                  : l10n.profilesBadgeCustom,
              color: isPresetRow ? colorForProfile(profile.id) : cs.primary,
            ),
          if (isSelected) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.check_circle, color: cs.primary, size: AppSpacing.xl),
          ],
          if (hasActions)
            PopupMenuButton<_ProfileAction>(
              icon: Icon(
                Icons.more_vert,
                size: AppSpacing.xl,
                color: cs.onSurfaceVariant,
              ),
              tooltip: l10n.profilesActionsTooltip,
              onSelected: (action) {
                switch (action) {
                  case _ProfileAction.edit:
                    onEdit?.call();
                  case _ProfileAction.duplicate:
                    onDuplicate?.call();
                  case _ProfileAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (ctx) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: _ProfileAction.edit,
                    child: Text(l10n.profilesEditProfile),
                  ),
                if (onDuplicate != null)
                  PopupMenuItem(
                    value: _ProfileAction.duplicate,
                    child: Text(l10n.profilesDuplicateProfile),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: _ProfileAction.delete,
                    child: Text(
                      l10n.profilesDeleteProfile,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    if (!isInlineSelected) return row;
    return ColoredBox(color: cs.primary.withValues(alpha: 0.08), child: row);
  }

  Future<void> _showImportDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profilesImportTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profilesImportHint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l10n.profilesImportLabel,
                  hintText:
                      'export ANTHROPIC_BASE_URL=...\nexport '
                      'ANTHROPIC_AUTH_TOKEN=...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.md,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profilesImportButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }

    final text = controller.text;
    controller.dispose();

    if (text.trim().isEmpty) return;

    final result = parseShellScript(text);
    if (result.envVars.isEmpty) {
      if (mounted) {
        context.showSnack(l10n.profilesImportNoVars);
      }
      return;
    }

    final name = _deriveProfileName(result, l10n.profilesImportedFallbackName);
    final profile = buildProfileFromEnvVars(name, result);

    final settings = ref.read(settingsNotifierProvider);
    final updatedProfiles = [...settings.profiles, profile];

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('profiles', updatedProfiles);

      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting(
            'lastUsedProfilesByAgent',
            settings.lastUsedProfilesWithAgent(
              _primaryAgentForProfile(profile),
              profile.id,
            ),
          );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.profilesImportParsed.replaceAll(
                '{count}',
                '${result.envVars.length}',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profilesFailedToSave)),
        );
      }
    }
  }

  String _deriveProfileName(
    ShellScriptParseResult result,
    String fallbackName,
  ) {
    // Secret variables are skipped so a pasted credential can never
    // become the (unmasked) profile name.
    return suggestProfileName(result.envVars) ?? fallbackName;
  }

  void _confirmDeleteProfile(
    BuildContext context,
    WidgetRef ref,
    AIBackendProfile profile,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.profilesDeleteTitle),
          content: Text(l10n.profilesDeleteConfirm(profile.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                final settings = ref.read(settingsNotifierProvider);
                final notifier = ref.read(settingsNotifierProvider.notifier);
                final updatedProfiles = settings.profiles
                    .where((p) => p.id != profile.id)
                    .toList();
                notifier.updateSetting('profiles', updatedProfiles);
                final updatedLastUsedProfiles = Map<String, String>.from(
                  settings.lastUsedProfilesByAgent,
                )..removeWhere((_, value) => value == profile.id);
                notifier.updateSetting(
                  'lastUsedProfilesByAgent',
                  updatedLastUsedProfiles,
                );
                // Sweep DraftStorage so per-session profile mappings do not
                // outlive the profile itself. Without this, ChatScreen
                // _loadInitialSettings hits the firstWhere fallback every
                // time the user opens an affected session.
                unawaited(DraftStorage().sweepProfileReferences(profile.id));
                Navigator.pop(context);
              },
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
  }

  void _duplicateProfile(
    BuildContext context,
    WidgetRef ref,
    AIBackendProfile profile,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final duplicate = AIBackendProfile(
      id: 'custom_$now',
      name: '${profile.name}${AppLocalizations.of(context).profilesCopySuffix}',
      description: profile.description,
      startupBashScript: profile.startupBashScript,
      environmentVariables: profile.environmentVariables
          .map((e) => EnvironmentVariable(name: e.name, value: e.value))
          .toList(),
      defaultModelMode: profile.defaultModelMode,
      models: profile.models,
      isBuiltIn: false,
      compatibility: profile.compatibility,
      createdAt: now,
      updatedAt: now,
    );

    final settings = ref.read(settingsNotifierProvider);
    final updatedProfiles = [...settings.profiles, duplicate];

    ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting('profiles', updatedProfiles);

    context.showSnack(
      AppLocalizations.of(context).profilesDuplicated(profile.name),
    );
  }

  void _showAddProfileMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.auto_fix_high,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                title: Text(l10n.profilesWizardTitle),
                subtitle: Text(l10n.profilesWizardSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed('profile-wizard');
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.add),
                ),
                title: Text(l10n.profilesAddProfile),
                subtitle: Text(l10n.profilesAddProfileSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed('profile-editor');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ProfileAction { edit, duplicate, delete }

String _primaryAgentForProfile(AIBackendProfile profile) {
  final compatibility = profile.compatibility;
  if (compatibility.claude) return 'claude';
  if (compatibility.codex) return 'codex';
  if (compatibility.agy) return 'agy';
  return 'claude';
}

IconData _iconForProfile(String id) {
  switch (id) {
    case 'anthropic':
      return Icons.auto_awesome;
    case 'deepseek':
      return Icons.psychology;
    case 'zai':
      return Icons.bolt;
    case 'minimax':
      return Icons.memory;
    case 'xiaomi-mimo':
      return Icons.rocket_launch;
    case 'openrouter':
      return Icons.hub;
    case 'openai':
      return Icons.smart_toy;
    case 'azure-openai':
      return Icons.cloud;
    default:
      return Icons.computer;
  }
}
