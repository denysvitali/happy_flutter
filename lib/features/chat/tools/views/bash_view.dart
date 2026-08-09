import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/exit_code_badge.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/command_utils.dart';
import 'package:happy_flutter/core/utils/tool_result_parser.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import 'terminal_command_bar.dart';
import 'terminal_output_section.dart';

/// View for displaying Bash tool command and output.
class BashView extends StatelessWidget {
  const BashView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? 'pending';

    final command = cleanShellCommand(input['command'] as String?);
    final description = input['description'] as String?;

    final stdout = state == 'completed' && result != null
        ? parseStdout(result)
        : null;
    final stderr = state == 'completed' && result != null
        ? parseStderr(result)
        : null;
    final exitCode = state == 'completed' && result != null
        ? parseExitCode(result)
        : null;
    final error = state == 'error' && result != null ? result.toString() : null;

    return ToolSectionView(
      child: CommandView(
        command: command,
        description: description,
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        error: error,
        rawResult: result,
      ),
    );
  }

}

/// View for function-style command execution tools.
///
/// Codex function tools use input/result field names that differ from Claude's
/// `Bash` tool, but they should still render as terminal output.
class ExecCommandView extends StatelessWidget {
  const ExecCommandView({required this.tool, super.key});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? 'pending';

    final command = cleanShellCommand(
      input['cmd'] as String? ?? input['command'] as String?,
    );
    final cwd = input['workdir'] as String? ?? input['cwd'] as String?;

    final stdout = state == 'completed' && result != null
        ? parseStdout(result)
        : null;
    final stderr = state == 'completed' && result != null
        ? parseStderr(result)
        : null;
    final exitCode = state == 'completed' && result != null
        ? parseExitCode(result)
        : null;
    final error = state == 'error' && result != null
        ? (parseErrorText(result) ?? result.toString())
        : null;

    return ToolSectionView(
      child: CommandView(
        command: command,
        cwd: cwd,
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        error: error,
        rawResult: result,
      ),
    );
  }
}

/// Command view showing the command being executed and its output.
class CommandView extends StatelessWidget {
  const CommandView({
    required this.command,
    super.key,
    this.cwd,
    this.description,
    this.stdout,
    this.stderr,
    this.exitCode,
    this.error,
    this.rawResult,
    this.hideEmptyOutput = true,
  });

  /// The shell command string.
  final String command;

  /// Optional working directory / target shown in the card header.
  final String? cwd;

  /// Human-readable description of what the command does.
  final String? description;

  /// Standard output text.
  final String? stdout;

  /// Standard error text.
  final String? stderr;

  /// Process exit code.
  final int? exitCode;

  /// Generic error message.
  final String? error;

  /// Raw command result shown behind the optional JSON toggle.
  final dynamic rawResult;

  /// Whether to hide sections when output is empty.
  final bool hideEmptyOutput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TerminalCommandBar(
          command: command,
          cwd: cwd,
          description: description,
        ),
        if (stdout != null && stdout!.isNotEmpty)
          TerminalOutputSection(
            label: 'stdout',
            output: stdout!,
            isError: false,
          ),
        if (stderr != null && stderr!.isNotEmpty)
          TerminalOutputSection(
            label: 'stderr',
            output: stderr!,
            isError: true,
          ),
        if (error != null)
          TerminalOutputSection(
            label: 'error',
            output: error!,
            isError: true,
          ),
        if (exitCode != null) ExitCodeBadge(exitCode: exitCode!),
        // Raw JSON output is reachable via long-press → details; no inline
        // toggle here. The `rawResult` field is preserved for callers that
        // pass it through (e.g. message_detail_screen pulls it from the
        // tool data directly), but the inline UI only renders the text
        // sections above.
        if (stdout == null &&
            stderr == null &&
            error == null &&
            exitCode != null &&
            exitCode == 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'No output',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A pill chip that displays a file path with a leading file icon.
class FilePillChip extends StatelessWidget {
  /// Creates a [FilePillChip].
  const FilePillChip({required this.path, super.key, this.onTap});

  /// The file path to display.
  final String path;

  /// Optional tap callback. When provided, the chip becomes tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastSlash = path.lastIndexOf('/');
    final dir = lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
    final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: AppBorder.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: AppIconSize.xs,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xxs2),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (dir.isNotEmpty)
                    TextSpan(
                      text: dir,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.xs,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  TextSpan(
                    text: filename,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        child: chip,
      ),
    );
  }
}
