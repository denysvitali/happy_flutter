import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/message.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
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
  bool _isSending = false;
  PermissionMode _permissionMode = PermissionMode.readOnly;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedPermissionMode();
  }

  Future<void> _loadSavedPermissionMode() async {
    final savedMode = await DraftStorage().getPermissionMode(widget.sessionId);
    if (savedMode != null) {
      setState(() {
        _permissionMode = PermissionMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => PermissionMode.readOnly,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    // final session = ref.watch(currentSessionNotifierProvider);
    // final messages = ref.watch(messagesProvider(widget.sessionId));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chatChat),
            // if (session != null)
            //   Text(
            //     session.metadata?.path ?? 'Unknown',
            //     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            //   ),
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
                // if (messages.isEmpty)
                //   const _EmptyChatView()
                // else
                //   _MessagesList(
                //     messages: messages,
                //     scrollController: _scrollController,
                //   ),
                Center(child: Text(l10n.chatChatLoading)),
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
    DraftStorage().savePermissionMode(widget.sessionId, mode.name);
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
      // Send message through WebSocket/RPC
      // await ref.read(messagesProvider(widget.sessionId).notifier).sendMessage(text);
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
            onPressed: () {
              Navigator.pop(context);
              // Delete session
              // Navigator.pop(context);
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
