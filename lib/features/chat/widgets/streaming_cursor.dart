import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// A blinking vertical bar cursor shown at the end of a
/// streaming assistant message.
///
/// Fades in and out with a ~500 ms period to signal that the
/// AI is still generating text.  Disappears once streaming ends.
///
/// Usage:
/// ```dart
/// Row(
///   children: [
///     Text(streamingText),
///     const StreamingCursor(),
///   ],
/// )
/// ```
class StreamingCursor extends StatefulWidget {
  const StreamingCursor({super.key});

  @override
  State<StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.slower, // 500 ms half-period
    );

    _opacity = CurvedAnimation(parent: _controller, curve: AppCurve.standard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 2,
          height: 14,
          margin: const EdgeInsets.only(left: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xxs),
          ),
        ),
      ),
    );
  }
}
