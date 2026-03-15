import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/components/app_card.dart';
import '../../core/components/app_section_header.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changelogTitle)),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          AppSectionHeader(
            title: 'February 2026',
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
            ),
          ),
          _ReleaseCard(
            version: 'Latest',
            items: const [
              'Interactive Inbox with friend requests'
                  ' and feed updates',
              'Dedicated Find Friends flow'
                  ' and user search',
              'Improved Settings with profile,'
                  ' machines, and account controls',
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: 'January 2026',
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
            ),
          ),
          _ReleaseCard(
            version: 'Previous',
            items: const [
              'Session list refinements'
                  ' and status indicators',
              'Improved localization coverage'
                  ' in core flows',
              'Developer diagnostics'
                  ' and logs improvements',
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.tonalIcon(
            onPressed: () => _openReleases(),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              AppLocalizations.of(context)
                  .changelogOpenGitHub,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleases() async {
    final uri = Uri.parse(
      'https://github.com/slopus/happy/releases',
    );
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.version,
    required this.items,
  });

  final String version;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(
                    alpha: AppOpacity.faint,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppRadius.xs,
                  ),
                ),
                child: Text(
                  version,
                  style:
                      theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xsm,
                      right: AppSpacing.sm,
                    ),
                    child: Container(
                      width: AppSpacing.xs,
                      height: AppSpacing.xs,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
