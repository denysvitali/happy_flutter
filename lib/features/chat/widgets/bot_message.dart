import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/pressable_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'streaming_cursor.dart';

/// Left-aligned bot message bubble with full markdown rendering.
class BotMessage extends StatelessWidget {
  const BotMessage({
    required this.text,
    required this.messageData,
    super.key,
    this.onOptionPress,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isStreaming = false,
    this.isCompact = false,
  });

  final String text;
  final Map<String, dynamic> messageData;
  final void Function(String)? onOptionPress;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isStreaming;

  /// Reduce vertical padding when sandwiched between two tool-like
  /// neighbors so the tool flow reads tightly.
  final bool isCompact;

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

    // Grouped radii: left side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: isFirstInGroup ? _full : _small,
      topRight: _full,
      bottomLeft: isLastInGroup ? _full : _small,
      bottomRight: _full,
    );

    return PressableCard(
      onTap: () => showMessageDetailSheet(context, messageData),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        showRawMarkdownSheet(context, text);
      },
      pressedScale: 0.97,
      enableHaptics: false,
      duration: const Duration(milliseconds: 100),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: isCompact ? 0 : (isFirstInGroup ? AppSpacing.xs : 1),
            bottom: isCompact ? 0 : (isLastInGroup ? AppSpacing.xs : 1),
          ),
          child: Semantics(
            label: isStreaming
                ? 'AI response streaming'
                : 'AI message: ${_truncateForLabel(text)}',
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: isCompact ? AppSpacing.xs : AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: radius,
                border: Border.all(
                  color: cs.outlineVariant.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  width: AppBorder.hairline,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: cs.onSurface),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarkdownView(
                      markdown: text,
                      onOptionPress: onOptionPress,
                    ),
                    if (isStreaming) const StreamingCursor(),
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
