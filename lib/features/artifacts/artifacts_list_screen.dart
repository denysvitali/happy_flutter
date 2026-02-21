import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/artifact.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

/// Screen displaying the list of all artifacts.
class ArtifactsListScreen extends ConsumerStatefulWidget {
  const ArtifactsListScreen({super.key});

  @override
  ConsumerState<ArtifactsListScreen> createState() =>
      _ArtifactsListScreenState();
}

class _ArtifactsListScreenState
    extends ConsumerState<ArtifactsListScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(artifactsNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifacts = ref.watch(artifactsNotifierProvider);
    final sortedArtifacts = artifacts.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.artifactsTitle)),
      body: sortedArtifacts.isEmpty
          ? _buildEmptyState(l10n)
          : _buildList(sortedArtifacts),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/artifacts/new'),
        tooltip: l10n.commonCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.description_outlined,
      title: l10n.artifactsDetail,
      subtitle: 'Create your first artifact using the + button.',
    );
  }

  Widget _buildList(List<DecryptedArtifact> artifacts) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: artifacts.length,
      itemBuilder: (context, index) {
        final artifact = artifacts[index];
        return Padding(
          key: ValueKey(artifact.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ArtifactListCard(artifact: artifact),
        );
      },
    );
  }
}

class _ArtifactListCard extends StatelessWidget {
  const _ArtifactListCard({required this.artifact});

  final DecryptedArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final date = DateTime.fromMillisecondsSinceEpoch(artifact.updatedAt);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';

    final title =
        (artifact.title?.isNotEmpty ?? false)
            ? artifact.title!
            : _shortId(artifact.id);

    final isDraft = artifact.draft ?? false;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () => context.push('/artifacts/${artifact.id}'),
      child: Row(
        children: [
          // Leading icon container.
          Container(
            width: AppSpacing.xxxl + AppSpacing.lg, // 48 px
            height: AppSpacing.xxxl + AppSpacing.lg,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.description_outlined,
              size: AppSpacing.xl,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Title + metadata.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isDraft) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _TypeBadge(
                        label: context.l10n.artifactsDraft,
                        color: cs.tertiary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right,
            size: AppSpacing.xl,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length > 12) return '${id.substring(0, 12)}...';
    return id;
  }
}

/// Small colored pill badge for artifact type / status labels.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
