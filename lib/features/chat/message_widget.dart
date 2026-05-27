import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import 'markdown/markdown.dart';
import 'tools/tools.dart';
import 'widgets/agent_event_widget.dart';
import 'widgets/bot_message.dart';
import 'widgets/error_message_widget.dart';
import 'widgets/hidden_tool_summary.dart';
import 'widgets/streaming_cursor.dart';
import 'widgets/thinking_block.dart';
import 'widgets/user_bubble.dart';

export 'widgets/agent_event_widget.dart';
export 'widgets/bot_message.dart';
export 'widgets/error_message_widget.dart';
export 'widgets/message_detail_sheet.dart';
export 'widgets/send_status_indicator.dart';
export 'widgets/thinking_block.dart';
export 'widgets/user_bubble.dart';

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
    this.isSessionOnline = true,
    this.onOptionPress,
    this.onRetry,
    this.animate = true,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isStreaming = false,
    this.isCompact = false,
  });

  final Map<String, dynamic> messageData;
  final bool isFromCurrentUser;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? messages;
  final String? sessionId;
  final bool isSessionOnline;
  final void Function(String)? onOptionPress;
  final VoidCallback? onRetry;

  /// Whether to play the entrance fade+slide animation.
  ///
  /// Set to [false] for messages that were already present when the screen
  /// opened (bulk-loaded history) so that 50 simultaneous
  /// [AnimationController]s don't all compete for frame time on open.
  final bool animate;

  /// Whether this is the first message in a group from the same sender.
  final bool isFirstInGroup;

  /// Whether this is the last message in a group from the same sender.
  final bool isLastInGroup;

  /// Whether the assistant is currently streaming this message.
  ///
  /// When [true] a blinking [StreamingCursor] is appended after the content.
  /// Only meaningful for bot messages; ignored for user bubbles.
  final bool isStreaming;

  /// Whether this message is sandwiched between two tool-like neighbors.
  ///
  /// Bot messages in this position render with reduced vertical padding so
  /// the tool flow reads tightly. Ignored for non-bot kinds.
  final bool isCompact;

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Widget? _cachedBody;
  int? _cachedBodySignature;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      // Only create controller for new messages that need animation.
      // Bulk-loaded messages (animate=false) skip controller creation
      // entirely to avoid 50+ controllers competing for frame time.
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      );
      _opacity = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOut,
      );
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller!,
          curve: Curves.elasticOut,
        ),
      );
      _controller!.forward();
    } else {
      // Historical message — use static animations to avoid
      // controller overhead.
      _opacity = const AlwaysStoppedAnimation(1.0);
      _slide = const AlwaysStoppedAnimation(Offset.zero);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildCachedBody(context);

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: body),
    );
  }

  Widget _buildCachedBody(BuildContext context) {
    // Cache signature is derived from STABLE message identifiers and
    // content, not from Map/List object identity. The parent (sync) may
    // hand us a fresh Map for the same logical message; identity-based
    // hashing would invalidate the cache on every parent rebuild.
    //
    // Callback identity is intentionally excluded — parent closures churn
    // on every rebuild but the bubble's rendered output depends only on
    // whether a callback is present, not on which closure instance it is.
    final msg = widget.messageData;
    final messageId =
        msg['id'] as String? ??
        msg['localId'] as String? ??
        msg['key'] as String?;
    final content = msg['content'] ?? msg['text'];
    final signature = Object.hash(
      messageId,
      msg['kind'],
      msg['role'],
      msg['name'],
      msg['sendStatus'],
      msg['isThinking'],
      msg['updatedAt'] ?? msg['createdAt'],
      content is String ? content : content?.toString(),
      // Tool/Agent messages also need to invalidate when the messages
      // list reference changes meaningfully. List identity is acceptable
      // because chat_screen only passes `_messages` for Task/Agent and
      // recreates it deliberately when contents change.
      widget.messages == null ? 0 : widget.messages!.length,
      widget.sessionId,
      widget.isSessionOnline,
      widget.isFromCurrentUser,
      widget.isFirstInGroup,
      widget.isLastInGroup,
      widget.isStreaming,
      widget.isCompact,
      widget.onOptionPress != null,
      widget.onRetry != null,
    );

    if (_cachedBody != null && _cachedBodySignature == signature) {
      return _cachedBody!;
    }

    final kind = widget.messageData['kind'] as String? ?? 'unknown';

    // Agent events render as centered system-style text - no animation.
    if (kind == 'agent-event') {
      return _cacheBody(
        signature,
        AgentEventWidget(event: widget.messageData['event']),
      );
    }

    // Error messages render as tappable error cards - no animation.
    if (kind == 'error') {
      return _cacheBody(
        signature,
        ErrorMessageWidget(messageData: widget.messageData),
      );
    }

    // Tool calls render without bubble styling - no animation.
    if (kind == 'tool-call') {
      final messageId = widget.messageData['id'] as String?;
      return _cacheBody(
        signature,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: ToolView(
            tool: widget.messageData,
            metadata: widget.metadata,
            sessionId: widget.sessionId,
            isSessionOnline: widget.isSessionOnline,
            onPress: (widget.sessionId != null && messageId != null)
                ? () {
                    final isTask =
                        widget.messageData['name'] == 'Task' ||
                        widget.messageData['name'] == 'Agent';
                    final route = isTask
                        ? '/chat/${widget.sessionId}'
                              '/agent/$messageId'
                        : '/chat/${widget.sessionId}'
                              '/message/$messageId';
                    context.push(route, extra: widget.messageData);
                  }
                : null,
          ),
        ),
      );
    }

    if (kind == 'hidden-tool-summary') {
      return _cacheBody(
        signature,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: HiddenToolSummary(
            data: widget.messageData,
            metadata: widget.metadata,
            sessionId: widget.sessionId,
            isSessionOnline: widget.isSessionOnline,
          ),
        ),
      );
    }

    final content =
        widget.messageData['content'] ?? widget.messageData['text'] ?? '';
    final text = content is String ? content : content.toString();

    // Thinking blocks get a collapsible container instead of a bubble.
    final isThinking = widget.messageData['isThinking'] == true;
    if (isThinking && !widget.isFromCurrentUser) {
      return _cacheBody(signature, ThinkingBlock(content: text));
    }

    final sendStatus = widget.messageData['sendStatus'] as String?;

    return _cacheBody(
      signature,
      widget.isFromCurrentUser
          ? UserBubble(
              text: text,
              onOptionPress: widget.onOptionPress,
              sendStatus: sendStatus,
              onRetry: widget.onRetry,
              isFirstInGroup: widget.isFirstInGroup,
              isLastInGroup: widget.isLastInGroup,
            )
          : BotMessage(
              text: text,
              messageData: widget.messageData,
              onOptionPress: widget.onOptionPress,
              isFirstInGroup: widget.isFirstInGroup,
              isLastInGroup: widget.isLastInGroup,
              isStreaming: widget.isStreaming,
              isCompact: widget.isCompact,
            ),
    );
  }

  Widget _cacheBody(int signature, Widget body) {
    _cachedBodySignature = signature;
    _cachedBody = body;
    return body;
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
