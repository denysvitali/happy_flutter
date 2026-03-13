import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final settings = ref.watch(settingsNotifierProvider);
    final customProfiles = settings.profiles;
    final selectedProfileId = settings.lastUsedProfile;

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
            onPressed: () => context.pushNamed('profile-editor'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // None option
          _buildProfileCard(
            context: context,
            profile: null,
            isSelected: selectedProfileId == null,
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('lastUsedProfile', null);
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Built-in profiles
          ...builtInProfiles.map((profile) {
            final isSelected =
                selectedProfileId == profile.id;
            return KeyedSubtree(
              key: ValueKey(profile.id),
              child: Column(
                children: [
                  _buildProfileCard(
                    context: context,
                    profile: profile,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSetting(
                            'lastUsedProfile',
                            profile.id,
                          );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            );
          }),

          // Custom profiles
          if (customProfiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                l10n.profilesCustomTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...customProfiles.map((profile) {
              final isSelected =
                  selectedProfileId == profile.id;
              return KeyedSubtree(
                key: ValueKey(profile.id),
                child: Column(
                  children: [
                    _buildProfileCard(
                      context: context,
                      profile: profile,
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(
                                settingsNotifierProvider.notifier)
                            .updateSetting(
                              'lastUsedProfile',
                              profile.id,
                            );
                      },
                      onEdit: () => context.pushNamed(
                        'profile-editor',
                        extra: profile,
                      ),
                      onDelete: () => _confirmDeleteProfile(
                        context,
                        ref,
                        profile,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required AIBackendProfile? profile,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: profile == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : profile.isBuiltIn
                    ? colorForProfile(profile.id)
                    : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            profile == null
                ? Icons.remove
                : profile.isBuiltIn
                    ? _iconForProfile(profile.id)
                    : Icons.person_outline,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        title: Text(
          profile?.name ?? AppLocalizations.of(context).profilesNone,
        ),
        subtitle: Text(
          profile?.description ??
              AppLocalizations.of(context).profilesDefaultDescription,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
              ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onTap,
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
                  fontSize: 13,
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
}

IconData _iconForProfile(String id) {
  switch (id) {
    case 'anthropic':
      return Icons.auto_awesome;
    case 'deepseek':
      return Icons.psychology;
    case 'zai':
      return Icons.bolt;
    case 'openai':
      return Icons.smart_toy;
    case 'azure-openai':
      return Icons.cloud;
    default:
      return Icons.computer;
  }
}
