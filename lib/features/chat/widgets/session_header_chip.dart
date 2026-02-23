import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// A small chip used in the session header to display status or machine info
class SessionHeaderChip extends StatelessWidget {
  /// Creates a session header chip
  const SessionHeaderChip({
    required this.text,
    this.leading,
    super.key,
  });

  /// The text to display in the chip
  final String text;

  /// Optional leading widget (typically an icon or status dot)
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
