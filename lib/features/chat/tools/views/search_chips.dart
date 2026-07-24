import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Pill badge naming a search tool and echoing its pattern, e.g.
/// `[🔍 grep | TODO\(.*\)]` or `[🌐 glob | **/*.dart]`.
///
/// Shared by the glob and grep views, which carried identical copies
/// differing only in icon, label, and accent colour.
class SearchToolBadge extends StatelessWidget {
  const SearchToolBadge({
    required this.label,
    required this.pattern,
    required this.icon,
    required this.accent,
    super.key,
  });

  /// Tool name shown before the divider ('glob', 'grep').
  final String label;

  /// The user's search pattern, rendered monospace and selectable.
  final String pattern;

  /// Leading icon for the tool.
  final IconData icon;

  /// Accent colour for the icon and pattern text.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xxs2,
      ),
      decoration: _chipDecoration(cs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.sm, color: accent),
          const SizedBox(width: AppSpacing.xsm),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppSpacing.xsm),
          Container(width: 1, height: AppIconSize.xs, color: cs.outlineVariant),
          const SizedBox(width: AppSpacing.xsm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SelectableText(
              pattern,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill chip showing the directory a search was scoped to.
class SearchPathChip extends StatelessWidget {
  const SearchPathChip({required this.path, super.key});

  /// The search path, truncated with an ellipsis when long.
  final String path;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs2,
      ),
      decoration: _chipDecoration(cs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: AppIconSize.xs,
            color: cs.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              path,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _chipDecoration(ColorScheme cs) => BoxDecoration(
  color: cs.surfaceContainerHighest,
  borderRadius: BorderRadius.circular(AppRadius.xsm),
  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
);
