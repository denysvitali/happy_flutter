import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import 'markdown/markdown.dart';
import 'tools/tools.dart';

/// Message widget for displaying chat messages with speech bubbles,
/// entrance animations, and full markdown support.
class MessageWidget extends StatefulWidget {
  /// Creates a [MessageWidget].
  const MessageWidget({
    required this.messageData,
    required this.isFromCurrentUser,
    super.key,
    this.metadata,
    this.messages,
    this.sessionId,
    this.onOptionPress,
  });

  final Map<String, dynamic> messageData;
  final bool isFromCurrentUser;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? messages;
  final String? sessionId;
  final void Function(String)? onOptionPress;

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.messageData['kind'] as String? ?? 'unknown';

    // Agent events render as centered system-style text - no animation.
    if (kind == 'agent-event') {
      return _AgentEventWidget(event: widget.messageData['event']);
    }

    // Tool calls render without bubble styling - no animation.
    if (kind == 'tool-call') {
      final messageId = widget.messageData['id'] as String?;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ToolView(
          tool: widget.messageData,
          metadata: widget.metadata,
          messages: widget.messages,
          sessionId: widget.sessionId,
          onPress: (widget.sessionId != null && messageId != null)
              ? () {
                  final isTask =
                      widget.messageData['name'] == 'Task';
                  final route = isTask
                      ? '/chat/${widget.sessionId}'
                            '/agent/$messageId'
                      : '/chat/${widget.sessionId}'
                            '/message/$messageId';
                  context.push(route, extra: widget.messageData);
                }
              : null,
        ),
      );
    }

    final content =
        widget.messageData['content'] ?? widget.messageData['text'] ?? '';
    final text = content is String ? content : content.toString();

    // Thinking blocks get a collapsible container instead of a bubble.
    final isThinking = widget.messageData['isThinking'] == true;
    if (isThinking && !widget.isFromCurrentUser) {
      return FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: _ThinkingBlock(content: text),
        ),
      );
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.isFromCurrentUser
            ? _UserBubble(
                text: text,
                onOptionPress: widget.onOptionPress,
              )
            : _BotMessage(
                text: text,
                onOptionPress: widget.onOptionPress,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User bubble (right-aligned, primary color, iMessage-style radius)
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.text,
    this.onOptionPress,
  });

  final String text;
  final void Function(String)? onOptionPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 60,
          right: AppSpacing.md,
          top: 1,
          bottom: 2,
        ),
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
            ),
            child: SelectionArea(
              contextMenuBuilder: (ctx, selectableRegionState) {
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors:
                      selectableRegionState.contextMenuAnchors,
                  buttonItems: [
                    ...selectableRegionState
                        .contextMenuButtonItems,
                    ContextMenuButtonItem(
                      label: 'Copy All',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        Clipboard.setData(
                          ClipboardData(text: text),
                        );
                      },
                    ),
                  ],
                );
              },
              child: MarkdownView(
                markdown: text,
                onOptionPress: onOptionPress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bot message (left-aligned, full width, clean typography)
// ---------------------------------------------------------------------------

class _BotMessage extends StatelessWidget {
  const _BotMessage({
    required this.text,
    this.onOptionPress,
  });

  final String text;
  final void Function(String)? onOptionPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: 1,
        bottom: 2,
      ),
      child: SelectionArea(
        contextMenuBuilder: (ctx, selectableRegionState) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: [
              ...selectableRegionState.contextMenuButtonItems,
              ContextMenuButtonItem(
                label: 'Copy All',
                onPressed: () {
                  ContextMenuController.removeAny();
                  Clipboard.setData(ClipboardData(text: text));
                },
              ),
            ],
          );
        },
        child: DefaultTextStyle.merge(
          style: TextStyle(color: textColor),
          child: MarkdownView(
            markdown: text,
            onOptionPress: onOptionPress,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thinking block widget (collapsible)
// ---------------------------------------------------------------------------

class _ThinkingBlock extends StatefulWidget {
  const _ThinkingBlock({required this.content});

  final String content;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  String _getCleanContent() {
    return widget.content
        .replaceFirst(RegExp(r'^\*Thinking\.\.\.\*\s*\n*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row — always visible, tap to toggle.
            GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Thinking',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded content with animation.
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 0.5,
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      child: MarkdownView(
                        markdown: _getCleanContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent event widget
// ---------------------------------------------------------------------------

class _AgentEventWidget extends StatelessWidget {
  const _AgentEventWidget({required this.event});

  final dynamic event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _eventLabel(event);
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String? _eventLabel(dynamic event) {
    if (event is! Map<String, dynamic>) return null;
    final type = event['type'] as String?;
    switch (type) {
      case 'switch':
        final mode = event['mode'] as String?;
        return mode != null ? 'Switched to $mode mode' : 'Mode switched';
      case 'message':
        return event['message'] as String?;
      case 'limit-reached':
        return 'Usage limit reached';
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// MarkdownMessage - simple standalone markdown renderer
// ---------------------------------------------------------------------------

/// Markdown rendered message widget.
class MarkdownMessage extends StatelessWidget {
  /// Creates a [MarkdownMessage].
  const MarkdownMessage({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SimpleMarkdownView(markdown: content);
  }
}
