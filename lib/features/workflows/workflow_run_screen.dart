import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/wire_parsers.dart';
import 'workflow_display.dart';
import 'workflow_status_badge.dart';
import '../../core/utils/utils.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.taskData != null) {
      _run = WorkflowRun.tryFromJson(
        Map<String, dynamic>.from(widget.taskData!),
      );
    }
    // Show an already-cached run on first paint instead of waiting for the
    // poll/fetch to resolve — matters when embedded, where the parent view
    // has no skeleton to pass as [taskData].
    _loadFromSync();
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) => _loadFromSync());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
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
      setState(
        () => _run = WorkflowRun.withFallbackProgress(found, _run),
      );
    }
  }

  Future<void> _refresh() async {
    if (!sync.isInitialized) return;
    setState(() => _error = null);
    try {
      final run = await ref
          .read(workflowsNotifierProvider.notifier)
          .fetchWorkflowSnapshot(widget.sessionId, widget.runId);
      if (run != null && mounted) {
        setState(
          () => _run = WorkflowRun.withFallbackProgress(run, _run),
        );
      }
    } catch (e, st) {
      logger.warning('WorkflowRunScreen refresh failed: $e', e, st);
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rawRun = _run;
    final messages = sync.messagesForSession(widget.sessionId);
    final run = rawRun == null
        ? null
        : WorkflowRun.enrichFromMessages(rawRun, messages);
    final groups = run == null ? const <_PhaseGroup>[] : _phaseGroups(run);
    final logs = run == null
        ? const <WorkflowLog>[]
        : run.workflowProgress.whereType<WorkflowLog>().toList(growable: false);
    // Structured snapshot empty (older CLI / workflow types that emit only
    // per-agent task_* chips, no aggregate `workflow_progress`): fall back to
    // the raw step events so the user still sees every agent step.
    final stepChildren = (run == null || groups.isNotEmpty)
        ? const <Map<String, dynamic>>[]
        : WorkflowRun.collapseSteps(
            WorkflowRun.stepChildrenForRun(widget.runId, messages),
          );
    // When every agent runs the same model, repeating it on each row is
    // noise — show it once in the stat row instead.
    final models = <String>{
      for (final group in groups)
        for (final agent in group.agents)
          if (agent.model.isNotEmpty) agent.model,
    };
    final commonModel = models.length == 1 ? models.first : null;
    final elapsedMs = run == null ? null : _elapsedMs(run);

    final body = _loading && run == null
        ? const Center(child: CircularProgressIndicator())
        : run == null
        ? _ErrorState(
            error: _error ?? 'Workflow not found',
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
                            if (elapsedMs != null)
                              Text(
                                formatDuration(Duration(milliseconds: elapsedMs)),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (run.summary != null && run.summary!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(run.summary!, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _StatRow(run: run, modelFallback: commonModel),
                      ],
                    ),
                  ),
                ),
                if (groups.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) => _PhaseSection(
                        phase: groups[idx].phase,
                        agents: groups[idx].agents,
                        state: groups[idx].state,
                        hideModel: commonModel != null,
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
                if (logs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logs',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...logs.map(
                            (log) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                log.message,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: run == null
            ? const Text('Workflow')
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

  /// Live elapsed time while the run is still going; the daemon only sets
  /// `durationMs` once the run finishes.
  int? _elapsedMs(WorkflowRun run) {
    if (run.durationMs != null) return run.durationMs;
    final start = run.startTime;
    if (!WorkflowStatus.isLive(run.status) ||
        run.status == WorkflowStatus.paused ||
        start == null) {
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > start ? now - start : 0;
  }


  /// Groups agents under their phases for the detail view.
  ///
  /// Matches agents to phases by the explicit phase index (the same rule
  /// the chat inline view uses) because the wire indices may be 0- or
  /// 1-based — matching by list position would misplace every agent when
  /// the run uses 1-based indices. Agents whose phase index matches no
  /// phase event fall into a trailing bucket so they are never dropped.
  ///
  /// Phase events are deduped by index (last wins) so a phase emitting
  /// both a start and a done event renders one section, not two.
  List<_PhaseGroup> _phaseGroups(WorkflowRun run) {
    final progress = run.workflowProgress;
    final agents = progress.whereType<WorkflowAgent>().toList(growable: false);
    final byIndex = <int, WorkflowPhaseEvent>{};
    for (final event in progress.whereType<WorkflowPhaseEvent>()) {
      byIndex[event.index] = event;
    }
    final phaseEvents = byIndex.values.toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
    if (phaseEvents.isNotEmpty) {
      final matched = <String>{};
      final groups = <_PhaseGroup>[];
      for (final event in phaseEvents) {
        final phaseAgents = agents
            .where((a) => a.phaseIndex == event.index)
            .toList(growable: false);
        for (final agent in phaseAgents) {
          matched.add(agent.agentId);
        }
        groups.add(
          _PhaseGroup(
            WorkflowPhase(title: event.title),
            phaseAgents,
            _phaseState(event.kind, phaseAgents),
          ),
        );
      }
      final leftover = agents
          .where((a) => !matched.contains(a.agentId))
          .toList(growable: false);
      if (leftover.isNotEmpty) {
        groups.add(
          _PhaseGroup(
            WorkflowPhase(title: run.workflowName),
            leftover,
            _phaseState('start', leftover),
          ),
        );
      }
      return groups;
    }
    if (run.phases.isNotEmpty) {
      final groups = <_PhaseGroup>[];
      for (var i = 0; i < run.phases.length; i++) {
        final phaseAgents = agents
            .where((a) => a.phaseIndex == i)
            .toList(growable: false);
        groups.add(
          _PhaseGroup(
            run.phases[i],
            phaseAgents,
            _phaseState('start', phaseAgents),
          ),
        );
      }
      return groups;
    }
    if (agents.isNotEmpty) {
      return <_PhaseGroup>[
        _PhaseGroup(
          WorkflowPhase(title: run.workflowName),
          agents,
          _phaseState('start', agents),
        ),
      ];
    }
    return const <_PhaseGroup>[];
  }

  /// Derives a display state for a phase: `done` when the phase reported
  /// completion or every agent finished, `active` when it has agents in
  /// flight, and `pending` when nothing has reached it yet — a phase with
  /// no agents must never look like missing content.
  String _phaseState(String kind, List<WorkflowAgent> agents) {
    if (kind == 'done' || kind == 'completed') return 'done';
    if (agents.isEmpty) return 'pending';
    final finished = agents.every(
      (a) => a.state == 'done' || a.state == 'completed',
    );
    return finished ? 'done' : 'active';
  }
}

class _PhaseGroup {
  const _PhaseGroup(this.phase, this.agents, this.state);

  final WorkflowPhase phase;
  final List<WorkflowAgent> agents;

  /// One of `done`, `active`, `pending`.
  final String state;
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
            label: '${run.agentCount} agents',
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

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.phase,
    required this.agents,
    required this.state,
    required this.hideModel,
  });

  final WorkflowPhase phase;
  final List<WorkflowAgent> agents;

  /// One of `done`, `active`, `pending`.
  final String state;

  /// Suppress the per-agent model label (shown once in the stat row).
  final bool hideModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pending = state == 'pending';

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
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  phase.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: pending ? cs.onSurfaceVariant : null,
                  ),
                ),
              ),
            ],
          ),
          if (phase.detail != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              phase.detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (agents.isEmpty)
            _PhasePlaceholder(state: state)
          else
            ...agents.map(
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
      case 'done':
        return const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: AppColors.success,
        );
      case 'active':
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        );
      default:
        return Icon(
          Icons.circle_outlined,
          size: 16,
          color: cs.onSurfaceVariant,
        );
    }
  }
}

/// Stand-in row for a phase that has no agents yet, so pending phases
/// read as "not started" instead of missing content.
class _PhasePlaceholder extends StatelessWidget {
  const _PhasePlaceholder({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = switch (state) {
      'done' => 'Completed',
      'active' => 'Starting…',
      _ => 'Pending',
    };
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg + AppSpacing.xs,
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
        subtitle: agent.durationMs != null || agent.tokens != null
            ? Text(
                _agentStats(agent),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              )
            : null,
        children: [
          if (agent.promptPreview != null)
            _AgentDetailBlock(label: 'Prompt', text: agent.promptPreview!),
          if (agent.resultPreview != null)
            _AgentDetailBlock(label: 'Result', text: agent.resultPreview!),
          if (agent.error != null)
            _AgentDetailBlock(
              label: 'Error',
              text: agent.error!,
              color: cs.error,
            ),
        ],
      ),
    );
  }

  String _agentStats(WorkflowAgent agent) {
    final parts = <String>[];
    if (agent.durationMs != null) {
      parts.add('${agent.durationMs! ~/ 1000}s');
    }
    if (agent.tokens != null) {
      parts.add('${formatWorkflowCount(agent.tokens!)} tokens');
    }
    if (agent.toolCalls != null) {
      parts.add('${formatWorkflowCount(agent.toolCalls!)} tools');
    }
    return parts.join(' · ');
  }

  /// Mirrors the chat inline view: the wire sends `running` / `progress`
  /// for live agents, so without those cases every in-flight agent would
  /// fall into the "waiting" hourglass.
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
          Text(
            text,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color ?? cs.onSurfaceVariant,
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
            label: const Text('Retry'),
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
