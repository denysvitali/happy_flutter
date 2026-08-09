import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/exit_code_badge.dart';
import 'package:happy_flutter/core/utils/tool_result_parser.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import 'terminal_command_bar.dart';
import 'terminal_output_section.dart';

/// View for displaying Gemini execute tool (lowercase 'execute').
class GeminiExecuteView extends StatelessWidget {
  const GeminiExecuteView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final toolCall = WireParsers.asMap(input['toolCall']);
    final title = toolCall?['title'] as String?;

    String? command;
    String? description;
    String? cwd;

    if (title != null) {
      // Title format: "rm file.txt [cwd /path] (description)"
      final bracketIdx = title.indexOf(' [');
      command = bracketIdx > 0 ? title.substring(0, bracketIdx) : title;

      final cwdMatch = RegExp(r'\[cwd ([^\]]+)\]').firstMatch(title);
      if (cwdMatch != null) {
        cwd = cwdMatch.group(1);
      }

      final parenMatch = RegExp(r'\(([^)]+)\)$').firstMatch(title);
      if (parenMatch != null) {
        description = parenMatch.group(1);
      }
    }

    if (command == null) {
      final commandList = input['command'] as List?;
      if (commandList != null && commandList.isNotEmpty) {
        command = commandList.join(' ');
      }
    }

    cwd ??= input['cwd'] as String?;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TerminalCommandBar(
            command: command ?? 'Unknown command',
            cwd: cwd,
            description: description,
            label: 'execute',
          ),
          if (stdout != null && stdout.isNotEmpty)
            TerminalOutputSection(
              label: 'stdout',
              output: stdout,
              isError: false,
            ),
          if (stderr != null && stderr.isNotEmpty)
            TerminalOutputSection(
              label: 'stderr',
              output: stderr,
              isError: true,
            ),
          if (error != null)
            TerminalOutputSection(
              label: 'error',
              output: error,
              isError: true,
            ),
          if (exitCode != null) ExitCodeBadge(exitCode: exitCode),
        ],
      ),
    );
  }
}
