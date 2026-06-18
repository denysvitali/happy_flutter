import 'package:flutter/material.dart';

import 'chat_loading_shimmer.dart';
import 'empty_chat_view.dart';
import 'retry_error_view.dart';

/// Decides which child to render inside the chat pane's
/// [AnimatedSwitcher] based on the chat screen's reactive state.
///
/// Branches (in priority order):
/// 1. [isLoading] → [ChatLoadingShimmer]
/// 2. [loadFailed] → [RetryErrorView] (which is itself a button that
///    calls [onRetry])
/// 3. [messages] is empty → [EmptyChatView]
/// 4. Otherwise → the caller-provided [messageList] widget
///
/// Extracted from chat_screen.dart in batch 18. The widget is
/// pure: it takes its state as parameters and has no `ref.watch` of
/// its own. The chat screen's master_pane supplies the
/// already-watched [messageList] widget.
class ChatMessagesBody extends StatelessWidget {
  const ChatMessagesBody({
    required this.isLoading,
    required this.messages,
    required this.loadFailed,
    required this.onRetry,
    required this.onSuggestionTap,
    required this.messageList,
    super.key,
  });

  /// Whether the chat screen is in its initial load state. When
  /// true, the loading shimmer is shown regardless of other
  /// state.
  final bool isLoading;

  /// The current message list. Empty = show the empty-state view.
  final List<dynamic> messages;

  /// Whether the most recent load attempt failed. When true and
  /// [messages] is empty, the retry error view is shown.
  final bool loadFailed;

  /// Called when the user taps the retry button on the error view.
  final VoidCallback onRetry;

  /// Called when the user taps a suggestion chip in the empty view.
  final ValueChanged<String> onSuggestionTap;

  /// The message-list widget to render when not loading, not
  /// failed, and [messages] is non-empty. Typically produced by
  /// the chat screen's `_buildMessageList` helper.
  final Widget messageList;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const ChatLoadingShimmer(key: ValueKey('loading'))
        : messages.isEmpty
            ? (loadFailed
                ? RetryErrorView(key: const ValueKey('error'), onRetry: onRetry)
                : EmptyChatView(
                    key: const ValueKey('empty'),
                    onSuggestionTap: onSuggestionTap,
                  ))
            : messageList;
  }
}
