import 'package:flutter/material.dart';

/// Section container for displaying tool content with an optional title.
class ToolSectionView extends StatelessWidget {
  /// Optional title for the section.
  final String? title;

  /// Whether this section should take full width (no horizontal padding).
  final bool fullWidth;

  /// The content to display in the section.
  final List<Widget> children;

  const ToolSectionView({
    super.key,
    this.title,
    this.fullWidth = false,
    required this.children,
  });

  const ToolSectionView.single({
    super.key,
    this.title,
    this.fullWidth = false,
    required this.child,
  });

  /// The single child when using the factory constructor.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: 6,
                left: fullWidth ? 0 : 12,
                right: fullWidth ? 0 : 12,
              ),
              child: Text(
                title!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (fullWidth)
            ...children
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
