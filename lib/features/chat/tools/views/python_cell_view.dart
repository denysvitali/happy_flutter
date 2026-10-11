import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/grok_acp_normalize.dart';
import '../../../../core/utils/tool_result_parser.dart';
import '../../../../core/wire/wire_parsers.dart';
import '../../code_block_widget.dart';
import 'terminal_output_section.dart';

/// Prime Agent's Python source and text output, not its JSON envelope.
class PythonCellView extends StatelessWidget {
  const PythonCellView({required this.tool, super.key});

  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.toolInput(tool);
    final code = input['code'];
    final result = normalizeGrokToolResult(tool['result']);
    final isError = tool['state'] == 'error';
    final stdout = parseStdout(result);
    final stderr = parseStderr(result);
    final error =
        isError &&
            (stdout == null || stdout.isEmpty) &&
            (stderr == null || stderr.isEmpty)
        ? parseErrorText(result)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (code is String && code.isNotEmpty)
          CodeBlockWidget(
            code: code,
            language: 'python',
            maxVisibleLines: 4,
            fontSize: AppFontSize.md,
          ),
        if (stdout != null && stdout.isNotEmpty)
          TerminalOutputSection(
            label: isError ? 'error' : 'stdout',
            output: stdout,
            isError: isError,
            maxLines: 4,
          ),
        if (stderr != null && stderr.isNotEmpty)
          TerminalOutputSection(
            label: 'stderr',
            output: stderr,
            isError: true,
            maxLines: 4,
          ),
        if (error != null && error.isNotEmpty)
          TerminalOutputSection(
            label: 'error',
            output: error,
            isError: true,
            maxLines: 4,
          ),
      ],
    );
  }
}
