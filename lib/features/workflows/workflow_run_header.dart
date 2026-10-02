import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/workflow_run.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/utils.dart';
import '../../core/widgets/app_linear_progress_indicator.dart';
import 'workflow_display.dart';
import 'workflow_status_badge.dart';

/// Run status, elapsed time, summary, statistics, and phase progress.
///
/// Refresh and workflow projection remain owned by the parent screen. The
/// elapsed-time widget owns its timer so each tick rebuilds only its label.
class WorkflowRunHeader extends StatelessWidget {
  const WorkflowRunHeader({
    required this.run,
    required this.groups,
    required this.onRetry,
    this.commonModel,
    this.showRefreshWarning = false,
    super.key,
  });

  final WorkflowRun run;
  final List<WorkflowPhaseGroup> groups;
  final Future<void> Function() onRetry;
  final String? commonModel;
  final bool showRefreshWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
          if (showRefreshWarning) ...[
            const SizedBox(height: AppSpacing.sm),
            _WorkflowRefreshWarning(onRetry: onRetry),
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
    );
  }
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
      style: AppText.secondary(
        Theme.of(context),
        Theme.of(context).colorScheme.onSurfaceVariant,
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
        if (run.totalTokens != null && run.totalTokens! > 0)
          _StatChip(
            icon: Icons.token_outlined,
            label: '${formatWorkflowCount(run.totalTokens!)} tokens',
          ),
        if (run.totalToolCalls != null && run.totalToolCalls! > 0)
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
          style: AppText.secondary(Theme.of(context), cs.onSurfaceVariant),
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
    // Credit the live phase so "Phase 1 of 2" is not an empty bar. Completed
    // phases count fully; the active one counts as in-progress, not done.
    final inFlight = activeIdx >= 0 ? 0.45 : 0.0;
    final fraction = groups.isEmpty
        ? 0.0
        : ((done + inFlight) / groups.length).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          value: '${(fraction * 100).round()} percent',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: AppLinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppText.secondary(theme, cs.onSurfaceVariant)),
      ],
    );
  }
}
