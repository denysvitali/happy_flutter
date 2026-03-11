import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Animated typing indicator showing three bouncing dots.
///
/// Displayed at the bottom of the chat when the AI agent is
/// thinking or processing.
///
/// Uses a single [AnimationController] with staggered [Interval]s
/// rather than 3 separate controllers.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    // Each dot gets an Interval offset by 150ms (≈22% of 900ms).
    _animations = List.generate(3, (i) {
      final start = (i * 150) / 900.0;
      final end = start + 0.4; // each dot animates for 40% of total
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end.clamp(0.0, 1.0),
              curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(AppRadius.lg),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: EdgeInsets.only(
                        right: i < 2 ? AppSpacing.xs : 0,
                      ),
                      child: Transform.translate(
                        offset:
                            Offset(0, _animations[i].value),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
