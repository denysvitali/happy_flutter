import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A centered label shown at the top of the chat message list indicating
/// the beginning of the conversation.
class ConversationStartLabel extends StatelessWidget {
  const ConversationStartLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('header-beginning'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.xxl,
      ),
      child: Center(
        child: Text(
          context.l10n.chatBeginningOfConversation,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(
              alpha: AppOpacity.half,
            ),
          ),
        ),
      ),
    );
  }
}
