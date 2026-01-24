import 'package:flutter/material.dart';
import 'syntax_highlighter.dart';

/// Widget for displaying a code block with syntax highlighting, copy button,
/// and language badge.
class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String? language;
  final bool showLineNumbers;
  final bool isDarkMode;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const CodeBlockWidget({
    super.key,
    required this.code,
    this.language,
    this.showLineNumbers = false,
    this.isDarkMode = false,
    this.fontSize = 14,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _showCopyButton = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF8F8F8);
    final borderColor = widget.isDarkMode
        ? const Color(0xFF303030)
        : const Color(0xFFE0E0E0);

    return MouseRegion(
      onEnter: (_) => setState(() => _showCopyButton = true),
      onExit: (_) => setState(() => _showCopyButton = false),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with language badge and copy button
            _buildHeader(theme),
            // Code content
            Padding(
              padding: widget.padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showLineNumbers) _buildLineNumbers(),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SyntaxHighlighter(
                        code: widget.code,
                        language: widget.language,
                        isDarkMode: widget.isDarkMode,
                        fontSize: widget.fontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final headerBackground = widget.isDarkMode
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF0F0F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: headerBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        border: Border(
          bottom: BorderSide(
            color: widget.isDarkMode
                ? const Color(0xFF303030)
                : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Language badge
          if (widget.language != null)
            _buildLanguageBadge(theme),
          const Spacer(),
          // Copy button (hover-to-reveal)
          AnimatedOpacity(
            opacity: _showCopyButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: _buildCopyButton(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageBadge(ThemeData theme) {
    final detectedLanguage = detectLanguage(widget.language);
    final badgeColor = widget.isDarkMode
        ? const Color(0xFF38383A)
        : const Color(0xFFE5E5EA);
    final textColor = widget.isDarkMode
        ? const Color(0xFF8E8E93)
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        detectedLanguage ?? widget.language!.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCopyButton(ThemeData theme) {
    final iconColor = widget.isDarkMode
        ? const Color(0xFFCAC4D0)
        : const Color(0xFF49454F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copyToClipboard,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.content_copy,
                size: 14,
                color: iconColor,
              ),
              if (_copied)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Copied',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: iconColor,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineNumbers() {
    final lines = widget.code.split('\n');
    final textColor = widget.isDarkMode
        ? const Color(0xFF6E7681)
        : const Color(0xFF959DA5);
    final backgroundColor = widget.isDarkMode
        ? const Color(0xFF161B22)
        : const Color(0xFFF6F8FA);

    return Container(
      padding: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: lines.map((_) {
          return Text(
            '',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: widget.fontSize,
              color: textColor,
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }
}
