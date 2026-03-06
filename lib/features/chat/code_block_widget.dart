import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'syntax_highlighter.dart';

// Catppuccin Mocha palette constants
const _mocha = _MochaColors();

class _MochaColors {
  const _MochaColors();

  // Base surfaces
  Color get base => const Color(0xFF1E1E2E);
  Color get mantle => const Color(0xFF181825);
  Color get crust => const Color(0xFF11111B);
  Color get surface0 => const Color(0xFF313244);
  Color get surface1 => const Color(0xFF45475A);
  Color get overlay0 => const Color(0xFF6C7086);
  Color get subtext0 => const Color(0xFFA6ADC8);
  Color get text => const Color(0xFFCDD6F4);
  Color get green => const Color(0xFFA6E3A1);
  Color get red => const Color(0xFFF38BA8);
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
  bool _copied = false;

  /// Estimated line height in logical pixels (font size * line height ratio).
  double get _lineHeight => widget.fontSize * 1.5;

  /// Number of lines in the code.
  int get _lineCount => '\n'.allMatches(widget.code).length + 1;

  /// Whether the code needs vertical scrolling.
  bool get _needsVerticalScroll => _lineCount > widget.maxVisibleLines;

  /// Max height before vertical scrolling kicks in.
  double get _maxHeight =>
      widget.maxVisibleLines * _lineHeight +
      AppSpacing.md * 2; // top + bottom padding

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    final bgColor = isDark ? _mocha.crust : const Color(0xFFF1F5F9);
    final borderColor = isDark ? _mocha.surface0 : const Color(0xFFD0D7DE);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CodeHeader(
            language: widget.language,
            fileName: widget.fileName,
            isDark: isDark,
            copied: _copied,
            onCopy: _copyToClipboard,
          ),
          if (_needsVerticalScroll)
            SizedBox(height: _maxHeight, child: _buildScrollableCode(isDark))
          else
            _buildScrollableCode(isDark),
        ],
      ),
    );
  }

  /// Builds the horizontally (and optionally vertically) scrollable code area.
  Widget _buildScrollableCode(bool isDark) {
    final verticalScroll = SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: _buildCodeRow(isDark),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: verticalScroll,
    );
  }

  Widget _buildCodeRow(bool isDark) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLineNumbers)
            _LineNumbers(
              lineCount: _lineCount,
              fontSize: widget.fontSize,
              lineHeight: _lineHeight,
              isDark: isDark,
            ),
          Padding(
            padding: EdgeInsets.only(
              left: widget.showLineNumbers ? AppSpacing.md : AppSpacing.lg,
              right: AppSpacing.lg,
            ),
            child: SyntaxHighlighter(
              code: widget.code,
              language: widget.language,
              isDarkMode: isDark,
              fontSize: widget.fontSize,
              lineHeight: _lineHeight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

/// Header bar showing language name, optional filename, and copy button.
class _CodeHeader extends StatelessWidget {
  const _CodeHeader({
    required this.language,
    required this.fileName,
    required this.isDark,
    required this.copied,
    required this.onCopy,
  });
  final String? language;
  final String? fileName;
  final bool isDark;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final headerBg = isDark ? _mocha.mantle : const Color(0xFFEFF1F3);
    final dividerColor = isDark ? _mocha.surface0 : const Color(0xFFD0D7DE);
    final labelColor = isDark ? _mocha.subtext0 : const Color(0xFF6E7781);

    final displayName = _resolveDisplayName();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: headerBg,
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
                color: _languageColor(language),
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
                fontSize: 12,
                color: labelColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          const Spacer(),
          // Copy button – always visible
          _CopyButton(copied: copied, isDark: isDark, onTap: onCopy),
        ],
      ),
    );
  }

  /// Returns filename if available, otherwise the normalised language name.
  String? _resolveDisplayName() {
    if (fileName != null && fileName!.isNotEmpty) return fileName;
    final detected = detectLanguage(language);
    return detected ?? language;
  }

  /// Returns a subtle accent colour associated with the language.
  Color _languageColor(String? lang) {
    final normalized = lang?.toLowerCase() ?? '';
    return switch (normalized) {
      'dart' => const Color(0xFF00B4AB),
      'flutter' => const Color(0xFF54C5F8),
      'python' || 'py' => const Color(0xFF3572A5),
      'javascript' || 'js' || 'jsx' => const Color(0xFFF1E05A),
      'typescript' || 'ts' || 'tsx' => const Color(0xFF3178C6),
      'rust' || 'rs' => const Color(0xFFDEA584),
      'go' || 'golang' => const Color(0xFF00ADD8),
      'swift' => const Color(0xFFF05138),
      'kotlin' || 'kt' => const Color(0xFFA97BFF),
      'java' => const Color(0xFFB07219),
      'ruby' || 'rb' => const Color(0xFF701516),
      'bash' || 'sh' || 'shell' => const Color(0xFF89E051),
      'css' || 'scss' || 'sass' => const Color(0xFF563D7C),
      'html' || 'xml' => const Color(0xFFE34C26),
      'json' => const Color(0xFF6B8E23),
      'sql' => const Color(0xFFE38C00),
      'yaml' || 'yml' => const Color(0xFFCB171E),
      'markdown' || 'md' => const Color(0xFF083FA1),
      _ => const Color(0xFF8B949E),
    };
  }
}

/// Animated copy button with "Copied!" feedback.
class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.copied,
    required this.isDark,
    required this.onTap,
  });
  final bool copied;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = copied
        ? (isDark ? _mocha.green : const Color(0xFF1A7F37))
        : (isDark ? _mocha.overlay0 : const Color(0xFF6E7781));

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
                    fontSize: 11,
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

/// Left column displaying line numbers.
class _LineNumbers extends StatelessWidget {
  const _LineNumbers({
    required this.lineCount,
    required this.fontSize,
    required this.lineHeight,
    required this.isDark,
  });
  final int lineCount;
  final double fontSize;
  final double lineHeight;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final numColor = isDark ? _mocha.surface1 : const Color(0xFF8C959F);
    final dividerColor = isDark ? _mocha.surface0 : const Color(0xFFD0D7DE);

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(lineCount, (i) {
          return SizedBox(
            height: lineHeight,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                color: numColor,
                height: 1.0,
              ),
            ),
          );
        }),
      ),
    );
  }
}
