import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A horizontal divider with a "conversation cleared" label, shown
/// after a `/clear` command in the chat message list.
class ClearedDivider extends StatelessWidget {
  const ClearedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          Expanded(
            child: Container(
              height: AppBorder.thin,
              color: labelColor.withValues(
                alpha: AppOpacity.medium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            child: Text(
              context.l10n.chatConversationCleared,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontSize: AppFontSize.xxs,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: AppBorder.thin,
              color: labelColor.withValues(
                alpha: AppOpacity.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
