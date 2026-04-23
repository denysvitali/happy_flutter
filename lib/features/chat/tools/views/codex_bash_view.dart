import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/command_utils.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';

import '../tool_section_view.dart';
import '../tool_view_colors.dart';

/// View for displaying CodexBash tool (parsed bash commands).
class CodexBashView extends StatelessWidget {

  const CodexBashView({
    required this.tool, super.key,
    this.metadata,
  });
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final command = input['command'] as List?;
    final cwd = input['cwd'] as String?;
    final parsedCmd = input['parsed_cmd'] as List?;

    var operationType = 'bash';
    String? fileName;
    String? commandStr;

    if (parsedCmd != null && parsedCmd.isNotEmpty) {
      final firstCmd = WireParsers.asMap(parsedCmd[0]);
      if (firstCmd != null) {
        operationType = firstCmd['type'] as String? ?? 'bash';
        fileName = firstCmd['name'] as String?;
        commandStr = cleanShellCommand(firstCmd['cmd'] as String?);
      }
    }

    final displayCommand = commandStr ??
        (command != null && command.isNotEmpty
            ? cleanShellCommand(command.join(' '))
            : '');

    switch (operationType) {
      case 'read':
        return _buildReadView(context, fileName, commandStr, cwd);
      case 'write':
        return _buildWriteView(context, fileName, commandStr, cwd);
      default:
        return _buildCommandView(
          context,
          displayCommand,
          cwd,
          result,
          state,
        );
    }
  }

  Widget _buildReadView(
    BuildContext context,
    String? fileName,
    String? commandStr,
    String? cwd,
  ) {
    if (fileName == null) {
      return _buildCommandView(
        context,
        commandStr ?? '',
        cwd,
        null,
        'pending',
      );
    }

    final c = ToolViewColors.of(context);
    final resolvedPath = resolvePath(fileName, metadata);
    final lastSlash = resolvedPath.lastIndexOf('/');
    final dir = lastSlash >= 0
        ? resolvedPath.substring(0, lastSlash + 1)
        : '';
    final displayName = lastSlash >= 0
        ? resolvedPath.substring(lastSlash + 1)
        : resolvedPath;

    return ToolSectionView(
      child: _FileOperationBar(
        icon: Icons.visibility_outlined,
        iconColor: c.blue,
        label: context.l10n.toolSectionReading,
        dir: dir,
        filename: displayName,
        detail: commandStr,
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
      return _buildCommandView(
        context,
        commandStr ?? '',
        cwd,
        null,
        'pending',
      );
    }

    final c = ToolViewColors.of(context);
    final resolvedPath = resolvePath(fileName, metadata);
    final lastSlash = resolvedPath.lastIndexOf('/');
    final dir = lastSlash >= 0
        ? resolvedPath.substring(0, lastSlash + 1)
        : '';
    final displayName = lastSlash >= 0
        ? resolvedPath.substring(lastSlash + 1)
        : resolvedPath;

    return ToolSectionView(
      child: _FileOperationBar(
        icon: Icons.edit_document,
        iconColor: c.green,
        label: context.l10n.toolSectionWriting,
        dir: dir,
        filename: displayName,
        detail: commandStr,
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
    final stdout = result != null ? _getStdout(result) : null;
    final stderr = result != null ? _getStderr(result) : null;
    final exitCode = result != null ? _getExitCode(result) : null;
    final error = state == 'error' && result != null
        ? (_getErrorText(result) ?? result.toString())
        : null;

    return ToolSectionView(
      child: _CodexCommandView(
        command: command,
        cwd: cwd,
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        error: error,
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

  String? _getErrorText(dynamic result) {
    if (result is String) return result;
    if (result is Map<String, dynamic>) {
      return (result['stderr'] ??
              result['stdout'] ??
              result['output'] ??
              result['summary'])
          as String?;
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
// File operation bar (read / write)
// ---------------------------------------------------------------------------

class _FileOperationBar extends StatelessWidget {

  const _FileOperationBar({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.dir,
    required this.filename,
    this.detail,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String dir;
  final String filename;
  final String? detail;

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
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: c.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: iconColor,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // File path body
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 14,
                  color: c.mutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        if (dir.isNotEmpty)
                          TextSpan(
                            text: dir,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: AppFontSize.md,
                              color: c.mutedText,
                            ),
                          ),
                        TextSpan(
                          text: filename,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: AppFontSize.md,
                            color: c.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (detail != null && detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 10,
              ),
              child: SelectableText(
                detail!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.sm,
                  color: c.mutedText,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terminal command view (stateful for expand/collapse)
// ---------------------------------------------------------------------------

class _CodexCommandView extends StatefulWidget {

  const _CodexCommandView({
    required this.command,
    this.cwd,
    this.stdout,
    this.stderr,
    this.exitCode,
    this.error,
  });
  final String command;
  final String? cwd;
  final String? stdout;
  final String? stderr;
  final int? exitCode;
  final String? error;

  @override
  State<_CodexCommandView> createState() => _CodexCommandViewState();
}

class _CodexCommandViewState extends State<_CodexCommandView> {
  static const int _maxLines = 20;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TerminalCommandBar(
          command: widget.command,
          cwd: widget.cwd,
        ),
        if (widget.stdout != null && widget.stdout!.isNotEmpty)
          _TerminalOutputSection(
            label: 'stdout',
            output: widget.stdout!,
            isError: false,
            maxLines: _maxLines,
          ),
        if (widget.stderr != null && widget.stderr!.isNotEmpty)
          _TerminalOutputSection(
            label: 'stderr',
            output: widget.stderr!,
            isError: true,
            maxLines: _maxLines,
          ),
        if (widget.error != null)
          _TerminalOutputSection(
            label: 'error',
            output: widget.error!,
            isError: true,
            maxLines: _maxLines,
          ),
        if (widget.exitCode != null)
          _ExitCodeBadge(exitCode: widget.exitCode!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared terminal sub-widgets
// ---------------------------------------------------------------------------

class _TerminalCommandBar extends StatelessWidget {

  const _TerminalCommandBar({required this.command, this.cwd});
  final String command;
  final String? cwd;

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
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: c.headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(
                bottom: BorderSide(color: c.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 14,
                  color: c.mutedText,
                ),
                const SizedBox(width: 6),
                Text(
                  'bash',
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
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
        ],
      ),
    );
  }
}

class _TerminalOutputSection extends StatefulWidget {

  const _TerminalOutputSection({
    required this.label,
    required this.output,
    required this.isError,
    required this.maxLines,
  });
  final String label;
  final String output;
  final bool isError;
  final int maxLines;

  @override
  State<_TerminalOutputSection> createState() =>
      _TerminalOutputSectionState();
}

class _TerminalOutputSectionState extends State<_TerminalOutputSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);
    final totalLines = widget.output.split('\n').length;
    final needsTruncation = totalLines > widget.maxLines;
    final maxLines = _expanded ? 999 : widget.maxLines;

    final labelColor = widget.isError ? c.red : c.mutedText;
    final borderColor = widget.isError ? c.errorBorder : c.border;
    final bgColor = widget.isError ? c.errorBg : c.bg;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
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
                if (widget.isError)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.error_outline,
                      size: 13,
                      color: c.red,
                    ),
                  ),
                Text(
                  widget.label,
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
                _CopyButton(
                  text: AnsiParser.strip(widget.output),
                  iconSize: 13,
                ),
              ],
            ),
          ),
          CodeBlockWidget(
            code: widget.output,
            language: 'bash',
            isDarkMode: isDark,
            fontSize: AppFontSize.sm,
            maxVisibleLines: maxLines,
          ),
          if (needsTruncation)
            _ShowMoreButton(
              expanded: _expanded,
              hiddenCount: totalLines - widget.maxLines,
              onToggle: () => setState(() => _expanded = !_expanded),
              borderColor: borderColor,
            ),
        ],
      ),
    );
  }
}

class _ExitCodeBadge extends StatelessWidget {

  const _ExitCodeBadge({required this.exitCode});
  final int exitCode;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final isSuccess = exitCode == 0;
    final color = isSuccess ? c.green : c.red;
    final bgColor = isSuccess ? c.greenBadgeBg : c.redBadgeBg;
    final borderColor =
        isSuccess ? c.greenBadgeBorder : c.redBadgeBorder;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
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
