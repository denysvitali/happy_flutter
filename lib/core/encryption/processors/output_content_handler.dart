part of '../message_processor.dart';

/// Emits a visible `agent-event` for content the handler cannot render.
///
/// Replaces silent drops so the user sees that *something* arrived from
/// the agent — looking at an empty chat while the server seq advances
/// gives the impression the session is paused. The `droppedReasons`
/// telemetry still fires for Sentry grouping.
void _emitUnrenderedAgentEvent({
  required String id,
  required String suffix,
  required int seq,
  required int createdAt,
  required String label,
  required ({bool isSidechain, String? uuid, String? parentUuid}) meta,
  required List<Map<String, dynamic>> messages,
}) {
  messages.add({
    'id': '${id}_$suffix',
    'seq': seq,
    'createdAt': createdAt,
    'role': 'agent',
    'kind': 'agent-event',
    'event': {'type': 'unrendered', 'message': label},
    if (meta.isSidechain) 'isSidechain': true,
    'uuid': ?meta.uuid,
    'parentUuid': ?meta.parentUuid,
  });
}

void _processOutputContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required String sessionId,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  required List<Map<String, dynamic>> usageUpdates,
  List<String>? droppedReasons,
}) {
  final data = WireParsers.asMap(nestedContent['data']);
  if (data == null) {
    droppedReasons?.add(
      'seq=$seq id=$id: output data is not a Map',
    );
    _emitUnrenderedAgentEvent(
      id: id,
      suffix: 'ud',
      seq: seq,
      createdAt: createdAt,
      label: 'Unsupported agent message',
      meta: (isSidechain: false, uuid: null, parentUuid: null),
      messages: messages,
    );
    return;
  }

  if (data['isMeta'] == true || data['isCompactSummary'] == true) {
    _processMetaOutput(
      id: id,
      seq: seq,
      createdAt: createdAt,
      data: data,
      messages: messages,
    );
    return;
  }

  final meta = _sidechainMeta(data);
  final dataType = data['type'] as String?;

  // Plain text agent message — some server paths emit this shape instead
  // of the full `assistant` envelope. Before this branch existed these
  // messages were dropped by the unrecognized-dataType fallback at the
  // bottom, which accounts for the majority of "fetchMessages dropped
  // (output filter)" warnings.
  if (dataType == 'message') {
    final text = (data['message'] ?? data['text']) as String?;
    if (text == null || text.isEmpty) return;
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': text,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
    return;
  }

  if (dataType == 'assistant') {
    final effectiveUuid = (meta.uuid != null && meta.uuid!.isNotEmpty)
        ? meta.uuid!
        : id; // id is never null — always a wire id string

    final rawAgentMsg = data['message'];
    final agentMsg = WireParsers.asMap(rawAgentMsg);
    if (agentMsg == null) {
      if (rawAgentMsg is String && rawAgentMsg.isNotEmpty) {
        messages.add({
          'id': id,
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': rawAgentMsg,
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else {
        droppedReasons?.add(
          'seq=$seq id=$id: assistant message field unexpected type',
        );
        // Only surface a placeholder when the field carries unparseable
        // *data* — a null/missing message is just an empty signal and
        // should stay silent so legitimate acks do not spam the chat.
        if (rawAgentMsg != null) {
          _emitUnrenderedAgentEvent(
            id: id,
            suffix: 'amf',
            seq: seq,
            createdAt: createdAt,
            label: 'Unsupported agent message',
            meta: meta,
            messages: messages,
          );
        }
      }
      return;
    }

    final usageData = WireParsers.asMap(agentMsg['usage']);
    if (usageData != null) {
      usageUpdates.add({
        'sessionId': sessionId,
        'usage': usageData,
        'timestamp': createdAt,
      });
    }

    final agentModel = agentMsg['model'] as String?;

    final agentContentList = agentMsg['content'];
    if (agentContentList is! List) {
      if (agentContentList is String && agentContentList.isNotEmpty) {
        messages.add({
          'id': id,
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': agentContentList,
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else {
        droppedReasons?.add(
          'seq=$seq id=$id: assistant content unexpected type',
        );
        // Same rationale as the message-field branch above: null/missing
        // content stays silent (no information). Genuinely weird types
        // (numbers, maps, etc.) surface the placeholder.
        if (agentContentList != null) {
          _emitUnrenderedAgentEvent(
            id: id,
            suffix: 'act',
            seq: seq,
            createdAt: createdAt,
            label: 'Unsupported agent message',
            meta: meta,
            messages: messages,
          );
        }
      }
      return;
    }

    if (agentContentList.isEmpty) {
      // Truly empty content carries no information to render. Keep silent
      // (just log to telemetry) — emitting an "unrendered" chip here would
      // create noise for legitimately empty acks.
      droppedReasons?.add('seq=$seq id=$id: assistant content list is empty');
      return;
    }

    var i = 0;
    for (final c in agentContentList) {
      final block = WireParsers.asMap(c);
      if (block == null) {
        i++;
        continue;
      }
      final type = block['type'] as String?;

      if (type == 'text') {
        messages.add({
          'id': '${id}_t$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': block['text']?.toString() ?? '',
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (type == 'thinking') {
        messages.add({
          'id': '${id}_k$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'isThinking': true,
          'content': '*Thinking...*\n\n*${block['thinking']}*',
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (type == 'tool_use' ||
          type == 'toolCall' ||
          type == 'server_tool_use' ||
          type == 'mcp_tool_use' ||
          type == 'code_execution_tool_use') {
        // Use the JSONL message uuid (effectiveUuid) — NOT the
        // tool_use block id (toolu_*).  Sibling content blocks (text,
        // thinking, other tool_uses) in the same assistant message
        // all share the JSONL uuid; descendant sidechain messages
        // chain back via parentUuid==<that JSONL uuid>.  When the
        // tool-call message instead stored the toolu_* as its uuid,
        // any descendant whose chain ran through the assistant
        // message containing only this tool_use (no text sibling
        // carrying the JSONL uuid) failed to resolve, fragmenting
        // long subagent transcripts into many "Subagent output
        // (recovered)" placeholders.  toolUseId still holds toolu_*
        // for the first sidechain root that chains via parentUuid==
        // toolu_*; the grouper indexes both fields.
        messages.add({
          'id': '${id}_u$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'tool-call',
          'name': block['name'] ?? block['server_name'] ?? type,
          'input': WireParsers.asMap(block['input']) ?? <String, dynamic>{},
          'toolUseId': block['id'],
          'state': 'running',
          'content': block,
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (type == 'tool_result' ||
          type == 'web_search_tool_result' ||
          type == 'server_tool_result' ||
          type == 'mcp_tool_result' ||
          type == 'code_execution_tool_result') {
        final toolUseId = block['tool_use_id'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          toolResults.add({
            'toolUseId': toolUseId,
            'result': block['content'],
            'isError': block['is_error'] == true,
            'createdAt': createdAt,
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': effectiveUuid,
            'parentUuid': ?meta.parentUuid,
          });
        }
      } else if (type == 'redacted_thinking') {
        // Anthropic's encrypted thinking blob — deliberately invisible
        // to the user. No telemetry, no placeholder.
      } else if (type != null) {
        // Omit type and index so GlitchTip groups all unrecognized
        // content blocks into a single issue instead of one per variant.
        droppedReasons?.add(
          'seq=$seq id=$id: unrecognized output content block',
        );
        _emitUnrenderedAgentEvent(
          id: id,
          suffix: 'ub$i',
          seq: seq,
          createdAt: createdAt,
          label: 'Unsupported content block ($type)',
          meta: meta,
          messages: messages,
        );
      }
      i++;
    }
    return;
  }

  if (dataType == 'web_search_call') {
    final toolUseId = (data['id'] ?? data['call_id']) as String?;
    final effectiveUuid = (meta.uuid != null && meta.uuid!.isNotEmpty)
        ? meta.uuid!
        : id;
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': 'web_search',
      'input': _webSearchInput(data),
      'toolUseId': toolUseId ?? id,
      'state': _webSearchState(data['status'] as String?),
      'result': data,
      'content': data,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': toolUseId ?? effectiveUuid,
      'parentUuid': ?meta.parentUuid,
    });
    return;
  }

  // pi/codex result envelope. Some backends send tool calls/results as
  // `data.output[]` entries with `role: toolCall/toolResult` instead of
  // `data.toolResults`.
  if (dataType == 'result') {
    var handled = false;

    final batchedResults = WireParsers.asList(data['toolResults']) ?? const [];
    for (final item in batchedResults) {
      final tr = WireParsers.asMap(item);
      if (tr == null) continue;
      final toolUseId = (tr['toolCallId'] ?? tr['tool_use_id']) as String?;
      if (toolUseId == null || toolUseId.isEmpty) continue;
      handled = true;
      toolResults.add({
        'toolUseId': toolUseId,
        'result': tr['content'],
        'isError': tr['isError'] == true || tr['is_error'] == true,
        'createdAt': createdAt,
        if (meta.isSidechain) 'isSidechain': true,
        'uuid': ?meta.uuid,
        'parentUuid': ?meta.parentUuid,
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

      if (role == 'toolCall' && callId != null && callId.isNotEmpty) {
        handled = true;
        messages.add({
          'id': '${id}_ro$i',
          'localId': localId,
          'seq': seq,
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
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': callId,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (role == 'toolResult' &&
          callId != null &&
          callId.isNotEmpty) {
        handled = true;
        toolResults.add({
          'toolUseId': callId,
          'result': row['content'] ?? row['output'] ?? row['result'],
          'isError': row['isError'] == true || row['is_error'] == true,
          'createdAt': createdAt,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': callId,
          'parentUuid': ?meta.parentUuid,
        });
      }
      i++;
    }

    if (handled) return;
  }

  if (dataType == 'user') {
    if (meta.isSidechain) {
      final userMessage = WireParsers.asMap(data['message']);
      final msgContent = userMessage?['content'];
      final promptText = msgContent is String
          ? msgContent
          : (msgContent is List
                ? _extractTextFromContentBlocks(msgContent)
                : null);
      if (promptText != null && promptText.isNotEmpty) {
        messages.add({
          'id': '${id}_sc',
          'seq': seq,
          'createdAt': createdAt,
          'kind': 'sidechain-root',
          'isSidechain': true,
          'prompt': promptText,
          'uuid': ?meta.uuid,
          'parentUuid': ?meta.parentUuid,
        });
        return;
      }
    }

    final msgContent = data['message']?['content'];
    if (msgContent is String && msgContent.isNotEmpty) {
      messages.add({
        'id': id,
        'localId': localId,
        'seq': seq,
        'createdAt': createdAt,
        'role': 'user',
        'kind': 'text',
        'content': msgContent,
        'raw': outerContent,
        if (meta.isSidechain) 'isSidechain': true,
        'uuid': ?meta.uuid,
        'parentUuid': ?meta.parentUuid,
      });
      return;
    }
    if (msgContent is List) {
      var i = 0;
      for (final c in msgContent) {
        if (c is! Map<String, dynamic>) {
          i++;
          continue;
        }
        final type = c['type'] as String?;
        if (type == 'text') {
          final text = c['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            messages.add({
              'id': '${id}_t$i',
              'localId': localId,
              'seq': seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': text,
              'raw': outerContent,
              if (meta.isSidechain) 'isSidechain': true,
              'uuid': ?meta.uuid,
              'parentUuid': ?meta.parentUuid,
            });
          }
        } else if (type == 'tool_result') {
          toolResults.add({
            'toolUseId': c['tool_use_id'],
            'result': c['content'],
            'isError': c['is_error'] == true,
            'createdAt': createdAt,
            'permissions': c['permissions'],
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': ?meta.uuid,
            'parentUuid': ?meta.parentUuid,
          });
        } else if (type == 'tool-result') {
          // Interrupted-tool variant emitted by the CLI when a user
          // aborts a tool call mid-run. Different field names from the
          // standard tool_result block, but the downstream consumer
          // only needs toolUseId + result + isError.
          final callId = (c['callId'] ?? c['tool_use_id']) as String?;
          if (callId != null && callId.isNotEmpty) {
            toolResults.add({
              'toolUseId': callId,
              'result': c['output'] ?? c['content'],
              'isError': c['isError'] == true || c['is_error'] == true,
              'createdAt': createdAt,
              'permissions': c['permissions'],
              if (meta.isSidechain) 'isSidechain': true,
              'uuid': ?meta.uuid,
              'parentUuid': ?meta.parentUuid,
            });
          }
        } else if (type == 'image') {
          // Render a placeholder so the message does not vanish; the
          // rich image pipeline is out of scope for this fix.
          messages.add({
            'id': '${id}_i$i',
            'localId': localId,
            'seq': seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': '[image]',
            'raw': outerContent,
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': ?meta.uuid,
            'parentUuid': ?meta.parentUuid,
          });
        } else if (type != null) {
          droppedReasons?.add('user content block type=$type not handled');
          _emitUnrenderedAgentEvent(
            id: id,
            suffix: 'uu$i',
            seq: seq,
            createdAt: createdAt,
            label: 'Unsupported content block ($type)',
            meta: meta,
            messages: messages,
          );
        }
        i++;
      }
    }
    return;
  }

  // Handle top-level tool-result / tool-call-result envelopes.
  // The server sometimes wraps tool results at the output level
  // (same shape the ACP handler processes).
  // Check both `data['type']` and `data['dataType']` since different
  // server responses use different field names.
  if (_isToolResultEnvelope(data)) {
    _addToolResultEnvelope(
      data: data,
      createdAt: createdAt,
      toolResults: toolResults,
      meta: meta,
    );
    return;
  }

  // Unrecognized dataType -- log to help diagnose silent drops.
  // Omit seq, id, dataType, and keys from the reason so GlitchTip
  // groups all unrecognized output data types into a single issue
  // instead of one per variant.
  droppedReasons?.add('output data type not handled');
  _emitUnrenderedAgentEvent(
    id: id,
    suffix: 'udt',
    seq: seq,
    createdAt: createdAt,
    label: dataType != null && dataType.isNotEmpty
        ? 'Unsupported message ($dataType)'
        : 'Unsupported agent message',
    meta: meta,
    messages: messages,
  );
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

/// Handles `isMeta` / `isCompactSummary` output messages.
///
/// Some meta subtypes are UI-relevant: compact boundaries, task
/// lifecycle events, API retries, tool progress ticks. Render them
/// as `agent-event` messages (with the sidechain uuid chain when
/// applicable, so they also serve as bridge records for the grouper).
/// Unrecognized meta subtypes fall back to an invisible bridge
/// record when they carry a sidechain uuid, or a no-op otherwise.
void _processMetaOutput({
  required String id,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> data,
  required List<Map<String, dynamic>> messages,
}) {
  final meta = _sidechainMeta(data);
  final dataType = data['type'] as String?;
  final subtype = data['subtype'] as String?;

  void addEvent(String suffix, String eventType, String label) {
    messages.add({
      'id': '${id}_$suffix',
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'agent-event',
      'event': {'type': eventType, 'message': label},
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
  }

  if (dataType == 'system') {
    if (subtype == 'task_started' ||
        subtype == 'task_progress' ||
        subtype == 'task_notification') {
      final description = data['description'] as String?;
      final summary = data['summary'] as String?;
      final status = data['status'] as String?;

      if (subtype == 'task_notification' &&
          (status == 'completed' || status == 'failed')) {
        messages.add({
          'id': '${id}_tn',
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': summary ?? 'Task $status',
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': ?meta.uuid,
          'parentUuid': ?meta.parentUuid,
        });
        return;
      }

      final label = description ?? summary ?? 'Task $subtype';
      addEvent('te', 'message', label);
      return;
    }

    if (subtype == 'compact_boundary') {
      addEvent('cb', 'message', 'Context compacted');
      return;
    }

    if (subtype == 'api_retry') {
      final attempt = data['attempt'];
      final maxRetries = data['max_retries'];
      addEvent(
        'ar',
        'message',
        'Retrying API request ($attempt/$maxRetries)...',
      );
      return;
    }
  }

  if (dataType == 'tool_progress') {
    final toolName = data['tool_name'] as String? ?? 'tool';
    final elapsed = data['elapsed_time_seconds'];
    final elapsedStr = elapsed is num ? '${elapsed.toStringAsFixed(0)}s' : '';
    final label =
        '$toolName running${elapsedStr.isNotEmpty ? ' ($elapsedStr)' : ''}...';
    addEvent('tp', 'message', label);
    return;
  }

  if (dataType == 'rate_limit_event') {
    final info = WireParsers.asMap(data['rate_limit_info']);
    final status = info?['status'] as String?;
    if (status == 'allowed_warning' || status == 'rejected') {
      final label = status == 'rejected'
          ? 'Rate limit reached — waiting for reset'
          : 'Approaching rate limit';
      addEvent('rl', 'limit-reached', label);
    }
    return;
  }

  // No actionable subtype. If the message is part of a sidechain
  // UUID chain, emit an invisible bridge record so the grouper can
  // still resolve subsequent real sidechain messages back to the
  // parent Task tool-call.
  if (meta.isSidechain && meta.uuid != null && meta.uuid!.isNotEmpty) {
    messages.add({
      'id': '${id}_bridge',
      'seq': seq,
      'createdAt': createdAt,
      'isSidechain': true,
      'isBridge': true,
      'uuid': meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
  }
}
