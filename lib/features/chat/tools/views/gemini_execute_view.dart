import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/exit_code_badge.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/tool_result_parser.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import 'terminal_command_bar.dart';

/// View for displaying Gemini execute tool (lowercase 'execute').
class GeminiExecuteView extends StatefulWidget {
  const GeminiExecuteView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  State<GeminiExecuteView> createState() => _GeminiExecuteViewState();
}

class _GeminiExecuteViewState extends State<GeminiExecuteView> {
  static const int _maxLines = 20;
  bool _outputExpanded = false;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(widget.tool['input']) ?? {};
    final result = widget.tool['result'];
    final state = widget.tool['state'] as String? ?? '';

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
            _TerminalOutputSection(
              label: 'stdout',
              output: stdout,
              isError: false,
              expanded: _outputExpanded,
              maxLines: _maxLines,
              onToggleExpand: () =>
                  setState(() => _outputExpanded = !_outputExpanded),
            ),
          if (stderr != null && stderr.isNotEmpty)
            _TerminalOutputSection(
              label: 'stderr',
              output: stderr,
              isError: true,
              expanded: _outputExpanded,
              maxLines: _maxLines,
              onToggleExpand: () =>
                  setState(() => _outputExpanded = !_outputExpanded),
            ),
          if (error != null)
            _TerminalOutputSection(
              label: 'error',
              output: error,
              isError: true,
              expanded: _outputExpanded,
              maxLines: _maxLines,
              onToggleExpand: () =>
                  setState(() => _outputExpanded = !_outputExpanded),
            ),
          if (exitCode != null) ExitCodeBadge(exitCode: exitCode),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terminal command bar with optional description
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Terminal output section (stdout / stderr / error)
// ---------------------------------------------------------------------------

class _TerminalOutputSection extends StatelessWidget {
  const _TerminalOutputSection({
    required this.label,
    required this.output,
    required this.isError,
    required this.expanded,
    required this.maxLines,
    required this.onToggleExpand,
  });
  final String label;
  final String output;
  final bool isError;
  final bool expanded;
  final int maxLines;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lines = output.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > maxLines;
    final visibleLines = expanded || !needsTruncation
        ? lines
        : lines.take(maxLines).toList();
    final visibleText = visibleLines.join('\n');

    final labelColor = isError ? AppColors.error : cs.onSurfaceVariant;
    final borderColor = isError ? AppColors.error : cs.outlineVariant;
    final bgColor = isError ? cs.errorContainer : cs.surface;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xsm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xxs2,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (isError)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs2),
                    child: Icon(
                      Icons.error_outline,
                      size: AppIconSize.xs,
                      color: AppColors.error,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.xs,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalLines line${totalLines == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: AppFontSize.xxs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ToolViewCopyButton(text: AnsiParser.strip(output), iconSize: 13),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: SelectableText.rich(
              TextSpan(
                children: AnsiParser.parse(
                  visibleText,
                  defaultStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                    color: isError ? AppColors.error : cs.onSurface,
                    height: AppLineHeight.relaxed,
                  ),
                ),
              ),
            ),
          ),
          if (needsTruncation)
            ToolViewShowMoreButton(
              expanded: expanded,
              hiddenCount: totalLines - maxLines,
              onToggle: onToggleExpand,
            ),
        ],
      ),
    );
  }
}

