import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/pressable_card.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'send_status_indicator.dart';

/// Right-aligned speech bubble for user messages.
///
/// Uses primary color background with iMessage-style grouped radii.
class UserBubble extends StatelessWidget {
  const UserBubble({
    required this.text,
    super.key,
    this.onOptionPress,
    this.sendStatus,
    this.onRetry,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final String text;
  final void Function(String)? onOptionPress;

  /// `null` = confirmed (server-origin), `'sending'`, `'sent'`,
  /// `'failed'`.
  final String? sendStatus;
  final VoidCallback? onRetry;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  static const _full = Radius.circular(AppRadius.xl);
  static const _small = Radius.circular(AppRadius.xsm);

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

    // Grouped radii: right side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: _full,
      topRight: isFirstInGroup ? _full : _small,
      bottomLeft: _full,
      bottomRight: isLastInGroup ? _full : _small,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.sm,
          top: isFirstInGroup ? AppSpacing.xs : 1,
          bottom: isLastInGroup ? AppSpacing.xs : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            PressableCard(
              onLongPress: () {
                HapticFeedback.heavyImpact();
                showRawMarkdownSheet(context, text);
              },
              pressedScale: 0.97,
              enableHaptics: false,
              duration: const Duration(milliseconds: 100),
              child: Semantics(
                label: 'User message: ${_truncateForLabel(text)}',
                button: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md + 2,
                    vertical: AppSpacing.sm + 2,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.80,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(40),
                        blurRadius: AppSpacing.sm,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MarkdownView(
                    markdown: text,
                    onOptionPress: onOptionPress,
                    textColor: cs.onPrimary,
                  ),
                ),
              ),
            ),
            if (sendStatus != null)
              SendStatusIndicator(
                status: sendStatus!,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}
