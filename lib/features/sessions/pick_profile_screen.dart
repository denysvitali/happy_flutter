import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A selectable AI profile entry.
class _AiProfile {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _AiProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
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
      description: 'Anthropic\'s Claude — balanced, safe, '
          'and capable AI assistant',
      icon: Icons.auto_awesome,
      color: Color(0xFFD97757),
    ),
    _AiProfile(
      id: 'gemini',
      name: 'Gemini',
      description: 'Google\'s Gemini — multimodal AI '
          'with strong reasoning',
      icon: Icons.diamond_outlined,
      color: Color(0xFF4285F4),
    ),
    _AiProfile(
      id: 'openai',
      name: 'OpenAI',
      description: 'OpenAI models — powerful general-purpose '
          'AI assistant',
      icon: Icons.hub_outlined,
      color: Color(0xFF10A37F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose an AI backend profile for your session.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
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
  final _AiProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: profile.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  profile.icon,
                  color: profile.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
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
