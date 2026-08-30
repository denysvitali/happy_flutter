import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';

/// A tap-to-copy icon button for tool views: copies [text] to the clipboard
/// and briefly swaps to a checkmark for 2 seconds to confirm the copy.
class ToolViewCopyButton extends StatefulWidget {
  const ToolViewCopyButton({required this.text, this.iconSize = 14, super.key});

  /// The text copied to the clipboard when tapped.
  final String text;

  /// Size of the copy/check icon.
  final double iconSize;

  @override
  State<ToolViewCopyButton> createState() => _ToolViewCopyButtonState();
}

class _ToolViewCopyButtonState extends State<ToolViewCopyButton> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await setClipboardTextSafely(widget.text);
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final label = _copied ? context.l10n.commonCopied : context.l10n.commonCopy;
    return Semantics(
      button: true,
      label: label,
      onTap: _handleCopy,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: _handleCopy,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppTouchTarget.min),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppDuration.fast),
          child: Icon(
            _copied ? Icons.check : Icons.copy,
            key: ValueKey(_copied),
            size: widget.iconSize,
            color: _copied
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A full-width expand/collapse toggle row for truncated tool-view content.
/// Shows "Show less" when [expanded], otherwise "Show more" (with an optional
/// "$hiddenCount more line(s)" hint).
class ToolViewShowMoreButton extends StatelessWidget {
  const ToolViewShowMoreButton({
    required this.expanded,
    required this.onToggle,
    this.hiddenCount,
    super.key,
  });

  /// Whether the content is currently expanded.
  final bool expanded;

  /// Called when the row is tapped to toggle expansion.
  final VoidCallback onToggle;

  /// Number of hidden lines shown in the collapsed label, if known.
  final int? hiddenCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = hiddenCount;
    final collapsedLabel = count != null
        ? context.l10n.codeBlockShowAllLines(count)
        : context.l10n.toolOutputShowMore;
    final label = expanded ? context.l10n.toolOutputShowLess : collapsedLabel;

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      onTap: onToggle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xsm),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
            color: cs.surfaceContainer,
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
                size: AppIconSize.sm,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
