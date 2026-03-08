import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Platform-aware tap target with ripple (Android) or press-scale (iOS).
///
/// On iOS: wraps the child in a [GestureDetector] with an [AnimatedScale]
/// that shrinks to 97 % on press — matching the iOS feel.
///
/// On Android and other platforms: uses [InkWell] with a ripple, preserving
/// Material feedback.
///
/// When [haptic] is true (the default), a light impact fires on each tap.
class AppTappable extends StatefulWidget {
  /// Creates a tappable wrapper.
  const AppTappable({
    required this.child,
    super.key,
    this.onTap,
    this.borderRadius,
    this.haptic = true,
    this.semanticLabel,
    this.tooltip,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// Called when the widget is tapped.
  final VoidCallback? onTap;

  /// The border radius of the ripple (Android) or clip (iOS).
  ///
  /// Defaults to `BorderRadius.circular(AppRadius.sm)` when null.
  final BorderRadius? borderRadius;

  /// Whether to trigger haptic feedback on tap.
  ///
  /// Defaults to true.
  final bool haptic;

  /// Optional semantic label for accessibility.
  final String? semanticLabel;

  /// Optional tooltip message.
  final String? tooltip;

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(AppRadius.sm);

    final isIOS = !kIsWeb && Platform.isIOS;

    Widget result;

    if (isIOS) {
      result = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppTouchTarget.min,
          minHeight: AppTouchTarget.min,
        ),
        child: GestureDetector(
          onTap: widget.onTap == null ? null : _handleTap,
          onTapDown: widget.onTap == null
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: widget.onTap == null
              ? null
              : (_) =>
                  setState(() => _pressed = false),
          onTapCancel: widget.onTap == null
              ? null
              : () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: AppDuration.fast,
            curve: Curves.easeInOut,
            child: widget.child,
          ),
        ),
      );
    } else {
      result = InkWell(
        onTap: widget.onTap == null ? null : _handleTap,
        borderRadius: radius,
        splashColor: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.08),
        highlightColor: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.04),
        splashFactory: InkRipple.splashFactory,
        child: widget.child,
      );
    }

    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip!,
        child: result,
      );
    }

    if (widget.semanticLabel != null) {
      result = Semantics(
        label: widget.semanticLabel,
        button: true,
        child: result,
      );
    }

    return result;
  }
}
