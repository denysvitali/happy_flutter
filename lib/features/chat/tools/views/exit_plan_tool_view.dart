import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying ExitPlanMode tool (proposal summary).
class ExitPlanToolView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const ExitPlanToolView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final plan = input['plan'] as String? ?? '<empty>';

    return ToolSectionView(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Text(plan, style: const TextStyle(fontSize: 14, height: 1.5)),
      ),
    );
  }
}
