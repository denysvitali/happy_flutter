import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// Animated typing indicator showing three bouncing dots
class TypingIndicator extends StatefulWidget {
  /// Creates a typing indicator
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  static const double _cycleMs = 900;
  static const double _stagger1 = 0 / _cycleMs;
  static const double _stagger2 = 150 / _cycleMs;
  static const double _stagger3 = 300 / _cycleMs;
  static const double _dotSpan = 330 / _cycleMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    _dot1 = _buildDotAnimation(_stagger1, _stagger1 + _dotSpan);
    _dot2 = _buildDotAnimation(_stagger2, _stagger2 + _dotSpan);
    _dot3 = _buildDotAnimation(_stagger3, _stagger3 + _dotSpan);
  }

  Animation<double> _buildDotAnimation(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -4,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -4,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start.clamp(0.0, 1.0),
          end.clamp(0.0, 1.0),
          curve: Curves.linear,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dotColor = cs.onSurfaceVariant.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(offset: _dot1.value, color: dotColor),
              const SizedBox(width: AppSpacing.xs),
              _Dot(offset: _dot2.value, color: dotColor),
              const SizedBox(width: AppSpacing.xs),
              _Dot(offset: _dot3.value, color: dotColor),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.offset, required this.color});
  final double offset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
