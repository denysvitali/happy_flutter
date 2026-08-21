import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A horizontal divider with a "conversation cleared" label, shown
/// after a `/clear` command in the chat message list.
///
/// Part of the inline-transcript divider family (see
/// [ModelChangeDivider]): centered label between two static hairline
/// rules that fade out toward the edges, so notices read as carved
/// into the transcript rather than stamped across it.
class ClearedDivider extends StatelessWidget {
  const ClearedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final glass =
        theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    // Cleared stays the quietest member of the family — it marks an
    // erasure, not an event worth hunting for.
    final labelColor = cs.onSurfaceVariant.withValues(
      alpha: AppOpacity.half,
    );
    return Padding(
      key: const ValueKey('cleared-divider'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(child: _buildRule(glass)),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Text(
              context.l10n.chatConversationCleared,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.xxs,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(child: _buildRule(glass)),
        ],
      ),
    );
  }

  /// Static hairline rule fading transparent → glass → transparent.
  Widget _buildRule(AppColorScheme glass) {
    return Container(
      height: AppBorder.hairline,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            glass.glassBorder,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
