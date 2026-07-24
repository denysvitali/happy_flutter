import 'package:flutter/material.dart';

import '../../../../core/models/workflow_run.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/wire_parsers.dart';
import '../../../workflows/workflow_display.dart';

/// Compact inline progress for a Claude Code dynamic workflow.
///
/// Renders the latest phase/agent snapshot carried on task_progress
/// sidechain events. Phases are shown as a vertical stepper, current
/// agents are listed with status, and the most recent log line is
/// surfaced so the user sees live progress instead of radio silence.
class WorkflowInlineView extends StatelessWidget {
  /// Creates a [WorkflowInlineView].
  const WorkflowInlineView({
    required this.children,
    super.key,
  });

  /// Sidechain children of the Workflow tool-call, including agent-event
  /// messages with `workflowProgress` snapshots.
  final List<dynamic>? children;

  @override
  Widget build(BuildContext context) {
    final progress = _latestProgress();
    if (progress.isEmpty) {
      // No aggregate `workflow_progress` snapshot (older CLI / workflow types
      // that emit only per-agent task_* chips): surface the raw step events so
      // the expanded card shows the same "N steps" the header promises.
      return _buildStepsFallback(
        context,
        WireParsers.asList(children) ?? const <dynamic>[],
      );
    }

    final phases = _extractPhases(progress);
    final agents = _extractAgents(progress);
    final logs = _extractLogs(progress);
    final currentPhaseIndex = _currentPhaseIndex(phases, agents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phases.isNotEmpty) ...[
          _PhaseStepper(
            phases: phases,
            currentIndex: currentPhaseIndex,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (agents.isNotEmpty)
          ...agents.map((agent) => _AgentStatusRow(agent: agent)),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xsm),
          _LogPreview(log: logs.last.message),
        ],
      ],
    );
  }

  Widget _buildStepsFallback(BuildContext context, List<dynamic> raw) {
    final steps = WorkflowRun.collapseSteps(
      raw.whereType<Map<String, dynamic>>().toList(growable: false),
    );
    if (steps.isEmpty) return const SizedBox.shrink();
    const maxRows = 4;
    final shown = steps.length > maxRows
        ? steps.sublist(steps.length - maxRows)
        : steps;
    final extra = steps.length - shown.length;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in shown) _InlineStepRow(step: step),
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: AppSpacing.xxs),
            child: Text(
              '+ $extra more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  List<WorkflowProgressEvent> _latestProgress() {
    final messages = WireParsers.asList(children);
    if (messages == null) return const [];

    // Walk children in reverse: the most recent task_progress event
    // carries the complete workflow snapshot.
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg is! Map<String, dynamic>) continue;
      final list = WorkflowRun.rawWorkflowProgress(msg);
      if (list == null || list.isEmpty) continue;
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(WorkflowProgressEvent.tryFromJson)
          .whereType<WorkflowProgressEvent>()
          .toList(growable: false);
      if (parsed.isNotEmpty) return parsed;
    }
    return const [];
  }

  List<WorkflowPhaseEvent> _extractPhases(
    List<WorkflowProgressEvent> progress,
  ) {
    return progress.whereType<WorkflowPhaseEvent>().toList(growable: false);
  }

  List<WorkflowAgent> _extractAgents(
    List<WorkflowProgressEvent> progress,
  ) {
    return progress.whereType<WorkflowAgent>().toList(growable: false);
  }

  List<WorkflowLog> _extractLogs(List<WorkflowProgressEvent> progress) {
    return progress.whereType<WorkflowLog>().toList(growable: false);
  }

  int _currentPhaseIndex(
    List<WorkflowPhaseEvent> phases,
    List<WorkflowAgent> agents,
  ) {
    if (phases.isEmpty) return -1;

    // Prefer matching against each phase's explicit `index` field, so the
    // result is correct whether the wire uses 0-based or 1-based indices.
    var matchedPosition = -1;
    for (final agent in agents) {
      for (var i = 0; i < phases.length; i++) {
        if (phases[i].index == agent.phaseIndex) {
          if (i > matchedPosition) matchedPosition = i;
        }
      }
    }
    if (matchedPosition >= 0) return matchedPosition;

    // Fallback: assume phaseIndex maps directly to the phase list position.
    var maxIndex = -1;
    for (final agent in agents) {
      if (agent.phaseIndex > maxIndex) maxIndex = agent.phaseIndex;
    }
    if (maxIndex < 0) return 0;
    return maxIndex.clamp(0, phases.length - 1);
  }
}

// ---------------------------------------------------------------------------
// Phase stepper
// ---------------------------------------------------------------------------

class _PhaseStepper extends StatelessWidget {
  const _PhaseStepper({
    required this.phases,
    required this.currentIndex,
  });

  final List<WorkflowPhaseEvent> phases;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < phases.length; i++) ...[
          _PhaseDot(
            phase: phases[i],
            isCurrent: i == currentIndex,
            isCompleted: i < currentIndex,
          ),
          if (i < phases.length - 1)
            Container(
              width: 12,
              height: 1,
              color: cs.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({
    required this.phase,
    required this.isCurrent,
    required this.isCompleted,
  });

  final WorkflowPhaseEvent phase;
  final bool isCurrent;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color bg;
    final Color fg;
    if (isCurrent) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
    } else if (isCompleted) {
      bg = AppColors.success.withValues(alpha: 0.15);
      fg = AppColors.success;
    } else {
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xsm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            Icon(Icons.check_rounded, size: 10, color: fg)
          else if (isCurrent)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          else
            Icon(Icons.circle_outlined, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            phase.title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent status row
// ---------------------------------------------------------------------------

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({required this.agent});

  final WorkflowAgent agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = agent.label;
    final phaseTitle = agent.phaseTitle;
    final model = agent.model;

    final (icon, color) = workflowStateStyle(
      agent.state,
      cs,
      pendingIcon: Icons.hourglass_empty_rounded,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            flex: 3,
            child: Text(
              phaseTitle.isNotEmpty ? '$phaseTitle · $label' : label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (model.isNotEmpty)
            Flexible(
              flex: 1,
              child: Text(
                model,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (agent.toolCalls != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _MiniStat(icon: Icons.build_outlined, value: '${agent.toolCalls}'),
          ],
          if (agent.tokens != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _MiniStat(icon: Icons.token_outlined, value: '${agent.tokens}'),
          ],
        ],
      ),
    );
  }

}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: cs.onSurfaceVariant),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFontSize.xxs,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Log preview
// ---------------------------------------------------------------------------

class _LogPreview extends StatelessWidget {
  const _LogPreview({required this.log});

  final String log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 24, top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notes_rounded,
            size: 12,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              log,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


/// Compact step row for the inline fallback (raw `task_*` chips / sidechain
/// events when no `workflowProgress` snapshot is present).
class _InlineStepRow extends StatelessWidget {
  const _InlineStepRow({required this.step});

  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = WorkflowRun.stepLabel(step);
    final state = WorkflowRun.stepState(step);
    final (icon, color) = workflowStateStyle(state, cs);
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

}
