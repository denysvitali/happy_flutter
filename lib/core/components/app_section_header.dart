import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// A titled section divider used in lists and settings screens.
///
/// The [title] is rendered in [TextTheme.labelSmall] in ALL CAPS
/// using the theme primary color. An optional [trailing] widget is
/// right-aligned on the same row.
///
/// Default padding: [AppSpacing.lg] horizontal, [AppSpacing.md] top,
/// [AppSpacing.xs] bottom. Pass [padding] to override.
class AppSectionHeader extends StatelessWidget {
  /// Creates a section header.
  const AppSectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.padding,
  });

  /// The section label text.
  final String title;

  /// Optional widget aligned to the trailing edge.
  final Widget? trailing;

  /// Padding around the header row.
  ///
  /// Defaults to `EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
  /// AppSpacing.lg, AppSpacing.xs)` when null.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding =
        padding ??
        const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
        );

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: AppText.label(theme, theme.colorScheme.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
