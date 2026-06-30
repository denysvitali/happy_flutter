import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Banner rendered as the FIRST item in the chat message list whenever
/// orphan sidechain messages exist in the loaded window. The chat
/// screen's `_visibleCount = _pageSize` clamp can otherwise hide those
/// orphans when top-level entries dominate the visible window — leaving
/// the user staring at task-completion messages and missing the
/// subagent content underneath.
///
/// Tapping the banner raises `_visibleCount` (via the chat screen's
/// existing "load more" path) so the orphans become visible. Once the
/// banner is dismissed (count → 0), the chat screen no longer renders
/// it and the orphan filter in [_chat_screen_builders] is bypassed for
/// the visible window.
class OrphanBanner extends StatelessWidget {
  const OrphanBanner({
    required this.orphanCount,
    required this.onTap,
    super.key,
  });

  /// Number of orphan sidechain messages currently hidden by the
  /// visible-window clamp. The banner hides itself when this is 0 —
  /// callers should guard at the call site rather than instantiating
  /// the widget unconditionally.
  final int orphanCount;

  /// Invoked when the user taps the banner. The chat screen handles
  /// `_loadMore()` here so the same visible-window math governs both
  /// pagination taps and orphan expansion.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (orphanCount <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();

    // The banner is informational, not an error: use the M3 tertiary
    // surface tones (or the app's warning container fallback when the
    // extension isn't registered) so it reads as "look here, more
    // below" rather than "something went wrong".
    final containerColor = appColors?.warningContainer ?? cs.tertiaryContainer;
    final foregroundColor = appColors?.onWarning ?? cs.onTertiaryContainer;
    final accentColor = appColors?.warning ?? cs.tertiary;

    return Material(
      color: containerColor.withValues(alpha: AppOpacity.medium),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: foregroundColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)
                          .chatOrphanBanner(orphanCount),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      AppLocalizations.of(context)
                          .chatOrphanBannerTapToShow(orphanCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foregroundColor.withValues(
                          alpha: AppOpacity.strong,
                        ),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: AppOpacity.soft),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  orphanCount.toString(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
