import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// A selectable AI profile entry.
class _AiProfile {

  const _AiProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
}

/// Screen for selecting an AI profile (Claude, Gemini, OpenAI).
///
/// Pops with a string identifier of the selected profile.
class PickProfileScreen extends StatelessWidget {
  const PickProfileScreen({super.key});

  static const _profiles = [
    _AiProfile(
      id: 'claude',
      name: 'Claude',
      description: "Anthropic's Claude — balanced, safe, "
          'and capable AI assistant',
      icon: Icons.auto_awesome,
      color: Color(0xFFD97757),
    ),
    _AiProfile(
      id: 'gemini',
      name: 'Gemini',
      description: "Google's Gemini — multimodal AI "
          'with strong reasoning',
      icon: Icons.diamond_outlined,
      color: Color(0xFF4285F4),
    ),
    _AiProfile(
      id: 'codex',
      name: 'Codex',
      description: 'OpenAI Codex — powerful general-purpose '
          'AI assistant',
      icon: Icons.hub_outlined,
      color: Color(0xFF10A37F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

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
          ..._profiles.map(
            (profile) => _ProfileCard(
              profile: profile,
              onTap: () => context.pop(profile.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {

  const _ProfileCard({
    required this.profile,
    required this.onTap,
  });
  final _AiProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: profile.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  profile.icon,
                  color: profile.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
