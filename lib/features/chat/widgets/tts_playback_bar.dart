import 'package:flutter/material.dart';

import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Compact playback bar shown above the chat input while TTS speech
/// is in progress.
///
/// The bar shows a one-line preview of the message being spoken, plus
/// three large tap targets for previous / stop / next so a user who
/// isn't looking at the screen can navigate between agent replies by
/// feel. When extra replies have been queued (e.g. new replies arrived
/// while an earlier one was still playing) a "+N" pill is shown next
/// to the preview text.
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
      // Subtle primary tint so the bar reads as an active, persistent
      // control rather than blending into the chat surface.
      color: Color.alphaBlend(
        cs.primary.withValues(alpha: 0.08),
        cs.surfaceContainerHighest,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              _PulsingSpeaker(color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ValueListenableBuilder<String?>(
                  valueListenable: TtsService().currentText,
                  builder: (context, text, _) => _PreviewText(
                    text: text,
                    onSurfaceVariant: cs.onSurfaceVariant,
                    onSurface: cs.onSurface,
                    textTheme: textTheme,
                  ),
                ),
              ),
              const _QueueBadge(),
              const SizedBox(width: AppSpacing.xs),
              _NavButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous reply',
                onPressed: canGoPrev ? onPrev : null,
              ),
              _StopButton(onPressed: onStop, color: cs.primary),
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

class _PreviewText extends StatelessWidget {
  const _PreviewText({
    required this.text,
    required this.onSurfaceVariant,
    required this.onSurface,
    required this.textTheme,
  });

  final String? text;
  final Color onSurfaceVariant;
  final Color onSurface;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hasText = text != null && text!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Speaking',
          style: textTheme.labelSmall?.copyWith(
            color: onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          hasText ? text!.replaceAll(RegExp(r'\s+'), ' ').trim() : '…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge();

  @override
  Widget build(BuildContext context) {
    // Watching `currentText` ensures the bar (and so this badge)
    // rebuilds whenever a queued item starts playing — `queuedCount`
    // isn't a listenable itself, so we piggy-back on the existing
    // listener cadence.
    return ValueListenableBuilder<String?>(
      valueListenable: TtsService().currentText,
      builder: (context, _, _) {
        final n = TtsService().queuedCount;
        if (n == 0) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '+$n',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingSpeaker extends StatefulWidget {
  const _PulsingSpeaker({required this.color});

  final Color color;

  @override
  State<_PulsingSpeaker> createState() => _PulsingSpeakerState();
}

class _PulsingSpeakerState extends State<_PulsingSpeaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 24 + 8 * t,
                height: 24 + 8 * t,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: (0.20 * (1 - t)).clamp(0.0, 1.0),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 16,
                  color: widget.color,
                  semanticLabel: 'Speaking',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onPressed == null
        ? cs.onSurface.withValues(alpha: AppOpacity.medium)
        : cs.onSurface;
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

/// Primary stop button — filled pill so it reads as the most
/// prominent action in the bar.
class _StopButton extends StatelessWidget {
  const _StopButton({required this.onPressed, required this.color});

  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Tooltip(
        message: 'Stop speaking',
        child: Semantics(
          button: true,
          label: 'Stop speaking',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onPressed,
            child: Container(
              width: AppTouchTarget.comfortable,
              height: AppTouchTarget.comfortable,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stop_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: AppSpacing.lg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
