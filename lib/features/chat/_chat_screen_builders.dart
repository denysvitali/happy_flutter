// NOTE: _chat_screen_builders.dart is a `part` file because Dart's
// library-private (`_`) visibility is required for _ChatScreenState's
// private member access. Converting to a regular import would require
// making those members public, which violates the project's preference
// for minimal public APIs. LSP tools may not resolve definitions across
// part boundaries.
part of 'chat_screen.dart';

extension _ChatScreenBuilders on _ChatScreenState {
  Widget _buildMessageList({required bool hideToolCalls}) {
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
    final entry = ref.watch(sessionUiEntryProvider(widget.sessionId));
    final isLoadingFromServer = allLocalVisible && entry.isLoadingOlderMessages;
    final hasServerMore = allLocalVisible && entry.hasOlderMessages;

    final showHeader =
        hasLocalMore ||
        isLoadingFromServer ||
        (!hasServerMore && allLocalVisible && totalCount > 0);

    final metadataJson = _metadataJson;

    if (!identical(visibleMessages, _cachedListItemsSource) ||
        _visibleCount != _cachedListItemsVisibleCount ||
        _cachedListItems == null ||
        _cachedKeyToListIndex == null ||
        _cachedListItemsHideToolCalls != hideToolCalls) {
      // Pure pipeline: hide-tools / orphan / agent-event / /clear dividers.
      // Sidechain orphans render inline (see _sync_messaging_merge notes).
      final items = buildChatListItems(
        visibleMessages: visibleMessages,
        hideToolCalls: hideToolCalls,
        shouldRenderAgentEvent: AgentEventWidget.shouldRenderInChat,
        shouldHideToolCall: _shouldHideToolCall,
        onMessageError: (msg, e, st) {
          // Never let a single malformed message abort the whole list —
          // otherwise rendering halts at the offending item and every
          // message after it disappears from the UI.
          logger.warning(
            '[chat] skipped malformed message id='
            '${msg['id']} seq=${msg['seq']}: $e',
            e,
            st,
          );
        },
      );

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
      _cachedListItemsHideToolCalls = hideToolCalls;
      _cachedListItems = items;
      _cachedKeyToListIndex = keyToListIndex;
    }

    final items = _cachedListItems ?? const [];
    final keyToListIndex = _cachedKeyToListIndex ?? const {};

    // Only rebuild neighbor cache if the items list actually changed.
    // The _refreshFromSync method handles cache invalidation when messages
    // change.
    _rebuildNeighborCache(items);

    // Show a typing indicator at the bottom of the chat when the agent
    // is actively working (thinking flag or recent stream activity) but
    // the newest visible item is not already a streaming text bubble.
    // This closes the "dead chat" gap between the user sending a message
    // and the first visible agent output arriving.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final recentlyReceiving =
        _lastMessageStreamActivityAt > 0 &&
        nowMs - _lastMessageStreamActivityAt < 10000;
    final agentWorking =
        (_session?.active ?? false) &&
        ((_session?.thinking ?? false) || recentlyReceiving);
    // Suppress the indicator when the newest visible item is already an
    // agent text bubble with a streaming cursor — two indicators would
    // be redundant.
    final lastItem = items.isNotEmpty ? items.last : null;
    final lastIsStreamingText =
        lastItem != null &&
        lastItem['role'] == 'agent' &&
        lastItem['kind'] != 'tool-call' &&
        lastItem['kind'] != 'hidden-tool-summary' &&
        lastItem['isThinking'] != true;
    final showTypingIndicator = agentWorking && !lastIsStreamingText;

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
      itemCount:
          items.length +
          (showHeader ? 1 : 0) +
          (showTypingIndicator ? 1 : 0),
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final idx = keyToListIndex[key.value];
        if (idx == null) return null;
        // Offset by the typing indicator slot at index 0.
        return showTypingIndicator ? idx + 1 : idx;
      },
      itemBuilder: (context, index) {
        // Index 0 in a reversed list is the bottom — the typing
        // indicator lives here so it appears below the newest message.
        if (showTypingIndicator && index == 0) {
          return const TypingIndicator(
            key: ValueKey('typing-indicator'),
          );
        }
        final adjustedIndex =
            showTypingIndicator ? index - 1 : index;
        try {
          return _buildMessageItem(
            context: context,
            index: adjustedIndex,
            items: items,
            showHeader: showHeader,
            hasLocalMore: hasLocalMore,
            isLoadingFromServer: isLoadingFromServer,
            metadataJson: metadataJson,
          );
        } catch (e, st) {
          // A single bad message must not blank the whole list. Return a
          // lightweight placeholder so the next item still renders.
          logger.error('[chat] itemBuilder threw for index=$index', e, st);
          return const SizedBox.shrink();
        }
      },
    );
    // Messages dissolve under the app bar instead of hard-clipping.
    final fadedList = ScrollEdgeFade(topExtent: 28, child: listView);
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds >= 8) {
      OpenTelemetryService().recordDuration(
        'app.chat.message_list_build',
        stopwatch.elapsed,
        attributes: {
          'visible_bucket': items.length < 25
              ? 'small'
              : items.length < 100
              ? 'medium'
              : 'large',
        },
        description: 'Slow chat message-list build duration',
      );
      if (logger.shouldLog(LogLevel.debug)) {
        logger.debug(
          '[Perf] buildMessageList '
          'session=${widget.sessionId} '
          'visible=${items.length} '
          'total=$totalCount '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
        );
      }
    }
    return fadedList;
  }

  Widget _buildMessageItem({
    required BuildContext context,
    required int index,
    required List<Map<String, dynamic>?> items,
    required bool showHeader,
    required bool hasLocalMore,
    required bool isLoadingFromServer,
    required Map<String, dynamic>? metadataJson,
  }) {
    final adjusted = index;
    if (showHeader && adjusted == items.length) {
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
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: AppOpacity.medium),
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

    if (message['kind'] == 'model-change') {
      final markerId =
          message['id'] as String? ?? 'model-change-$reversedIndex';
      return ModelChangeDivider(
        key: ValueKey(markerId),
        fromModel: message['fromModel'] as String? ?? '',
        toModel: message['toModel'] as String? ?? '',
      );
    }

    final (prevMessage, nextMessage) =
        _neighborCache[reversedIndex] ?? (null, null);

    final currentRole = message['role'] as String?;
    final nextRole = nextMessage?['role'] as String?;
    final sameSender = nextRole == currentRole;
    final isToolCall = message['kind'] == 'tool-call';
    final nextIsToolCall = nextMessage?['kind'] == 'tool-call';
    final isToolLike = isToolCall || message['kind'] == 'hidden-tool-summary';
    final nextIsToolLike =
        nextIsToolCall || nextMessage?['kind'] == 'hidden-tool-summary';
    final bottomPad = (isToolLike && nextIsToolLike)
        ? AppSpacing.xxs
        : sameSender
        ? AppSpacing.xs
        : AppSpacing.md;

    final prevRole = prevMessage?['role'] as String?;
    final prevIsToolLike =
        prevMessage?['kind'] == 'tool-call' ||
        prevMessage?['kind'] == 'hidden-tool-summary';
    final isFirstInGroup = nextRole != currentRole;
    final isLastInGroup = prevRole != currentRole;
    // A non-tool message wedged between two tool-like neighbors renders
    // with reduced vertical padding so the tool flow reads tightly. Short
    // agent acknowledgements between hidden-tool-summary groups would
    // otherwise feel "far apart" due to standard bubble padding.
    final isCompact = !isToolLike && prevIsToolLike && nextIsToolLike;

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
        isToolCall &&
        (toolName == 'Task' || toolName == 'Agent' || toolName == 'Workflow');
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
          onRetry:
              message['role'] == 'user' && message['sendStatus'] == 'failed'
              ? () => _retryMessage(message)
              : null,
          animate:
              _initialLoadComplete && !_seenMessageIds.contains(messageKey),
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          isStreaming: isStreaming,
          isCompact: isCompact,
        ),
      ),
    );
  }

  bool _shouldHideToolCall(
    Map<String, dynamic> message, {
    required bool hideToolCalls,
  }) {
    if (!hideToolCalls || message['kind'] != 'tool-call') return false;

    // Task/Agent tool calls always show — they represent
    // agent sub-conversations and must render as TaskView
    // with their inline children, never be collapsed into
    // the hidden-tool-summary.
    final toolName = message['name'] as String?;
    if (toolName == 'Task' || toolName == 'Agent' || toolName == 'Workflow') {
      return false;
    }

    final state = message['state'] as String?;
    if (state == 'pending' || state == 'running' || state == 'error') {
      return false;
    }

    final permission = WireParsers.asMap(message['permission']);
    if (permission == null) return true;

    final status = permission['status'];
    return status == 'approved' || status == 'denied' || status == 'canceled';
  }
}
