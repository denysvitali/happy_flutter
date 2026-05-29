import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_colors.dart';

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
    final c = ToolViewColors.of(context);
    final count = hiddenCount;
    final collapsedLabel = count != null
        ? 'Show $count more line${count == 1 ? '' : 's'}'
        : 'Show more';

    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xsm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
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
              expanded ? 'Show less' : collapsedLabel,
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
