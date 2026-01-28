import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying Gemini execute tool (lowercase 'execute').
class GeminiExecuteView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const GeminiExecuteView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    // Gemini sends nice title in toolCall.title
    final toolCall = input['toolCall'] as Map<String, dynamic>?;
    final title = toolCall?['title'] as String?;

    // Extract command and description
    String? command;
    String? description;

    if (title != null) {
      // Title is like "rm file.txt [cwd /path] (description)"
      // Extract just the command part before [
      final bracketIdx = title.indexOf(' [');
      if (bracketIdx > 0) {
        command = title.substring(0, bracketIdx);
      } else {
        command = title;
      }

      // Extract description from parentheses at the end
      final parenMatch = RegExp(r'\(([^)]+)\)$').firstMatch(title);
      if (parenMatch != null) {
        description = parenMatch.group(1);
      }
    }

    // Try to get command from other fields
    if (command == null) {
      final commandList = input['command'] as List?;
      if (commandList != null && commandList.isNotEmpty) {
        command = commandList.join(' ');
      }
    }

    // Extract CWD
    String? cwd;
    if (title != null) {
      final cwdMatch = RegExp(r'\[cwd ([^\]]+)\]').firstMatch(title);
      if (cwdMatch != null) {
        cwd = cwdMatch.group(1);
      }
    }
    if (cwd == null) {
      cwd = input['cwd'] as String?;
    }

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Command display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.terminal,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    command ?? 'Unknown command',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Description if available
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // CWD if available
          if (cwd != null && cwd.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Working directory: $cwd',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          // Error display
          if (state == 'error' && result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
