import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/safe_ui_messages.dart';
import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/utils.dart';
import '../../core/wire/wire_parsers.dart';
import 'workflow_display.dart';
import 'workflow_status_badge.dart';

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
    if (!sync.isInitialized || _refreshing) return;
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

    final transcriptIndex = WorkflowTranscriptIndex.fromMessages(
      sync.messagesForSession(widget.sessionId),
    );
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
        ? const Center(child: CircularProgressIndicator())
        : run == null
        ? _ErrorState(
            error: _error ?? context.l10n.workflowNotFoundSafe,
            onRetry: _refresh,
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WorkflowStatusBadge(status: run.status),
                          const SizedBox(width: AppSpacing.sm),
                          _WorkflowElapsedTime(run: run),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _WorkflowRefreshWarning(onRetry: _refresh),
                      ],
                      if (run.summary != null && run.summary!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(run.summary!, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _StatRow(run: run, modelFallback: commonModel),
                      if (groups.length > 1) ...[
                        const SizedBox(height: AppSpacing.md),
                        _PhaseProgress(groups: groups),
                      ],
                    ],
                  ),
                ),
              ),
              if (groups.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) => _PhaseSection(
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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

/// Keeps the one-second elapsed-time invalidation local to the timestamp.
///
/// Workflow projections can be large, so the parent screen only rebuilds
/// when workflow data changes or a refresh completes.
class _WorkflowElapsedTime extends StatefulWidget {
  const _WorkflowElapsedTime({required this.run});

  final WorkflowRun run;

  @override
  State<_WorkflowElapsedTime> createState() => _WorkflowElapsedTimeState();
}

class _WorkflowElapsedTimeState extends State<_WorkflowElapsedTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTimer();
  }

  @override
  void didUpdateWidget(covariant _WorkflowElapsedTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run.status != widget.run.status ||
        oldWidget.run.startTime != widget.run.startTime ||
        oldWidget.run.durationMs != widget.run.durationMs) {
      _updateTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimer() {
    _timer?.cancel();
    _timer = null;
    if (_isTicking(widget.run)) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  bool _isTicking(WorkflowRun run) =>
      WorkflowStatus.isLive(run.status) &&
      run.status != WorkflowStatus.paused &&
      run.startTime != null &&
      run.durationMs == null;

  int? _elapsedMs(WorkflowRun run) {
    if (run.durationMs != null) return run.durationMs;
    final start = run.startTime;
    if (!_isTicking(run) || start == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > start ? now - start : 0;
  }

  @override
  Widget build(BuildContext context) {
    final elapsedMs = _elapsedMs(widget.run);
    if (elapsedMs == null) return const SizedBox.shrink();
    return Text(
      formatDuration(Duration(milliseconds: elapsedMs)),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _WorkflowRefreshWarning extends StatelessWidget {
  const _WorkflowRefreshWarning({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: cs.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.workflowRefreshWarning,
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.run, this.modelFallback});

  final WorkflowRun run;

  /// Model to display when the run itself does not report one but every
  /// agent shares the same model.
  final String? modelFallback;

  @override
  Widget build(BuildContext context) {
    final model = run.defaultModel ?? modelFallback;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        if (run.agentCount != null)
          _StatChip(
            icon: Icons.smart_toy_outlined,
            label:
                '${run.agentCount} '
                '${run.agentCount == 1 ? 'agent' : 'agents'}',
          ),
        if (run.totalTokens != null)
          _StatChip(
            icon: Icons.token_outlined,
            label: '${formatWorkflowCount(run.totalTokens!)} tokens',
          ),
        if (run.totalToolCalls != null)
          _StatChip(
            icon: Icons.build_outlined,
            label: '${formatWorkflowCount(run.totalToolCalls!)} tools',
          ),
        if (model != null && model.isNotEmpty)
          _StatChip(icon: Icons.model_training_outlined, label: model),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Compact per-phase progress bar and "Phase N of M" label for the header.
class _PhaseProgress extends StatelessWidget {
  const _PhaseProgress({required this.groups});

  final List<WorkflowPhaseGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final done = groups.where((g) => g.state == WorkflowPhaseState.done).length;
    final activeIdx = groups.indexWhere(
      (g) => g.state == WorkflowPhaseState.active,
    );
    // The phase the user should be looking at: the running one, else how far
    // the run got before it stopped.
    final current = activeIdx >= 0 ? activeIdx + 1 : done;
    final label = current == 0
        ? '${groups.length} phases'
        : 'Phase $current of ${groups.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(
            value: groups.isEmpty ? 0 : done / groups.length,
            minHeight: 4,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.group,
    required this.hideModel,
    required this.runIsLive,
  });

  final WorkflowPhaseGroup group;

  /// Suppress the per-agent model label (shown once in the stat row).
  final bool hideModel;

  /// A phase with no agents reads as "Pending" on a live run but "Skipped"
  /// once the run is over — otherwise a finished run looks stuck.
  final bool runIsLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = group.state;
    final pending = state == WorkflowPhaseState.pending;

    // A phase nothing has reached yet is one compact row: a bold heading plus
    // an italic "Pending" line for each is a screen of empty scaffolding.
    if (pending && group.agents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            _PhaseStateIcon(state: state),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                group.phase.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              runIsLive ? 'Pending' : 'Skipped',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final agentCount = group.agents.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PhaseStateIcon(state: state),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  group.phase.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (agentCount > 0)
                Text(
                  '$agentCount ${agentCount == 1 ? 'agent' : 'agents'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (group.phase.detail != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.only(left: 16 + AppSpacing.sm),
              child: Text(
                group.phase.detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (group.agents.isEmpty)
            _PhasePlaceholder(state: state)
          else
            ...group.agents.map(
              (agent) => _AgentRow(agent: agent, hideModel: hideModel),
            ),
        ],
      ),
    );
  }
}

class _PhaseStateIcon extends StatelessWidget {
  const _PhaseStateIcon({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (state) {
      case WorkflowPhaseState.done:
        return const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: AppColors.success,
        );
      case WorkflowPhaseState.failed:
        return Icon(Icons.error_outline_rounded, size: 16, color: cs.error);
      case WorkflowPhaseState.active:
        // Boxed at the icon size so the spinner shares the baseline and
        // metrics of the other state glyphs instead of reading as a stray
        // speck next to the phase title.
        return SizedBox(
          width: 16,
          height: 16,
          child: Center(
            child: SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ),
        );
      default:
        return Icon(Icons.radio_button_unchecked, size: 16, color: cs.outline);
    }
  }
}

/// Stand-in row for a phase that has agents pending or reported completion
/// without agents, so a phase never looks like missing content.
class _PhasePlaceholder extends StatelessWidget {
  const _PhasePlaceholder({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = switch (state) {
      WorkflowPhaseState.done => 'Completed',
      WorkflowPhaseState.failed => 'Failed',
      WorkflowPhaseState.active => 'Starting…',
      _ => 'Pending',
    };
    return Padding(
      padding: const EdgeInsets.only(
        left: 16 + AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Left offset that aligns expanded content with the agent label:
/// tile padding (md) + state icon (16) + icon gap (sm).
const double _kChildIndent = AppSpacing.md + 16 + AppSpacing.sm;

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent, required this.hideModel});

  final WorkflowAgent agent;

  /// Suppress the model label when every agent shares one model.
  final bool hideModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, color) = workflowStateStyle(
      agent.state,
      cs,
      pendingIcon: Icons.hourglass_empty_rounded,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      color: cs.surfaceContainerLow,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          _kChildIndent,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.topLeft,
        title: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                agent.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!hideModel && agent.model.isNotEmpty)
              Text(
                agent.model,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        subtitle: _AgentSubtitle(agent: agent, stats: _agentStats(agent)),
        children: [
          if (agent.promptPreview != null)
            _AgentDetailBlock(label: 'Prompt', text: agent.promptPreview!),
          if (agent.resultPreview != null)
            _AgentDetailBlock(label: 'Result', text: agent.resultPreview!),
          if (agent.error != null)
            _AgentDetailBlock(
              label: context.l10n.workflowErrorTitle,
              text: safeUiFailureMessage(
                context.l10n,
                SafeUiFailure.workflowAgent,
              ),
              color: cs.error,
            ),
        ],
      ),
    );
  }

  String _agentStats(WorkflowAgent agent) {
    final parts = <String>[];
    if (agent.durationMs != null) {
      parts.add(formatDuration(Duration(milliseconds: agent.durationMs!)));
    }
    if (agent.tokens != null) {
      parts.add('${formatWorkflowCount(agent.tokens!)} tokens');
    }
    if (agent.toolCalls != null) {
      parts.add('${formatWorkflowCount(agent.toolCalls!)} tools');
    }
    return parts.join(' · ');
  }
}

/// Agent subtitle: the run stats plus, while the agent is live, the tool it is
/// working in right now — the difference between "something is happening" and
/// a row that looks frozen.
class _AgentSubtitle extends StatelessWidget {
  const _AgentSubtitle({required this.agent, required this.stats});

  final WorkflowAgent agent;
  final String stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tool = agent.lastToolName;
    final summary = agent.lastToolSummary;
    final toolLine = tool == null || tool.isEmpty
        ? null
        : (summary == null || summary.isEmpty ? tool : '$tool · $summary');
    if (stats.isEmpty && toolLine == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats.isNotEmpty)
          Text(
            stats,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        if (toolLine != null)
          Row(
            children: [
              Icon(Icons.build_outlined, size: 11, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  toolLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _AgentDetailBlock extends StatelessWidget {
  const _AgentDetailBlock({
    required this.label,
    required this.text,
    this.color,
  });

  final String label;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              text.trim(),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color ?? cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
                          ? theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'RobotoMono',
                            )
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
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (lastTool != null && lastTool.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              lastTool,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
