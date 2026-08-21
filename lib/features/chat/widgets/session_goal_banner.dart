import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';

/// Sticky chat banner showing the current Codex goal for this session.
///
/// Aurora glass family: a rounded glass panel — translucent
/// surfaceContainerLow fill, hairline glass border — with a 3 px
/// accent-gradient leading edge, so the signature gradient is worn
/// quietly instead of painted across the surface.
class SessionGoalBanner extends ConsumerWidget {
  const SessionGoalBanner({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(
      sessionsNotifierProvider.select(
        (sessions) => sessions[sessionId]?.agentState?.goal,
      ),
    );

    if (goal == null || !goal.isVisible) return const SizedBox.shrink();

    return _GoalBannerBody(goal: goal);
  }
}

class _GoalBannerBody extends StatelessWidget {
  const _GoalBannerBody({required this.goal});

  final CodexGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Bare-MaterialApp test hosts carry no AppColorScheme extension;
    // fall back to the dark scheme so the chrome still renders.
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final accent = appCs.accentLinearGradient.colors.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Material(
        color: cs.surfaceContainerLow.withValues(alpha: 0.92),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: appCs.glassBorder, width: AppBorder.hairline),
        ),
        elevation: AppElevation.low,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Signature accent edge — 3 px of gradient, nothing more.
            Container(
              width: AppBorder.accent,
              decoration: BoxDecoration(
                gradient: appCs.accentLinearGradient,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.smd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GoalIconTile(accent: accent),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Goal',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _StatusPill(label: goal.status, color: accent),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            goal.objective,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient-tinted icon tile echoing the banner's leading edge.
class _GoalIconTile extends StatelessWidget {
  const _GoalIconTile({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(Icons.flag_rounded, size: 17, color: accent),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = label.trim().isEmpty ? 'active' : label.trim();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: AppBorder.hairline,
        ),
      ),
      child: Text(
        normalized,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
