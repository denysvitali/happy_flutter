import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// View for displaying CodexBash tool (parsed bash commands).
class CodexBashView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const CodexBashView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final command = input['command'] as List?;
    final cwd = input['cwd'] as String?;
    final parsedCmd = input['parsed_cmd'] as List?;

    // Determine operation type from parsed_cmd
    String operationType = 'bash';
    String? fileName;
    String? commandStr;

    if (parsedCmd != null && parsedCmd is List && parsedCmd.isNotEmpty) {
      final firstCmd = parsedCmd[0] as Map<String, dynamic>?;
      if (firstCmd != null) {
        operationType = firstCmd['type'] as String? ?? 'bash';
        fileName = firstCmd['name'] as String?;
        commandStr = firstCmd['cmd'] as String?;
      }
    }

    // Get display command
    final displayCommand = commandStr ??
        (command != null && command is List && command.isNotEmpty
            ? command.join(' ')
            : '');

    // Build based on operation type
    switch (operationType) {
      case 'read':
        return _buildReadView(context, fileName, commandStr, cwd);
      case 'write':
        return _buildWriteView(context, fileName, commandStr, cwd);
      default:
        return _buildCommandView(context, displayCommand, cwd, result, state);
    }
  }

  Widget _buildReadView(
    BuildContext context,
    String? fileName,
    String? commandStr,
    String? cwd,
  ) {
    if (fileName == null) {
      return _buildCommandView(context, commandStr ?? '', cwd, null, 'pending');
    }

    final resolvedPath = resolvePath(fileName, metadata);
    final displayName = resolvedPath.split('/').lastOrNull ?? resolvedPath;

    return ToolSectionView(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reading: $displayName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (commandStr != null && commandStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  commandStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWriteView(
    BuildContext context,
    String? fileName,
    String? commandStr,
    String? cwd,
  ) {
    if (fileName == null) {
      return _buildCommandView(context, commandStr ?? '', cwd, null, 'pending');
    }

    final resolvedPath = resolvePath(fileName, metadata);
    final displayName = resolvedPath.split('/').lastOrNull ?? resolvedPath;

    return ToolSectionView(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Writing: $displayName',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (commandStr != null && commandStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  commandStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandView(
    BuildContext context,
    String command,
    String? cwd,
    dynamic result,
    String state,
  ) {
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
                    command,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // CWD if provided
          if (cwd != null && cwd.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'CWD: $cwd',
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
              child: Container(
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
