part of 'code_block_widget.dart';

/// Header bar showing language name, wrap toggle, expand, and copy button.
class _CodeHeader extends StatefulWidget {
  const _CodeHeader({
    required this.language,
    required this.fileName,
    required this.codeViewer,
    required this.copied,
    required this.wrapLines,
    required this.onCopy,
    required this.onToggleWrap,
    required this.onExpand,
  });
  final String? language;
  final String? fileName;
  final CodeViewerTheme codeViewer;
  final bool copied;
  final bool wrapLines;
  final VoidCallback onCopy;
  final VoidCallback onToggleWrap;
  final VoidCallback? onExpand;

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
    final l10n = AppLocalizations.of(context);

    final displayName = _resolveDisplayName();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        height: AppTouchTarget.min - AppSpacing.sm,
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
              Flexible(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              onPressed: widget.onToggleWrap,
              icon: Icon(
                widget.wrapLines
                    ? Icons.wrap_text_rounded
                    : Icons.swap_horiz_rounded,
                size: AppFontSize.base,
              ),
              tooltip: widget.wrapLines
                  ? l10n.codeBlockDisableWrap
                  : l10n.codeBlockEnableWrap,
              color: labelColor,
              visualDensity: VisualDensity.compact,
            ),
            if (widget.onExpand != null)
              IconButton(
                onPressed: widget.onExpand,
                icon: const Icon(
                  Icons.open_in_full_rounded,
                  size: AppFontSize.base,
                ),
                tooltip: l10n.codeBlockOpenFullScreen,
                color: labelColor,
                visualDensity: VisualDensity.compact,
              ),
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
    final iconColor = copied ? codeViewer.successAccent : codeViewer.idleAccent;

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
                  size: AppFontSize.base,
                  color: iconColor,
                ),
                const SizedBox(width: AppSpacing.xs),
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

/// Footer shown when an inline block clipped lines away.
///
/// Replaces the old nested vertical scroll view: the conversation keeps the
/// vertical drag, and the reader gets the whole file in the full-screen view.
class _MoreLinesFooter extends StatelessWidget {
  const _MoreLinesFooter({
    required this.hiddenLines,
    required this.codeViewer,
    required this.onExpand,
  });

  final int hiddenLines;
  final CodeViewerTheme codeViewer;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = onExpand == null
        ? l10n.codeBlockHiddenLines(hiddenLines)
        : l10n.codeBlockShowAllLines(hiddenLines);

    final content = Container(
      decoration: BoxDecoration(
        color: codeViewer.headerBackground,
        border: Border(top: BorderSide(color: codeViewer.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.unfold_more_rounded,
            size: AppFontSize.base,
            color: codeViewer.idleAccent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onExpand == null
                    ? codeViewer.muted
                    : codeViewer.idleAccent,
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    if (onExpand == null) return content;
    return InkWell(onTap: onExpand, child: content);
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
        border: Border(top: BorderSide(color: codeViewer.divider)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        AppLocalizations.of(
          context,
        ).codeBlockTruncated(displayedChars, originalChars),
        style: TextStyle(
          color: codeViewer.muted,
          fontSize: AppFontSize.sm,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Left column displaying line numbers in horizontal-scroll mode.
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
