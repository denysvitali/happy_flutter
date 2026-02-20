import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
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
  StreamSubscription<void>? _dataSyncSubscription;
  StreamSubscription<String>? _messageSyncSubscription;
  bool _isSending = false;
  bool _isLoadingMessages = true;

  /// Whether [_doInitialLoad] has already been called (or is in progress).
  /// Guards against double-invocation when the data-change listener fires
  /// before [_initializeSyncBackedChat] had a chance to call it directly.
  bool _didStartInitialLoad = false;

  /// Number of messages in `_messages` the last time `_refreshFromSync` was
  /// called.  Used to detect how many older messages were prepended by a
  /// server fetch so that `_visibleCount` can be bumped by the same amount,
  /// keeping the viewport stable.
  int _prevMessagesLength = 0;

  /// Whether autoscroll to the bottom is active.
  ///
  /// Autoscroll is enabled when the user is within [_autoScrollThreshold]
  /// pixels of the bottom of the list. When the user scrolls up past that
  /// threshold, autoscroll is disabled so they can read history without
  /// being interrupted by new messages. A pill button is shown to
  /// re-enable autoscroll.
  bool _autoScroll = true;

  /// Distance (in pixels) from the bottom of the list within which
  /// autoscroll is considered active.
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.readOnly;
  ClaudeModel _modelMode = ClaudeModel.defaultModel;
  Session? _session;
  List<Map<String, dynamic>> _messages = const [];
  /// Cached result of `_session?.metadata?.toJson()`.
  ///
  /// Recomputed only when [_session] changes so that [_buildMessageList]
  /// does not allocate a new [Map] for every message item on every rebuild.
  Map<String, dynamic>? _metadataJson;
  static const int _pageSize = 50;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedPermissionMode();
    _initializeSyncBackedChat();
  }

  Future<void> _loadSavedPermissionMode() async {
    final savedMode = await DraftStorage().getPermissionMode(widget.sessionId);
    if (!mounted) return;
    if (savedMode != null) {
      final parsedMode = PermissionModeExtension.fromString(savedMode);
      setState(() {
        _permissionMode = parsedMode ?? PermissionMode.readOnly;
      });
    }
  }

  @override
  void dispose() {
    _dataSyncSubscription?.cancel();
    _messageSyncSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSyncBackedChat() async {
    // Subscribe to changes before initial load to avoid race conditions.
    _messageSyncSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (mounted) _refreshFromSync();
        });
    _dataSyncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      // If sync wasn't ready when the screen opened, seize the first data
      // change as the signal that it is now initialized and trigger the
      // initial load then instead.
      if (!_didStartInitialLoad && sync.isInitialized) {
        _doInitialLoad();
      } else {
        _refreshFromSync();
      }
    });

    if (!sync.isInitialized) {
      // Sync not ready yet (e.g. deep-link opened the chat before auth
      // finished). _dataSyncSubscription will call _doInitialLoad() on the
      // first data-change event once sync is up.
      return;
    }

    await _doInitialLoad();
  }

  /// Triggers the one-time initial fetch for this session and clears the
  /// loading spinner once it completes (successfully or not).
  Future<void> _doInitialLoad() async {
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;

    sync.onSessionVisible(widget.sessionId);
    try {
      await sync.messagesSync[widget.sessionId]?.awaitQueue();
    } catch (_) {
      // Fetch failed (e.g. encryption not yet set up, network error).
      // Fall through so we still clear the spinner and show whatever
      // messages are available locally.
    }
    if (mounted) {
      _refreshFromSync(markLoaded: true);
    }
  }

  void _refreshFromSync({bool markLoaded = false}) {
    final latestSession = sync.sessions[widget.sessionId];
    final latestMessages = sync.messagesForSession(widget.sessionId);

    final sessionChanged = latestSession != _session;
    final messagesChanged = !_sameMessages(latestMessages, _messages);
    if (!sessionChanged && !messagesChanged && !markLoaded) {
      return;
    }

    if (!mounted) {
      return;
    }

    final hadRequests =
        _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    setState(() {
      _session = latestSession;

      // If older messages were prepended (length grew from the front),
      // bump _visibleCount by the same delta to keep the viewport stable.
      if (messagesChanged && latestMessages.length > _prevMessagesLength) {
        final prepended = latestMessages.length - _prevMessagesLength;
        // Only adjust when we were already showing all locally-loaded
        // messages (i.e., we triggered a server fetch from the top).
        if (_visibleCount >= _prevMessagesLength && _prevMessagesLength > 0) {
          _visibleCount = (_visibleCount + prepended)
              .clamp(0, latestMessages.length);
        }
      }

      _messages = latestMessages;
      _prevMessagesLength = latestMessages.length;

      if (sessionChanged) {
        _metadataJson = latestSession?.metadata?.toJson();
      }
      if (markLoaded) {
        _isLoadingMessages = false;
      }
    });

    if (messagesChanged && _autoScroll) {
      _scrollToBottom();
    }

    if (newPermission) {
      _scrollToBottom();
    }
  }

  bool _sameMessages(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    // Check first and last message identity as a fast heuristic.
    // Messages are append-only and ordered, so this catches new arrivals
    // and seq updates (streaming content changes).
    final lastA = a[a.length - 1];
    final lastB = b[b.length - 1];
    if (lastA['id'] != lastB['id']) return false;
    if (lastA['seq'] != lastB['seq']) return false;
    final firstA = a[0];
    final firstB = b[0];
    if (firstA['id'] != firstB['id']) return false;
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
    // messages). Autoscroll is active when within [_autoScrollThreshold]
    // of 0.
    final nearBottom = pos.pixels <= _autoScrollThreshold;
    if (nearBottom != _autoScroll) {
      setState(() {
        _autoScroll = nearBottom;
      });
    }

    // Load older messages when the user scrolls toward the top of the
    // reversed list (pixels approaching maxScrollExtent).
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;

    if (_visibleCount < _messages.length) {
      // Client-side windowing: more locally-loaded messages to reveal.
      _isLoadingMore = true;
      setState(() {
        _visibleCount =
            (_visibleCount + _pageSize).clamp(0, _messages.length);
      });
      // Reset the guard after the frame so rapid scroll events don't
      // queue multiple consecutive setState calls.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isLoadingMore = false;
      });
      return;
    }

    // All locally-loaded messages are visible — check whether the server
    // has older messages that haven't been fetched yet.
    if (sync.hasOlderMessages(widget.sessionId) &&
        !sync.isLoadingOlderMessages(widget.sessionId)) {
      sync.fetchOlderMessages(widget.sessionId);
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

  Color _getStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = _session;
    if (session == null) return colorScheme.outline;

    if (session.agentState?.requests?.isNotEmpty ?? false) {
      // amber / warning — use tertiary or a semantic amber
      return const Color(0xFFF59E0B);
    }
    if (session.thinking) return colorScheme.primary;
    if (session.presence == 'online') return const Color(0xFF22C55E);
    return colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final isThinking = _session?.thinking ?? false;

    return Scaffold(
      appBar: _ChatAppBar(
        session: _session,
        sessionTitle: _getSessionTitle(),
        relativePath: _formatRelativePath(_session?.metadata?.path),
        machine: _getMachine(),
        statusText: _getStatusText(),
        statusColor: _getStatusColor(context),
        isThinking: isThinking,
        onStop: _stopSession,
        onMenuTap: () => _showSessionMenu(context),
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
                          ? const _EmptyChatView(
                              key: ValueKey('empty'),
                            )
                          : _buildMessageList(),
                ),
                // Scroll-to-bottom pill — shown when autoscroll is disabled
                // (the user has scrolled up to read history).
                AnimatedOpacity(
                  opacity:
                      (!_autoScroll && !_isLoadingMessages) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale:
                        (!_autoScroll && !_isLoadingMessages) ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 56),
                        child: _ScrollToBottomPill(
                          onTap: () {
                            setState(() => _autoScroll = true);
                            _scrollToBottom();
                          },
                        ),
                      ),
                    ),
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
          if (_session?.agentState?.requests?.isNotEmpty ?? false)
            _PermissionRequiredBanner(
              onTap: () => _scrollToBottom(),
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
            isPermissionPending:
                _session?.agentState?.requests?.isNotEmpty ?? false,
            isSessionOnline: _session?.isPresenceOnline ?? false,
            onAbort: _abortSession,
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

  static const _abortReason =
      "The user doesn't want to proceed with this tool use. "
      'The tool use was rejected (eg. if it was a file edit, the '
      'new_string was NOT written to the file). STOP what you are '
      'doing and wait for the user to tell you how to proceed.';

  Future<void> _stopSession() async {
    if (!sync.isInitialized) return;
    try {
      await sync.sessionRPC(
        widget.sessionId,
        'abort',
        {'reason': _abortReason},
      );
    } catch (e) {
      debugPrint('Stop session failed: $e');
    }
  }

  Future<void> _abortSession() async {
    if (!sync.isInitialized) return;
    await sync.sessionRPC(
      widget.sessionId,
      'abort',
      {'reason': _abortReason},
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

    // True when there are more locally-loaded messages above the window.
    final hasLocalMore = startIndex > 0;

    // True when all locally-loaded messages are visible but the server
    // may have older messages not yet fetched.
    final allLocalVisible = _visibleCount >= totalCount;
    final isLoadingFromServer =
        allLocalVisible && sync.isLoadingOlderMessages(widget.sessionId);
    final hasServerMore =
        allLocalVisible && sync.hasOlderMessages(widget.sessionId);

    // Show a header widget above the topmost message.
    // Priority: client-side spinner > server spinner > "beginning" label.
    final showHeader = hasLocalMore || isLoadingFromServer ||
        (!hasServerMore && allLocalVisible && totalCount > 0);

    // Build a key→listIndex lookup once (O(n)) so that
    // findChildIndexCallback is O(1) instead of O(n) per item.
    final keyToListIndex = <String, int>{};
    for (var i = 0; i < visibleMessages.length; i++) {
      final m = visibleMessages[i];
      final k =
          m['id'] as String? ?? m['toolUseId'] as String?;
      if (k != null) {
        // The list is reversed: logical index i maps to item
        // index (visibleMessages.length - 1 - i).
        keyToListIndex[k] = visibleMessages.length - 1 - i;
      }
    }

    // Use the cached metadata so itemBuilder does not allocate a
    // new Map on every message item during each rebuild.
    final metadataJson = _metadataJson;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 6, bottom: 80),
      itemCount: visibleMessages.length + (showHeader ? 1 : 0),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        return keyToListIndex[key.value];
      },
      itemBuilder: (context, index) {
        // Reversed: index 0 = last message (bottom).
        // The header (if any) sits at the very top — the last item index
        // in the reversed list.
        if (showHeader && index == visibleMessages.length) {
          if (hasLocalMore) {
            // Client-side windowing: more already-loaded messages above.
            return const Center(
              key: ValueKey('header-local-more'),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (isLoadingFromServer) {
            // Server fetch in progress.
            return const Center(
              key: ValueKey('header-server-loading'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          // No more messages anywhere — beginning of conversation.
          return _buildConversationStartLabel(context);
        }

        final reversedIndex = visibleMessages.length - 1 - index;

        final message = visibleMessages[reversedIndex];
        final nextMessage = reversedIndex + 1 < visibleMessages.length
            ? visibleMessages[reversedIndex + 1]
            : null;

        // Consistent spacing: 8px between same-sender, 16px between
        // different senders.
        final currentRole = message['role'] as String?;
        final nextRole = nextMessage?['role'] as String?;
        final sameSender = nextRole == currentRole;
        final bottomPad = sameSender ? 8.0 : 16.0;

        final messageKey = message['id'] as String? ??
            message['toolUseId'] as String? ??
            'msg-$reversedIndex';
        return Padding(
          key: ValueKey(messageKey),
          padding: EdgeInsets.only(bottom: bottomPad),
          child: MessageWidget(
            messageData: message,
            isFromCurrentUser: message['role'] == 'user',
            metadata: metadataJson,
            messages: _messages,
            sessionId: widget.sessionId,
            onOptionPress: _onOptionPress,
          ),
        );
      },
    );
  }

  Widget _buildConversationStartLabel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('header-beginning'),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Beginning of conversation',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: colorScheme.outlineVariant),
          ),
        ],
      ),
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

    // /clear resets the conversation context on the server and collapses
    // the local message window so the UI feels instantly cleared.
    if (text == '/clear') {
      _controller.clear();
      unawaited(DraftStorage().removeDraft(widget.sessionId));
      setState(() {
        _isSending = true;
        _visibleCount = _pageSize;
        _autoScroll = true;
      });
      try {
        if (!sync.isInitialized) {
          throw StateError('Sync is not initialized');
        }
        await sync.sendMessage(
          widget.sessionId,
          text,
          permissionMode: _permissionMode.toModeString(),
          modelMode: _modelMode.modeString,
        );
        _refreshFromSync();
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.chatFailedToSend}: $e',
            ),
          ),
        );
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final deleted =
                  await sync.deleteSession(widget.sessionId);
              if (!mounted) {
                return;
              }
              if (deleted) {
                Navigator.of(this.context).pop();
                return;
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to delete session'),
                ),
              );
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

// ─── _ChatAppBar ──────────────────────────────────────────────────────────

/// Custom [PreferredSizeWidget] app bar for the chat screen.
///
/// Shows the session title (bolder weight), a pill-shaped path chip
/// in monospace, and a status row with a [AppStatusDot] and status text.
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.relativePath,
    required this.machine,
    required this.statusText,
    required this.statusColor,
    required this.isThinking,
    required this.onStop,
    required this.onMenuTap,
  });

  final Session? session;
  final String sessionTitle;
  final String relativePath;
  final Machine? machine;
  final String statusText;
  final Color statusColor;
  final bool isThinking;
  final VoidCallback onStop;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(context),
      // Show a subtle shadow when content scrolls beneath the app bar.
      scrolledUnderElevation: AppElevation.low,
      actions: [
        if (isThinking)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            iconSize: 24,
            tooltip: 'Stop',
            onPressed: onStop,
          ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          iconSize: 24,
          tooltip: 'More options',
          onPressed: onMenuTap,
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (session == null) {
      return Text(context.l10n.chatChat);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final machineName =
        machine?.metadata?.displayName ?? machine?.metadata?.host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Session name — w600 for visual hierarchy, ellipsis for long titles.
        Text(
          sessionTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Path pill chip + status badge in one row.
        Row(
          children: [
            if (relativePath.isNotEmpty) ...[
              _PathChip(path: relativePath),
              const SizedBox(width: AppSpacing.xs),
              // Subtle vertical separator between path and status.
              Container(
                width: 1,
                height: 10,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            AppStatusDot(color: statusColor, pulse: isThinking),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                [
                  statusText,
                  if (machineName != null) machineName,
                ].join('  ·  '),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
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
}

// ─── _PathChip ────────────────────────────────────────────────────────────

/// Pill-shaped chip that shows a filesystem path in monospace.
class _PathChip extends StatelessWidget {
  const _PathChip({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        path,
        style: GoogleFonts.sourceCodePro(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: -0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── _ScrollToBottomPill ──────────────────────────────────────────────────

/// A small pill-shaped button with a downward chevron that scrolls
/// the message list back to the latest message.
///
/// Rendered inside [AnimatedOpacity] + [AnimatedScale] by the parent
/// for a smooth fade+scale entrance/exit.
class _ScrollToBottomPill extends StatelessWidget {
  const _ScrollToBottomPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(100),
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                'Latest',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _PermissionRequiredBanner ────────────────────────────────────────────

/// A slim amber banner shown above the chat input when a session has
/// pending permission requests. Tapping it scrolls to the bottom of the
/// message list where the permission tool card is rendered.
class _PermissionRequiredBanner extends StatelessWidget {
  const _PermissionRequiredBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF3CD),
          border: Border(
            top: BorderSide(color: Color(0xFFFFC107), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(
              Icons.security_rounded,
              size: 16,
              color: Color(0xFFE65100),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Permission required',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A4100),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFE65100),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _EmptyChatView ───────────────────────────────────────────────────────

/// Centered empty-state view shown when a session has no messages yet.
///
/// Displays a large icon on a soft circular background, a title, and
/// a subtitle prompt — all using theme colors.
class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon on a soft circular background
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.chatStartConversation,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatSendMessageToBegin,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _TypingIndicator ─────────────────────────────────────────────────────

/// Animated typing indicator showing three bouncing dots in a speech bubble.
///
/// Each dot animates with a staggered delay (0 ms, 150 ms, 300 ms) using a
/// spring-like bounce curve for a smooth, natural wave effect.
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

  // Stagger offsets: 0 ms, 150 ms, 300 ms across a 900 ms cycle.
  static const double _cycleMs = 900;
  static const double _stagger1 = 0 / _cycleMs;
  static const double _stagger2 = 150 / _cycleMs;
  static const double _stagger3 = 300 / _cycleMs;
  // Each dot occupies ~37 % of the cycle (≈330 ms window).
  static const double _dotSpan = 330 / _cycleMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    _dot1 = _buildDotAnimation(_stagger1, _stagger1 + _dotSpan);
    _dot2 = _buildDotAnimation(_stagger2, _stagger2 + _dotSpan);
    _dot3 = _buildDotAnimation(_stagger3, _stagger3 + _dotSpan);
  }

  /// Builds a spring-like bounce animation for a single dot within
  /// [start]..[end] of the controller's 0..1 range.
  Animation<double> _buildDotAnimation(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -5)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -5, end: 1)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start.clamp(0.0, 1.0),
          end.clamp(0.0, 1.0),
          curve: Curves.linear,
        ),
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
    final bubbleColor = colorScheme.surfaceContainerHighest;
    final dotColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
