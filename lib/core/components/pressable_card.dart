import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Wraps [child] with a canonical press animation (scale + optional haptics).
class PressableCard extends StatefulWidget {
  /// Creates a pressable card around [child].
  const PressableCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.98,
    this.enableHaptics = true,
    this.duration = AppDuration.fast,
    super.key,
  });

  /// The content scaled on press.
  final Widget child;

  /// Called on tap; fires [HapticFeedback.lightImpact] first if enabled.
  final VoidCallback? onTap;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// Scale applied while pressed (1.0 = no scale).
  final double pressedScale;

  /// Whether to fire light-impact haptics on tap.
  final bool enableHaptics;

  /// Press animation duration.
  final Duration duration;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.enableHaptics) {
                HapticFeedback.lightImpact();
              }
              widget.onTap!.call();
            },
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: AppCurve.standard,
        child: widget.child,
      ),
    );
  }
}
