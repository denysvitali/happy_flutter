import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/utils.dart';
import 'chat_input.dart';
import 'message_widget.dart';
import 'widgets/permission_mode_selector.dart';

/// Chat screen for a session
class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatScreen({super.key, required this.sessionId});

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
  PermissionMode _permissionMode = PermissionMode.readOnly;
  Session? _session;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

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

    if (messagesChanged) {
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

    for (int i = 0; i < a.length; i++) {
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
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      // Load more messages
      // _loadMoreMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chatChat),
            if (_session != null)
              Text(
                _session?.metadata?.path ?? 'Unknown',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
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
                // Messages list
                if (_isLoadingMessages)
                  Center(child: Text(l10n.chatChatLoading))
                else if (_messages.isEmpty)
                  const _EmptyChatView()
                else
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageWidget(
                        messageData: message,
                        isFromCurrentUser: message['role'] == 'user',
                        metadata: _session?.metadata?.toJson(),
                        messages: _messages,
                        sessionId: widget.sessionId,
                      );
                    },
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
            showSettingsButton: true,
            // machineName: session?.metadata?.name,
            // currentPath: session?.metadata?.path,
            onSettingsPressed: _showPermissionModeSettings,
          ),
        ],
      ),
    );
  }

  void _onPermissionModeChanged(PermissionMode mode) {
    setState(() => _permissionMode = mode);
    DraftStorage().savePermissionMode(widget.sessionId, mode.toModeString());
  }

  void _showPermissionModeSettings() {
    // The settings overlay is built into ChatInput
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _controller.clear();
    });

    // Clear draft after sending
    await DraftStorage().removeDraft(widget.sessionId);

    try {
      if (!sync.isInitialized) {
        throw StateError('Sync is not initialized');
      }
      await sync.sendMessage(
        widget.sessionId,
        text,
        displayText: text,
        permissionMode: _permissionMode.toModeString(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.l10n.chatFailedToSend}: ${e.toString()}')));
        _controller.text = text;
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
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

/// Empty chat view
class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

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
