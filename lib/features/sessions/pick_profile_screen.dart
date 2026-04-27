import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
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
  const PickProfileScreen({super.key, this.agent = 'claude'});

  final String agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedId = ref.watch(
      settingsNotifierProvider.select((s) => s.lastUsedProfileForAgent(agent)),
    );
    final customProfiles = ref.watch(
      settingsNotifierProvider.select((s) => s.profiles),
    );
    final filteredBuiltInProfiles = builtInProfiles
        .where((profile) => profile.compatibility.supportsAgent(agent))
        .toList();
    final filteredCustomProfiles = customProfiles
        .where((profile) => profile.compatibility.supportsAgent(agent))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickSelectProfile),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ListView(
        padding: AppScreenPadding.standard,
        children: [
          // Subtitle
          Text(
            l10n.pickProfileChooseBackend,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── "None" ────────────────────────────────────────────────
          _ProfileCard(
            name: l10n.pickProfileNone,
            description: l10n.pickProfileNoneDesc,
            icon: Icons.remove_circle_outline_rounded,
            color: cs.onSurfaceVariant,
            isSelected: selectedId == null,
            onTap: () => context.pop<String?>(null),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Built-in profiles ─────────────────────────────────────
          AppSectionHeader(
            title: l10n.pickProfileBuiltInSection,
            uppercase: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < filteredBuiltInProfiles.length; i++) ...[
                  _ProfileTile(
                    name: filteredBuiltInProfiles[i].name,
                    description: filteredBuiltInProfiles[i].description ?? '',
                    icon: _iconForProfile(filteredBuiltInProfiles[i].id),
                    color: colorForProfile(filteredBuiltInProfiles[i].id),
                    isSelected: selectedId == filteredBuiltInProfiles[i].id,
                    isFirst: i == 0,
                    isLast: i == filteredBuiltInProfiles.length - 1,
                    onTap: () =>
                        context.pop<String?>(filteredBuiltInProfiles[i].id),
                  ),
                  if (i < filteredBuiltInProfiles.length - 1)
                    Divider(
                      height: 1,
                      indent: AppSpacing.lg + 36 + AppSpacing.md,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),

          // ── Custom profiles ───────────────────────────────────────
          if (filteredCustomProfiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSectionHeader(
              title: l10n.pickProfileCustomSection,
              uppercase: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < filteredCustomProfiles.length; i++) ...[
                    _ProfileTile(
                      name: filteredCustomProfiles[i].name,
                      description:
                          filteredCustomProfiles[i].description ??
                          l10n.pickProfileCustomDescription,
                      icon: Icons.person_outline_rounded,
                      color: cs.primary,
                      isSelected: selectedId == filteredCustomProfiles[i].id,
                      isFirst: i == 0,
                      isLast: i == filteredCustomProfiles.length - 1,
                      onTap: () =>
                          context.pop<String?>(filteredCustomProfiles[i].id),
                    ),
                    if (i < filteredCustomProfiles.length - 1)
                      Divider(
                        height: 1,
                        indent: AppSpacing.lg + 36 + AppSpacing.md,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

IconData _iconForProfile(String id) {
  switch (id) {
    case 'anthropic':
      return Icons.auto_awesome_rounded;
    case 'deepseek':
      return Icons.psychology_rounded;
    case 'zai':
      return Icons.bolt_rounded;
    case 'minimax':
      return Icons.memory_rounded;
    case 'openrouter':
      return Icons.hub_rounded;
    case 'openai':
      return Icons.smart_toy_rounded;
    case 'azure-openai':
      return Icons.cloud_rounded;
    default:
      return Icons.computer_rounded;
  }
}

/// A standalone card for the "None" option — larger, more prominent.
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
    final cs = theme.colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: AppOpacity.faint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SettingsIconContainer(icon: icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.primary : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 22)
            else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurface.withValues(alpha: AppOpacity.medium),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row inside a grouped card for a built-in / custom profile.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(AppRadius.lg) : Radius.zero,
      bottom: isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
    );

    return AppTappable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        color: isSelected
            ? cs.primary.withValues(alpha: AppOpacity.faint)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            SettingsIconContainer(icon: icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.primary : null,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20)
            else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurface.withValues(alpha: AppOpacity.medium),
              ),
          ],
        ),
      ),
    );
  }
}
