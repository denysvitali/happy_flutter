import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/sync/sync_subscription_mixin.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';

/// A sliver section of artifacts linked to a session, across all its runs.
class WorkflowSessionArtifacts extends ConsumerStatefulWidget {
  const WorkflowSessionArtifacts({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<WorkflowSessionArtifacts> createState() =>
      _WorkflowSessionArtifactsState();
}

class _WorkflowSessionArtifactsState
    extends ConsumerState<WorkflowSessionArtifacts>
    with SyncSubscriptionMixin {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      final notifier = ref.read(artifactsNotifierProvider.notifier)
        ..loadFromSync();
      await notifier.refreshFromSync();
      if (mounted) setState(() => _loading = false);
    });
    subscribeToDomains([SyncDomain.artifacts], () {
      ref.read(artifactsNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artifacts =
        ref
            .watch(artifactsListProvider)
            .where(
              (artifact) =>
                  artifact.draft != true &&
                  (artifact.sessions?.contains(widget.sessionId) ?? false),
            )
            .toList()
          ..sort((a, b) {
            final updated = b.updatedAt.compareTo(a.updatedAt);
            return updated != 0 ? updated : a.id.compareTo(b.id);
          });

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.workflowSessionArtifactsTitle,
                  style: AppText.title(theme),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.workflowSessionArtifactsSubtitle,
                  style: AppText.secondary(theme),
                ),
                if (artifacts.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (_loading)
                    const AppCircularProgressIndicator()
                  else
                    Text(
                      context.l10n.artifactsEmpty,
                      style: AppText.secondary(theme),
                    ),
                ],
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: artifacts.length,
          itemBuilder: (context, index) {
            final artifact = artifacts[index];
            final title = artifact.title?.trim();
            return ListTile(
              key: ValueKey('workflow-session-artifact-${artifact.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: const Icon(Icons.description_outlined),
              title: Text(
                title == null || title.isEmpty ? artifact.id : title,
                style: AppText.title(theme),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(
                'artifact-detail',
                pathParameters: {'artifactId': artifact.id},
              ),
            );
          },
        ),
      ],
    );
  }
}
