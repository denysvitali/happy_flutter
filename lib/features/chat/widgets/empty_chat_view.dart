import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// View shown when the chat is empty
class EmptyChatView extends StatelessWidget {
  /// Creates an empty chat view
  const EmptyChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.chatStartConversation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chatSendMessageToBegin,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
