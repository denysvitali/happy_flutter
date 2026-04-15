// NOTE: _chat_screen_builders.dart is a `part` file because Dart's
// library-private (`_`) visibility is required for _ChatScreenState's
// private member access. Converting to a regular import would require
// making those members public, which violates the project's preference
// for minimal public APIs. LSP tools may not resolve definitions across
// part boundaries.
part of 'chat_screen.dart';

extension _ChatScreenBuilders on _ChatScreenState {
  Widget _buildMessageList() {
    final stopwatch = Stopwatch()..start();
    final totalCount = _messages.length;
    final startIndex = (totalCount - _visibleCount).clamp(0, totalCount);

    if (!identical(_messages, _cachedVisibleSource) ||
        totalCount != _cachedMessagesLength ||
        _visibleCount != _cachedVisibleCount) {
      _cachedVisibleSource = _messages;
      _cachedMessagesLength = totalCount;
      _cachedVisibleCount = _visibleCount;
      _cachedVisibleMessages = _messages.sublist(startIndex);
    }
    final visibleMessages = _cachedVisibleMessages ?? const [];

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

    final metadataJson = _metadataJson;

    if (!identical(visibleMessages, _cachedListItemsSource) ||
        _visibleCount != _cachedListItemsVisibleCount ||
        _cachedListItems == null ||
        _cachedKeyToListIndex == null) {
      final items = <Map<String, dynamic>?>[];
      for (final msg in visibleMessages) {
        // Sidechain (agent) messages should only appear inside
        // the AgentConversationScreen, never in the main chat.
        if (msg['isSidechain'] == true) continue;
        items.add(msg);
        final role = msg['role'] as String?;
        final content = msg['content'] ?? msg['text'];
        final text = content is String ? content : content?.toString() ?? '';
        if (role == 'user' && text.trim() == '/clear') {
          items.add(null);
        }
      }

      final keyToListIndex = <String, int>{};
      for (var i = 0; i < items.length; i++) {
        final m = items[i];
        if (m == null) continue;
        final k = m['id'] as String? ?? m['toolUseId'] as String?;
        if (k != null) {
          keyToListIndex[k] = items.length - 1 - i;
        }
      }

      _cachedListItemsSource = visibleMessages;
      _cachedListItemsVisibleCount = _visibleCount;
      _cachedListItems = items;
      _cachedKeyToListIndex = keyToListIndex;
    }

    final items = _cachedListItems ?? const [];
    final keyToListIndex = _cachedKeyToListIndex ?? const {};

    // Only rebuild neighbor cache if the items list actually changed.
    // The _refreshFromSync method handles cache invalidation when messages
    // change.
    _rebuildNeighborCache(items);

    final listView = ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(
        top: AppSpacing.xsm,
        bottom: AppSpacing.xs,
      ),
      // Each message item is wrapped in RepaintBoundary already;
      // skip the default automatic wrappers to reduce widget depth.
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: items.length + (showHeader ? 1 : 0),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        return keyToListIndex[key.value];
      },
      itemBuilder: (context, index) {
        final adjusted = index;
        if (showHeader && adjusted == items.length) {
          if (hasLocalMore || isLoadingFromServer) {
            return Center(
              key: ValueKey(
                hasLocalMore
                    ? 'header-local-more'
                    : 'header-server-loading',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(
                      alpha: AppOpacity.medium,
                    ),
                  ),
                ),
              ),
            );
          }

          return const ConversationStartLabel();
        }

        final reversedIndex = items.length - 1 - adjusted;
        final item = items[reversedIndex];

        if (item == null) {
          return const ClearedDivider();
        }

        final message = item;
        final (prevMessage, nextMessage) =
            _neighborCache[reversedIndex] ?? (null, null);

        final currentRole = message['role'] as String?;
        final nextRole = nextMessage?['role'] as String?;
        final sameSender = nextRole == currentRole;
        final isToolCall = message['kind'] == 'tool-call';
        final nextIsToolCall = nextMessage?['kind'] == 'tool-call';
        final bottomPad = (isToolCall && nextIsToolCall)
            ? 0.0
            : sameSender
            ? AppSpacing.xs
            : AppSpacing.md;

        final prevRole = prevMessage?['role'] as String?;
        final isFirstInGroup = nextRole != currentRole;
        final isLastInGroup = prevRole != currentRole;

        final messageKey =
            message['id'] as String? ??
            message['toolUseId'] as String? ??
            'msg-$reversedIndex';
        // Only pass the full messages list to tool-call items that need it
        // (Task / Agent sub-conversation rendering). Regular text messages
        // don't use it and passing _messages to every item causes every
        // MessageWidget to see a changed prop on each new message arrival.
        final toolName = isToolCall ? message['name'] as String? : null;
        final needsMessages =
            isToolCall && (toolName == 'Task' || toolName == 'Agent');
        // Show streaming cursor on the last agent text message while thinking.
        final isNewest = reversedIndex == items.length - 1;
        final isStreaming =
            isNewest &&
            (_session?.thinking ?? false) &&
            message['role'] == 'agent' &&
            !isToolCall;
        return RepaintBoundary(
          key: ValueKey(messageKey),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: MessageWidget(
              messageData: message,
              isFromCurrentUser: message['role'] == 'user',
              metadata: metadataJson,
              messages: needsMessages ? _messages : null,
              sessionId: widget.sessionId,
              isSessionOnline:
                  (_session?.isOnline ?? false) ||
                  ((_session?.metadata?.machineId?.isNotEmpty ?? false) &&
                      (_session?.metadata?.path?.isNotEmpty ?? false)),
              onOptionPress: _onOptionPress,
              onRetry: message['role'] == 'user' &&
                      message['sendStatus'] == 'failed'
                  ? () => _retryMessage(message)
                  : null,
              animate: _initialLoadComplete &&
                  !_seenMessageIds.contains(messageKey),
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
              isStreaming: isStreaming,
            ),
          ),
        );
      },
    );
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds >= 8) {
      logger.debug(
        '[Perf] buildMessageList '
        'session=${widget.sessionId} '
        'visible=${items.length} '
        'total=$totalCount '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
    return listView;
  }
}
