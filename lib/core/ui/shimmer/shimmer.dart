import 'package:flutter/material.dart';

import '../../theme/app_color_scheme.dart';
import '../../theme/app_tokens.dart';

/// A loading episode has a bounded motion budget. Only explicit configuration
/// or visibility changes start another episode, never routine rebuilds.
class _LoadingMotion {
  _LoadingMotion(TickerProvider vsync, {this.restingValue = 0.5})
    : controller = AnimationController(vsync: vsync);

  final AnimationController controller;
  final double restingValue;
  bool? _active;
  Duration? _duration;
  int _generation = 0;

  void update(BuildContext context, bool enabled, Duration duration) {
    final reduced = AppMotion.reduceMotion(context);
    final visible = TickerMode.valuesOf(context).enabled;
    final active = enabled && !reduced && visible && duration > Duration.zero;
    if (_active == active && _duration == duration) return;
    _active = active;
    _duration = duration;
    final generation = ++_generation;
    controller
      ..stop()
      ..duration = duration
      ..value = active ? 0 : restingValue;
    if (active) {
      controller
          .repeat(reverse: true, count: AppMotion.activityPulseCount)
          .whenCompleteOrCancel(() {
            if (_generation == generation) controller.value = restingValue;
          });
    }
  }

  void dispose() {
    _generation++;
    controller.dispose();
  }
}

/// Provides a shared [AnimationController] to descendant [Shimmer]
/// widgets so multiple shimmers on screen share a single ticker
/// instead of each creating its own.
///
/// Wrap a group of [Shimmer] widgets (e.g. a loading skeleton list)
/// in a [ShimmerScope] to avoid N independent animation controllers.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final Duration duration;
  final bool enabled;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final _LoadingMotion _motion;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _motion = _LoadingMotion(this);
    _animation = _motion.controller.drive(CurveTween(curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.update(context, widget.enabled, widget.duration);
  }

  @override
  void didUpdateWidget(ShimmerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion.update(context, widget.enabled, widget.duration);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScopeData(animation: _animation, child: widget.child);
  }
}

class _ShimmerScopeData extends InheritedWidget {
  const _ShimmerScopeData({required this.animation, required super.child});

  final Animation<double> animation;

  static _ShimmerScopeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScopeData>();
  }

  @override
  bool updateShouldNotify(_ShimmerScopeData oldWidget) =>
      animation != oldWidget.animation;
}

/// Animated shimmer gradient loading effect.
///
/// When [colors] is omitted, the shimmer automatically adapts to the
/// current theme using [AppColorScheme.shimmerBase] and
/// [AppColorScheme.shimmerHighlight].
///
/// When placed inside a [ShimmerScope], reuses the scope's shared
/// animation controller instead of creating its own.
class Shimmer extends StatefulWidget {
  const Shimmer({
    required this.child,
    this.colors,
    this.shimmerWidthPercent = 80,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final List<Color>? colors;
  final double shimmerWidthPercent;
  final Duration duration;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with TickerProviderStateMixin {
  _LoadingMotion? _motion;
  Animation<double>? _ownAnimation;
  Animation<double>? _sharedAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sharedAnimation = _ShimmerScopeData.maybeOf(context)?.animation;
    _updateMotion();
  }

  void _updateMotion() {
    if (_sharedAnimation != null) {
      _motion?.dispose();
      _motion = null;
      _ownAnimation = null;
      return;
    }
    final motion = _motion ??= _LoadingMotion(this);
    _ownAnimation ??= motion.controller.drive(
      CurveTween(curve: Curves.easeInOut),
    );
    motion.update(context, widget.enabled, widget.duration);
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  @override
  void dispose() {
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    // A child may request reduced motion or be hidden below an active scope.
    // Do not listen to the shared controller in either case.
    final isStatic =
        AppMotion.reduceMotion(context) ||
        !TickerMode.valuesOf(context).enabled;
    final animation = isStatic
        ? const AlwaysStoppedAnimation<double>(0.5)
        : _sharedAnimation ?? _ownAnimation!;

    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorScheme>();
    final effectiveColors =
        widget.colors ??
        (appColors != null
            ? [
                appColors.shimmerBase,
                appColors.shimmerHighlight,
                appColors.shimmerHighlight,
                appColors.shimmerBase,
              ]
            : [
                theme.colorScheme.surfaceContainerHigh,
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainerHigh,
              ]);
    // Stops must match the colour count exactly or the gradient throws.
    // Custom lists of any other length fall back to even spacing.
    final List<double>? effectiveStops;
    if (widget.colors == null) {
      effectiveStops = const [0.0, 0.35, 0.65, 1.0];
    } else if (widget.colors!.length == 5) {
      effectiveStops = const [0.0, 0.2, 0.5, 0.8, 1.0];
    } else {
      effectiveStops = null;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return RepaintBoundary(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: effectiveColors,
                stops: effectiveStops,
                begin: Alignment.topLeft,
                end: Alignment.topRight,
                transform: _ShimmerGradientTransform(
                  animation: animation,
                  widthPercent: widget.shimmerWidthPercent,
                  boundsWidth: bounds.width,
                ),
              ).createShader(bounds);
            },
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Custom gradient transform for shimmer effect
class _ShimmerGradientTransform extends GradientTransform {
  const _ShimmerGradientTransform({
    required this.animation,
    required this.widthPercent,
    required this.boundsWidth,
  });
  final Animation<double> animation;
  final double widthPercent;
  final double boundsWidth;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shimmerWidth = bounds.width * (widthPercent / 100);
    final start =
        -shimmerWidth + (bounds.width + shimmerWidth) * animation.value;

    // Clamp values to bounds
    final clampedStart = start.clamp(-shimmerWidth, bounds.width);
    return Matrix4.translationValues(clampedStart - bounds.left, 0, 0);
  }
}

/// Pre-configured shimmer styles for common use cases
class ShimmerStyles {
  /// Default shimmer for list items
  static Widget listTile({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
  }) {
    return Shimmer(
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  /// Shimmer for card-like content
  static Widget card({
    required BuildContext context,
    required double height,
    double? width,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(AppRadius.md),
    ),
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      ),
    );
  }

  /// Shimmer for text lines
  static Widget textLine({
    required BuildContext context,
    double height = 16,
    double width = double.infinity,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(AppRadius.xs),
    ),
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      ),
    );
  }

  /// Shimmer for avatar placeholder
  static Widget avatar({required BuildContext context, double size = 48}) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  /// Multi-line text shimmer
  static Widget textLines({
    required BuildContext context,
    int lines = 3,
    double lineHeight = 16,
    double width = double.infinity,
    double spacing = 8,
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (index) {
          return Padding(
            padding: index > 0
                ? EdgeInsets.only(top: spacing)
                : EdgeInsets.zero,
            child: Container(
              height: lineHeight,
              width: index == lines - 1 ? width * 0.6 : width,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Loading shimmer placeholder for images
class ShimmerImagePlaceholder extends StatelessWidget {
  const ShimmerImagePlaceholder({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
    super.key,
  });
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      ),
    );
  }
}

/// Pulse loading indicator
class ShimmerPulse extends StatefulWidget {
  const ShimmerPulse({this.size = 48, this.color, super.key});
  final double size;

  /// Dot color. Defaults to [ColorScheme.surfaceContainerHighest] when null.
  final Color? color;

  @override
  State<ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<ShimmerPulse>
    with SingleTickerProviderStateMixin {
  late final _LoadingMotion _motion;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _motion = _LoadingMotion(this, restingValue: 0);
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(_motion.controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion.update(context, true, const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        widget.color ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _opacityAnimation,
      child: AnimatedBuilder(
        animation: _motion.controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 1 - 0.2 * _motion.controller.value,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: resolvedColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
