import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Compact chip showing the active loop count for the current session.
///
/// Tapping it navigates to the Loops screen. Hides itself when the count
/// is zero so it doesn't add visual noise to sessions without loops.
class LoopCountBadge extends ConsumerWidget {
  const LoopCountBadge({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Watch the notifier but only react to the count for this session —
    // other sessions' loops changing shouldn't rebuild the badge.
    final count = ref.watch(
      loopsNotifierProvider.select(
        (state) => state[sessionId]?.length ?? 0,
      ),
    );
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () {
          HapticFeedback.selectionClick();
          context.pushNamed(
            'chat-loops',
            pathParameters: {'sessionId': sessionId},
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                l10n.loopsBadgeCount(count),
                style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
