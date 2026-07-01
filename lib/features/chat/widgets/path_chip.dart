import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// A chip widget that displays a file path with monospace font
class PathChip extends StatelessWidget {
  /// Creates a path chip
  const PathChip({required this.path, super.key});

  /// The path string to display
  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 10,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              path,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xxs,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: -0.2,
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
