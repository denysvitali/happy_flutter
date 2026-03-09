import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Displays an icon, title, and optional subtitle for empty list states.
///
/// The icon sits inside a gradient-tinted rounded container with a
/// subtle breathing scale animation to feel alive. Title uses
/// [TextTheme.titleMedium]; subtitle uses [TextTheme.bodyMedium].
class AppEmptyState extends StatefulWidget {
  /// Creates an empty-state placeholder.
  const AppEmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.action,
  });

  /// The icon to display inside the rounded container.
  final IconData icon;

  /// The primary message (required).
  final String title;

  /// Secondary description shown beneath the title.
  final String? subtitle;

  /// Optional action widget (e.g. a button).
  final Widget? action;

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(
        parent: _breathe,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breathing icon container with gradient.
            AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(
                scale: _scale.value,
                child: child,
              ),
              child: Container(
                width: AppSpacing.xxxl * 2,
                height: AppSpacing.xxxl * 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surfaceContainerHighest,
                      cs.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  widget.icon,
                  size: AppSpacing.xxxl + AppSpacing.sm,
                  color: cs.onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Title.
            Text(
              widget.title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            // Subtitle.
            if (widget.subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Action widget.
            if (widget.action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}
