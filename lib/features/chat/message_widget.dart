import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'markdown/markdown.dart';
import 'tools/tools.dart';

/// Message widget for displaying chat messages with speech bubbles,
/// tails, entrance animations, and full markdown support.
///
/// Supports rich text formatting including headers, lists, code blocks,
/// tables, mermaid diagrams, and text selection via long-press.
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
// User bubble (right-aligned, primary color, tail bottom-right)
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
          left: 48,
          right: 10,
          top: 1,
          bottom: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            // Tail pointing bottom-right
            CustomPaint(
              size: const Size(8, 10),
              painter: _UserTailPainter(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bot message (left-aligned, plain content, full width, no bubble)
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
        left: 10,
        right: 10,
        top: 1,
        bottom: 4,
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
// Tail painters
// ---------------------------------------------------------------------------

/// Draws a small triangle tail for the user (sent) bubble.
///
/// The tail attaches to the bottom-right corner of the bubble,
/// pointing downward and to the right, like an iMessage sent bubble.
class _UserTailPainter extends CustomPainter {
  const _UserTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_UserTailPainter old) => old.color != color;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
///
/// A simpler widget for rendering just markdown content without
/// the chat message container styling.
class MarkdownMessage extends StatelessWidget {
  /// Creates a [MarkdownMessage].
  const MarkdownMessage({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SimpleMarkdownView(markdown: content);
  }
}
