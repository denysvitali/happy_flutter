import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';
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
          if (exitCode != null) _ExitCodeBadge(exitCode: exitCode),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                Icon(Icons.terminal, size: 14, color: c.mutedText),
                const SizedBox(width: 6),
                Text(
                  'execute',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.mutedText,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                if (cwd != null && cwd!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '\u00b7',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: c.lineNumberText,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                _CopyButton(text: command, iconSize: 14),
              ],
            ),
          ),
          // Command line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.md,
                      color: c.primaryText,
                      height: 1.4,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  Icon(Icons.info_outline, size: 12, color: c.blue),
                  const SizedBox(width: 6),
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
      margin: const EdgeInsets.only(top: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.error_outline, size: 13, color: c.red),
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
                const SizedBox(width: 8),
                _CopyButton(text: AnsiParser.strip(output), iconSize: 13),
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
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (needsTruncation)
            _ShowMoreButton(
              expanded: expanded,
              hiddenCount: totalLines - maxLines,
              onToggle: onToggleExpand,
              borderColor: borderColor,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exit code badge
// ---------------------------------------------------------------------------

class _ExitCodeBadge extends StatelessWidget {
  const _ExitCodeBadge({required this.exitCode});
  final int exitCode;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final isSuccess = exitCode == 0;
    final color = isSuccess ? c.green : c.red;
    final bgColor = isSuccess ? c.greenBadgeBg : c.redBadgeBg;
    final borderColor = isSuccess ? c.greenBadgeBorder : c.redBadgeBorder;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              'exit $exitCode',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Show more / less button
// ---------------------------------------------------------------------------

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onToggle,
    required this.borderColor,
  });
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onToggle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);

    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor)),
          color: c.headerBg,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.sm),
            bottomRight: Radius.circular(AppRadius.sm),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: c.mutedText,
            ),
            const SizedBox(width: 4),
            Text(
              expanded
                  ? 'Show less'
                  : 'Show $hiddenCount more '
                        'line${hiddenCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: AppFontSize.xs,
                color: c.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Copy button
// ---------------------------------------------------------------------------

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text, this.iconSize = 14});
  final String text;
  final double iconSize;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await setClipboardTextSafely(widget.text);
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);

    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          key: ValueKey(_copied),
          size: widget.iconSize,
          color: _copied ? c.copyIconDone : c.copyIcon,
        ),
      ),
    );
  }
}
