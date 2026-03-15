import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
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
    this.isSessionOnline = true,
    this.onOptionPress,
    this.animate = true,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final Map<String, dynamic> messageData;
  final bool isFromCurrentUser;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? messages;
  final String? sessionId;
  final bool isSessionOnline;
  final void Function(String)? onOptionPress;

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
    if (widget.animate) {
      _controller.forward();
    } else {
      // Historical message — skip animation entirely so bulk-loaded
      // messages don't all animate at once (50 AnimationControllers
      // competing for frame time caused jank on chat open).
      _controller.value = 1.0;
    }
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: ToolView(
          tool: widget.messageData,
          metadata: widget.metadata,
          messages: widget.messages,
          sessionId: widget.sessionId,
          isSessionOnline: widget.isSessionOnline,
          onPress: (widget.sessionId != null && messageId != null)
              ? () {
                  final isTask = widget.messageData['name'] == 'Task' ||
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

    final sendStatus =
        widget.messageData['sendStatus'] as String?;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.isFromCurrentUser
            ? _UserBubble(
                text: text,
                onOptionPress: widget.onOptionPress,
                sendStatus: sendStatus,
                isFirstInGroup: widget.isFirstInGroup,
                isLastInGroup: widget.isLastInGroup,
              )
            : _BotMessage(
                text: text,
                messageData: widget.messageData,
                onOptionPress: widget.onOptionPress,
                isFirstInGroup: widget.isFirstInGroup,
                isLastInGroup: widget.isLastInGroup,
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
    this.sendStatus,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final String text;
  final void Function(String)? onOptionPress;

  /// `null` = confirmed (server-origin), `'sending'`, `'sent'`,
  /// `'failed'`.
  final String? sendStatus;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  static const _full = Radius.circular(AppRadius.xl);
  static const _small = Radius.circular(AppRadius.xsm);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

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
        padding: const EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.sm,
          top: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
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
                  markdown: text,
                  onOptionPress: onOptionPress,
                  textColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            if (sendStatus != null)
              _SendStatusIndicator(status: sendStatus!),
          ],
        ),
      ),
    );
  }
}

/// Tiny status label shown below user bubbles for optimistic messages.
class _SendStatusIndicator extends StatelessWidget {
  const _SendStatusIndicator({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      fontSize: AppFontSize.xxs,
      height: 1.2,
    );

    switch (status) {
      case 'sending':
        return Padding(
          padding: const EdgeInsets.only(
            top: 3,
            right: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: cs.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'Sending',
                style: style?.copyWith(
                  color: cs.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'failed':
        return Padding(
          padding: const EdgeInsets.only(
            top: 3,
            right: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 10,
                color: cs.error.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 3),
              Text(
                'Failed to send',
                style: style?.copyWith(
                  color: cs.error.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      default:
        // 'sent' or unknown — no indicator.
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Bot message (left-aligned, full width, clean typography)
// ---------------------------------------------------------------------------

class _BotMessage extends StatelessWidget {
  const _BotMessage({
    required this.text,
    required this.messageData,
    this.onOptionPress,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final String text;
  final Map<String, dynamic> messageData;
  final void Function(String)? onOptionPress;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  static const _full = Radius.circular(AppRadius.xl);
  static const _small = Radius.circular(AppRadius.xsm);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Grouped radii: left side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: isFirstInGroup ? _full : _small,
      topRight: _full,
      bottomLeft: isLastInGroup ? _full : _small,
      bottomRight: _full,
    );

    return GestureDetector(
      onTap: () =>
          _showMessageDetailSheet(context, messageData),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showRawMarkdownSheet(context, text);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.xxl,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width * 0.85,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
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
                child: MarkdownView(
                  markdown: text,
                  onOptionPress: onOptionPress,
                ),
              ),
            ),
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

  /// Whether the collapse animation has fully completed (value == 0).
  /// When true and [_expanded] is false, we skip building the markdown
  /// content entirely to avoid unnecessary layout work.
  bool _animationComplete = true;

  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  /// Cached result of the content-cleaning logic. Recomputed only when
  /// [widget.content] changes (in [didUpdateWidget]), not on every build.
  late String _cleanedContent;

  static final _thinkingPrefix =
      RegExp(r'^\*Thinking\.\.\.\*\s*\n*');

  static String _computeCleanContent(String raw) {
    var text = raw.replaceFirst(_thinkingPrefix, '').trim();
    // Strip outer *...* italic markers baked in by
    // message_processor/sync_service.
    if (text.startsWith('*') &&
        text.endsWith('*') &&
        text.length > 2) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _cleanedContent = _computeCleanContent(widget.content);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    // Listen for animation status so we can drop the markdown subtree once
    // the collapse transition finishes.
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      // Collapse animation finished — safe to remove markdown from tree.
      setState(() => _animationComplete = true);
    } else if (_animationComplete) {
      // Animation is running again; re-insert markdown so the transition
      // has content to animate.
      setState(() => _animationComplete = false);
    }
  }

  @override
  void didUpdateWidget(_ThinkingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      _cleanedContent = _computeCleanContent(widget.content);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      // About to expand — ensure markdown is in the tree before animating.
      _animationComplete = false;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Only build the markdown content when expanded or animating.
    final showContent = _expanded || !_animationComplete;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: AppOpacity.subtle),
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
                    child: showContent
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: DefaultTextStyle.merge(
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: AppFontSize.md,
                                    height: 1.5,
                                  ),
                                  child: SimpleMarkdownView(
                                    markdown: _cleanedContent,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
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
// Message detail bottom sheet (tap on bot message)
// ---------------------------------------------------------------------------

void _showMessageDetailSheet(
  BuildContext context,
  Map<String, dynamic> messageData,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = AppLocalizations.of(context);

  // meta may be directly on the message or inside the 'raw' decrypted record.
  final raw = messageData['raw'] as Map<String, dynamic>?;
  final meta = (messageData['meta'] as Map<String, dynamic>?)
      ?? (raw?['meta'] is Map<String, dynamic>
          ? raw!['meta'] as Map<String, dynamic>
          : null);
  final model = meta?['model'] as String?
      ?? messageData['model'] as String?;
  final permissionMode = meta?['permissionMode'] as String?;
  final createdAt = messageData['createdAt'] as int?;

  final hasDetails = model != null || permissionMode != null;

  // Capture now once when the sheet is opened, not on every rebuild.
  final now = DateTime.now();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.messageDetailDetails,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!hasDetails)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  l10n.messageDetailNoDetails,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (model != null)
              _MessageInfoRow(
                icon: Icons.auto_awesome_outlined,
                label: l10n.messageDetailModel,
                value: model,
              ),
            if (permissionMode != null)
              _MessageInfoRow(
                icon: Icons.shield_outlined,
                label: l10n.messageDetailPermission,
                value: permissionMode,
              ),
            if (createdAt != null)
              _MessageInfoRow(
                icon: Icons.access_time_outlined,
                label: l10n.messageDetailSent,
                value: _formatTimestamp(createdAt, now),
              ),
          ],
        ),
      ),
    ),
  );
}

String _formatTimestamp(int milliseconds, DateTime now) {
  final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final diff = now.difference(dt);

  final timeStr =
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  if (diff.inDays == 0) return 'Today at $timeStr';
  if (diff.inDays == 1) return 'Yesterday at $timeStr';
  return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
}

class _MessageInfoRow extends StatelessWidget {
  const _MessageInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
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
                    fontSize: AppFontSize.md,
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

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

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

    final jsonString = _jsonEncoder.convert({
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
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
                  _DetailRow(
                    label: l10n.messageDetailMessageId,
                    value: messageId ?? l10n.commonNA,
                  ),
                  _DetailRow(
                    label: l10n.messageDetailSeq,
                    value: seq?.toString() ?? l10n.commonNA,
                  ),
                  _DetailRow(
                    label: l10n.messageDetailTimestamp,
                    value: timestamp,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Debug data
                  Text(
                    l10n.messageDetailDebugData,
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
                          ? _jsonEncoder.convert(debugData)
                          : 'No debug data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.sm,
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
