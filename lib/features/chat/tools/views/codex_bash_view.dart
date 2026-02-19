import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// View for displaying CodexBash tool (parsed bash commands).
class CodexBashView extends StatelessWidget {
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  const CodexBashView({
    super.key,
    required this.tool,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final command = input['command'] as List?;
    final cwd = input['cwd'] as String?;
    final parsedCmd = input['parsed_cmd'] as List?;

    String operationType = 'bash';
    String? fileName;
    String? commandStr;

    if (parsedCmd != null && parsedCmd.isNotEmpty) {
      final firstCmd = parsedCmd[0] as Map<String, dynamic>?;
      if (firstCmd != null) {
        operationType = firstCmd['type'] as String? ?? 'bash';
        fileName = firstCmd['name'] as String?;
        commandStr = firstCmd['cmd'] as String?;
      }
    }

    final displayCommand = commandStr ??
        (command != null && command.isNotEmpty
            ? command.join(' ')
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
        iconColor: const Color(0xFF58A6FF),
        label: 'Reading',
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
        iconColor: const Color(0xFF3FB950),
        label: 'Writing',
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
    final stdout = state == 'completed' && result != null
        ? _getStdout(result)
        : null;
    final stderr = state == 'completed' && result != null
        ? _getStderr(result)
        : null;
    final exitCode = state == 'completed' && result != null
        ? _getExitCode(result)
        : null;
    final error =
        state == 'error' && result != null ? result.toString() : null;

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
  final IconData icon;
  final Color iconColor;
  final String label;
  final String dir;
  final String filename;
  final String? detail;

  const _FileOperationBar({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.dir,
    required this.filename,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
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
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D)),
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
                  color: const Color(0xFF8B949E),
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
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: Color(0xFF8B949E),
                            ),
                          ),
                        TextSpan(
                          text: filename,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFFE6EDF3),
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
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF8B949E),
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
  final String command;
  final String? cwd;
  final String? stdout;
  final String? stderr;
  final int? exitCode;
  final String? error;

  const _CodexCommandView({
    required this.command,
    this.cwd,
    this.stdout,
    this.stderr,
    this.exitCode,
    this.error,
  });

  @override
  State<_CodexCommandView> createState() => _CodexCommandViewState();
}

class _CodexCommandViewState extends State<_CodexCommandView> {
  static const int _maxLines = 20;
  bool _stdoutExpanded = false;
  bool _stderrExpanded = false;

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
            expanded: _stdoutExpanded,
            maxLines: _maxLines,
            onToggleExpand: () =>
                setState(() => _stdoutExpanded = !_stdoutExpanded),
          ),
        if (widget.stderr != null && widget.stderr!.isNotEmpty)
          _TerminalOutputSection(
            label: 'stderr',
            output: widget.stderr!,
            isError: true,
            expanded: _stderrExpanded,
            maxLines: _maxLines,
            onToggleExpand: () =>
                setState(() => _stderrExpanded = !_stderrExpanded),
          ),
        if (widget.error != null)
          _TerminalOutputSection(
            label: 'error',
            output: widget.error!,
            isError: true,
            expanded: _stderrExpanded,
            maxLines: _maxLines,
            onToggleExpand: () =>
                setState(() => _stderrExpanded = !_stderrExpanded),
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
  final String command;
  final String? cwd;

  const _TerminalCommandBar({required this.command, this.cwd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
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
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  size: 14,
                  color: Color(0xFF8B949E),
                ),
                const SizedBox(width: 6),
                Text(
                  'bash',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8B949E),
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                if (cwd != null && cwd!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '·',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF484F58),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cwd!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF484F58),
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
                const Text(
                  r'$',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF3FB950),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    command,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFFE6EDF3),
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

class _TerminalOutputSection extends StatelessWidget {
  final String label;
  final String output;
  final bool isError;
  final bool expanded;
  final int maxLines;
  final VoidCallback onToggleExpand;

  const _TerminalOutputSection({
    required this.label,
    required this.output,
    required this.isError,
    required this.expanded,
    required this.maxLines,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = output.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > maxLines;
    final visibleLines = expanded || !needsTruncation
        ? lines
        : lines.take(maxLines).toList();
    final visibleText = visibleLines.join('\n');

    final labelColor =
        isError ? const Color(0xFFF85149) : const Color(0xFF8B949E);
    final borderColor =
        isError ? const Color(0xFF5A1E1E) : const Color(0xFF30363D);
    final bgColor =
        isError ? const Color(0xFF160B0B) : const Color(0xFF0D1117);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
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
              color: const Color(0xFF161B22),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (isError)
                  const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.error_outline,
                      size: 13,
                      color: Color(0xFFF85149),
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalLines line${totalLines == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF484F58),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                _CopyButton(text: output, iconSize: 13),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              visibleText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isError
                    ? const Color(0xFFFFA198)
                    : const Color(0xFFE6EDF3),
                height: 1.5,
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

class _ExitCodeBadge extends StatelessWidget {
  final int exitCode;

  const _ExitCodeBadge({required this.exitCode});

  @override
  Widget build(BuildContext context) {
    final isSuccess = exitCode == 0;
    final color =
        isSuccess ? const Color(0xFF3FB950) : const Color(0xFFF85149);
    final bgColor =
        isSuccess ? const Color(0xFF0D2818) : const Color(0xFF2D1117);
    final borderColor =
        isSuccess ? const Color(0xFF1A4328) : const Color(0xFF5A1E1E);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
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
                fontSize: 11,
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
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onToggle;
  final Color borderColor;

  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onToggle,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor)),
          color: const Color(0xFF161B22),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: const Color(0xFF8B949E),
            ),
            const SizedBox(width: 4),
            Text(
              expanded
                  ? 'Show less'
                  : 'Show $hiddenCount more '
                      'line${hiddenCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8B949E),
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
  final String text;
  final double iconSize;

  const _CopyButton({required this.text, this.iconSize = 14});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          key: ValueKey(_copied),
          size: widget.iconSize,
          color: _copied
              ? const Color(0xFF3FB950)
              : const Color(0xFF8B949E),
        ),
      ),
    );
  }
}
