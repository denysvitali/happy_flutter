import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/changelog_service.dart';
import '../../core/theme/app_tokens.dart';

/// Changelog screen — shows commits between the previous and current version.
///
/// Uses the Conventional Commits specification to categorise entries by type
/// (feat, fix, docs, chore, etc.) and renders them in a readable list.
class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({required this.toVersion, super.key, this.fromVersion});

  /// Version that was previously installed (null on first install).
  final String? fromVersion;

  /// Current version tag, e.g. "1.2.3".
  final String toVersion;

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  late final ChangelogService _changelogService;
  ChangelogResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _changelogService = ChangelogService();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _changelogService.getChangelog(
      fromVersion: widget.fromVersion,
      toVersion: widget.toVersion,
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changelogTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: l10n.changelogOpenGitHub,
            onPressed: () => _openGitHubReleases(),
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null || result.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.changelogNoEntriesAvailable),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: result.entries.length,
      itemBuilder: (context, index) {
        final entry = result.entries[index];
        return _ChangelogEntryTile(entry: entry);
      },
    );
  }

  Future<void> _openGitHubReleases() async {
    final uri = Uri.parse('https://github.com/slopus/happy/releases');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ChangelogEntryTile extends StatelessWidget {
  const _ChangelogEntryTile({required this.entry});

  final ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final typeColor = _typeColor(entry.type, cs);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Center(
              child: Text(
                _typeEmoji(entry.type),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        entry.type,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.scope != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        entry.scope!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.isBreaking == true) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'BREAKING',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(entry.message, style: theme.textTheme.bodyMedium),
                if (entry.date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(entry.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '${dt.year}-$month-$day';
    } catch (_) {
      return isoDate.split('T').first;
    }
  }

  Color _typeColor(String type, ColorScheme cs) {
    switch (type) {
      case 'feat':
        return cs.primary;
      case 'fix':
        return cs.error;
      case 'docs':
        return Colors.blue;
      case 'style':
        return Colors.purple;
      case 'refactor':
        return Colors.orange;
      case 'perf':
        return Colors.teal;
      case 'test':
        return Colors.green;
      case 'build':
        return Colors.brown;
      case 'ci':
        return Colors.indigo;
      case 'chore':
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'feat':
        return '✨';
      case 'fix':
        return '🐛';
      case 'docs':
        return '📖';
      case 'style':
        return '💄';
      case 'refactor':
        return '♻️';
      case 'perf':
        return '⚡';
      case 'test':
        return '✅';
      case 'build':
        return '📦';
      case 'ci':
        return '👷';
      case 'chore':
        return '🔧';
      default:
        return '•';
    }
  }
}
