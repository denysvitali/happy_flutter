import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A centered label shown at the top of the chat message list indicating
/// the beginning of the conversation.
///
/// Matches the divider family: tiny uppercase label with hairline side
/// rules that fade from transparent to glass to transparent.
class ConversationStartLabel extends StatelessWidget {
  const ConversationStartLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ruleColor = cs.onSurfaceVariant.withValues(
      alpha: AppOpacity.soft,
    );

    return Padding(
      key: const ValueKey('header-beginning'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.xxl,
      ),
      child: Row(
        children: [
          Expanded(child: _HairlineRule(color: ruleColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              context.l10n.chatBeginningOfConversation.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.half),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(child: _HairlineRule(color: ruleColor)),
        ],
      ),
    );
  }
}

/// Hairline rule fading transparent → glass → transparent.
class _HairlineRule extends StatelessWidget {
  const _HairlineRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
