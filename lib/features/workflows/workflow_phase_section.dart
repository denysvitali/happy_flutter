import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/safe_ui_messages.dart';
import '../../core/models/workflow_run.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/utils.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'workflow_display.dart';

/// A workflow phase and its expandable agent details.
class WorkflowPhaseSection extends StatelessWidget {
  const WorkflowPhaseSection({
    required this.group,
    required this.hideModel,
    required this.runIsLive,
    super.key,
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
              style: AppText.secondary(theme, cs.onSurfaceVariant),
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
                  style: AppText.title(theme),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (agentCount > 0)
                Text(
                  '$agentCount ${agentCount == 1 ? 'agent' : 'agents'}',
                  style: AppText.secondary(theme, cs.onSurfaceVariant),
                ),
            ],
          ),
          if (group.phase.detail != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.only(left: 16 + AppSpacing.sm),
              child: Text(
                group.phase.detail!,
                style: AppText.secondary(theme, cs.onSurfaceVariant),
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
              child: AppCircularProgressIndicator(
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
        style: AppText.secondary(
          theme,
          cs.onSurfaceVariant,
        ).copyWith(fontStyle: FontStyle.italic),
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
                style: AppText.secondary(theme, cs.onSurfaceVariant),
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
    final tokens = agent.tokens;
    if (tokens != null && tokens > 0) {
      parts.add('${formatWorkflowCount(tokens)} tokens');
    }
    final toolCalls = agent.toolCalls;
    if (toolCalls != null && toolCalls > 0) {
      parts.add('${formatWorkflowCount(toolCalls)} tools');
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
          Text(stats, style: AppText.secondary(theme, cs.onSurfaceVariant)),
        if (toolLine != null)
          Row(
            children: [
              Icon(
                Icons.build_outlined,
                size: AppIconSize.xs,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  toolLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.secondary(theme, cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _AgentDetailBlock extends StatefulWidget {
  const _AgentDetailBlock({
    required this.label,
    required this.text,
    this.color,
  });

  final String label;
  final String text;
  final Color? color;

  static const int collapsedMaxLines = 8;

  @override
  State<_AgentDetailBlock> createState() => _AgentDetailBlockState();
}

class _AgentDetailBlockState extends State<_AgentDetailBlock> {
  bool _expanded = false;

  bool _exceeds(String text, TextStyle? style, double maxWidth) {
    if (!maxWidth.isFinite) {
      return '\n'.allMatches(text).length + 1 >
          _AgentDetailBlock.collapsedMaxLines;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _AgentDetailBlock.collapsedMaxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bodyStyle = AppText.secondary(
      theme,
      widget.color ?? cs.onSurfaceVariant,
    );
    final trimmed = widget.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: AppText.label(theme, cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xxs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final overflows = _exceeds(
                  trimmed,
                  bodyStyle,
                  constraints.maxWidth,
                );
                final body = SelectableText(
                  trimmed,
                  maxLines: _expanded || !overflows
                      ? null
                      : _AgentDetailBlock.collapsedMaxLines,
                  style: bodyStyle,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_expanded && overflows)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(child: body),
                      )
                    else
                      body,
                    if (overflows)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(
                              AppTouchTarget.min,
                              AppTouchTarget.min,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _expanded
                                ? context.l10n.toolOutputShowLess
                                : context.l10n.toolOutputShowMore,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
