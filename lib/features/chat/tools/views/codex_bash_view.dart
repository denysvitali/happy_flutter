import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/exit_code_badge.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/command_utils.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/utils/tool_result_parser.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../tool_section_view.dart';
import '../tool_view_widgets.dart';
import 'terminal_command_bar.dart';

/// View for displaying CodexBash tool (parsed bash commands).
class CodexBashView extends StatelessWidget {
  const CodexBashView({required this.tool, super.key, this.metadata});

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

    final displayCommand =
        commandStr ??
        (command != null && command.isNotEmpty
            ? cleanShellCommand(command.join(' '))
            : '');

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

    final cs = Theme.of(context).colorScheme;
    final resolvedPath = resolvePath(fileName, metadata);
    final lastSlash = resolvedPath.lastIndexOf('/');
    final dir = lastSlash >= 0 ? resolvedPath.substring(0, lastSlash + 1) : '';
    final displayName = lastSlash >= 0
        ? resolvedPath.substring(lastSlash + 1)
        : resolvedPath;

    return ToolSectionView(
      child: _FileOperationBar(
        icon: Icons.visibility_outlined,
        iconColor: cs.primary,
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
      return _buildCommandView(context, commandStr ?? '', cwd, null, 'pending');
    }

    final resolvedPath = resolvePath(fileName, metadata);
    final lastSlash = resolvedPath.lastIndexOf('/');
    final dir = lastSlash >= 0 ? resolvedPath.substring(0, lastSlash + 1) : '';
    final displayName = lastSlash >= 0
        ? resolvedPath.substring(lastSlash + 1)
        : resolvedPath;

    return ToolSectionView(
      child: _FileOperationBar(
        icon: Icons.edit_document,
        iconColor: AppColors.success,
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
    final stdout = result != null ? parseStdout(result) : null;
    final stderr = result != null ? parseStderr(result) : null;
    final exitCode = result != null ? parseExitCode(result) : null;
    final error = state == 'error' && result != null
        ? (parseErrorText(result) ?? result.toString())
        : null;

    return ToolSectionView(
      child: _CodexCommandView(
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
    final cs = theme.colorScheme;

    return Container(
      decoration: toolCardDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Container(
            padding: toolCardHeaderPadding,
            decoration: toolCardHeaderDecoration(cs),
            child: Row(
              children: [
                Icon(icon, size: AppIconSize.sm, color: iconColor),
                const SizedBox(width: AppSpacing.xsm),
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
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: AppIconSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
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
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        TextSpan(
                          text: filename,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: AppFontSize.md,
                            color: cs.onSurface,
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
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.smd,
              ),
              child: SelectableText(
                detail!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.sm,
                  color: cs.onSurfaceVariant,
                  height: AppLineHeight.normal,
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
    this.rawResult,
  });
  final String command;
  final String? cwd;
  final String? stdout;
  final String? stderr;
  final int? exitCode;
  final String? error;
  final dynamic rawResult;

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
        TerminalCommandBar(command: widget.command, cwd: widget.cwd),
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
        if (widget.exitCode != null) ExitCodeBadge(exitCode: widget.exitCode!),
        // Raw JSON output is reachable via long-press → details; no inline
        // toggle here.
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared terminal sub-widgets
// ---------------------------------------------------------------------------


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
  State<_TerminalOutputSection> createState() => _TerminalOutputSectionState();
}

class _TerminalOutputSectionState extends State<_TerminalOutputSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isError = widget.isError;
    final totalLines = widget.output.split('\n').length;
    final needsTruncation = totalLines > widget.maxLines;

    final labelColor = isError ? AppColors.error : cs.onSurfaceVariant;
    final borderColor = isError ? AppColors.error : cs.outlineVariant;
    final bgColor = isError ? cs.errorContainer : cs.surface;

    final lines = widget.output.split('\n');
    final visibleLines = _expanded || !needsTruncation
        ? lines
        : lines.take(widget.maxLines).toList();
    final visibleText = visibleLines.join('\n');
    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
      fontSize: AppFontSize.sm,
      color: cs.onSurface,
      height: AppLineHeight.relaxed,
    );
    final parsedSpans = AnsiParser.parse(
      visibleText,
      defaultStyle: defaultStyle,
    );

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
                    color: cs.onSurfaceVariant,
                    fontSize: AppFontSize.xxs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ToolViewCopyButton(
                  text: AnsiParser.strip(widget.output),
                  iconSize: 13,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: SelectableText.rich(
              TextSpan(children: parsedSpans),
              style: defaultStyle,
            ),
          ),
          if (needsTruncation)
            ToolViewShowMoreButton(
              expanded: _expanded,
              hiddenCount: totalLines - widget.maxLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
    );
  }
}
