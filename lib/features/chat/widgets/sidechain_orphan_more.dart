import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';

/// "Show N more sub-agent messages" row.
///
/// Sidechain orphans are sub-agent messages whose parent Task never made
/// it into the loaded window; after a bounded walk-back the grouper gives
/// up and renders them inline. Two production sessions accumulated 91 and
/// 119 of them, which buried the actual conversation. Only the newest
/// handful stay inline; the rest sit behind this row until tapped.
class SidechainOrphanMore extends StatelessWidget {
  const SidechainOrphanMore({
    required this.hiddenCount,
    required this.onExpand,
    super.key,
  });

  /// How many orphans are collapsed behind this row.
  final int hiddenCount;

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    // TODO(l10n): localize once the sidechain strings land in the ARB.
    final label = hiddenCount == 1
        ? 'Show 1 earlier sub-agent message'
        : 'Show $hiddenCount earlier sub-agent messages';
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.lg,
      ),
      child: Center(
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(
                color: appCs.glassBorder,
                width: AppBorder.hairline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: onExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.unfold_more_rounded,
                      size: AppFontSize.sm,
                      color: cs.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: AppFontSize.xxs,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
