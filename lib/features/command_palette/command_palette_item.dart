part of 'command_palette_overlay.dart';

class _CommandPaletteItem extends StatefulWidget {
  const _CommandPaletteItem({
    required this.command,
    required this.isSelected,
    required this.colorScheme,
    required this.titleHighlights,
    required this.subtitleHighlights,
    required this.onTap,
    required this.onHover,
  });

  final CommandItem command;
  final bool isSelected;
  final ColorScheme colorScheme;

  /// Character positions (0-based) in [command.title] to highlight.
  final Set<int> titleHighlights;

  /// Character positions (0-based) in [command.subtitle] to highlight.
  final Set<int> subtitleHighlights;

  final VoidCallback onTap;
  final void Function(bool) onHover;

  @override
  State<_CommandPaletteItem> createState() => _CommandPaletteItemState();
}

class _CommandPaletteItemState extends State<_CommandPaletteItem> {
  bool _isHovered = false;

  /// Builds a [Text.rich] widget that bolds and colors characters whose
  /// 0-based index appears in [highlights].  When [highlights] is empty the
  /// result is a plain unstyled span, matching the original behaviour.
  Widget _buildHighlightedText(
    String text,
    Set<int> highlights,
    TextStyle baseStyle,
    Color highlightColor,
  ) {
    if (highlights.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var lastWasHighlighted = false;

    void flush(bool highlighted) {
      if (buffer.isEmpty) return;
      final chunk = buffer.toString();
      buffer.clear();
      if (highlighted) {
        spans.add(
          TextSpan(
            text: chunk,
            style: baseStyle.copyWith(
              color: highlightColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: chunk, style: baseStyle));
      }
    }

    for (var i = 0; i < text.length; i++) {
      final highlighted = highlights.contains(i);
      if (i > 0 && highlighted != lastWasHighlighted) {
        flush(lastWasHighlighted);
      }
      buffer.write(text[i]);
      lastWasHighlighted = highlighted;
    }
    flush(lastWasHighlighted);

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected || _isHovered;
    final colorScheme = widget.colorScheme;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: AppBorder.thick,
            ),
          ),
          child: Row(
            children: [
              // Icon
              if (widget.command.icon != null)
                Container(
                  width: AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  height: AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    widget.command.icon,
                    size: AppSpacing.xl - AppSpacing.sm,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHighlightedText(
                      widget.command.title,
                      widget.titleHighlights,
                      TextStyle(
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                      colorScheme.primary,
                    ),
                    if (widget.command.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      _buildHighlightedText(
                        widget.command.subtitle!,
                        widget.subtitleHighlights,
                        TextStyle(
                          fontSize: AppFontSize.md,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: -0.1,
                        ),
                        colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),

              // Pin indicator
              if (widget.command.isPinned)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    Icons.push_pin,
                    size: AppSpacing.lg,
                    color: colorScheme.primary,
                  ),
                ),

              // Shortcut
              if (widget.command.shortcut != null)
                Tooltip(
                  message:
                      'Press ${widget.command.shortcut} to run this command',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      widget.command.shortcut!,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
