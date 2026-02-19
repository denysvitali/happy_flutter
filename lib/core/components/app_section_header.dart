import 'package:flutter/material.dart';

/// A titled section divider used in lists and settings screens.
///
/// The [title] is rendered in [TextTheme.labelSmall] in ALL CAPS
/// using the theme primary color. An optional [trailing] widget is
/// right-aligned on the same row.
///
/// Default padding is 12 px top, 4 px bottom, 16 px horizontal.
/// Pass [padding] to override.
class AppSectionHeader extends StatelessWidget {
  /// Creates a section header.
  const AppSectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.padding,
  });

  /// The section label text. Rendered in ALL CAPS.
  final String title;

  /// Optional widget aligned to the trailing edge.
  final Widget? trailing;

  /// Padding around the header row.
  ///
  /// Defaults to `EdgeInsets.fromLTRB(16, 12, 16, 4)` when null.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding =
        padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 4);

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
