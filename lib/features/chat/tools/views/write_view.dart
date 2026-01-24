import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'edit_view.dart';

/// View for displaying Write tool content.
class WriteView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const WriteView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final content = input['content'] as String? ?? '<no contents>';

    return ToolSectionView(
      child: DiffView(
        oldText: '',
        newText: content,
        showLineNumbers: false,
        showPlusMinus: false,
      ),
    );
  }
}
