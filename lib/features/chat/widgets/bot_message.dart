import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'streaming_cursor.dart';

/// Left-aligned bot message bubble with full markdown rendering.
class BotMessage extends StatefulWidget {
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

  @override
  State<BotMessage> createState() => _BotMessageState();
}

class _BotMessageState extends State<BotMessage> {
  bool _pressed = false;

  // Precomputed border-radius variants. Selecting one is just an indexed
  // lookup — avoids allocating a fresh BorderRadius on every build.
  static const BorderRadius _radiusFirstLast = BorderRadius.only(
    topLeft: BotMessage._full,
    topRight: BotMessage._full,
    bottomLeft: BotMessage._full,
    bottomRight: BotMessage._full,
  );
  static const BorderRadius _radiusFirstOnly = BorderRadius.only(
    topLeft: BotMessage._full,
    topRight: BotMessage._full,
    bottomLeft: BotMessage._small,
    bottomRight: BotMessage._full,
  );
  static const BorderRadius _radiusLastOnly = BorderRadius.only(
    topLeft: BotMessage._small,
    topRight: BotMessage._full,
    bottomLeft: BotMessage._full,
    bottomRight: BotMessage._full,
  );
  static const BorderRadius _radiusMiddle = BorderRadius.only(
    topLeft: BotMessage._small,
    topRight: BotMessage._full,
    bottomLeft: BotMessage._small,
    bottomRight: BotMessage._full,
  );

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  BorderRadius _radius() {
    if (widget.isFirstInGroup && widget.isLastInGroup) return _radiusFirstLast;
    if (widget.isFirstInGroup) return _radiusFirstOnly;
    if (widget.isLastInGroup) return _radiusLastOnly;
    return _radiusMiddle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Grouped radii: left side pinches for consecutive messages.
    final radius = _radius();

    return GestureDetector(
      onTap: () => showMessageDetailSheet(context, widget.messageData),
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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: widget.isCompact
                  ? 0
                  : (widget.isFirstInGroup ? AppSpacing.xs : 1),
              bottom: widget.isCompact
                  ? 0
                  : (widget.isLastInGroup ? AppSpacing.xs : 1),
            ),
            child: Semantics(
              label: widget.isStreaming
                  ? 'AI response streaming'
                  : 'AI message: ${_truncateForLabel(widget.text)}',
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: widget.isCompact ? AppSpacing.xs : AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: radius,
                  border: Border.all(
                    color: cs.outlineVariant.withValues(
                      alpha: AppOpacity.subtle,
                    ),
                    width: 0.5,
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: cs.onSurface),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarkdownView(
                        markdown: widget.text,
                        onOptionPress: widget.onOptionPress,
                      ),
                      if (widget.isStreaming) const StreamingCursor(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
