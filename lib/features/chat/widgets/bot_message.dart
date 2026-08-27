import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'message_focus_view.dart';
import 'streaming_cursor.dart';

/// Left-aligned assistant response with full markdown rendering.
///
/// Assistant prose uses an editorial, open-canvas layout. A compact accent
/// marker establishes authorship at the start of a group without wrapping
/// every long response in another competing card.
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

  @override
  State<BotMessage> createState() => _BotMessageState();
}

class _BotMessageState extends State<BotMessage> {
  bool _pressed = false;

  /// Marks the in-place bubble row so the focus view can animate its copy
  /// from exactly where the finger is.
  final GlobalKey _anchorKey = GlobalKey();

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  void _openFocusView() {
    HapticFeedback.heavyImpact();
    setState(() => _pressed = false);
    unawaited(
      showMessageFocusView(
        context,
        anchorKey: _anchorKey,
        text: widget.text,
        messageData: widget.messageData,
        messageBuilder: _row,
      ),
    );
  }

  /// The full bubble row (alignment + padding included), rendered both
  /// in-place and as the focused copy so the two line up pixel for pixel.
  Widget _row(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final appColors = theme.extension<AppColorScheme>();
    final accentGradient =
        appColors?.accentLinearGradient ??
        LinearGradient(colors: <Color>[cs.primary, cs.tertiary]);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
          top: widget.isCompact
              ? 0
              : (widget.isFirstInGroup ? AppSpacing.sm : 1),
          bottom: widget.isCompact
              ? 0
              : (widget.isLastInGroup ? AppSpacing.sm : 1),
        ),
        child: Semantics(
          label: widget.isStreaming
              ? 'AI response streaming'
              : 'AI message: ${_truncateForLabel(widget.text)}',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSpacing.xxl,
                child: widget.isFirstInGroup
                    ? Container(
                        key: const ValueKey<String>('assistant-message-marker'),
                        width: AppSpacing.xl,
                        height: AppSpacing.xl,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: accentGradient,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: AppIconSize.xs,
                          color: cs.onPrimary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  key: const ValueKey<String>('assistant-message-surface'),
                  padding: EdgeInsets.only(
                    top: widget.isCompact ? 0 : AppSpacing.xxs,
                    bottom: widget.isCompact ? 0 : AppSpacing.xs,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      height: AppLineHeight.relaxed,
                      color: cs.onSurface.withValues(alpha: AppOpacity.strong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarkdownView(
                          markdown: widget.text,
                          onOptionPress: widget.onOptionPress,
                          isStreaming: widget.isStreaming,
                        ),
                        if (widget.isStreaming)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xxxs),
                            child: StreamingCursor(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showMessageDetailSheet(context, widget.messageData),
      onLongPress: _openFocusView,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: KeyedSubtree(key: _anchorKey, child: _row(context)),
      ),
    );
  }
}
