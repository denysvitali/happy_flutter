part of 'code_block_widget.dart';

/// Aurora-glass chrome fill for code-block strips (header, footers).
///
/// A static alpha lift of the glass highlight over the chrome base — no
/// [BackdropFilter], no per-frame shader — so the strip reads as a separate
/// translucent pane above the code surface at zero raster cost.
Color _glassChromeFill(Color base, AppColorScheme glass) =>
    Color.alphaBlend(glass.glassHighlight.withValues(alpha: 0.5), base);

/// Resolves the ambient Aurora scheme, falling back to the dark tokens when
/// the extension is not registered (bare-[MaterialApp] tests).
AppColorScheme _glassOf(BuildContext context) =>
    Theme.of(context).extension<AppColorScheme>() ?? AppColorScheme.dark();

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
    final glass = _glassOf(context);
    final base = _hovered
        ? widget.codeViewer.headerHover
        : widget.codeViewer.headerBackground;
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
          color: _glassChromeFill(base, glass),
          border: Border(
            bottom: BorderSide(
              color: glass.glassBorder,
              width: AppBorder.hairline,
            ),
          ),
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
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
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
            // Copy button – quiet ghost icon; the success-green check carries
            // the confirmation state.
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

/// Ghost-icon copy button with "copied" feedback.
///
/// Icon-only: the tooltip names the action, and the confirmation flips the
/// glyph to a success-green check. No label text keeps the header quiet.
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
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: copied ? l10n.commonCopied : l10n.commonCopyCode,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: AnimatedSwitcher(
            duration: AppDuration.fast,
            switchInCurve: AppCurve.enter,
            switchOutCurve: AppCurve.exit,
            child: Icon(
              key: ValueKey(copied),
              copied ? Icons.check_rounded : Icons.content_copy_rounded,
              size: AppFontSize.base,
              color: copied ? codeViewer.successAccent : codeViewer.idleAccent,
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
        color: _glassChromeFill(codeViewer.headerBackground, _glassOf(context)),
        border: Border(
          top: BorderSide(
            color: _glassOf(context).glassBorder,
            width: AppBorder.hairline,
          ),
        ),
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
    final glass = _glassOf(context);
    return Container(
      decoration: BoxDecoration(
        color: _glassChromeFill(codeViewer.headerBackground, glass),
        border: Border(
          top: BorderSide(color: glass.glassBorder, width: AppBorder.hairline),
        ),
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
          color: codeViewer.lineNumberText.withValues(alpha: _gutterDigitAlpha),
          height: lineHeight / fontSize,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
