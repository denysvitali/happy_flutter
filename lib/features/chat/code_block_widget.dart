import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/services/mmkv_storage.dart';
import '../../core/theme/app_color_scheme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/code_viewer_theme.dart';
import '../../core/theme/language_colors.dart';
import '../../core/utils/clipboard_utils.dart';
import '../../core/utils/syntax_cache.dart';
import 'code_block_line_spans.dart';
import 'syntax_highlighter.dart';

part 'code_block_chrome.dart';

/// Opacity of gutter digits: line numbers stay legible but recede behind
/// the code they index. Shared by both gutters (joined and per-line) across
/// the library — a `part` file can only see library-level declarations, not
/// another class's statics.
const double _gutterDigitAlpha = 0.72;

/// App-wide soft-wrap preference for code blocks.
///
/// The toggle in a code block header is not per-block: flipping it updates
/// every mounted [CodeBlockWidget] through [notifier] and persists the choice
/// in MMKV so it survives restarts.
class CodeBlockWrapPreference {
  CodeBlockWrapPreference._();

  /// MMKV key backing the preference.
  static const String storageKey = 'code-block-soft-wrap';

  static final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);

  /// Whether a persisted value has been observed. Until it has, every mount
  /// re-reads MMKV: the first code block can easily build before
  /// `Storage().initialize()` has run, and a static field initialiser would
  /// have latched the resulting `null` as `false` for the process lifetime.
  static bool _loadedFromStorage = false;

  /// Reads the persisted preference if it has not been read yet.
  ///
  /// Cheap and idempotent — a map lookup that stops re-trying as soon as
  /// storage answers with a real value.
  static void ensureLoaded() {
    if (_loadedFromStorage) return;
    final stored = MMKVStorage().getBool(storageKey);
    if (stored == null) return;
    _loadedFromStorage = true;
    if (_notifier.value == stored) return;
    _applyWhenSafe(stored);
  }

  /// Publishes [value] outside the build phase.
  ///
  /// [ensureLoaded] runs from `initState`, which is inside a build; notifying
  /// listeners there would mark already-built code blocks dirty mid-frame.
  static void _applyWhenSafe(bool value) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _notifier.value = value;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifier.value = value;
    });
  }

  /// Listenable used by [CodeBlockWidget] to rebuild on preference changes.
  static ValueListenable<bool> get notifier => _notifier;

  /// Whether long lines currently soft-wrap instead of scrolling sideways.
  static bool get wrapLines => _notifier.value;

  /// Sets the preference and persists it.
  static void setWrapLines(bool value) {
    // An explicit choice supersedes anything still unread in storage.
    _loadedFromStorage = true;
    if (_notifier.value == value) return;
    _notifier.value = value;
    MMKVStorage().setBool(storageKey, value);
  }

  /// Flips the preference.
  static void toggle() => setWrapLines(!_notifier.value);

  /// Restores the default (no wrapping) and drops the persisted value —
  /// tests only.
  @visibleForTesting
  static void resetForTest() {
    _loadedFromStorage = false;
    _notifier.value = false;
    MMKVStorage().removeKey(storageKey);
  }
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
    this.isStreaming = false,
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

  /// Explicit streaming marker from the caller. While true (or while the
  /// content is detected to be append-growing), only a bounded plain-text
  /// tail renders; full tokenization runs once streaming settles.
  final bool isStreaming;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  static const int _maxDisplayedCodeUnits = 100000;
  static const int _maxDisplayedLines = 2000;

  /// How long content must stop growing before an append-detected stream is
  /// considered complete and the full block is tokenized.
  static const Duration _streamSettleDelay = Duration(milliseconds: 2000);

  /// Approximate advance width of a monospace glyph relative to font size.
  /// Used to size the line-number gutter in wrapped mode.
  static const double _monospaceAdvanceRatio = 0.62;

  /// Thickness of the vertical rule separating gutter from code.
  static const double _gutterRuleWidth = 1;

  bool _copied = false;

  /// Cached line data — computed once and updated only when [widget.code]
  /// changes, avoiding repeated scans on every build.
  late List<String> _displayLines;
  late String _displayCode;
  late bool _isTruncated;

  /// Memoised wrapped-mode spans and the brightness they were built for.
  List<List<TextSpan>>? _cachedLineSpans;
  bool? _cachedSpansDark;

  /// Whether the block is believed to be mid-stream. While true the block
  /// renders a bounded plain-text tail ([syntaxStreamingTailUnits]) without
  /// touching the shared token cache; the highlighted full block is built
  /// once streaming ends. See [didUpdateWidget] for how this is detected.
  bool _streaming = false;
  Timer? _settleTimer;

  /// Memoised inline wrapped-line count and the inputs it was measured
  /// against, so unchanged blocks do not relayout on every rebuild.
  int? _wrappedInlineCount;
  double? _wrappedCountWidth;
  double? _wrappedCountFontSize;
  double? _wrappedCountScale;

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
    CodeBlockWrapPreference.ensureLoaded();
    _streaming = widget.isStreaming;
    _updateDisplayCode();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    var invalidate = false;
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language) {
      invalidate = true;
    }
    if (widget.isStreaming || oldWidget.isStreaming) {
      // Explicit signal from the caller wins.
      _settleTimer?.cancel();
      if (_streaming != widget.isStreaming) invalidate = true;
      _streaming = widget.isStreaming;
    } else if (_grewByAppend(oldWidget)) {
      // No explicit signal: infer streaming from append-only growth and
      // stay on the cheap path until growth quiets down.
      if (!_streaming) invalidate = true;
      _streaming = true;
      _armSettleTimer();
    } else if (_streaming) {
      _settleTimer?.cancel();
      _streaming = false;
      invalidate = true;
    }
    if (invalidate) _updateDisplayCode();
  }

  /// Whether [widget.code] is [oldWidget.code] plus appended characters —
  /// the shape of a streaming delta.
  bool _grewByAppend(CodeBlockWidget oldWidget) =>
      widget.code.length > oldWidget.code.length &&
      widget.code.startsWith(oldWidget.code);

  void _armSettleTimer() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_streamSettleDelay, () {
      _settleTimer = null;
      if (!mounted || !_streaming) return;
      setState(() {
        _streaming = false;
        _updateDisplayCode();
      });
    });
  }

  void _updateDisplayCode() {
    var code = widget.code;
    if (_streaming && code.length > syntaxStreamingTailUnits) {
      // Mid-stream the growing block must not re-tokenize (and evict the
      // shared token cache) on every delta; render a bounded plain tail,
      // matching MarkdownView's streaming behavior, and swap in the
      // highlighted full block once streaming ends.
      code = '…${code.substring(code.length - syntaxStreamingTailUnits)}';
    }
    _displayCode = _truncateForDisplay(code);
    _isTruncated = !_streaming && _displayCode.length != code.length;
    _displayLines = _displayCode.split('\n');
    _cachedLineSpans = null;
    _wrappedInlineCount = null;
  }

  /// Per-logical-line spans for wrapped mode, tokenised once for the whole
  /// block and memoised until the code, language, or palette changes.
  List<TextSpan> _lineSpans(bool isDark, int index) {
    if (_streaming) {
      // Streaming snapshots must not enter the shared token cache (see
      // SyntaxTokenCache.get), so wrapped mode renders plain spans instead
      // of going through buildCodeLineSpans; full styling returns when the
      // stream settles.
      final line = _displayLines[index];
      return line.isEmpty
          ? const <TextSpan>[TextSpan(text: ' ')]
          : <TextSpan>[TextSpan(text: line)];
    }
    if (_cachedLineSpans == null || _cachedSpansDark != isDark) {
      _cachedLineSpans = buildCodeLineSpans(
        code: _displayCode,
        language: widget.language,
        isDarkMode: isDark,
      );
      _cachedSpansDark = isDark;
    }
    final lines = _cachedLineSpans!;
    final spans = index < lines.length ? lines[index] : const <TextSpan>[];
    // Blank lines render a single space so the row keeps a full line height
    // and its number stays aligned with the code column.
    if (spans.isEmpty) return const <TextSpan>[TextSpan(text: ' ')];
    return spans;
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

  /// Maximum inline height, matching the horizontal-scroll mode's cap of
  /// [CodeBlockWidget.maxVisibleLines] rendered rows plus vertical padding.
  double get _maxInlineHeight =>
      widget.maxVisibleLines * _lineHeight + AppSpacing.md * 2;

  /// Text style shared by every code row; also used to measure wrapping.
  TextStyle get _codeTextStyle => TextStyle(
    fontFamily: 'monospace',
    fontSize: widget.fontSize,
    height: _lineHeight / widget.fontSize,
    decoration: TextDecoration.none,
  );

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
    // Wrapped inline mode only knows how many lines it could fit once it has
    // a width, so it renders its own footer from inside a LayoutBuilder.
    final ownsFooter = wrapLines && !widget.fullScreen;

    return Container(
      decoration: BoxDecoration(
        color: codeViewer.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Hairline glass seam instead of the old full-strength border: the
        // block edge reads as a pane boundary, not a drawn frame.
        border: Border.all(
          color: _glassOf(context).glassBorder,
          width: AppBorder.hairline,
        ),
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
          if (!ownsFooter && _hasHiddenLines)
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
                  isStreaming: _streaming,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wrapped mode, inline: a height-bounded column of per-logical-line rows.
  ///
  /// A single very long logical line (minified JSON, a long log line) wraps
  /// into many visual rows, so clipping by logical line alone would let an
  /// inline block grow taller than the screen inside the chat list. The rows
  /// that fit [CodeBlockWidget.maxVisibleLines] *visual* rows are measured
  /// here, the rest are delegated to the full-screen reader through the same
  /// footer horizontal-scroll mode uses, and a clip bounds the height even if
  /// the measurement and the final layout disagree.
  Widget _buildWrappedColumn(bool isDark, CodeViewerTheme codeViewer) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _wrappedInlineLineCount(context, constraints.maxWidth);
        final hidden = _displayLines.length - count;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _maxInlineHeight),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  fit: OverflowBoxFit.deferToChild,
                  child: _withGutterRule(
                    codeViewer,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < count; i++)
                            _wrappedLine(i, isDark, codeViewer),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hidden > 0)
              _MoreLinesFooter(
                hiddenLines: hidden,
                codeViewer: codeViewer,
                onExpand: widget.allowExpand ? _showExpanded : null,
              ),
          ],
        );
      },
    );
  }

  /// Wrapped mode, full screen: lazily built rows so a 2000-line file does
  /// not materialise every line at once.
  Widget _buildWrappedList(bool isDark, CodeViewerTheme codeViewer) {
    return _withGutterRule(
      codeViewer,
      Scrollbar(
        controller: _vController,
        child: ListView.builder(
          controller: _vController,
          primary: false,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          itemCount: _visibleLineCount,
          itemBuilder: (context, index) =>
              _wrappedLine(index, isDark, codeViewer),
        ),
      ),
    );
  }

  /// Draws the gutter rule as one continuous line behind [child].
  ///
  /// Per-row borders leave a gap wherever a logical line wraps, because the
  /// gutter box is only as tall as its number. Painting the rule once across
  /// the whole code area keeps it continuous, exactly like horizontal-scroll
  /// mode's single gutter.
  Widget _withGutterRule(CodeViewerTheme codeViewer, Widget child) {
    if (!widget.showLineNumbers) return child;
    return Stack(
      children: [
        child,
        Positioned(
          left: _gutterWidth - _gutterRuleWidth,
          top: 0,
          bottom: 0,
          width: _gutterRuleWidth,
          child: IgnorePointer(
            child: ColoredBox(
              key: const ValueKey<String>('code-gutter-rule'),
              color: codeViewer.divider,
            ),
          ),
        ),
      ],
    );
  }

  /// Number of logical lines an inline wrapped block can show before it hits
  /// its visual-row budget.
  ///
  /// Measures real wrapping with a [TextPainter] rather than estimating from
  /// character counts, so the footer's hidden-line count is exact for any
  /// font; the result is memoised against the content (reset in
  /// [_updateDisplayCode]), width, font size, and text scale so unchanged
  /// blocks skip relayout entirely. The first logical line is always
  /// rendered, even when it alone overflows the budget.
  int _wrappedInlineLineCount(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite) return _visibleLineCount;
    final gutter = widget.showLineNumbers
        ? _gutterWidth + AppSpacing.md
        : AppSpacing.lg;
    final codeWidth = maxWidth - gutter - AppSpacing.lg;
    if (codeWidth <= 0) return 1;

    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    // TextScaler instances lack value equality; compare a resolved probe.
    final scale = scaler.scale(10) / 10;
    if (!_streaming &&
        _wrappedInlineCount != null &&
        _wrappedCountWidth == codeWidth &&
        _wrappedCountFontSize == widget.fontSize &&
        _wrappedCountScale == scale) {
      return _wrappedInlineCount!;
    }
    // While streaming the content changes every tick, so exact per-line
    // TextPainter measurement would relayout the visible window on every
    // delta. A character-count estimate keeps those frames cheap; it is
    // replaced by exact metrics once the stream settles. The estimate may
    // be off by one visual row until then — the clip bounds the height.
    final count = _streaming
        ? _estimateWrappedInlineCount(scale, codeWidth)
        : _measureWrappedInlineCount(context, scaler, codeWidth);
    if (!_streaming) {
      _wrappedInlineCount = count;
      _wrappedCountWidth = codeWidth;
      _wrappedCountFontSize = widget.fontSize;
      _wrappedCountScale = scale;
    }
    return count;
  }

  int _measureWrappedInlineCount(
    BuildContext context,
    TextScaler scaler,
    double codeWidth,
  ) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
    );
    final budget = widget.maxVisibleLines;
    var rows = 0;
    var count = 0;
    for (final line in _displayLines) {
      painter
        ..text = TextSpan(
          text: line.isEmpty ? ' ' : line,
          style: _codeTextStyle,
        )
        ..layout(maxWidth: codeWidth);
      final metrics = painter.computeLineMetrics().length;
      final lineRows = metrics < 1 ? 1 : metrics;
      if (count > 0 && rows + lineRows > budget) break;
      rows += lineRows;
      count++;
      if (rows >= budget) break;
    }
    painter.dispose();
    return count;
  }

  /// Character-count estimate of the wrapped-row budget for streaming
  /// frames; stops as soon as the budget is reached.
  int _estimateWrappedInlineCount(double scale, double codeWidth) {
    final advance = widget.fontSize * _monospaceAdvanceRatio * scale;
    final budget = widget.maxVisibleLines;
    var rows = 0;
    var count = 0;
    for (final line in _displayLines) {
      final cols = line.isEmpty ? 1 : line.length;
      final lineRows = (cols * advance / codeWidth).ceil();
      if (count > 0 && rows + lineRows > budget) break;
      rows += lineRows;
      count++;
      if (rows >= budget) break;
    }
    return count;
  }

  /// One logical line in wrapped mode.
  ///
  /// The number and the code share a top-aligned [Row], so a logical line that
  /// wraps over several visual rows still gets exactly one number, aligned
  /// with its first visual row.
  Widget _wrappedLine(int index, bool isDark, CodeViewerTheme codeViewer) {
    // Blank lines render a single space so the row keeps a full line height
    // and the number stays aligned with the code column.
    final spans = _lineSpans(isDark, index);
    return Row(
      key: ValueKey<String>('code-line-${index + 1}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLineNumbers)
          SizedBox(
            width: _gutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.sm + AppSpacing.xs,
              ),
              child: Text(
                '${index + 1}',
                key: ValueKey<String>('code-line-number-${index + 1}'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: widget.fontSize,
                  color: codeViewer.lineNumberText.withValues(
                    alpha: _gutterDigitAlpha,
                  ),
                  height: _lineHeight / widget.fontSize,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
            // Spans come from one tokenisation of the whole block, so
            // multi-line constructs (block comments, multi-line strings,
            // heredocs) keep their styling across the lines they span.
            child: Text.rich(TextSpan(children: spans, style: _codeTextStyle)),
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
