import 'package:flutter/material.dart';
import '../../markdown/markdown_view.dart';
import '../tool_section_view.dart';

/// View for displaying ExitPlanMode tool (plan proposal).
///
/// Renders the plan text as markdown inside a [ToolSectionView].
/// Permission actions (accept edits, yolo, deny) are handled by
/// the [PermissionFooter] in the parent [ToolView].
class ExitPlanToolView extends StatelessWidget {
  const ExitPlanToolView({
    required this.tool,
    super.key,
    this.metadata,
  });

  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input =
        tool['input'] as Map<String, dynamic>? ?? {};
    final plan = input['plan'] as String? ?? '';
    final displayPlan =
        plan.isEmpty ? '(no plan provided)' : plan;

    return ToolSectionView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        child: MarkdownView(markdown: displayPlan),
      ),
    );
  }
}
