import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import 'profile_editor_screen.dart';

/// Profiles screen - AI backend profiles management in Settings.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final customProfiles = settings.profiles;
    final selectedProfileId = settings.lastUsedProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileEditorScreen(),
              ),
            ),
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
                  fontWeight: FontWeight.bold,
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
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProfileEditorScreen(existing: profile),
                        ),
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
                    ? _colorForProfile(profile.id)
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

Color _colorForProfile(String id) {
  switch (id) {
    case 'anthropic':
      return const Color(0xFFD97757);
    case 'deepseek':
      return const Color(0xFF4A6CF7);
    case 'zai':
      return const Color(0xFF6366F1);
    case 'openai':
      return const Color(0xFF10A37F);
    case 'azure-openai':
      return const Color(0xFF0078D4);
    default:
      return const Color(0xFF6B7280);
  }
}
