import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool _didStartInitialLoad = false;
  int _prevMessagesLength = 0;
  bool _autoScroll = true;
  static const double _autoScrollThreshold = 100;

  PermissionMode _permissionMode = PermissionMode.defaultMode;
  ClaudeModel _modelMode = ClaudeModel.defaultModel;
  Session? _session;
  List<Map<String, dynamic>> _messages = const [];
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
        _permissionMode = parsedMode ?? PermissionMode.defaultMode;
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
    _messageSyncSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) {
          if (mounted) _refreshFromSync();
        });
    _dataSyncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      if (!_didStartInitialLoad && sync.isInitialized) {
        _doInitialLoad();
      } else {
        _refreshFromSync();
      }
    });

    if (!sync.isInitialized) {
      return;
    }

    await _doInitialLoad();
  }

  Future<void> _doInitialLoad() async {
    if (_didStartInitialLoad) return;
    _didStartInitialLoad = true;

    sync.onSessionVisible(widget.sessionId);
    try {
      await sync.messagesSync[widget.sessionId]?.awaitQueue();
    } catch (_) {
      // Fall through so we still clear the spinner.
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

    final hadRequests = _session?.agentState?.requests?.isNotEmpty ?? false;
    final hasRequests =
        latestSession?.agentState?.requests?.isNotEmpty ?? false;
    final newPermission = !hadRequests && hasRequests;

    setState(() {
      _session = latestSession;

      if (messagesChanged && latestMessages.length > _prevMessagesLength) {
        final prepended = latestMessages.length - _prevMessagesLength;
        if (_visibleCount >= _prevMessagesLength && _prevMessagesLength > 0) {
          _visibleCount = (_visibleCount + prepended).clamp(
            0,
            latestMessages.length,
          );
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

    final nearBottom = pos.pixels <= _autoScrollThreshold;
    if (nearBottom != _autoScroll) {
      setState(() {
        _autoScroll = nearBottom;
      });
    }

    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;

    if (_visibleCount < _messages.length) {
      _isLoadingMore = true;
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, _messages.length);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isLoadingMore = false;
      });
      return;
    }

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

    final hasRequests = session.agentState?.requests?.isNotEmpty ?? false;
    if (hasRequests) return 'Permission required';

    if (session.thinking) {
      final idx = Random(
        session.thinkingAt ?? DateTime.now().millisecondsSinceEpoch,
      ).nextInt(_thinkingMessages.length);
      return _thinkingMessages[idx];
    }

    if (session.presence == 'online') return 'Online';

    final lastSeen = DateTime.fromMillisecondsSinceEpoch(session.updatedAt);
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
      return const Color(0xFFF59E0B);
    }
    if (session.thinking) return colorScheme.primary;
    if (session.presence == 'online') return const Color(0xFF34C759);
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
        onMenuTap: () => _showSessionMenu(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingMessages
                      ? Center(
                          key: const ValueKey('loading'),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : _messages.isEmpty
                      ? const _EmptyChatView(key: ValueKey('empty'))
                      : _buildMessageList(),
                ),
                // Scroll-to-bottom pill
                IgnorePointer(
                  ignoring:
                      _autoScroll || _isLoadingMessages,
                  child: AnimatedOpacity(
                    opacity:
                        (!_autoScroll &&
                                !_isLoadingMessages)
                            ? 1.0
                            : 0.0,
                    duration:
                        const Duration(
                          milliseconds: 200,
                        ),
                    curve: Curves.easeInOut,
                    child: AnimatedScale(
                      scale:
                          (!_autoScroll &&
                                  !_isLoadingMessages)
                              ? 1.0
                              : 0.8,
                      duration:
                          const Duration(
                            milliseconds: 200,
                          ),
                      curve: Curves.easeInOut,
                      child: Align(
                        alignment:
                            Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                          ),
                          child:
                              _ScrollToBottomPill(
                            onTap: () {
                              HapticFeedback
                                  .lightImpact();
                              setState(
                                () =>
                                    _autoScroll =
                                        true,
                              );
                              _scrollToBottom();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Typing indicator
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
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
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                bottom: 8,
                              ),
                              child: _TypingIndicator(),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-typing')),
                  ),
                ),
              ],
            ),
          ),
          if (_session?.agentState?.requests?.isNotEmpty ?? false)
            _PermissionRequiredBanner(onTap: () => _scrollToBottom()),
          ChatInput(
            sessionId: widget.sessionId,
            controller: _controller,
            onSend: _sendMessage,
            isSending: _isSending,
            permissionMode: _permissionMode,
            onPermissionModeChanged: _onPermissionModeChanged,
            modelMode: _modelMode,
            onModelModeChanged: _onModelModeChanged,
            contextSize:
                sync.sessionUsage[widget.sessionId]?['contextSize'] as int?,
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

  Future<void> _abortSession() async {
    if (!sync.isInitialized) return;
    await sync.sessionRPC(widget.sessionId, 'abort', {'reason': _abortReason});
  }

  void _showSessionMenu(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      backgroundColor: cs.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: cs.onSurfaceVariant,
              ),
              title: Text(l10n.chatSessionSettings),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: cs.error),
              title: Text(
                l10n.chatDeleteSession,
                style: TextStyle(color: cs.error),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
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
    final totalCount = _messages.length;
    final startIndex = (totalCount - _visibleCount).clamp(0, totalCount);
    final visibleMessages = _messages.sublist(startIndex);

    final hasLocalMore = startIndex > 0;

    final allLocalVisible = _visibleCount >= totalCount;
    final isLoadingFromServer =
        allLocalVisible && sync.isLoadingOlderMessages(widget.sessionId);
    final hasServerMore =
        allLocalVisible && sync.hasOlderMessages(widget.sessionId);

    final showHeader =
        hasLocalMore ||
        isLoadingFromServer ||
        (!hasServerMore && allLocalVisible && totalCount > 0);

    final keyToListIndex = <String, int>{};
    for (var i = 0; i < visibleMessages.length; i++) {
      final m = visibleMessages[i];
      final k = m['id'] as String? ?? m['toolUseId'] as String?;
      if (k != null) {
        keyToListIndex[k] = visibleMessages.length - 1 - i;
      }
    }

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
        if (showHeader && index == visibleMessages.length) {
          if (hasLocalMore || isLoadingFromServer) {
            return Center(
              key: ValueKey(
                hasLocalMore ? 'header-local-more' : 'header-server-loading',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            );
          }

          return _buildConversationStartLabel(context);
        }

        final reversedIndex = visibleMessages.length - 1 - index;

        final message = visibleMessages[reversedIndex];
        final nextMessage = reversedIndex + 1 < visibleMessages.length
            ? visibleMessages[reversedIndex + 1]
            : null;

        final currentRole = message['role'] as String?;
        final nextRole = nextMessage?['role'] as String?;
        final sameSender = nextRole == currentRole;
        final bottomPad = sameSender ? AppSpacing.xs : AppSpacing.md;

        final messageKey =
            message['id'] as String? ??
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('header-beginning'),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Center(
        child: Text(
          'Beginning of conversation',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
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
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to clear: $e')));
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
          SnackBar(content: Text('${context.l10n.chatFailedToSend}: $e')),
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
    final cs = Theme.of(context).colorScheme;
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
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
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

// ─── _ChatAppBar ──────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.relativePath,
    required this.machine,
    required this.statusText,
    required this.statusColor,
    required this.isThinking,
    required this.onMenuTap,
  });

  final Session? session;
  final String sessionTitle;
  final String relativePath;
  final Machine? machine;
  final String statusText;
  final Color statusColor;
  final bool isThinking;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(context),
      scrolledUnderElevation: 0.5,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          iconSize: 22,
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
        Text(
          sessionTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (relativePath.isNotEmpty) ...[
              _PathChip(path: relativePath),
              const SizedBox(width: 6),
            ],
            _SessionHeaderChip(
              text: statusText,
              leading: AppStatusDot(
                color: statusColor,
                pulse: isThinking,
                size: 6,
              ),
            ),
            if (machineName != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: _SessionHeaderChip(
                  text: machineName,
                  leading: Icon(
                    Icons.computer_outlined,
                    size: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── _PathChip ────────────────────────────────────────────────────────────

class _PathChip extends StatelessWidget {
  const _PathChip({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
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

class _ScrollToBottomPill extends StatelessWidget {
  const _ScrollToBottomPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _PermissionRequiredBanner ────────────────────────────────────────────

class _PermissionRequiredBanner extends StatelessWidget {
  const _PermissionRequiredBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Permission required',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _EmptyChatView ───────────────────────────────────────────────────────

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              l10n.chatStartConversation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chatSendMessageToBegin,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _TypingIndicator ─────────────────────────────────────────────────────

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

  static const double _cycleMs = 900;
  static const double _stagger1 = 0 / _cycleMs;
  static const double _stagger2 = 150 / _cycleMs;
  static const double _stagger3 = 300 / _cycleMs;
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

  Animation<double> _buildDotAnimation(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: -4,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -4,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOut)),
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
    final cs = Theme.of(context).colorScheme;
    final dotColor = cs.onSurfaceVariant.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(offset: _dot1.value, color: dotColor),
              SizedBox(width: AppSpacing.xs),
              _Dot(offset: _dot2.value, color: dotColor),
              SizedBox(width: AppSpacing.xs),
              _Dot(offset: _dot3.value, color: dotColor),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.offset, required this.color});
  final double offset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─── _SessionHeaderChip ───────────────────────────────────────────────────

class _SessionHeaderChip extends StatelessWidget {
  const _SessionHeaderChip({required this.text, this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
