import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying Bash tool command and output.
class BashView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const BashView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? 'pending';

    final command = input['command'] as String? ?? '';

    return ToolSectionView(
      child: CommandView(
        command: command,
        stdout: state == 'completed' && result != null
            ? _getStdout(result)
            : null,
        stderr: state == 'completed' && result != null
            ? _getStderr(result)
            : null,
        error: state == 'error' && result != null ? result.toString() : null,
      ),
    );
  }

  String? _getStdout(dynamic result) {
    if (result is String) return result;
    if (result is Map<String, dynamic>) return result['stdout'] as String?;
    return null;
  }

  String? _getStderr(dynamic result) {
    if (result is Map<String, dynamic>) return result['stderr'] as String?;
    return null;
  }
}

/// Command view showing the command being executed.
class CommandView extends StatelessWidget {
  final String command;
  final String? stdout;
  final String? stderr;
  final String? error;
  final bool hideEmptyOutput;

  const CommandView({
    super.key,
    required this.command,
    this.stdout,
    this.stderr,
    this.error,
    this.hideEmptyOutput = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Command display
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.terminal, size: 16, color: theme.colorScheme.primary),
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
        // Output sections
        if (stdout != null && stdout!.isNotEmpty)
          _buildOutputSection(context, 'Output', stdout!, false),
        if (stderr != null && stderr!.isNotEmpty)
          _buildOutputSection(context, 'Error', stderr!, true),
        if (error != null) _buildOutputSection(context, 'Error', error!, true),
      ],
    );
  }

  Widget _buildOutputSection(
    BuildContext context,
    String label,
    String output,
    bool isError,
  ) {
    final theme = Theme.of(context);
    final backgroundColor = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isError
              ? theme.colorScheme.error.withOpacity(0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            output,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
