part of 'sync_service.dart';

extension SyncMessagingParse on Sync {
  /// Process a decrypted message into display messages and tool results.
  /// Test helper for [_processDecryptedMessage].
  @visibleForTesting
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  testProcessDecryptedMessage({
    required String id,
    required int seq,
    required String sessionId,
    required Map<String, dynamic> content,
    String? localId,
    int? createdAtMs,
  }) {
    return _processDecryptedMessage(
      DecryptedMessage(
        id: id,
        seq: seq,
        localId: localId,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      sessionId,
    );
  }

  ///
  /// Returns a tuple of (displayMessages, toolResults).
  /// Display messages are added to the session message list.
  /// Tool results are used to update existing tool-call message states.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processDecryptedMessage(DecryptedMessage message, String sessionId) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;

    if (content is! Map<String, dynamic>) {
      // Fallback for non-map content
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'kind': 'text',
            'content': content?.toString() ?? '',
            'raw': content,
          },
        ],
        [],
      );
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    // User messages: {role: 'user', content: {type: 'text', text: '...'}}
    if (role == MessageRole.user) {
      if (nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text') {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': nestedContent['text']?.toString() ?? '',
              'raw': content,
            },
          ],
          [],
        );
      }
      // Fallback for non-text user messages
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': content.toString(),
            'raw': content,
          },
        ],
        [],
      );
    }

    // Agent messages: {role: 'agent', content: {type: ..., data: ...}}
    if (role == MessageRole.agent) {
      if (nestedContent is! Map<String, dynamic>) {
        return (
          [
            {
              'id': 'error-${message.id}_parse',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'system',
              'kind': 'error',
              'errorType': 'agent_content_not_map',
              'errorMessage':
                  'Agent message content is not '
                  'a valid structure',
              'debugData': {
                'messageId': message.id,
                'seq': message.seq,
                'contentType': '${nestedContent.runtimeType}',
              },
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      final contentType = nestedContent['type'] as String?;

      // Output type: Claude/assistant messages
      if (contentType == 'output') {
        return _processOutputContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // Event type: mode switches, limit reached, etc.
      if (contentType == 'event') {
        // When the agent sends session-cleared (after a /clear restart),
        // immediately drop the session's ephemeral presence to offline so
        // that waitForAgentReady blocks until the new Claude process sends
        // its first keep-alive. Without this, a follow-up message is posted
        // while the old Claude is dead and the new one hasn't connected yet.
        final evData = nestedContent['data'];
        if (evData is Map<String, dynamic>) {
          final evType = (evData['t'] ?? evData['type']) as String?;
          if (evType == 'session-cleared') {
            _presenceTimers[sessionId]?.cancel();
            _presenceTimers.remove(sessionId);
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged();
            }
          }
        }
        return _processEventContent(message, nestedContent, createdAt, content);
      }

      // Codex type: Codex agent messages
      if (contentType == 'codex') {
        return _processCodexContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // ACP type: unified agent communication protocol
      if (contentType == 'acp') {
        return _processAcpContent(message, nestedContent, createdAt, content);
      }

      // Session protocol envelope embedded directly under content.
      if (_looksLikeSessionEnvelope(nestedContent)) {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      // Session protocol wrapper (agent role).
      if (contentType == 'session') {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      final fallback = _extractAgentFallbackText(nestedContent);
      if (fallback != null && fallback.isNotEmpty) {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'agent',
              'kind': 'text',
              'content': fallback,
              'raw': content,
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      return (
        [
          {
            'id': 'error-${message.id}_parse',
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'system',
            'kind': 'error',
            'errorType': 'unknown_agent_content_type',
            'errorMessage': 'Unrecognized agent content type: $contentType',
            'debugData': {
              'messageId': message.id,
              'seq': message.seq,
              'contentType': contentType,
            },
          },
        ],
        <Map<String, dynamic>>[],
      );
    }

    // Session protocol envelope role.
    if (role == MessageRole.session) {
      return _processSessionContent(
        message,
        nestedContent ?? content,
        createdAt,
        content,
      );
    }

    return (
      [
        {
          'id': 'error-${message.id}_parse',
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'unknown_role',
          'errorMessage': 'Unrecognized message role: $role',
          'debugData': {
            'messageId': message.id,
            'seq': message.seq,
            'role': role,
          },
        },
      ],
      <Map<String, dynamic>>[],
    );
  }

  bool _looksLikeSessionEnvelope(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    final hasEvent =
        value['ev'] is Map<String, dynamic> ||
        value['event'] is Map<String, dynamic>;
    final hasIdentity =
        value['id'] != null || value['uuid'] != null || value['time'] != null;
    return hasEvent && hasIdentity;
  }

  String? _extractAgentFallbackText(dynamic nestedContent) {
    if (nestedContent is! Map<String, dynamic>) return null;

    final directText = nestedContent['text'] ?? nestedContent['message'];
    if (directText is String && directText.isNotEmpty) {
      return directText;
    }

    final data = nestedContent['data'];
    if (data is Map<String, dynamic>) {
      final dataMessage = data['message'];
      if (dataMessage is String && dataMessage.isNotEmpty) {
        return dataMessage;
      }
      final dataText = data['text'];
      if (dataText is String && dataText.isNotEmpty) {
        return dataText;
      }
    }

    return null;
  }

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

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
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
                  if (isSidechain) 'isSidechain': true,
                  'uuid': dataUuid,
                  'parentUuid': ?dataParentUuid,
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
                if (isSidechain) 'isSidechain': true,
                'uuid': dataUuid,
                'parentUuid': ?dataParentUuid,
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
              _notifyDataChanged();
            }
          } else if (state == 'running') {
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(thinking: true);
              _notifyDataChanged();
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
                'event': {
                  'type': 'message',
                  'message': 'Context compacted',
                },
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
        final elapsedStr = elapsed is num ? '${elapsed.toStringAsFixed(0)}s' : '';
        final label = '$toolName running${elapsedStr.isNotEmpty ? ' ($elapsedStr)' : ''}...';
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

    if (dataType == 'assistant') {
      if (dataUuid == null || dataUuid.isEmpty) return ([], []);

      final agentMsg = data['message'];
      if (agentMsg is! Map<String, dynamic>) return ([], []);

      // Extract usage data for context window tracking
      final usageData = WireParsers.asMap(agentMsg['usage']);
      if (usageData != null) {
        _updateSessionUsage(sessionId, usageData, createdAt);
      }

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
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'tool_use' ||
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
            'input': WireParsers.asMap(c['input'])
                ?? <String, dynamic>{},
            'toolUseId': c['id'],
            'state': 'running',
            'content': c,
            'raw': outerContent,
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
              'isError':
                  data['isError'] == true || data['is_error'] == true,
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
      return ([], toolResults);
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
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
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
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': WireParsers.asMap(data['input'])
                ?? <String, dynamic>{},
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
      final result = data['output'] ?? data['content'];
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
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
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
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': WireParsers.asMap(data['input'])
                ?? <String, dynamic>{},
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
      final result = data['output'] ?? data['content'];
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

    // Skip task lifecycle events (task_started, task_complete, turn_aborted,
    // token_count, permission-request, etc.)
    return ([], []);
  }
}
