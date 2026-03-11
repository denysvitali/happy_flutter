import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/theme/app_tokens.dart';

/// Custom round button widget with polished styling.
///
/// Primary buttons get a gradient background and subtle
/// shadow. Secondary buttons have a bordered outline
/// style with hover feedback.
class RoundButton extends StatelessWidget {
  const RoundButton({
    required this.title,
    super.key,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
    this.height = AppTouchTarget.comfortable + 4,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !isLoading && onPressed != null;

    if (isPrimary) {
      return _PrimaryButton(
        title: title,
        onPressed: onPressed,
        isLoading: isLoading,
        enabled: enabled,
        icon: icon,
        height: height,
        theme: theme,
      );
    }

    return _SecondaryButton(
      title: title,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
      icon: icon,
      height: height,
      theme: theme,
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.title,
    required this.onPressed,
    required this.isLoading,
    required this.enabled,
    required this.icon,
    required this.height,
    required this.theme,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;
  final double height;
  final ThemeData theme;

  @override
  State<_PrimaryButton> createState() =>
      _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.theme.colorScheme;
    final scale = _pressed ? 0.97 : 1.0;

    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () =>
          setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.enabled
                  ? [
                      scheme.primary,
                      Color.lerp(
                        scheme.primary,
                        scheme.tertiary,
                        0.3,
                      )!,
                    ]
                  : [
                      scheme.primary
                          .withValues(alpha: 0.5),
                      scheme.primary
                          .withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(
              AppRadius.pill,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: scheme.primary
                          .withValues(alpha: 0.35),
                      blurRadius: AppSpacing.lg,
                      offset: const Offset(
                        0,
                        AppSpacing.xs,
                      ),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? AppLoadingIndicator(
                    size: AppSpacing.xl,
                    strokeWidth: 2.5,
                    color: scheme.onPrimary,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 20,
                          color: scheme.onPrimary,
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                      ],
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({
    required this.title,
    required this.onPressed,
    required this.isLoading,
    required this.enabled,
    required this.icon,
    required this.height,
    required this.theme,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;
  final double height;
  final ThemeData theme;

  @override
  State<_SecondaryButton> createState() =>
      _SecondaryButtonState();
}

class _SecondaryButtonState
    extends State<_SecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.theme.colorScheme;
    final scale = _pressed ? 0.97 : 1.0;
    final bgAlpha = _pressed ? 0.06 : 0.0;

    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () =>
          setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          height: widget.height,
          decoration: BoxDecoration(
            color: scheme.primary
                .withValues(alpha: bgAlpha),
            border: Border.all(
              color: widget.enabled
                  ? scheme.outline
                      .withValues(alpha: 0.5)
                  : scheme.outline
                      .withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(
              AppRadius.pill,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? AppLoadingIndicator(
                    size: AppSpacing.xl,
                    strokeWidth: 2,
                    color: scheme.primary,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 18,
                          color: widget.enabled
                              ? scheme.onSurface
                              : scheme.onSurface
                                  .withValues(
                                  alpha: 0.4,
                                ),
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                      ],
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.enabled
                              ? scheme.onSurface
                              : scheme.onSurface
                                  .withValues(
                                  alpha: 0.4,
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
