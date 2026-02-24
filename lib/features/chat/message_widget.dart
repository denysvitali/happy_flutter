import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
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
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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

    // Error messages render as tappable error cards - no animation.
    if (kind == 'error') {
      return _ErrorMessageWidget(messageData: widget.messageData);
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
                  final isTask = widget.messageData['name'] == 'Task';
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
            ? _UserBubble(text: text, onOptionPress: widget.onOptionPress)
            : _BotMessage(text: text, onOptionPress: widget.onOptionPress),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User bubble (right-aligned, primary color, iMessage-style radius)
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, this.onOptionPress});

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
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showRawMarkdownSheet(context, text);
          },
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
            child: MarkdownView(
              markdown: text,
              onOptionPress: onOptionPress,
              textColor: Colors.white,
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
  const _BotMessage({required this.text, this.onOptionPress});

  final String text;
  final void Function(String)? onOptionPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showRawMarkdownSheet(context, text);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: 1,
          bottom: 2,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: textColor),
          child: MarkdownView(markdown: text, onOptionPress: onOptionPress),
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
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — always visible, tap to toggle.
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
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Thinking',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Expanded content — ClipRect prevents overflow during animation.
              ClipRect(
                child: SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          child: SimpleMarkdownView(markdown: _getCleanContent()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
// Raw markdown bottom sheet (long-press to copy)
// ---------------------------------------------------------------------------

/// Shows a bottom sheet with selectable raw markdown text
/// and a copy-all button. This provides a reliable way to
/// copy message content on Android where SelectionArea can
/// be unreliable.
void _showRawMarkdownSheet(BuildContext context, String markdown) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = context.l10n;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatCopyMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: markdown));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.commonCopy),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.commonCopy),
                ),
              ],
            ),
          ),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
          // Selectable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SelectableText(
                  markdown,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
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

// ---------------------------------------------------------------------------
// Error message widget (tappable with detail bottom sheet)
// ---------------------------------------------------------------------------

class _ErrorMessageWidget extends StatelessWidget {
  const _ErrorMessageWidget({required this.messageData});

  final Map<String, dynamic> messageData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final errorType = messageData['errorType'] as String? ?? 'unknown';
    final errorMessage =
        messageData['errorMessage'] as String? ?? 'Unknown error';

    return GestureDetector(
      onTap: () => _showErrorDetailSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorType.replaceAll('_', ' '),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      errorMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onErrorContainer.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final errorType = messageData['errorType'] as String? ?? 'unknown';
    final errorMessage =
        messageData['errorMessage'] as String? ?? 'Unknown error';
    final messageId = messageData['id'] as String?;
    final seq = messageData['seq'] as int?;
    final createdAt = messageData['createdAt'] as int?;
    final debugData = messageData['debugData'] as Map<String, dynamic>?;

    final timestamp = createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(createdAt).toString()
        : 'Unknown';

    final jsonString = const JsonEncoder.withIndent('  ').convert({
      'errorType': errorType,
      'errorMessage': errorMessage,
      'messageId': messageId,
      'seq': seq,
      'createdAt': timestamp,
      'debugData': debugData,
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      errorType.replaceAll('_', ' '),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonString));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.commonCopy),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.commonCopy),
                  ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
            // Error details
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Error message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      errorMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Metadata
                  _DetailRow(label: 'Message ID', value: messageId ?? 'N/A'),
                  _DetailRow(label: 'Seq', value: seq?.toString() ?? 'N/A'),
                  _DetailRow(label: 'Timestamp', value: timestamp),
                  const SizedBox(height: AppSpacing.md),
                  // Debug data
                  Text(
                    'Debug Data',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: SelectableText(
                      debugData != null
                          ? const JsonEncoder.withIndent(
                              '  ',
                            ).convert(debugData)
                          : 'No debug data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: const Color(0xFF9CDCFE),
                        height: 1.4,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
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
