import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/shell_script_parser.dart';

/// Profiles screen - AI backend profiles management in Settings.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customProfiles = ref.watch(
      settingsNotifierProvider.select((s) => s.profiles),
    );
    final selectedProfileId = ref.watch(
      settingsNotifierProvider.select((s) => s.lastUsedProfile),
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
      body: ListView(
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
                  ref
                      .read(
                          settingsNotifierProvider.notifier)
                      .updateSetting(
                          'lastUsedProfile', null);
                },
              ),
              ...builtInProfiles.map((profile) {
                // Use customised version if user has configured
                // this built-in profile.
                final effective = resolveProfile(
                  profile.id,
                  customProfiles,
                );
                final isSelected =
                    selectedProfileId == profile.id;
                return _buildProfileRow(
                  context: context,
                  profile: effective ?? profile,
                  isSelected: isSelected,
                  onTap: () {
                    ref
                        .read(settingsNotifierProvider
                            .notifier)
                        .updateSetting(
                          'lastUsedProfile',
                          profile.id,
                        );
                  },
                  onEdit: () => context.pushNamed(
                    'profile-editor',
                    extra: effective ?? profile,
                  ),
                );
              }),
            ],
          ),

          if (customProfiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            SettingsSection(
              title: l10n.profilesCustomTitle,
              children: [
                ...customProfiles.map((profile) {
                  final isSelected =
                      selectedProfileId == profile.id;
                  return _buildProfileRow(
                    context: context,
                    profile: profile,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider
                              .notifier)
                          .updateSetting(
                            'lastUsedProfile',
                            profile.id,
                          );
                    },
                    onEdit: () => context.pushNamed(
                      'profile-editor',
                      extra: profile,
                    ),
                    onDuplicate: () => _duplicateProfile(context, ref, profile),
                    onDelete: () =>
                        _confirmDeleteProfile(
                      context,
                      ref,
                      profile,
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required BuildContext context,
    required AIBackendProfile? profile,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onDuplicate,
  }) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = profile == null
        ? cs.onSurfaceVariant
        : profile.isBuiltIn
            ? colorForProfile(profile.id)
            : cs.primary;
    final icon = profile == null
        ? Icons.remove
        : profile.isBuiltIn
            ? _iconForProfile(profile.id)
            : Icons.person_outline;

    return SettingsRow(
      icon: icon,
      iconColor: iconColor,
      title: profile?.name ??
          AppLocalizations.of(context).profilesNone,
      subtitle: profile?.description ??
          AppLocalizations.of(context)
              .profilesDefaultDescription,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: cs.primary,
              size: AppSpacing.xl,
            ),
          if (onDuplicate != null)
            IconButton(
              icon: Icon(
                Icons.copy_outlined,
                size: AppSpacing.xl,
                color: cs.onSurfaceVariant,
              ),
              onPressed: onDuplicate,
              visualDensity: VisualDensity.compact,
            ),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: AppSpacing.xl,
                color: cs.onSurfaceVariant,
              ),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: AppSpacing.xl,
                color: cs.error,
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
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
                  hintText: 'export ANTHROPIC_BASE_URL=...\nexport '
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilesImportNoVars)),
        );
      }
      return;
    }

    final name = _deriveProfileName(result);
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
          .updateSetting('lastUsedProfile', profile.id);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.profilesImportParsed
                  .replaceAll('{count}', '${result.envVars.length}'),
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

  String _deriveProfileName(ShellScriptParseResult result) {
    final modelVar = result.envVars.firstWhere(
      (e) =>
          e.name == 'ANTHROPIC_MODEL' ||
          e.name == 'ANTHROPIC_DEFAULT_OPUS_MODEL' ||
          e.name == 'OPENAI_MODEL',
      orElse: () => result.envVars.first,
    );
    final modelValue = modelVar.value;
    if (modelValue.isNotEmpty) {
      final parts = modelValue.split('/');
      return parts.length > 1 ? parts.last : modelValue;
    }
    return 'Imported Profile';
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
                final updatedProfiles = settings.profiles
                    .where((p) => p.id != profile.id)
                    .toList();
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('profiles', updatedProfiles);
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
      name: '${profile.name} (Copy)',
      description: profile.description,
      startupBashScript: profile.startupBashScript,
      environmentVariables: profile.environmentVariables
          .map((e) => EnvironmentVariable(name: e.name, value: e.value))
          .toList(),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)
              .profilesDuplicated(profile.name),
        ),
      ),
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
    case 'openai':
      return Icons.smart_toy;
    case 'azure-openai':
      return Icons.cloud;
    default:
      return Icons.computer;
  }
}
