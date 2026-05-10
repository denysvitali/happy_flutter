import 'package:flutter/material.dart';

import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Compact playback bar shown above the chat input while TTS speech
/// is in progress.
///
/// The bar is intentionally minimal — three large tap targets for
/// previous, stop, and next — so a user who isn't looking at the
/// screen (the user described listening on a phone) can navigate
/// between agent replies by feel.
///
/// The widget watches [TtsService.currentToken] and animates itself
/// in/out based on whether a speech token is set. It is purely
/// presentational; the parent screen wires up the actual
/// prev/stop/next behavior because it has the message list.
class TtsPlaybackBar extends StatelessWidget {
  const TtsPlaybackBar({
    required this.onPrev,
    required this.onStop,
    required this.onNext,
    this.canGoPrev = true,
    this.canGoNext = true,
    super.key,
  });

  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onNext;

  /// When false, the previous-button is disabled (e.g. already on
  /// the oldest speakable message).
  final bool canGoPrev;

  /// When false, the next-button is disabled (e.g. nothing newer to
  /// jump to).
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: TtsService().currentToken,
      builder: (context, token, _) {
        final visible = token != null;
        return AnimatedSwitcher(
          duration: AppDuration.fast,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: visible
              ? _Bar(
                  key: const ValueKey('tts-playback-bar'),
                  onPrev: onPrev,
                  onStop: onStop,
                  onNext: onNext,
                  canGoPrev: canGoPrev,
                  canGoNext: canGoNext,
                )
              : const SizedBox.shrink(key: ValueKey('tts-playback-bar-empty')),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.onPrev,
    required this.onStop,
    required this.onNext,
    required this.canGoPrev,
    required this.canGoNext,
    super.key,
  });

  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onNext;
  final bool canGoPrev;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.volume_up_rounded,
                size: AppSpacing.lg,
                color: cs.primary,
                semanticLabel: 'Speaking',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Speaking…',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous reply',
                onPressed: canGoPrev ? onPrev : null,
              ),
              _NavButton(
                icon: Icons.stop_rounded,
                tooltip: 'Stop speaking',
                onPressed: onStop,
                isPrimary: true,
              ),
              _NavButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Next reply',
                onPressed: canGoNext ? onNext : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onPressed == null
        ? cs.onSurface.withValues(alpha: AppOpacity.medium)
        : (isPrimary ? cs.primary : cs.onSurface);
    return SizedBox(
      width: AppTouchTarget.comfortable,
      height: AppTouchTarget.comfortable,
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: AppSpacing.xl,
      ),
    );
  }
}
