import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tool_section_view.dart';

/// View for displaying Bash tool command and output.
class BashView extends StatelessWidget {
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  const BashView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? 'pending';

    final command = input['command'] as String? ?? '';

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
      child: CommandView(
        command: command,
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

/// Command view showing the command being executed and its output.
class CommandView extends StatefulWidget {
  /// The shell command string.
  final String command;

  /// Standard output text.
  final String? stdout;

  /// Standard error text.
  final String? stderr;

  /// Process exit code.
  final int? exitCode;

  /// Generic error message.
  final String? error;

  /// Whether to hide sections when output is empty.
  final bool hideEmptyOutput;

  const CommandView({
    super.key,
    required this.command,
    this.stdout,
    this.stderr,
    this.exitCode,
    this.error,
    this.hideEmptyOutput = true,
  });

  @override
  State<CommandView> createState() => _CommandViewState();
}

class _CommandViewState extends State<CommandView> {
  static const int _defaultMaxLines = 20;

  bool _stdoutExpanded = false;
  bool _stderrExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TerminalCommandBar(command: widget.command),
        if (widget.stdout != null && widget.stdout!.isNotEmpty)
          _TerminalOutputSection(
            label: 'stdout',
            output: widget.stdout!,
            isError: false,
            expanded: _stdoutExpanded,
            maxLines: _defaultMaxLines,
            onToggleExpand: () =>
                setState(() => _stdoutExpanded = !_stdoutExpanded),
          ),
        if (widget.stderr != null && widget.stderr!.isNotEmpty)
          _TerminalOutputSection(
            label: 'stderr',
            output: widget.stderr!,
            isError: true,
            expanded: _stderrExpanded,
            maxLines: _defaultMaxLines,
            onToggleExpand: () =>
                setState(() => _stderrExpanded = !_stderrExpanded),
          ),
        if (widget.error != null)
          _TerminalOutputSection(
            label: 'error',
            output: widget.error!,
            isError: true,
            expanded: _stderrExpanded,
            maxLines: _defaultMaxLines,
            onToggleExpand: () =>
                setState(() => _stderrExpanded = !_stderrExpanded),
          ),
        if (widget.exitCode != null)
          _ExitCodeBadge(exitCode: widget.exitCode!),
        if (widget.stdout == null &&
            widget.stderr == null &&
            widget.error == null &&
            widget.exitCode != null &&
            widget.exitCode == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
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
// Private sub-widgets
// ---------------------------------------------------------------------------

class _TerminalCommandBar extends StatelessWidget {
  final String command;

  const _TerminalCommandBar({required this.command});

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  style: const TextStyle(
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
    final visibleLines =
        expanded || !needsTruncation ? lines : lines.take(maxLines).toList();
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
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          // Output text
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
          // Show more / show less button
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
    final bgColor = isSuccess
        ? const Color(0xFF0D2818)
        : const Color(0xFF2D1117);
    final borderColor = isSuccess
        ? const Color(0xFF1A4328)
        : const Color(0xFF5A1E1E);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        ],
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
                  : 'Show $hiddenCount more line'
                      '${hiddenCount == 1 ? '' : 's'}',
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
