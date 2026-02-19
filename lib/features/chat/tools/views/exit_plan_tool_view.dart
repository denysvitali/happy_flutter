import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying ExitPlanMode tool (proposal summary).
class ExitPlanToolView extends StatelessWidget {
  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  const ExitPlanToolView({
    super.key,
    required this.tool,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final input =
        tool['input'] as Map<String, dynamic>? ?? {};
    final plan = input['plan'] as String? ?? '';
    final state = tool['state'] as String? ?? 'running';
    final isCompleted = state == 'completed';

    return ToolSectionView(
      child: _PlanCard(
        plan: plan,
        isCompleted: isCompleted,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String plan;
  final bool isCompleted;

  const _PlanCard({
    required this.plan,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use a warm amber/orange accent for plan cards
    // to signal an important decision.
    final accentColor = isCompleted
        ? colorScheme.tertiary
        : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withAlpha(100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, accentColor),
          _buildBody(context, accentColor),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(16),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(13),
        ),
        border: Border(
          bottom: BorderSide(
            color: accentColor.withAlpha(50),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withAlpha(70),
                width: 1,
              ),
            ),
            child: Icon(
              isCompleted
                  ? Icons.assignment_turned_in_rounded
                  : Icons.assignment_rounded,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCompleted
                      ? 'Plan ready'
                      : 'Exit plan mode',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  isCompleted
                      ? 'Review the plan below'
                      : 'Proposed execution plan',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(
                    color: accentColor.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withAlpha(70),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  size: 10,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isCompleted ? 'DONE' : 'PLAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final displayPlan =
        plan.isEmpty ? '(no plan provided)' : plan;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative left border accent block
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: accentColor.withAlpha(140),
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 15,
                  color: accentColor.withAlpha(180),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayPlan,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      height: 1.6,
                      color:
                          theme.colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
