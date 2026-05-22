import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'send_status_indicator.dart';

/// Right-aligned speech bubble for user messages.
///
/// Uses primary color background with iMessage-style grouped radii.
class UserBubble extends StatefulWidget {
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

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  bool _pressed = false;

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    // Grouped radii: right side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: UserBubble._full,
      topRight: widget.isFirstInGroup ? UserBubble._full : UserBubble._small,
      bottomLeft: UserBubble._full,
      bottomRight: widget.isLastInGroup ? UserBubble._full : UserBubble._small,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.sm,
          top: widget.isFirstInGroup ? AppSpacing.xs : 1,
          bottom: widget.isLastInGroup ? AppSpacing.xs : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: () {
                HapticFeedback.heavyImpact();
                showRawMarkdownSheet(context, widget.text);
              },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
                child: Semantics(
                  label: 'User message: ${_truncateForLabel(widget.text)}',
                  button: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 2,
                      vertical: AppSpacing.sm + 2,
                    ),
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.sizeOf(context).width *
                          0.80,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: MarkdownView(
                      markdown: widget.text,
                      onOptionPress: widget.onOptionPress,
                      textColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.sendStatus != null)
              SendStatusIndicator(
                status: widget.sendStatus!,
                onRetry: widget.onRetry,
              ),
          ],
        ),
      ),
    );
  }
}
