import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/scroll_when_bounded.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Maximum readable width for a centred placeholder block.
const double _kMaxWidth = 360;

/// Displays an icon, title, and optional subtitle for empty list states.
///
/// The icon sits inside a gradient-tinted rounded container with a
/// brief breathing scale animation to feel alive (it settles after a
/// couple of cycles so an idle screen never animates forever). Title
/// uses [TextTheme.titleMedium]; subtitle uses [TextTheme.bodyMedium].
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
  /// Breaths played before the icon settles at rest scale. Empty states
  /// can sit on screen indefinitely; an endless breathing loop would
  /// repaint the whole state for as long as it is visible.
  static const int _kBreathCycles = 2;

  late final AnimationController _breathe;
  late final Animation<double> _scale;
  bool _reduceMotion = false;
  int _breathsDone = 0;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _breathe
        ..stop()
        ..value = 0.0;
    } else {
      _runBreath();
    }
  }

  void _runBreath() {
    _breathe.forward().whenComplete(() {
      _breathe.reverse().whenComplete(() {
        _breathsDone++;
        if (!mounted || _breathsDone >= _kBreathCycles) return;
        _runBreath();
      });
    });
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

    final subtitle = widget.subtitle;
    final semanticsLabel = subtitle == null || subtitle.isEmpty
        ? widget.title
        : context.l10n.a11yEmptyState(widget.title, subtitle);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + title + subtitle announce as one node instead of three
          // disconnected fragments. The action keeps its own semantics so
          // it stays individually focusable.
          Semantics(
            container: true,
            label: semanticsLabel,
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconContainer(cs),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          if (widget.action != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            widget.action!,
          ],
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxWidth),
        child: scrollWhenBounded(content),
      ),
    );
  }

  Widget _buildIconContainer(ColorScheme cs) {
    final iconContainer = Container(
      width: AppSpacing.xxxl * 2,
      height: AppSpacing.xxxl * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest,
            cs.surfaceContainerHighest.withValues(alpha: 0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          width: AppBorder.hairline,
        ),
      ),
      child: Icon(
        widget.icon,
        size: AppSpacing.xxxl + AppSpacing.sm,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );

    if (_reduceMotion) return iconContainer;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: iconContainer,
    );
  }
}
