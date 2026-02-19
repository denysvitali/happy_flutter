import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/sync_service.dart';
import 'chat_input.dart';
import 'message_widget.dart';
import 'widgets/permission_mode_selector.dart';

/// Chat screen for a session
class ChatScreen extends ConsumerStatefulWidget {

  const ChatScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _syncPollTimer;
  bool _isSubscribing = false;
  bool _isSending = false;
  bool _isLoadingMessages = true;
  bool _isSubscribed = false;

  /// Whether autoscroll to the bottom is active.
  ///
  /// Autoscroll is enabled when the user is within [_autoScrollThreshold]
  /// pixels of the bottom of the list. When the user scrolls up past that
  /// threshold, autoscroll is disabled so they can read history without being
  /// interrupted by new messages. A FAB is shown to re-enable autoscroll.
  bool _autoScroll = true;

  /// Distance (in pixels) from the bottom of the list within which
  /// autoscroll is considered active.
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.readOnly;
  ClaudeModel _modelMode = ClaudeModel.defaultModel;
  Session? _session;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedPermissionMode();
    _initializeSyncBackedChat();
  }

  Future<void> _loadSavedPermissionMode() async {
    final savedMode = await DraftStorage().getPermissionMode(widget.sessionId);
    if (savedMode != null) {
      final parsedMode = PermissionModeExtension.fromString(savedMode);
      setState(() {
        _permissionMode = parsedMode ?? PermissionMode.readOnly;
      });
    }
  }

  @override
  void dispose() {
    _syncPollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSyncBackedChat() async {
    _syncPollTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) => unawaited(_onSyncTick()),
    );
    await _onSyncTick();
  }

  Future<void> _onSyncTick() async {
    if (!sync.isInitialized) {
      return;
    }

    if (!_isSubscribed && !_isSubscribing) {
      _isSubscribing = true;
      try {
        sync.onSessionVisible(widget.sessionId);
        _isSubscribed = true;
        await sync.messagesSync[widget.sessionId]?.awaitQueue();
        _refreshFromSync(markLoaded: true);
      } finally {
        _isSubscribing = false;
      }
      return;
    }

    _refreshFromSync();
  }

  void _refreshFromSync({bool markLoaded = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages =
        sync.sessionMessages[widget.sessionId] ?? <Map<String, dynamic>>[];

    final sessionChanged = latestSession != _session;
    final messagesChanged = !_sameMessages(latestMessages, _messages);
    if (!sessionChanged && !messagesChanged && !markLoaded) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _session = latestSession;
      _messages = List<Map<String, dynamic>>.from(latestMessages);
      if (markLoaded) {
        _isLoadingMessages = false;
      }
    });

    if (messagesChanged && _autoScroll) {
      _scrollToBottom();
    }
  }

  bool _sameMessages(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id']) {
        return false;
      }
      if (a[i]['seq'] != b[i]['seq']) {
        return false;
      }
    }
    return true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      // With reverse: true, position 0 is the bottom
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // With reverse: true, pixels == 0 means we are at the bottom (newest
    // messages). Autoscroll is active when within [_autoScrollThreshold] of 0.
    final nearBottom = pos.pixels <= _autoScrollThreshold;
    if (nearBottom != _autoScroll) {
      setState(() {
        _autoScroll = nearBottom;
      });
    }

    // Load older messages when the user scrolls toward the top of the reversed
    // list (pixels approaching maxScrollExtent).
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= _messages.length) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, _messages.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isThinking = _session?.thinking ?? false;

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(l10n),
        actions: [
          if (isThinking)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Stop',
              onPressed: _stopSession,
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSessionMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Messages list with AnimatedSwitcher for loading state
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingMessages
                      ? const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        )
                      : _messages.isEmpty
                          ? const _EmptyChatView(key: ValueKey('empty'))
                          : _buildMessageList(),
                ),
                // "Scroll to bottom" FAB — shown when autoscroll is disabled
                // (i.e. the user has scrolled up to read history).
                if (!_autoScroll && !_isLoadingMessages)
                  Positioned(
                    right: 12,
                    bottom: 60,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        setState(() => _autoScroll = true);
                        _scrollToBottom();
                      },
                      tooltip: 'Scroll to bottom',
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                // Typing indicator overlay at the bottom of the messages area
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                    child: isThinking && !_isLoadingMessages
                        ? const Align(
                            key: ValueKey('typing'),
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 12,
                                right: 12,
                                bottom: 8,
                              ),
                              child: _TypingIndicator(),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('no-typing'),
                          ),
                  ),
                ),
              ],
            ),
          ),
          ChatInput(
            sessionId: widget.sessionId,
            controller: _controller,
            onSend: _sendMessage,
            isSending: _isSending,
            permissionMode: _permissionMode,
            onPermissionModeChanged: _onPermissionModeChanged,
            modelMode: _modelMode,
            onModelModeChanged: _onModelModeChanged,
            contextSize: sync.sessionUsage[widget.sessionId]
                ?['contextSize'] as int?,
          ),
        ],
      ),
    );
  }

  void _onPermissionModeChanged(PermissionMode mode) {
    setState(() => _permissionMode = mode);
    DraftStorage().savePermissionMode(widget.sessionId, mode.toModeString());
  }

  void _onModelModeChanged(ClaudeModel model) {
    setState(() => _modelMode = model);
  }

  void _onPlanAccepted(String permissionMode) {
    final parsed = PermissionModeExtension.fromString(permissionMode);
    if (parsed != null) {
      _onPermissionModeChanged(parsed);
    }
  }

  void _onPlanDiscarded() {
    // Nothing to do — user can type a new message.
  }

  void _onPlanChangesProposed() {
    // Nothing to do — user can just type.
  }

  Future<void> _stopSession() async {
    if (!sync.isInitialized) return;
    try {
      await sync.sessionRPC(widget.sessionId, 'interrupt', {});
    } catch (e) {
      debugPrint('Stop session failed: $e');
    }
  }

  Machine? _getMachine() {
    final machineId = _session?.metadata?.machineId;
    if (machineId == null) return null;
    return sync.machines[machineId];
  }

  String _getSessionTitle() {
    final summary = _session?.metadata?.summary?.text;
    if (summary != null && summary.isNotEmpty) return summary;
    final path = _session?.metadata?.path;
    if (path != null && path.isNotEmpty) {
      return path.split('/').last;
    }
    return 'Chat';
  }

  String _formatRelativePath(String? path) {
    if (path == null || path.isEmpty) return '';
    final homeDir = _session?.metadata?.homeDir;
    if (homeDir != null && path.startsWith(homeDir)) {
      return '~${path.substring(homeDir.length)}';
    }
    return path;
  }

  static const _thinkingMessages = [
    'Vibing...',
    'Thinking deeply...',
    'Crafting a response...',
    'Working on it...',
    'In the zone...',
    'Pondering...',
  ];

  String _getStatusText() {
    final session = _session;
    if (session == null) return '';

    final hasRequests =
        session.agentState?.requests?.isNotEmpty ?? false;
    if (hasRequests) return 'Permission required';

    if (session.thinking) {
      final idx = Random(
        session.thinkingAt ?? DateTime.now().millisecondsSinceEpoch,
      ).nextInt(_thinkingMessages.length);
      return _thinkingMessages[idx];
    }

    if (session.presence == 'online') return 'Online';

    // Offline — show "Last seen" based on updatedAt
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(
      session.updatedAt,
    );
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return 'Last seen ${diff.inHours}h ago';
    }
    return 'Last seen ${diff.inDays}d ago';
  }

  Color _getStatusColor() {
    final session = _session;
    if (session == null) return Colors.grey;

    if (session.agentState?.requests?.isNotEmpty ?? false) {
      return Colors.orange;
    }
    if (session.thinking) return Colors.blue;
    if (session.presence == 'online') return Colors.green;
    return Colors.grey;
  }

  Widget _buildAppBarTitle(AppLocalizations l10n) {
    if (_session == null) {
      return Text(l10n.chatChat);
    }

    final machine = _getMachine();
    final machineName =
        machine?.metadata?.displayName ?? machine?.metadata?.host;
    final path = _formatRelativePath(_session?.metadata?.path);
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();
    final isThinking = _session?.thinking ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getSessionTitle(),
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        if (path.isNotEmpty)
          Text(
            path,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Row(
          children: [
            _StatusDot(
              color: statusColor,
              pulsing: isThinking,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                [
                  statusText,
                  if (machineName != null) machineName,
                ].join('  ·  '),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSessionMenu(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.chatSessionSettings),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l10n.chatDeleteSession),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    // Only render the last _visibleCount messages
    final totalCount = _messages.length;
    final startIndex =
        (totalCount - _visibleCount).clamp(0, totalCount);
    final visibleMessages = _messages.sublist(startIndex);
    final hasMore = startIndex > 0;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: visibleMessages.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Reversed: index 0 = last message (bottom)
        final reversedIndex = visibleMessages.length - 1 - index;

        // "Load more" at the top (last index in reversed list)
        if (hasMore && index == visibleMessages.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = visibleMessages[reversedIndex];
        final messageKey = message['id'] as String? ??
            message['toolUseId'] as String? ??
            'msg-$reversedIndex';
        return MessageWidget(
          key: ValueKey(messageKey),
          messageData: message,
          isFromCurrentUser: message['role'] == 'user',
          metadata: _session?.metadata?.toJson(),
          messages: _messages,
          sessionId: widget.sessionId,
          onOptionPress: _onOptionPress,
        );
      },
    );
  }

  Future<void> _onOptionPress(String option) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      if (!sync.isInitialized) {
        throw StateError('Sync is not initialized');
      }
      await sync.sendMessage(
        widget.sessionId,
        option,
        displayText: option,
        permissionMode: _permissionMode.toModeString(),
        modelMode: _modelMode.modeString,
      );
      _refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.chatFailedToSend}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _controller.clear();
    });

    try {
      // Clear draft after sending
      unawaited(DraftStorage().removeDraft(widget.sessionId));

      if (!sync.isInitialized) {
        throw StateError('Sync is not initialized');
      }
      await sync.sendMessage(
        widget.sessionId,
        text,
        displayText: text,
        permissionMode: _permissionMode.toModeString(),
        modelMode: _modelMode.modeString,
      );
      _refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(
            '${context.l10n.chatFailedToSend}: $e',
          ),
        ));
        _controller.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chatDeleteSession),
        content: Text(l10n.chatDeleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final deleted = await sync.deleteSession(widget.sessionId);
              if (!mounted) {
                return;
              }
              if (deleted) {
                Navigator.of(this.context).pop();
                return;
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Failed to delete session')),
              );
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

/// Animated typing indicator showing three bouncing dots in a speech bubble.
///
/// Each dot animates sequentially with a staggered delay, translating
/// upward by 4 logical pixels and back, creating a wave effect.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();
    // Total cycle: 900 ms — each dot occupies a 300 ms window,
    // staggered by 150 ms so they overlap slightly for a smooth wave.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    _dot1 = _buildDotAnimation(0.0, 0.33);
    _dot2 = _buildDotAnimation(0.22, 0.55);
    _dot3 = _buildDotAnimation(0.44, 0.77);
  }

  /// Builds a bounce animation for a single dot within [start]..[end]
  /// of the controller's 0..1 range. Outside that interval the dot
  /// sits at rest (offset 0).
  Animation<double> _buildDotAnimation(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -4, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.linear),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use the same surface-variant color as bot message bubbles.
    final bubbleColor = colorScheme.surfaceContainerHighest;
    final dotColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(offset: _dot1.value, color: dotColor),
              const SizedBox(width: 4),
              _Dot(offset: _dot2.value, color: dotColor),
              const SizedBox(width: 4),
              _Dot(offset: _dot3.value, color: dotColor),
            ],
          );
        },
      ),
    );
  }
}

/// A single dot used by [_TypingIndicator].
class _Dot extends StatelessWidget {

  const _Dot({required this.offset, required this.color});
  final double offset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Pulsing status dot indicator
class _StatusDot extends StatefulWidget {

  const _StatusDot({required this.color, this.pulsing = false});
  final Color color;
  final bool pulsing;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(
              alpha: widget.pulsing ? _animation.value : 1.0,
            ),
          ),
        );
      },
    );
  }
}

/// Empty chat view
class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.chatStartConversation,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatSendMessageToBegin,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
