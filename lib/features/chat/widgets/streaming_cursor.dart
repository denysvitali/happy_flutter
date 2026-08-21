import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';

/// A small gradient caret shown at the end of a streaming assistant
/// message.
///
/// Aurora Glass treatment: a rounded caret (with a trailing dot) painted
/// with the signature [AppColorScheme.accentLinearGradient], breathing on
/// a ~1 s scale + opacity loop to signal that the AI is still generating.
/// Disappears once streaming ends. Honors
/// [MediaQuery.disableAnimationsOf] — when animations are disabled the
/// caret renders static at full strength.
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
  late final Animation<double> _breath;
  bool? _animationsDisabled;

  /// Caret stem width ([AppSpacing.xxxs]) and height — roughly the x-height
  /// of the body copy it trails.
  static const double _caretWidth = AppSpacing.xxxs;
  static const double _caretHeight = AppFontSize.lg;

  /// Trailing dot diameter.
  static const double _dotSize = AppSpacing.xxs2;

  /// Breathing floor for opacity and scale.
  static const double _minBreath = 0.45;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.pulse);

    // One pulse breathes down and back up (reverse repeat), so the caret
    // never blinks out completely — it dims toward [_minBreath] and
    // returns, once per [AppDuration.pulse].
    _breath = Tween<double>(begin: 1.0, end: _minBreath).animate(
      CurvedAnimation(parent: _controller, curve: AppCurve.standard),
    );
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
        ..value = 0;
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final gradient =
        appColors?.accentLinearGradient ??
        LinearGradient(
          colors:
              appColors?.accentGradient ?? <Color>[cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _breath,
        child: ScaleTransition(
          alignment: Alignment.centerLeft,
          scale: _breath,
          child: Container(
            // Breathing headroom so the scale never clips.
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            margin: const EdgeInsets.only(left: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('streaming-cursor-stem'),
                  width: _caretWidth,
                  height: _caretHeight,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(AppRadius.xxs),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxxs),
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (appColors?.accentGradient ??
                                <Color>[cs.primary, cs.secondary])
                            .last,
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
