import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

/// Screen that shows a detailed view of a single message within a session.
///
/// Looks up the session from [sessionsNotifierProvider] and finds the message
/// by [messageId] within the session's message list.
class MessageDetailScreen extends ConsumerWidget {
  /// Creates a [MessageDetailScreen].
  const MessageDetailScreen({
    required this.sessionId,
    required this.messageId,
    super.key,
  });

  /// The ID of the session containing the message.
  final String sessionId;

  /// The ID of the message to display.
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final session = sessions[sessionId];

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Message')),
        body: const Center(child: Text('Session not found')),
      );
    }

    // Messages are not stored directly on Session model — they come
    // through the sync/websocket layer and are stored separately.
    // For now show a placeholder view indicating this.
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: _MessagePlaceholderView(messageId: messageId),
    );
  }
}

/// Placeholder view shown when message data is not yet accessible
/// via the sessions provider.
class _MessagePlaceholderView extends StatelessWidget {
  const _MessagePlaceholderView({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Message ID card
        Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Message ID',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  messageId,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info notice
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Content',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Full message content is available in the chat view. '
                        'Navigate back to the session to see the complete '
                        'message.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
