import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// A small chip used in the session header to display status or machine info
class SessionHeaderChip extends StatelessWidget {
  /// Creates a session header chip
  const SessionHeaderChip({
    required this.text,
    this.leading,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.tooltip,
    super.key,
  });

  /// The text to display in the chip
  final String text;

  /// Optional leading widget (typically an icon or status dot)
  final Widget? leading;

  /// Optional text color override.
  final Color? textColor;

  /// Optional background color override.
  final Color? backgroundColor;

  /// Optional border color override.
  final Color? borderColor;

  /// Optional tooltip text. Defaults to [text].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolvedTextColor = textColor ?? cs.onSurfaceVariant;
    final resolvedBackgroundColor =
        backgroundColor ?? cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final resolvedBorderColor =
        borderColor ?? cs.outlineVariant.withValues(alpha: 0.3);
    return Tooltip(
      message: tooltip ?? text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: resolvedBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: resolvedBorderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: resolvedTextColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
