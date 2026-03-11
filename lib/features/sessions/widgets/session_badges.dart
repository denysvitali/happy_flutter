import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Circular checkbox shown at the leading edge in selection
/// mode, replacing the status color bar.
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({
    required this.isSelected,
    required this.borderRadius,
    super.key,
  });

  final bool isSelected;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          bottomLeft: borderRadius.bottomLeft,
        ),
      ),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? cs.primary : cs.surface,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
            : null,
      ),
    );
  }
}

/// Draft icon overlay badge shown on avatar bottom-right corner.
class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: AppSpacing.lg,
        height: AppSpacing.lg,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drive_file_rename_outline,
          size: 10,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Task progress badge shown near the timestamp/status area.
class TodoProgressBadge extends StatelessWidget {
  const TodoProgressBadge({
    required this.completed,
    required this.total,
    super.key,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 10,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
