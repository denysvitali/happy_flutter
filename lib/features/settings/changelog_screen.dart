import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What\'s New')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReleaseCard(
            version: 'Latest',
            date: 'February 2026',
            items: const [
              'Interactive Inbox with friend requests and feed updates',
              'Dedicated Find Friends flow and user search',
              'Improved Settings with profile, machines, and account controls',
            ],
          ),
          const SizedBox(height: 12),
          _ReleaseCard(
            version: 'Previous',
            date: 'January 2026',
            items: const [
              'Session list refinements and status indicators',
              'Improved localization coverage in core flows',
              'Developer diagnostics and logs improvements',
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => _openReleases(),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open GitHub Releases'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleases() async {
    final uri = Uri.parse('https://github.com/slopus/happy/releases');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.version,
    required this.date,
    required this.items,
  });

  final String version;
  final String date;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              version,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
