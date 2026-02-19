import 'package:flutter/material.dart';

/// Section container for displaying tool content with an optional title.
class ToolSectionView extends StatelessWidget {
  /// Optional title for the section.
  final String? title;

  /// Whether this section should take full width (no horizontal padding).
  final bool fullWidth;

  /// The content to display in the section.
  final List<Widget> children;

  /// Optional single child (alternative to children).
  final Widget? child;

  const ToolSectionView({
    super.key,
    this.title,
    this.fullWidth = false,
    this.children = const [],
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveChildren = child != null ? [child!] : children;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            _SectionHeader(title: title!, fullWidth: fullWidth),
          if (fullWidth)
            ...effectiveChildren
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: effectiveChildren,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool fullWidth;

  const _SectionHeader({required this.title, required this.fullWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: fullWidth ? 0 : 12,
        right: fullWidth ? 0 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Courier New', 'Courier'],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  labelColor.withValues(alpha: 0.35),
                  labelColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
