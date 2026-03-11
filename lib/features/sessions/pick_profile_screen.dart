import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/built_in_profiles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for selecting an AI backend profile.
///
/// Shows built-in profiles (Anthropic, DeepSeek, Z.AI, OpenAI, Azure)
/// plus any user-defined custom profiles from settings.
///
/// Pops with the selected profile ID string, or `null` for "None".
class PickProfileScreen extends ConsumerWidget {
  const PickProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final selectedId = settings.lastUsedProfile;
    final customProfiles = settings.profiles;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickSelectProfile),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Choose an AI backend profile for your session.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // "None" option
          _ProfileCard(
            name: 'None',
            description: 'Use default configuration',
            icon: Icons.remove_circle_outline,
            color: theme.colorScheme.onSurfaceVariant,
            isSelected: selectedId == null,
            onTap: () => context.pop<String?>(null),
          ),

          // Built-in profiles
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              'BUILT-IN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...builtInProfiles.map(
            (profile) => _ProfileCard(
              name: profile.name,
              description: profile.description ?? '',
              icon: _iconForProfile(profile.id),
              color: colorForProfile(profile.id),
              isSelected: selectedId == profile.id,
              onTap: () => context.pop<String?>(profile.id),
            ),
          ),

          // Custom profiles
          if (customProfiles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                'CUSTOM',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...customProfiles.map(
              (profile) => _ProfileCard(
                name: profile.name,
                description: profile.description ?? 'Custom profile',
                icon: Icons.person_outline,
                color: theme.colorScheme.primary,
                isSelected: selectedId == profile.id,
                onTap: () => context.pop<String?>(profile.id),
              ),
            ),
          ],
        ],
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
    case 'openai':
      return Icons.smart_toy;
    case 'azure-openai':
      return Icons.cloud;
    default:
      return Icons.computer;
  }
}



class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color: theme
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
