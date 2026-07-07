import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/workflow_run.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
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
  });

  /// The session the workflow belongs to.
  final String sessionId;

  /// The workflow run id.
  final String runId;

  /// Optional pre-loaded workflow data passed via route extra.
  final Map<String, dynamic>? taskData;

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
    Future<void>.microtask(_refresh);
    _sub = sync.onWorkflowsChanged
        .where((sid) => sid == widget.sessionId)
        .listen((_) => _loadFromSync());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(),
    );
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
      setState(() => _run = found);
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
        setState(() => _run = run);
      }
    } catch (e, st) {
      logger.warning(
        'WorkflowRunScreen refresh failed: $e',
        e,
        st,
      );
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final run = _run;

    return Scaffold(
      appBar: AppBar(
        title: Text(run?.workflowName ?? 'Workflow'),
      ),
      body: _loading && run == null
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
                                if (run.durationMs != null)
                                  Text(
                                    _formatDuration(run.durationMs!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            if (run.summary != null &&
                                run.summary!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                run.summary!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            _StatRow(run: run),
                          ],
                        ),
                      ),
                    ),
                    if (run.phases.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, idx) => _PhaseSection(
                            phase: run.phases[idx],
                            agents: run.workflowProgress
                                .whereType<WorkflowAgent>()
                                .where((a) => a.phaseIndex == idx)
                                .toList(),
                          ),
                          childCount: run.phases.length,
                        ),
                      ),
                    if (run.workflowProgress.any(
                      (e) => e is WorkflowLog,
                    ))
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
                              ...run.workflowProgress
                                  .whereType<WorkflowLog>()
                                  .map(
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
                ),
    );
  }

  String _formatDuration(int ms) {
    final seconds = ms ~/ 1000;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ${seconds % 60}s';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.run});

  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
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
            label: '${run.totalTokens} tokens',
          ),
        if (run.totalToolCalls != null)
          _StatChip(
            icon: Icons.build_outlined,
            label: '${run.totalToolCalls} tools',
          ),
        if (run.defaultModel != null)
          _StatChip(
            icon: Icons.model_training_outlined,
            label: run.defaultModel!,
          ),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({required this.phase, required this.agents});

  final WorkflowPhase phase;
  final List<WorkflowAgent> agents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
          Text(
            phase.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          ...agents.map((agent) => _AgentRow(agent: agent)),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final WorkflowAgent agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = _stateIcon(agent.state);
    final color = _stateColor(agent.state, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      color: cs.surfaceContainerLow,
      elevation: 0,
      child: ExpansionTile(
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
            if (agent.model.isNotEmpty)
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                agent.promptPreview!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (agent.resultPreview != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                agent.resultPreview!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          if (agent.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Error: ${agent.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.error,
                ),
              ),
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
      parts.add('${agent.tokens} tokens');
    }
    if (agent.toolCalls != null) {
      parts.add('${agent.toolCalls} tools');
    }
    return parts.join(' · ');
  }

  IconData _stateIcon(String state) {
    switch (state) {
      case 'done':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      case 'start':
        return Icons.play_circle_outline;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _stateColor(String state, ColorScheme cs) {
    switch (state) {
      case 'done':
        return Colors.green;
      case 'error':
        return cs.error;
      case 'start':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
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
