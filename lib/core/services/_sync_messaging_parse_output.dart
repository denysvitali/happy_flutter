part of 'sync_service.dart';

extension SyncMessagingParseOutput on Sync {
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processOutputContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Sidechain metadata for sub-agent grouping. The authoritative
    // parent identifier — `parent_tool_use_id` — is attached uniformly
    // by `_attachParentToolUseId` in `_sync_messaging_parse.dart` so
    // every sidechain emission below carries it without each call
    // site having to thread the field manually.
    //
    // [WireParsers.isRawSidechain] is the single shared metadata-stage
    // definition (also used by message_processor.dart) so the two decrypt
    // pipelines can't drift. See GlitchTip HAPPY_FLUTTER-3C9.
    final isSidechain = WireParsers.isRawSidechain(data);
    final dataUuid = (data['uuid'] ?? data['id']) as String?;
    final dataParentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    final dataType = data['type'] as String?;

    // Process actionable meta messages before skipping the rest.
    if (data['isMeta'] == true || data['isCompactSummary'] == true) {
      // System messages with subtypes that carry UI-relevant information.
      if (dataType == 'system') {
        final subtype = data['subtype'] as String?;

        // Task lifecycle events are sidechain-linked by the CLI via
        // tool_use_id. Forward them so the sidechain grouper can attach
        // them as children of Agent/Task tool calls.
        if (subtype == 'task_started' ||
            subtype == 'task_progress' ||
            subtype == 'task_notification') {
          if (dataUuid == null || dataUuid.isEmpty) return ([], []);
          final description = data['description'] as String?;
          final summary = data['summary'] as String?;
          final status = data['status'] as String?;
          final label = description ?? summary ?? 'Task $subtype';
          // The lifecycle event's `tool_use_id` is the spawning
          // Agent/Task tool_use id — the authoritative parent key.
          // `task_id` is the SDK-assigned agentId for async runs.
          // Stamp both so the grouper can attach the event regardless
          // of whether the wire payload also carries
          // `parent_tool_use_id`.
          final toolUseId = data['tool_use_id'] as String?;
          final taskId = data['task_id'] as String?;

          // task_notification with status 'completed' or 'failed' can
          // carry a summary for display.
          if (subtype == 'task_notification' &&
              (status == 'completed' || status == 'failed')) {
            return (
              [
                {
                  'id': '${message.id}_tn',
                  'seq': message.seq,
                  'createdAt': createdAt,
                  'role': 'agent',
                  'kind': 'text',
                  'content': summary ?? 'Task $status',
                  'taskEvent': true,
                  'taskStatus': status,
                  if (isSidechain) 'isSidechain': true,
                  'uuid': dataUuid,
                  'parentUuid': ?dataParentUuid,
                  if (toolUseId != null && toolUseId.isNotEmpty)
                    'parentToolUseId': toolUseId,
                  if (taskId != null && taskId.isNotEmpty) 'agentId': taskId,
                },
              ],
              [],
            );
          }

          return (
            [
              {
                'id': '${message.id}_te',
                'seq': message.seq,
                'createdAt': createdAt,
                'role': 'agent',
                'kind': 'agent-event',
                'event': {'type': 'message', 'message': label},
                'taskEvent': true,
                if (isSidechain) 'isSidechain': true,
                'uuid': dataUuid,
                'parentUuid': ?dataParentUuid,
                if (toolUseId != null && toolUseId.isNotEmpty)
                  'parentToolUseId': toolUseId,
                if (taskId != null && taskId.isNotEmpty) 'agentId': taskId,
              },
            ],
            [],
          );
        }

        // session_state_changed → update session thinking/presence state.
        if (subtype == 'session_state_changed') {
          final state = data['state'] as String?;
          if (state == 'idle') {
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(thinking: false);
              _notifyDataChanged({SyncDomain.sessions});
            }
          } else if (state == 'running') {
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(thinking: true);
              _notifyDataChanged({SyncDomain.sessions});
            }
          }
          // Don't render a visible message.
          return ([], []);
        }

        // api_retry → show "Retrying..." event in conversation.
        if (subtype == 'api_retry') {
          final attempt = data['attempt'];
          final maxRetries = data['max_retries'];
          final label = 'Retrying API request ($attempt/$maxRetries)...';
          return (
            [
              {
                'id': '${message.id}_ar',
                'seq': message.seq,
                'createdAt': createdAt,
                'role': 'agent',
                'kind': 'agent-event',
                'event': {'type': 'message', 'message': label},
                'raw': outerContent,
              },
            ],
            [],
          );
        }

        // compact_boundary → show compaction event.
        if (subtype == 'compact_boundary') {
          return (
            [
              {
                'id': '${message.id}_cb',
                'seq': message.seq,
                'createdAt': createdAt,
                'role': 'agent',
                'kind': 'agent-event',
                'event': {'type': 'message', 'message': 'Context compacted'},
                'raw': outerContent,
              },
            ],
            [],
          );
        }
      }

      // tool_progress events: show elapsed time as agent event in sidechain.
      if (dataType == 'tool_progress') {
        final toolName = data['tool_name'] as String? ?? 'tool';
        final elapsed = data['elapsed_time_seconds'];
        final elapsedStr = elapsed is num
            ? '${elapsed.toStringAsFixed(0)}s'
            : '';
        final progress = elapsedStr.isEmpty ? '' : ' ($elapsedStr)';
        final label = '$toolName running$progress...';
        return (
          [
            {
              'id': '${message.id}_tp',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'agent',
              'kind': 'agent-event',
              'event': {'type': 'message', 'message': label},
              if (isSidechain) 'isSidechain': true,
              'uuid': ?dataUuid,
              'parentUuid': ?dataParentUuid,
            },
          ],
          [],
        );
      }

      // rate_limit_event → show rate limit warning as agent event.
      if (dataType == 'rate_limit_event') {
        final info = data['rate_limit_info'];
        if (info is Map<String, dynamic>) {
          final status = info['status'] as String?;
          if (status == 'allowed_warning' || status == 'rejected') {
            final label = status == 'rejected'
                ? 'Rate limit reached — waiting for reset'
                : 'Approaching rate limit';
            return (
              [
                {
                  'id': '${message.id}_rl',
                  'seq': message.seq,
                  'createdAt': createdAt,
                  'role': 'agent',
                  'kind': 'agent-event',
                  'event': {'type': 'limit-reached', 'message': label},
                  'raw': outerContent,
                },
              ],
              [],
            );
          }
        }
        return ([], []);
      }

      // prompt_suggestion → internal hint, no visible message for now.
      if (dataType == 'prompt_suggestion') {
        return ([], []);
      }

      // Skip remaining meta/compact summary messages.
      return ([], []);
    }

    if (dataType == 'message') {
      final text = data['message'] as String? ?? data['text'] as String?;
      if (text == null || text.isEmpty) return ([], []);
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': text,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?dataUuid,
            'parentUuid': ?dataParentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'assistant') {
      if (dataUuid == null || dataUuid.isEmpty) return ([], []);

      final agentMsg = data['message'];
      if (agentMsg is! Map<String, dynamic>) return ([], []);

      // Extract usage data for context window tracking
      final usageData = WireParsers.asMap(agentMsg['usage']);
      if (usageData != null) {
        _updateSessionUsage(sessionId, usageData, createdAt);
      }

      // Authoritative per-message inference model (e.g. "claude-opus-4-7").
      // Session metadata may carry a stale/user-supplied label — prefer this.
      final agentModel = agentMsg['model'] as String?;

      final agentContentList = agentMsg['content'];
      if (agentContentList is! List) return ([], []);

      final results = <Map<String, dynamic>>[];
      final toolResultsList = <Map<String, dynamic>>[];
      var i = 0;
      for (final c in agentContentList) {
        if (c is! Map<String, dynamic>) {
          i++;
          continue;
        }
        final type = c['type'] as String?;

        if (type == 'text') {
          results.add({
            'id': '${message.id}_t$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': c['text']?.toString() ?? '',
            'raw': outerContent,
            'model': ?agentModel,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'thinking') {
          results.add({
            'id': '${message.id}_k$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${c['thinking']}*',
            'raw': outerContent,
            'model': ?agentModel,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'tool_use' ||
            type == 'toolCall' ||
            type == 'server_tool_use' ||
            type == 'mcp_tool_use' ||
            type == 'code_execution_tool_use') {
          results.add({
            'id': '${message.id}_u$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': c['name'] ?? c['server_name'] ?? type,
            'input':
                WireParsers.asMap(c['input']) ??
                WireParsers.asMap(c['arguments']) ??
                <String, dynamic>{},
            'toolUseId': c['id'],
            'state': 'running',
            'content': c,
            'raw': outerContent,
            'model': ?agentModel,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'tool_result' ||
            type == 'web_search_tool_result' ||
            type == 'server_tool_result' ||
            type == 'mcp_tool_result' ||
            type == 'code_execution_tool_result') {
          final toolUseId = c['tool_use_id'] as String?;
          if (toolUseId != null && toolUseId.isNotEmpty) {
            toolResultsList.add({
              'toolUseId': toolUseId,
              'result': c['content'],
              'isError': c['is_error'] == true,
              'createdAt': createdAt,
              if (isSidechain) 'isSidechain': true,
              'uuid': dataUuid,
              'parentUuid': ?dataParentUuid,
            });
          }
        }
        i++;
      }
      return (results, toolResultsList);
    }

    if (dataType == 'web_search_call') {
      final toolUseId = (data['id'] ?? data['call_id']) as String?;
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'web_search',
            'input': _webSearchInput(data),
            'toolUseId': toolUseId ?? message.id,
            'state': _webSearchState(data['status'] as String?),
            'result': data,
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': toolUseId ?? dataUuid ?? message.id,
            'parentUuid': ?dataParentUuid,
          },
        ],
        [],
      );
    }

    // Handle top-level tool-result / tool-call-result envelopes.
    // Check both `type` and `dataType` since different server responses
    // use different field names.
    if (dataType == 'tool-result' ||
        dataType == 'tool-call-result' ||
        data['dataType'] == 'tool-result' ||
        data['dataType'] == 'tool-call-result') {
      final result = data['output'] ?? data['content'];
      final callId = data['callId'] as String?;
      if (callId != null && callId.isNotEmpty) {
        return (
          [],
          [
            {
              'toolUseId': callId,
              'result': result,
              'isError': data['isError'] == true || data['is_error'] == true,
              'createdAt': createdAt,
              if (isSidechain) 'isSidechain': true,
              'uuid': ?dataUuid,
              'parentUuid': ?dataParentUuid,
            },
          ],
        );
      }
      return ([], []);
    }

    // pi/codex result envelope with batched tool results.
    if (dataType == 'result') {
      final parsedMessages = <Map<String, dynamic>>[];
      final parsedResults = <Map<String, dynamic>>[];
      var handled = false;

      final toolResults = WireParsers.asList(data['toolResults']) ?? const [];
      for (final item in toolResults) {
        final tr = WireParsers.asMap(item);
        if (tr == null) continue;
        final toolUseId = (tr['toolCallId'] ?? tr['tool_use_id']) as String?;
        if (toolUseId == null || toolUseId.isEmpty) continue;
        handled = true;
        parsedResults.add({
          'toolUseId': toolUseId,
          'result': tr['content'],
          'isError': tr['isError'] == true || tr['is_error'] == true,
          'createdAt': createdAt,
          if (isSidechain) 'isSidechain': true,
          'uuid': ?dataUuid,
          'parentUuid': ?dataParentUuid,
        });
      }

      final outputItems = WireParsers.asList(data['output']) ?? const [];
      var i = 0;
      for (final item in outputItems) {
        final row = WireParsers.asMap(item);
        if (row == null) {
          i++;
          continue;
        }
        final role = row['role'] as String?;
        final callId =
            (row['toolCallId'] ?? row['callId'] ?? row['id']) as String?;
        if (callId == null || callId.isEmpty) {
          i++;
          continue;
        }

        if (role == 'toolCall') {
          handled = true;
          parsedMessages.add({
            'id': '${message.id}_ro$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': row['toolName'] ?? row['name'] ?? 'unknown',
            'input':
                WireParsers.asMap(row['arguments']) ??
                WireParsers.asMap(row['args']) ??
                WireParsers.asMap(row['input']) ??
                <String, dynamic>{},
            'toolUseId': callId,
            'state': _webSearchState(row['status'] as String?),
            'content': row,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': callId,
            'parentUuid': ?dataParentUuid,
          });
        } else if (role == 'toolResult') {
          handled = true;
          parsedResults.add({
            'toolUseId': callId,
            'result': row['content'] ?? row['output'] ?? row['result'],
            'isError': row['isError'] == true || row['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': callId,
            'parentUuid': ?dataParentUuid,
          });
        }
        i++;
      }

      if (handled) return (parsedMessages, parsedResults);
      return ([], []);
    }

    if (dataType == 'user') {
      // Sidechain root: isSidechain=true, message.content is
      // a string or content-block list (the prompt sent to the
      // sub-agent). We emit a hidden marker so
      // _groupSidechainMessages can match it.
      if (isSidechain) {
        final msgContent = data['message']?['content'];
        // Extract the prompt text — bare string or Claude API
        // content-block format [{type: 'text', text: '...'}].
        final promptText = msgContent is String
            ? msgContent
            : (msgContent is List
                  ? _extractTextFromContentBlocks(msgContent)
                  : null);
        if (promptText != null && promptText.isNotEmpty) {
          return (
            [
              {
                'id': '${message.id}_sc',
                'seq': message.seq,
                'createdAt': createdAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': promptText,
                'uuid': ?dataUuid,
                'parentUuid': ?dataParentUuid,
              },
            ],
            [],
          );
        }
      }

      // Tool results - collect them to update existing tool-call states
      final toolResults = <Map<String, dynamic>>[];
      final msgContent = data['message']?['content'];

      if (msgContent is List) {
        for (final c in msgContent) {
          if (c is Map<String, dynamic> && c['type'] == 'tool_result') {
            toolResults.add({
              'toolUseId': c['tool_use_id'],
              'result': c['content'],
              'isError': c['is_error'] == true,
              'createdAt': createdAt,
              'permissions': c['permissions'],
              if (isSidechain) 'isSidechain': true,
              'uuid': ?dataUuid,
              'parentUuid': ?dataParentUuid,
            });
          }
        }
      }

      // Sidechain chain bridge. In a Claude subagent transcript every
      // turn is: assistant(uuid=A) → user-with-tool_result(uuid=U,
      // parent=A) → assistant(uuid=A', parent=U) → ...  The user
      // tool_result message itself produces no visible display, so
      // without an explicit bridge entry SidechainGrouper has no way
      // to walk parentUuid through U and the next assistant looks
      // orphaned ("parent Task missing from history"). Emit a hidden
      // sidechain-link carrying (uuid, parentUuid) so the grouper can
      // index it in sidechainByUuid and bridge the chain. The
      // grouper filters it out of visible children.
      final hasChainAnchors =
          dataUuid != null && dataUuid.isNotEmpty &&
          dataParentUuid != null && dataParentUuid.isNotEmpty;
      final emitChainLink = isSidechain && hasChainAnchors;
      final extras = emitChainLink
          ? <Map<String, dynamic>>[
              {
                'id': '${message.id}_lk',
                'seq': message.seq,
                'createdAt': createdAt,
                'kind': 'sidechain-link',
                'isSidechain': true,
                'uuid': dataUuid,
                'parentUuid': dataParentUuid,
              },
            ]
          : const <Map<String, dynamic>>[];
      return (extras, toolResults);
    }

    // Streamlined text: replaces full assistant message in streamlined mode.
    if (dataType == 'streamlined_text') {
      final text = data['text'] as String?;
      if (text == null || text.isEmpty) return ([], []);
      return (
        [
          {
            'id': '${message.id}_sl',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': text,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?dataUuid,
            'parentUuid': ?dataParentUuid,
          },
        ],
        [],
      );
    }

    // Streamlined tool use summary: replaces tool_use blocks with a summary.
    if (dataType == 'streamlined_tool_use_summary') {
      final summary = data['tool_summary'] as String?;
      if (summary == null || summary.isEmpty) return ([], []);
      return (
        [
          {
            'id': '${message.id}_sts',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': '*$summary*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?dataUuid,
            'parentUuid': ?dataParentUuid,
          },
        ],
        [],
      );
    }

    // tool_use_summary: summary of completed tool operations.
    if (dataType == 'tool_use_summary') {
      final summary = data['summary'] as String?;
      if (summary == null || summary.isEmpty) return ([], []);
      return (
        [
          {
            'id': '${message.id}_tus',
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': '*$summary*',
            'raw': outerContent,
            'uuid': ?dataUuid,
            'parentUuid': ?dataParentUuid,
          },
        ],
        [],
      );
    }

    // Skip system, result, and other unrecognized messages
    return ([], []);
  }

  String _webSearchState(String? status) {
    return switch (status) {
      'completed' || 'succeeded' => 'completed',
      'failed' || 'error' => 'error',
      _ => 'running',
    };
  }

  Map<String, dynamic> _webSearchInput(Map<String, dynamic> data) {
    final action = WireParsers.asMap(data['action']);
    if (action == null) return <String, dynamic>{};

    final query = action['query'] as String?;
    if (query != null && query.isNotEmpty) {
      return {'query': query};
    }

    final queries = WireParsers.asList(action['queries']);
    if (queries != null && queries.isNotEmpty) {
      return {'query': queries.map((q) => q.toString()).join(', ')};
    }

    return <String, dynamic>{};
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processEventContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip ready and session-cleared events (session-cleared is handled at the
    // call site to reset ephemeral presence; ready is internal bookkeeping).
    if (data['type'] == 'ready' || data['type'] == 'session-cleared') {
      return ([], []);
    }

    return (
      [
        {
          'id': message.id,
          'localId': message.localId,
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'agent-event',
          'event': data,
          'content': '',
          'raw': outerContent,
        },
      ],
      [],
    );
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processCodexContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final usageData =
        _extractUsageMap(data['usage']) ??
        _extractUsageMap(
          data['message'] is Map ? (data['message'] as Map)['usage'] : null,
        );
    if (usageData != null) {
      _updateSessionUsage(sessionId, usageData, createdAt);
    }

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid = (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      final toolName = data['toolName'] ?? data['name'] ?? 'unknown';
      final toolInput = data['args'] ?? data['input'] ?? <String, dynamic>{};
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': toolName,
            'input': toolInput,
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['result'] ?? data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processAcpContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid = (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    // turn_aborted: clear thinking state when a turn is aborted.
    // The server may send this instead of or before session_state_changed:idle.
    if (dataType == 'turn_aborted') {
      final current = _sessions[sessionId];
      if (current != null) {
        _sessions[sessionId] = current.copyWith(
          thinking: false,
          thinkingAt: null,
        );
        _notifyDataChanged({SyncDomain.sessions});
      }
      return ([], []);
    }

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'thinking') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${data['text']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      final toolName = data['toolName'] ?? data['name'] ?? 'unknown';
      final toolInput = data['args'] ?? data['input'] ?? <String, dynamic>{};
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': toolName,
            'input': toolInput,
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-result' ||
        dataType == 'tool-call-result' ||
        data['dataType'] == 'tool-result' ||
        data['dataType'] == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['result'] ?? data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    if (dataType == 'file-edit') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file-edit',
            'input': {
              'filePath': data['filePath'],
              'description': data['description'],
              'diff': data['diff'],
              'oldContent': data['oldContent'],
              'newContent': data['newContent'],
            },
            'toolUseId': data['id'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    // Skip task lifecycle events (task_started, task_complete,
    // token_count, permission-request, etc.)
    return ([], []);
  }
}
