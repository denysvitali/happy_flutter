import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/exit_code_badge.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';
import '../tool_view_colors.dart';

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
        ? _getStdout(result)
        : null;
    final stderr = state == 'completed' && result != null
        ? _getStderr(result)
        : null;
    final exitCode = state == 'completed' && result != null
        ? _getExitCode(result)
        : null;
    final error = state == 'error' && result != null ? result.toString() : null;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TerminalCommandBar(
            command: command ?? 'Unknown command',
            cwd: cwd,
            description: description,
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

  String? _getStdout(dynamic result) {
    if (result is String) return result;
    if (result is Map<String, dynamic>) {
      return result['stdout'] as String?;
    }
    return null;
  }

  String? _getStderr(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result['stderr'] as String?;
    }
    return null;
  }

  int? _getExitCode(dynamic result) {
    if (result is Map<String, dynamic>) {
      final raw = result['exitCode'] ?? result['exit_code'];
      if (raw is int) return raw;
      if (raw is String) return int.tryParse(raw);
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Terminal command bar with optional description
// ---------------------------------------------------------------------------

class _TerminalCommandBar extends StatelessWidget {
  const _TerminalCommandBar({
    required this.command,
    this.cwd,
    this.description,
  });
  final String command;
  final String? cwd;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xsm,
            ),
            decoration: BoxDecoration(
              color: c.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: AppIconSize.sm, color: c.mutedText),
                const SizedBox(width: AppSpacing.xsm),
                Text(
                  'execute',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.mutedText,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                if (cwd != null && cwd!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '\u00b7',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: c.lineNumberText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      cwd!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.xs,
                        color: c.lineNumberText,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                ToolViewCopyButton(text: command, iconSize: 14),
              ],
            ),
          ),
          // Command line
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r'$',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                    color: c.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SelectableText(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.md,
                      color: c.primaryText,
                      height: AppLineHeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Optional description banner
          if (description != null && description!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xsm + 1,
              ),
              decoration: BoxDecoration(
                color: c.headerBg,
                border: Border(top: BorderSide(color: c.border)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.sm),
                  bottomRight: Radius.circular(AppRadius.sm),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: AppIconSize.xs, color: c.blue),
                  const SizedBox(width: AppSpacing.xsm),
                  Expanded(
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: c.mutedText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
    final c = ToolViewColors.of(context);
    final lines = output.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > maxLines;
    final visibleLines = expanded || !needsTruncation
        ? lines
        : lines.take(maxLines).toList();
    final visibleText = visibleLines.join('\n');

    final labelColor = isError ? c.red : c.mutedText;
    final borderColor = isError ? c.errorBorder : c.border;
    final bgColor = isError ? c.errorBg : c.bg;

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
              color: c.headerBg,
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
                      color: c.red,
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
                    color: c.lineNumberText,
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
                    color: isError ? c.errorText : c.primaryText,
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

