import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/safe_ui_messages.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/workflows_repository.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'workflow_card.dart';

/// Per-session list of Claude Code workflow runs.
class WorkflowsScreen extends ConsumerStatefulWidget {
  /// Creates a [WorkflowsScreen].
  const WorkflowsScreen({required this.sessionId, super.key});

  /// The session whose workflow runs are shown.
  final String sessionId;

  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> {
  StreamSubscription<String>? _sub;
  StreamSubscription<String>? _msgSub;
  Timer? _msgDebounce;
  bool _initialLoading = true;
  String? _error;
  bool _hasRetriedOnEmptyEvent = false;
  List<WorkflowRun>? _projectedSourceRuns;
  int _projectedMessageRevision = -1;
  List<_WorkflowCardProjection> _projectedRuns =
      const <_WorkflowCardProjection>[];

  /// Streaming mutates the message revision on every workflow step event;
  /// without a floor, each poll would re-walk the whole resident
  /// transcript to rebuild [WorkflowTranscriptIndex] (progressive-lag
  /// audit 2026-08-24). Revision-equal builds reuse forever; mid-stream
  /// builds reuse within [_transcriptIndexMinInterval].
  static const _transcriptIndexMinInterval = Duration(milliseconds: 250);
  WorkflowTranscriptIndex? _transcriptIndex;
  int _transcriptIndexRevision = -1;
  DateTime _transcriptIndexAt = DateTime.fromMillisecondsSinceEpoch(0);

  WorkflowTranscriptIndex _indexFor(int revision) {
    final cached = _transcriptIndex;
    if (cached != null && revision == _transcriptIndexRevision) {
      return cached;
    }
    final now = DateTime.now();
    if (cached != null &&
        now.difference(_transcriptIndexAt) < _transcriptIndexMinInterval) {
      return cached;
    }
    final index = WorkflowTranscriptIndex.fromMessages(
      sync.messagesForSession(widget.sessionId),
    );
    _transcriptIndex = index;
    _transcriptIndexRevision = revision;
    _transcriptIndexAt = now;
    return index;
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) {
          if (!mounted) return;
          setState(() {});
          if (_hasRetriedOnEmptyEvent) return;
          final runs = ref.read(
            workflowsNotifierProvider.select(
              (state) => state[widget.sessionId] ?? const <WorkflowRun>[],
            ),
          );
          if (runs.isEmpty && !_initialLoading) {
            _hasRetriedOnEmptyEvent = true;
            _refresh();
          }
        });
    // A message change means a workflow may have just completed (foreground
    // task_progress, or a background task_notification): debounce a refetch
    // so the card flips from a sparse row to the rich on-disk snapshot
    // promptly. We intentionally do NOT setState on every tick — that would
    // re-walk the whole transcript per run ~10x/s; the chat inline view is
    // the live progress surface, the list updates on completion.
    _msgSub = sync.onSessionMessagesChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) {
          if (!mounted) return;
          _msgDebounce?.cancel();
          _msgDebounce = Timer(const Duration(seconds: 1), _refreshVisible);
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgSub?.cancel();
    _msgDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!sync.isInitialized) return;
    setState(() => _error = null);
    try {
      final notifier = ref.read(workflowsNotifierProvider.notifier);
      final visibleRefresh = notifier.refreshSession(widget.sessionId);
      // Also refresh other relevant sessions in the background so the
      // global workflows map stays up to date. Start it while the visible
      // refresh is in flight: Sync shares per-session requests, so if the
      // visible session is also a global candidate this reuses the same RPC
      // rather than immediately issuing a second one.
      unawaited(notifier.refreshFromSync());
      await visibleRefresh;
    } catch (e, st) {
      logger.warning('WorkflowsScreen refresh failed: $e', e, st);
      if (mounted) {
        setState(
          () => _error = safeUiFailureMessage(
            context.l10n,
            SafeUiFailure.workflowLoad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  /// Refetch only the visible session's workflow list. Cheaper than
  /// [_refresh] (no global background sweep) so it is safe on a debounce.
  Future<void> _refreshVisible() async {
    if (!mounted || !sync.isInitialized) return;
    try {
      await ref
          .read(workflowsNotifierProvider.notifier)
          .refreshSession(widget.sessionId);
    } catch (e, st) {
      logger.warning('WorkflowsScreen visible refresh failed: $e', e, st);
    }
  }

  void _openRun(WorkflowRun run) {
    context.push(
      '/chat/${widget.sessionId}/workflow/${run.runId}',
      extra: run.toJson(),
    );
  }

  List<_WorkflowCardProjection> _projectionsFor(List<WorkflowRun> runs) {
    final revision = sync.messagesRevision(widget.sessionId);
    if (identical(_projectedSourceRuns, runs) &&
        revision == _projectedMessageRevision) {
      return _projectedRuns;
    }
    final index = _indexFor(revision);
    final projected = <_WorkflowCardProjection>[];
    for (final source in runs) {
      final run = WorkflowRun.enrichFromIndex(source, index);
      int? stepCount;
      String? stepPreview;
      final hasStructured =
          (run.summary != null && run.summary!.isNotEmpty) ||
          run.phases.isNotEmpty ||
          (run.agentCount != null && run.agentCount! > 0) ||
          (run.totalTokens != null && run.totalTokens! > 0) ||
          (run.totalToolCalls != null && run.totalToolCalls! > 0);
      if (!hasStructured) {
        final steps = WorkflowRun.stepChildrenForIndex(run.runId, index);
        if (steps.isNotEmpty) {
          stepCount = steps.length;
          final collapsed = WorkflowRun.collapseSteps(steps);
          stepPreview = collapsed.isEmpty
              ? null
              : WorkflowRun.stepLabel(collapsed.last);
        }
      }
      projected.add(
        _WorkflowCardProjection(
          run: run,
          stepCount: stepCount,
          stepPreview: stepPreview,
        ),
      );
    }
    _projectedSourceRuns = runs;
    _projectedMessageRevision = revision;
    return _projectedRuns = List<_WorkflowCardProjection>.unmodifiable(
      projected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(
      workflowsNotifierProvider.select(
        (state) => state[widget.sessionId] ?? const <WorkflowRun>[],
      ),
    );
    final isUnsupported = ref
        .read(workflowsRepositoryProvider)
        .isWorkflowListUnsupportedForSession(widget.sessionId);
    final projections = _projectionsFor(runs);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workflowsTitle)),
      body: _initialLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _refresh)
          : runs.isEmpty
          ? _EmptyState(isUnsupported: isUnsupported)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl * 2,
                ),
                itemCount: runs.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        context.l10n.workflowsCount(runs.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final projection = projections[index - 1];
                  final run = projection.run;
                  return WorkflowCard(
                    key: ValueKey('workflow-${run.runId}'),
                    run: run,
                    stepCount: projection.stepCount,
                    stepPreview: projection.stepPreview,
                    onTap: () => _openRun(run),
                  );
                },
              ),
            ),
    );
  }
}

class _WorkflowCardProjection {
  const _WorkflowCardProjection({
    required this.run,
    this.stepCount,
    this.stepPreview,
  });

  final WorkflowRun run;
  final int? stepCount;
  final String? stepPreview;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.isUnsupported = false});

  /// Whether the daemon reported that it does not support listing
  /// workflow runs (older CLI). Shown as a distinct message so the user
  /// knows workflows are unavailable rather than merely empty.
  final bool isUnsupported;

  @override
  Widget build(BuildContext context) {
    if (isUnsupported) {
      return Center(
        child: AppEmptyState(
          icon: Icons.update_disabled,
          title: context.l10n.workflowsUnavailableTitle,
          subtitle: context.l10n.workflowsUnavailableSubtitle,
        ),
      );
    }
    return Center(
      child: AppEmptyState(
        icon: Icons.account_tree_outlined,
        title: context.l10n.workflowsEmptyTitle,
        subtitle: context.l10n.workflowsEmptySubtitle,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline,
        title: context.l10n.workflowsLoadFailedTitle,
        subtitle: error,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.commonRetry),
        ),
      ),
    );
  }
}
