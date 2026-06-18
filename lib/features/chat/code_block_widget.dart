import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/code_viewer_theme.dart';
import '../../core/theme/language_colors.dart';
import '../../core/utils/clipboard_utils.dart';
import 'syntax_highlighter.dart';

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

  /// Maximum number of visible lines before scrolling.
  final int maxVisibleLines;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  static const int _maxDisplayedCodeUnits = 100000;
  static const int _maxDisplayedLines = 2000;
  bool _copied = false;

  /// Cached line count — computed once and updated only when [widget.code]
  /// changes, avoiding repeated `allMatches` scans on every build.
  late int _lineCount;
  late String _displayCode;
  late bool _isTruncated;

  // Explicit, non-primary controllers so the code pane scrolls independently
  // of the ambient PrimaryScrollController (shared by the chat list). Without
  // them a vertical drag on the code block bounced back instead of scrolling.
  late final ScrollController _vController;
  late final ScrollController _hController;

  /// Estimated line height in logical pixels (font size * line height ratio).
  double get _lineHeight => widget.fontSize * 1.5;

  /// Whether the code needs vertical scrolling.
  bool get _needsVerticalScroll => _lineCount > widget.maxVisibleLines;

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
    _lineCount = '\n'.allMatches(_displayCode).length + 1;
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

  /// Max height before vertical scrolling kicks in.
  double get _maxHeight =>
      widget.maxVisibleLines * _lineHeight +
      AppSpacing.md * 2; // top + bottom padding

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    // Resolve the chrome palette once per build. Both light and dark
    // themes register `CodeViewerTheme`, so this is always non-null.
    final codeViewer = isDark ? CodeViewerTheme.dark : CodeViewerTheme.light;

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
            onCopy: _copyToClipboard,
          ),
          if (_needsVerticalScroll)
            SizedBox(
              height: _maxHeight,
              child: _buildScrollableCode(isDark, codeViewer),
            )
          else
            _buildScrollableCode(isDark, codeViewer),
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

  /// Builds the horizontally (and optionally vertically) scrollable code area.
  Widget _buildScrollableCode(bool isDark, CodeViewerTheme codeViewer) {
    final verticalScroll = SingleChildScrollView(
      controller: _vController,
      primary: false,
      physics: const ClampingScrollPhysics(),
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: _buildCodeRow(isDark, codeViewer),
    );

    return SingleChildScrollView(
      controller: _hController,
      primary: false,
      scrollDirection: Axis.horizontal,
      child: verticalScroll,
    );
  }

  Widget _buildCodeRow(bool isDark, CodeViewerTheme codeViewer) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLineNumbers)
          _LineNumbers(
            lineCount: _lineCount,
            fontSize: widget.fontSize,
            lineHeight: _lineHeight,
            codeViewer: codeViewer,
          ),
        Padding(
          padding: EdgeInsets.only(
            left: widget.showLineNumbers ? AppSpacing.md : AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: SyntaxHighlighter(
            code: _displayCode,
            language: widget.language,
            isDarkMode: isDark,
            fontSize: widget.fontSize,
            lineHeight: _lineHeight,
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
}

/// Header bar showing language name, optional filename, and copy button.
class _CodeHeader extends StatefulWidget {
  const _CodeHeader({
    required this.language,
    required this.fileName,
    required this.codeViewer,
    required this.copied,
    required this.onCopy,
  });
  final String? language;
  final String? fileName;
  final CodeViewerTheme codeViewer;
  final bool copied;
  final VoidCallback onCopy;

  @override
  State<_CodeHeader> createState() => _CodeHeaderState();
}

class _CodeHeaderState extends State<_CodeHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.codeViewer.headerBackground;
    final hoverBg = widget.codeViewer.headerHover;
    final dividerColor = widget.codeViewer.divider;
    final labelColor = widget.codeViewer.headerLabel;

    final displayName = _resolveDisplayName();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        height: 36,
        decoration: BoxDecoration(
          color: _hovered ? hoverBg : headerBg,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            // Language dot indicator
            if (displayName != null) ...[
              Container(
                width: AppSpacing.xs,
                height: AppSpacing.xs,
                decoration: BoxDecoration(
                  color: _languageColor(widget.language),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xsm),
            ],
            // Language / file name label
            if (displayName != null)
              Text(
                displayName,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.sm,
                  color: labelColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            const Spacer(),
            // Copy button – always visible, more discoverable on hover
            _CopyButton(
              copied: widget.copied,
              codeViewer: widget.codeViewer,
              onTap: widget.onCopy,
            ),
          ],
        ),
      ),
    );
  }

  /// Returns filename if available, otherwise the normalised language name.
  String? _resolveDisplayName() {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return widget.fileName;
    }
    final detected = detectLanguage(widget.language);
    return detected ?? widget.language;
  }

  /// Returns a subtle accent colour associated with the language.
  ///
  /// Delegates to the canonical [colorForLanguage] lookup in
  /// `core/theme/language_colors.dart` so all language→colour
  /// mappings live in a single place.
  Color _languageColor(String? lang) => colorForLanguage(lang);
}

/// Animated copy button with "Copied!" feedback.
class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.copied,
    required this.codeViewer,
    required this.onTap,
  });
  final bool copied;
  final CodeViewerTheme codeViewer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = copied
        ? codeViewer.successAccent
        : codeViewer.idleAccent;

    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: copied ? l10n.commonCopied : l10n.commonCopyCode,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: AnimatedSwitcher(
            duration: AppDuration.fast,
            switchInCurve: AppCurve.enter,
            switchOutCurve: AppCurve.exit,
            child: Row(
              key: ValueKey(copied),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  copied ? Icons.check_rounded : Icons.content_copy_rounded,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  copied ? l10n.commonCopied : l10n.commonCopy,
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: iconColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice({
    required this.originalChars,
    required this.displayedChars,
    required this.codeViewer,
  });

  final int originalChars;
  final int displayedChars;
  final CodeViewerTheme codeViewer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: codeViewer.headerBackground,
        border: Border(
          top: BorderSide(color: codeViewer.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        'Showing $displayedChars of $originalChars characters',
        style: TextStyle(
          color: codeViewer.muted,
          fontSize: AppFontSize.sm,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Left column displaying line numbers.
///
/// Uses a single [Text] widget with all line numbers joined by `\n` instead
/// of one widget per line, reducing the widget count from O(N) to O(1) for
/// large code blocks.
class _LineNumbers extends StatelessWidget {
  const _LineNumbers({
    required this.lineCount,
    required this.fontSize,
    required this.lineHeight,
    required this.codeViewer,
  });
  final int lineCount;
  final double fontSize;
  final double lineHeight;
  final CodeViewerTheme codeViewer;

  @override
  Widget build(BuildContext context) {
    final lineNumbers = List.generate(lineCount, (i) => '${i + 1}').join('\n');

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: codeViewer.divider)),
      ),
      child: Text(
        lineNumbers,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          color: codeViewer.lineNumberText,
          height: lineHeight / fontSize,
        ),
      ),
    );
  }
}
