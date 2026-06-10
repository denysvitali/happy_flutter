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
        _cachedKeyToListIndex == null ||
        _cachedListItemsHideToolCalls != hideToolCalls) {
      final items = <Map<String, dynamic>?>[];
      var hiddenToolCalls = <Map<String, dynamic>>[];

      void flushHiddenToolCalls() {
        if (hiddenToolCalls.isEmpty) return;
        final first =
            hiddenToolCalls.first['id'] as String? ??
            hiddenToolCalls.first['toolUseId'] as String? ??
            'hidden-tool-${items.length}';
        items.add({
          'kind': 'hidden-tool-summary',
          'id': 'hidden-tool-summary-$first',
          'role': 'agent',
          'tools': hiddenToolCalls,
        });
        hiddenToolCalls = <Map<String, dynamic>>[];
      }

      for (final msg in visibleMessages) {
        try {
          // Sidechain (subagent) messages whose parent Task is in the
          // loaded window are attached to that Task's `children` array
          // by the grouper and are NOT in the top-level list here, so
          // they only appear inside the AgentConversationScreen for
          // their parent.
          //
          // Sidechain messages that landed in the top-level list are
          // orphans — their parent Task is not in the loaded window
          // (or never arrived).  We render them inline in the main
          // chat rather than absorbing them into a synthetic
          // "Subagent output (recovered)" tile, so the user can see
          // the actual content (text, tool-calls) and never loses
          // subagent output.  See _absorbOrphansIntoSyntheticTasks
          // removal in _sync_messaging_merge.
          //
          // Defense-in-depth: if a legacy cache still has a synthetic
          // `_orphanRecovery: true` placeholder, drop it — the chat
          // already has the real children rendered inline now, and
          // the synthetic would render as an empty duplicate.
          if (msg['_orphanRecovery'] == true) continue;
          // Agent events with no renderable label (telemetry-only types
          // like usage_report still present in older message caches, or
          // unknown future event types) render as zero-size widgets but
          // would still occupy a padded list row each — visible as the
          // chat "growing" with empty messages. Skip them entirely.
          if (msg['kind'] == 'agent-event' &&
              AgentEventWidget.labelFor(msg['event']) == null) {
            continue;
          }
          if (_shouldHideToolCall(msg, hideToolCalls: hideToolCalls)) {
            hiddenToolCalls.add(msg);
            continue;
          }
          flushHiddenToolCalls();
          items.add(msg);
          final role = msg['role'] as String?;
          final content = msg['content'] ?? msg['text'];
          final text = content is String ? content : content?.toString() ?? '';
          if (role == 'user' && text.trim() == '/clear') {
            items.add(null);
          }
        } catch (e, st) {
          // Never let a single malformed message abort the whole list —
          // otherwise rendering halts at the offending item and every
          // message after it disappears from the UI.
          logger.warning(
            '[chat] skipped malformed message id='
            '${msg['id']} seq=${msg['seq']}: $e',
            e,
            st,
          );
        }
      }
      flushHiddenToolCalls();

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
        try {
          return _buildMessageItem(
            context: context,
            index: index,
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
    if (stopwatch.elapsedMilliseconds >= 8 &&
        logger.shouldLog(LogLevel.debug)) {
      logger.debug(
        '[Perf] buildMessageList '
        'session=${widget.sessionId} '
        'visible=${items.length} '
        'total=$totalCount '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
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
    if (toolName == 'Task' || toolName == 'Agent') return false;

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
