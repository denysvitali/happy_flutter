import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/safe_ui_messages.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import '../../core/wire/wire_parsers.dart';
import 'workflow_display.dart';
import 'workflow_phase_section.dart';
import 'workflow_run_header.dart';

/// Detail view for a single Claude Code workflow run.
///
/// Shows phases, agents grouped by phase, and logs. Refreshes by re-fetching
/// the snapshot via [Sync.fetchWorkflowSnapshot].
class WorkflowRunScreen extends ConsumerStatefulWidget {
  /// Creates a [WorkflowRunScreen].
  const WorkflowRunScreen({
    required this.sessionId,
    required this.runId,
    super.key,
    this.taskData,
    this.embedded = false,
  });

  /// The session the workflow belongs to.
  final String sessionId;

  /// The workflow run id.
  final String runId;

  /// Optional pre-loaded workflow data passed via route extra.
  final Map<String, dynamic>? taskData;

  /// When true, render only the run body (no [Scaffold]/[AppBar]) so the
  /// screen can be embedded inside another view — e.g. the agent
  /// conversation screen falls back to it for a `Workflow` tool call whose
  /// inner transcript never reaches the session message stream.
  final bool embedded;

  @override
  ConsumerState<WorkflowRunScreen> createState() => _WorkflowRunScreenState();
}

class _WorkflowRunScreenState extends ConsumerState<WorkflowRunScreen> {
  StreamSubscription<String>? _sub;
  WorkflowRun? _run;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  bool _refreshing = false;
  final Set<String> _loggedFailureDetails = <String>{};
  WorkflowRun? _projectedSourceRun;
  int _projectedMessageRevision = -1;
  _WorkflowRunProjection? _projection;

  /// Same transcript-index floor as WorkflowsScreen — a live run bumps
  /// the message revision on every step event, and the index walk is
  /// O(resident transcript) (progressive-lag audit 2026-08-24).
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
    if (widget.taskData != null) {
      _run = WorkflowRun.tryFromJson(
        Map<String, dynamic>.from(widget.taskData!),
      );
      _logFailureDetails(_run);
    }
    // Show an already-cached run on first paint instead of waiting for the
    // poll/fetch to resolve — matters when embedded, where the parent view
    // has no skeleton to pass as [taskData].
    _loadFromSync();
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) => _loadFromSync());
    _updatePolling();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _loadFromSync() {
    if (!mounted) return;
    final runs = sync.workflowsForSession(widget.sessionId);
    final found = runs.where((r) => r.runId == widget.runId).firstOrNull;
    if (found != null) {
      _logFailureDetails(found);
      final next = WorkflowRun.withFallbackProgress(found, _run);
      if (next != _run) setState(() => _run = next);
      _updatePolling();
    }
  }

  void _updatePolling() {
    final run = _run;
    final shouldPoll = run == null || WorkflowStatus.isLive(run.status);
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refresh()),
    );
  }

  Future<void> _refresh() async {
    // Keep the timer armed so resume/reconnect recovers on its next tick.
    if (!mounted || !sync.canFetchWorkflowSnapshot || _refreshing) return;
    _refreshing = true;
    if (_error != null) setState(() => _error = null);
    try {
      final run = await ref
          .read(workflowsNotifierProvider.notifier)
          .fetchWorkflowSnapshot(widget.sessionId, widget.runId);
      if (run != null && mounted) {
        _logFailureDetails(run);
        final next = WorkflowRun.withFallbackProgress(run, _run);
        if (next != _run) setState(() => _run = next);
        _updatePolling();
      }
    } catch (e, st) {
      if (sync.isExpectedSocketTransportError(e)) {
        logger.info('WorkflowRunScreen refresh deferred: $e');
        return;
      }
      logger.warning('WorkflowRunScreen refresh failed: $e', e, st);
      if (mounted) {
        setState(
          () => _error = safeUiFailureMessage(
            context.l10n,
            SafeUiFailure.workflowLoad,
          ),
        );
      }
    } finally {
      _refreshing = false;
      if (mounted) {
        final transcriptChanged =
            _projectedMessageRevision !=
            sync.messagesRevision(widget.sessionId);
        if (_loading || transcriptChanged) {
          setState(() => _loading = false);
        }
      }
    }
  }

  _WorkflowRunProjection? _projectionFor(WorkflowRun? source) {
    final revision = sync.messagesRevision(widget.sessionId);
    if (source == null) {
      _projectedSourceRun = null;
      _projectedMessageRevision = revision;
      _projection = null;
      return null;
    }
    if (identical(source, _projectedSourceRun) &&
        revision == _projectedMessageRevision) {
      return _projection;
    }

    final transcriptIndex = _indexFor(revision);
    final run = WorkflowRun.enrichFromIndex(source, transcriptIndex);
    final groups = WorkflowRun.phaseGroups(
      run,
      fallbackTitle: workflowDisplayName(run),
    );
    final logs = run.workflowProgress.whereType<WorkflowLog>().toList(
      growable: false,
    );
    final stepChildren = groups.isNotEmpty
        ? const <Map<String, dynamic>>[]
        : WorkflowRun.collapseSteps(
            WorkflowRun.stepChildrenForIndex(run.runId, transcriptIndex),
          );
    final models = <String>{
      for (final group in groups)
        for (final agent in group.agents)
          if (agent.model.isNotEmpty) agent.model,
    };
    final projection = _WorkflowRunProjection(
      run: run,
      groups: groups,
      logs: logs,
      stepChildren: stepChildren,
      commonModel: models.length == 1 ? models.first : null,
    );
    _projectedSourceRun = source;
    _projectedMessageRevision = revision;
    _projection = projection;
    return projection;
  }

  void _logFailureDetails(WorkflowRun? run) {
    if (run == null) return;
    final runError = run.error?.trim();
    if (runError != null &&
        runError.isNotEmpty &&
        _loggedFailureDetails.add('run:$runError')) {
      logger.warning(
        'WorkflowRunScreen daemon-reported run failure '
        'runId=${widget.runId}',
        runError,
      );
    }
    for (final agent in run.workflowProgress.whereType<WorkflowAgent>()) {
      final error = agent.error?.trim();
      if (error == null ||
          error.isEmpty ||
          !_loggedFailureDetails.add('agent:${agent.agentId}:$error')) {
        continue;
      }
      logger.warning(
        'WorkflowRunScreen daemon-reported agent failure '
        'runId=${widget.runId} agentId=${agent.agentId}',
        error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final projection = _projectionFor(_run);
    final run = projection?.run;
    final groups = projection?.groups ?? const <WorkflowPhaseGroup>[];
    final logs = projection?.logs ?? const <WorkflowLog>[];
    // Structured snapshot empty (older CLI / workflow types that emit only
    // per-agent task_* chips, no aggregate `workflow_progress`): fall back to
    // the raw step events so the user still sees every agent step.
    final stepChildren =
        projection?.stepChildren ?? const <Map<String, dynamic>>[];
    // When every agent runs the same model, repeating it on each row is
    // noise — show it once in the stat row instead.
    final commonModel = projection?.commonModel;
    final body = _loading && run == null
        ? const Center(child: AppCircularProgressIndicator())
        : run == null
        ? _ErrorState(
            error: _error ?? context.l10n.workflowNotFoundSafe,
            onRetry: _refresh,
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: WorkflowRunHeader(
                  run: run,
                  groups: groups,
                  commonModel: commonModel,
                  showRefreshWarning: _error != null,
                  onRetry: _refresh,
                ),
              ),
              if (groups.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) => WorkflowPhaseSection(
                      group: groups[idx],
                      hideModel: commonModel != null,
                      runIsLive: WorkflowStatus.isLive(run.status),
                    ),
                    childCount: groups.length,
                  ),
                ),
              if (stepChildren.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) => _StepRow(step: stepChildren[idx]),
                    childCount: stepChildren.length,
                  ),
                ),
              if (run.error != null && run.error!.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RunTextSection(
                    title: context.l10n.workflowErrorTitle,
                    body: safeUiFailureMessage(
                      context.l10n,
                      SafeUiFailure.workflowRun,
                    ),
                    color: cs.error,
                  ),
                ),
              if (run.result != null && run.result!.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RunTextSection(title: 'Result', body: run.result!),
                ),
              if (logs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RunTextSection(
                    title: 'Logs',
                    body: logs.map((log) => log.message).join('\n'),
                    monospace: true,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: run == null
            ? Text(context.l10n.workflowTitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    workflowDisplayName(run),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    run.runId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary(theme, cs.onSurfaceVariant),
                  ),
                ],
              ),
      ),
      body: body,
    );
  }
}

class _WorkflowRunProjection {
  const _WorkflowRunProjection({
    required this.run,
    required this.groups,
    required this.logs,
    required this.stepChildren,
    this.commonModel,
  });

  final WorkflowRun run;
  final List<WorkflowPhaseGroup> groups;
  final List<WorkflowLog> logs;
  final List<Map<String, dynamic>> stepChildren;
  final String? commonModel;
}

/// A titled block of run-level text (result, error, log tail).
class _RunTextSection extends StatelessWidget {
  const _RunTextSection({
    required this.title,
    required this.body,
    this.color,
    this.monospace = false,
  });

  final String title;
  final String body;
  final Color? color;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.title(theme, color)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: SelectableText(
              body.trim(),
              style:
                  (monospace
                          ? AppText.secondary(
                              theme,
                            ).copyWith(fontFamily: 'RobotoMono')
                          : theme.textTheme.bodySmall)
                      ?.copyWith(color: color ?? cs.onSurface, height: 1.35),
            ),
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(error),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

/// A single step row in the fallback step timeline — used when a workflow run
/// carries no structured `workflowProgress` snapshot but does carry the raw
/// `task_*` progress chips / sidechain events that the chat inline view counts
/// as "N steps". Renders the step label with a status glyph so the Workflows
/// detail screen is never an empty page for a run that did real work.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = WorkflowRun.stepLabel(step);
    final state = WorkflowRun.stepState(step);
    final (icon, color) = workflowStateStyle(state, cs);
    final lastTool = WireParsers.parseString(step['subAgentLastTool']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppText.label(theme, cs.onSurface)),
          ),
          if (lastTool != null && lastTool.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              lastTool,
              style: AppText.secondary(theme, cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
