import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/mmkv_storage.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/code_viewer_theme.dart';
import '../../core/theme/language_colors.dart';
import '../../core/utils/clipboard_utils.dart';
import 'syntax_highlighter.dart';

part 'code_block_chrome.dart';

/// App-wide soft-wrap preference for code blocks.
///
/// The toggle in a code block header is not per-block: flipping it updates
/// every mounted [CodeBlockWidget] through [notifier] and persists the choice
/// in MMKV so it survives restarts.
class CodeBlockWrapPreference {
  CodeBlockWrapPreference._();

  /// MMKV key backing the preference.
  static const String storageKey = 'code-block-soft-wrap';

  static final ValueNotifier<bool> _notifier = ValueNotifier<bool>(
    MMKVStorage().getBool(storageKey) ?? false,
  );

  /// Listenable used by [CodeBlockWidget] to rebuild on preference changes.
  static ValueListenable<bool> get notifier => _notifier;

  /// Whether long lines currently soft-wrap instead of scrolling sideways.
  static bool get wrapLines => _notifier.value;

  /// Sets the preference and persists it.
  static void setWrapLines(bool value) {
    if (_notifier.value == value) return;
    _notifier.value = value;
    MMKVStorage().setBool(storageKey, value);
  }

  /// Flips the preference.
  static void toggle() => setWrapLines(!_notifier.value);

  /// Restores the default (no wrapping) — tests only.
  @visibleForTesting
  static void resetForTest() => _notifier.value = false;
}

/// Widget for displaying a code block with syntax highlighting, copy button,
/// line numbers, and language header.
class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({
    required this.code,
    super.key,
    this.language,
    this.fileName,
    this.showLineNumbers = true,
    this.isDarkMode,
    this.fontSize = 13,
    this.maxVisibleLines = 12,
    this.allowExpand = true,
    this.fullScreen = false,
  });

  /// The source code to display.
  final String code;

  /// Language identifier (e.g., 'dart', 'python', 'bash').
  final String? language;

  /// Optional filename to display in the header.
  final String? fileName;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Override dark mode. When null, follows the ambient [ThemeData] brightness.
  final bool? isDarkMode;

  /// Font size for code text.
  final double fontSize;

  /// Maximum number of lines rendered inline before the block is clipped and
  /// the reader is pointed at the full-screen viewer.
  final int maxVisibleLines;

  /// Whether the header offers a full-screen reader.
  final bool allowExpand;

  /// Whether this instance is the full-screen reader.
  ///
  /// Inline blocks never scroll vertically — they live inside the chat list,
  /// and a nested vertical scrollable there steals the conversation drag.
  /// The full-screen reader owns the viewport, so it may scroll freely.
  final bool fullScreen;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  static const int _maxDisplayedCodeUnits = 100000;
  static const int _maxDisplayedLines = 2000;

  /// Approximate advance width of a monospace glyph relative to font size.
  /// Used to size the line-number gutter in wrapped mode.
  static const double _monospaceAdvanceRatio = 0.62;

  bool _copied = false;

  /// Cached line data — computed once and updated only when [widget.code]
  /// changes, avoiding repeated scans on every build.
  late List<String> _displayLines;
  late String _displayCode;
  late bool _isTruncated;

  // Explicit, non-primary controller so the full-screen reader scrolls
  // independently of the ambient PrimaryScrollController.
  late final ScrollController _vController;
  late final ScrollController _hController;

  /// Estimated line height in logical pixels (font size * line height ratio).
  double get _lineHeight => widget.fontSize * 1.5;

  /// Number of logical lines actually rendered.
  int get _visibleLineCount => widget.fullScreen
      ? _displayLines.length
      : (_displayLines.length < widget.maxVisibleLines
            ? _displayLines.length
            : widget.maxVisibleLines);

  /// Whether lines were clipped away from an inline block.
  bool get _hasHiddenLines => _visibleLineCount < _displayLines.length;

  /// The rendered subset of [_displayLines].
  List<String> get _visibleLines => _hasHiddenLines
      ? _displayLines.sublist(0, _visibleLineCount)
      : _displayLines;

  @override
  void initState() {
    super.initState();
    _vController = ScrollController();
    _hController = ScrollController();
    _updateDisplayCode();
  }

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateDisplayCode();
    }
  }

  void _updateDisplayCode() {
    _displayCode = _truncateForDisplay(widget.code);
    _isTruncated = _displayCode.length != widget.code.length;
    _displayLines = _displayCode.split('\n');
  }

  String _truncateForDisplay(String code) {
    var lines = 1;
    var end = code.length < _maxDisplayedCodeUnits
        ? code.length
        : _maxDisplayedCodeUnits;
    for (var i = 0; i < end; i++) {
      if (code.codeUnitAt(i) == 10) {
        lines++;
        if (lines > _maxDisplayedLines) {
          end = i;
          break;
        }
      }
    }
    return end == code.length ? code : code.substring(0, end);
  }

  /// Width of the line-number gutter in wrapped mode.
  double get _gutterWidth {
    final digits = '$_visibleLineCount'.length;
    return digits * widget.fontSize * _monospaceAdvanceRatio +
        AppSpacing.md +
        AppSpacing.sm +
        AppSpacing.xs;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CodeBlockWrapPreference.notifier,
      builder: (context, wrapLines, _) => _buildBlock(context, wrapLines),
    );
  }

  Widget _buildBlock(BuildContext context, bool wrapLines) {
    final isDark =
        widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    // Resolve the chrome palette once per build. Both light and dark
    // themes register `CodeViewerTheme`, so this is always non-null.
    final codeViewer = isDark ? CodeViewerTheme.dark : CodeViewerTheme.light;

    final body = _buildBody(isDark, codeViewer, wrapLines);

    return Container(
      decoration: BoxDecoration(
        color: codeViewer.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: codeViewer.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CodeHeader(
            language: widget.language,
            fileName: widget.fileName,
            codeViewer: codeViewer,
            copied: _copied,
            wrapLines: wrapLines,
            onCopy: _copyToClipboard,
            onToggleWrap: CodeBlockWrapPreference.toggle,
            onExpand: widget.allowExpand ? _showExpanded : null,
          ),
          if (widget.fullScreen) Expanded(child: body) else body,
          if (_hasHiddenLines)
            _MoreLinesFooter(
              hiddenLines: _displayLines.length - _visibleLineCount,
              codeViewer: codeViewer,
              onExpand: widget.allowExpand ? _showExpanded : null,
            ),
          if (_isTruncated)
            _TruncatedNotice(
              originalChars: widget.code.length,
              displayedChars: _displayCode.length,
              codeViewer: codeViewer,
            ),
        ],
      ),
    );
  }

  /// Builds the code area.
  ///
  /// Inline blocks never nest a vertical scrollable inside the chat list —
  /// overflow is clipped and delegated to the full-screen reader instead.
  Widget _buildBody(bool isDark, CodeViewerTheme codeViewer, bool wrapLines) {
    if (wrapLines) {
      return widget.fullScreen
          ? _buildWrappedList(isDark, codeViewer)
          : _buildWrappedColumn(isDark, codeViewer);
    }

    final row = _buildUnwrappedRow(isDark, codeViewer);
    if (!widget.fullScreen) return row;
    return Scrollbar(
      controller: _vController,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical,
      child: SingleChildScrollView(
        controller: _vController,
        primary: false,
        child: row,
      ),
    );
  }

  /// Horizontal-scroll mode: one [SyntaxHighlighter] for the whole block with
  /// a pinned line-number gutter that does not scroll sideways.
  Widget _buildUnwrappedRow(bool isDark, CodeViewerTheme codeViewer) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLineNumbers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: _LineNumbers(
              lineCount: _visibleLineCount,
              fontSize: widget.fontSize,
              lineHeight: _lineHeight,
              codeViewer: codeViewer,
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _hController,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _hController,
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.showLineNumbers ? AppSpacing.md : AppSpacing.lg,
                  right: AppSpacing.lg,
                ),
                child: SyntaxHighlighter(
                  code: _visibleLines.join('\n'),
                  language: widget.language,
                  isDarkMode: isDark,
                  fontSize: widget.fontSize,
                  lineHeight: _lineHeight,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wrapped mode, inline: a bounded column of per-logical-line rows.
  Widget _buildWrappedColumn(bool isDark, CodeViewerTheme codeViewer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _visibleLineCount; i++)
            _wrappedLine(i, isDark, codeViewer),
        ],
      ),
    );
  }

  /// Wrapped mode, full screen: lazily built rows so a 2000-line file does
  /// not materialise every line at once.
  Widget _buildWrappedList(bool isDark, CodeViewerTheme codeViewer) {
    return Scrollbar(
      controller: _vController,
      child: ListView.builder(
        controller: _vController,
        primary: false,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: _visibleLineCount,
        itemBuilder: (context, index) =>
            _wrappedLine(index, isDark, codeViewer),
      ),
    );
  }

  /// One logical line in wrapped mode.
  ///
  /// The number and the code share a top-aligned [Row], so a logical line that
  /// wraps over several visual rows still gets exactly one number, aligned
  /// with its first visual row.
  Widget _wrappedLine(int index, bool isDark, CodeViewerTheme codeViewer) {
    // Blank lines render a single space so the row keeps a full line height
    // and the number stays aligned with the code column.
    final line = _visibleLines[index].isEmpty ? ' ' : _visibleLines[index];
    return Row(
      key: ValueKey<String>('code-line-${index + 1}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLineNumbers)
          SizedBox(
            width: _gutterWidth,
            child: Container(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.sm + AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: codeViewer.divider),
                ),
              ),
              child: Text(
                '${index + 1}',
                key: ValueKey<String>('code-line-number-${index + 1}'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: widget.fontSize,
                  color: codeViewer.lineNumberText,
                  height: _lineHeight / widget.fontSize,
                ),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.showLineNumbers ? AppSpacing.md : AppSpacing.lg,
              right: AppSpacing.lg,
            ),
            // Highlighting is per logical line in wrapped mode; multi-line
            // constructs (block comments) lose cross-line context, which is
            // an accepted trade for correct number alignment.
            child: SyntaxHighlighter(
              code: line,
              language: widget.language,
              isDarkMode: isDark,
              fontSize: widget.fontSize,
              lineHeight: _lineHeight,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard() async {
    await setClipboardTextSafely(widget.code);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showExpanded() {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.fileName ??
                widget.language ??
                AppLocalizations.of(dialogContext).codeBlockTitle,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: MaterialLocalizations.of(dialogContext).closeButtonTooltip,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: CodeBlockWidget(
              code: widget.code,
              language: widget.language,
              fileName: widget.fileName,
              showLineNumbers: widget.showLineNumbers,
              isDarkMode: widget.isDarkMode,
              fontSize: widget.fontSize,
              allowExpand: false,
              fullScreen: true,
            ),
          ),
        ),
      ),
    );
  }
}
