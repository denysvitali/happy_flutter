import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// Section container for displaying tool content with an optional title.
class ToolSectionView extends StatelessWidget {

  const ToolSectionView({
    super.key,
    this.title,
    this.fullWidth = false,
    this.children = const [],
    this.child,
  });
  /// Optional title for the section.
  final String? title;

  /// Whether this section should take full width (no horizontal padding).
  final bool fullWidth;

  /// The content to display in the section.
  final List<Widget> children;

  /// Optional single child (alternative to children).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveChildren = child != null ? [child!] : children;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          _SectionHeader(title: title!, fullWidth: fullWidth),
        if (fullWidth)
          ...effectiveChildren
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: effectiveChildren,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {

  const _SectionHeader({required this.title, required this.fullWidth});
  final String title;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSpacing.xsm,
        left: fullWidth ? 0 : AppSpacing.sm,
        right: fullWidth ? 0 : AppSpacing.sm,
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
          const SizedBox(height: AppSpacing.xs),
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
