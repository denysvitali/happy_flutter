import 'package:flutter/material.dart';
import '../../markdown/markdown_view.dart';
import '../tool_section_view.dart';

/// View for displaying ExitPlanMode tool (proposal summary).
class ExitPlanToolView extends StatelessWidget {

  const ExitPlanToolView({
    required this.tool, super.key,
    this.metadata,
    this.onAccept,
    this.onDiscard,
    this.onProposeChanges,
  });
  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// Called when the user accepts the plan.
  ///
  /// Receives either `'acceptEdits'` (Write mode) or
  /// `'bypassPermissions'` (Yolo mode).
  final void Function(String permissionMode)? onAccept;

  /// Called when the user discards the plan.
  final VoidCallback? onDiscard;

  /// Called when the user wants to propose changes.
  final VoidCallback? onProposeChanges;

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
        onAccept: onAccept,
        onDiscard: onDiscard,
        onProposeChanges: onProposeChanges,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {

  const _PlanCard({
    required this.plan,
    required this.isCompleted,
    this.onAccept,
    this.onDiscard,
    this.onProposeChanges,
  });
  final String plan;
  final bool isCompleted;
  final void Function(String permissionMode)? onAccept;
  final VoidCallback? onDiscard;
  final VoidCallback? onProposeChanges;

  bool get _hasActions =>
      onAccept != null ||
      onDiscard != null ||
      onProposeChanges != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          if (isCompleted && _hasActions)
            _buildActions(context, accentColor),
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
        horizontal: 12,
        vertical: 8,
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
    final displayPlan =
        plan.isEmpty ? '(no plan provided)' : plan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative left border accent block
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
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
                  child: MarkdownView(
                    markdown: displayPlan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            color: accentColor.withAlpha(50),
            height: 20,
            thickness: 1,
          ),
          Row(
            children: [
              if (onAccept != null) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _showAcceptSheet(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor:
                          theme.colorScheme.onTertiary,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Accept',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (onDiscard != null) ...[
                OutlinedButton(
                  onPressed: onDiscard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(
                      color: accentColor.withAlpha(120),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (onProposeChanges != null)
                TextButton(
                  onPressed: onProposeChanges,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        accentColor.withAlpha(200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Suggest changes',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAcceptSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.tertiary;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20, 16, 20, 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin:
                        const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius:
                          BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Choose execution mode',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'How should the plan be executed?',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _ModeButton(
                  icon: Icons.edit_rounded,
                  label: 'Write mode',
                  description:
                      'Approve each file change',
                  accentColor: accentColor,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAccept?.call('acceptEdits');
                  },
                ),
                const SizedBox(height: 10),
                _ModeButton(
                  icon: Icons.bolt_rounded,
                  label: 'Yolo mode',
                  description:
                      'Run without permission prompts',
                  accentColor: colorScheme.error,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onAccept?.call('bypassPermissions');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A styled button used in the accept mode bottom sheet.
class _ModeButton extends StatelessWidget {

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: accentColor.withAlpha(160),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
