import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import '../tool_section_view.dart';
import '../tool_view_colors.dart';

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

    final command = input['command'] as String? ?? '';
    final description =
        input['description'] as String? ?? _descriptionFromCommand(command);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionLabel(label: context.l10n.toolSectionCommand),
          const SizedBox(height: AppSpacing.xs),
          CommandView(
            command: command,
            description: description,
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            error: error,
          ),
        ],
      ),
    );
  }

  static String? _descriptionFromCommand(String command) {
    if (command.isEmpty) return null;
    final firstWord = command.split(' ').first;
    const knownCommands = {
      'cd', 'ls', 'pwd', 'mkdir', 'rm', 'cp', 'mv',
      'npm', 'yarn', 'git',
    };
    if (knownCommands.contains(firstWord)) return '$firstWord command';
    return command.length > 20 ? '${command.substring(0, 20)}...' : command;
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

  const CommandView({
    required this.command, super.key,
    this.description,
    this.stdout,
    this.stderr,
    this.exitCode,
    this.error,
    this.hideEmptyOutput = true,
  });
  /// The shell command string.
  final String command;

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

  /// Whether to hide sections when output is empty.
  final bool hideEmptyOutput;

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
        _TerminalCommandBar(
          command: widget.command,
          description: widget.description,
        ),
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
// Private sub-widgets
// ---------------------------------------------------------------------------

class _TerminalCommandBar extends StatelessWidget {

  const _TerminalCommandBar({
    required this.command,
    this.description,
  });
  final String command;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);
    // Show description as primary label; fall back to "bash".
    final label = description ?? 'bash';

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
          // Title bar -- description (or "bash") + copy button
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
                const SizedBox(width: AppSpacing.xsm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: description != null
                          ? c.primaryText
                          : c.mutedText,
                      fontFamily: description != null
                          ? null
                          : 'monospace',
                      letterSpacing: description != null
                          ? null
                          : 0.5,
                    ),
                  ),
                ),
                _CopyButton(text: command, iconSize: 14),
              ],
            ),
          ),
          // Command -- single line, truncated with "$" prefix
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                  child: Text(
                    // Collapse newlines so multi-line commands fit one line
                    command.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  State<_TerminalOutputSection> createState() =>
      _TerminalOutputSectionState();
}

class _TerminalOutputSectionState extends State<_TerminalOutputSection> {
  late int _totalLines;
  late bool _needsTruncation;
  late String _visibleText;
  late List<TextSpan> _parsedSpans;
  // Track the style used to build _parsedSpans so we can avoid
  // re-parsing when only unrelated parts of the tree rebuild.
  TextStyle? _lastDefaultStyle;

  /// Recomputes _totalLines, _needsTruncation, and _visibleText from
  /// widget fields.  Call whenever output, expanded, or maxLines changes.
  void _recomputeVisibleText() {
    final lines = widget.output.split('\n');
    _totalLines = lines.length;
    _needsTruncation = _totalLines > widget.maxLines;
    final visibleLines = widget.expanded || !_needsTruncation
        ? lines
        : lines.take(widget.maxLines).toList();
    _visibleText = visibleLines.join('\n');
  }

  /// Rebuilds _parsedSpans using [defaultStyle].  Only called when
  /// _visibleText or defaultStyle actually changes.
  void _recomputeSpans(TextStyle defaultStyle) {
    _parsedSpans = AnsiParser.parse(_visibleText, defaultStyle: defaultStyle);
    _lastDefaultStyle = defaultStyle;
  }

  @override
  void initState() {
    super.initState();
    _recomputeVisibleText();
    // Spans are populated on first build() once we have a BuildContext.
    _parsedSpans = const [];
  }

  @override
  void didUpdateWidget(_TerminalOutputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.output != widget.output ||
        oldWidget.expanded != widget.expanded ||
        oldWidget.maxLines != widget.maxLines) {
      _recomputeVisibleText();
      // Force re-parse on next build by clearing the cached style.
      _lastDefaultStyle = null;
    } else if (oldWidget.isError != widget.isError) {
      // visibleText is unchanged but the default text color may differ;
      // clear the cached style so build() re-parses with the new color.
      _lastDefaultStyle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);

    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: AppFontSize.sm,
      color: widget.isError ? c.errorText : c.primaryText,
      height: AppLineHeight.relaxed,
    );

    // Re-parse only when _visibleText or defaultStyle actually changed.
    if (_lastDefaultStyle != defaultStyle) {
      _recomputeSpans(defaultStyle);
    }

    final labelColor = widget.isError ? c.red : c.mutedText;
    final borderColor = widget.isError ? c.errorBorder : c.border;
    final bgColor = widget.isError ? c.errorBg : c.bg;

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
          // Section header
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
                if (widget.isError)
                  Padding(
                    padding:
                        const EdgeInsets.only(right: AppSpacing.xxs2),
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
                  '$_totalLines line${_totalLines == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.lineNumberText,
                    fontSize: AppFontSize.xxs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _CopyButton(
                  text: AnsiParser.strip(widget.output),
                  iconSize: 13,
                ),
              ],
            ),
          ),
          // Output text
          Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: SelectableText.rich(
              TextSpan(children: _parsedSpans),
            ),
          ),
          // Show more / show less button
          if (_needsTruncation)
            _ShowMoreButton(
              expanded: widget.expanded,
              hiddenCount: _totalLines - widget.maxLines,
              onToggle: widget.onToggleExpand,
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
      padding: const EdgeInsets.only(top: AppSpacing.xsm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs - 1,
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
                const SizedBox(width: AppSpacing.xxs2),
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
        ],
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xsm),
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
            const SizedBox(width: AppSpacing.xs),
            Text(
              expanded
                  ? 'Show less'
                  : 'Show $hiddenCount more line'
                      '${hiddenCount == 1 ? '' : 's'}',
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
    await Clipboard.setData(ClipboardData(text: widget.text));
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

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Small all-caps section label (e.g. "COMMAND", "OUTPUT").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 0.8,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier'],
      ),
    );
  }
}

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
    final dir =
        lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
    final filename =
        lastSlash >= 0 ? path.substring(lastSlash + 1) : path;

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
            size: 13,
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
