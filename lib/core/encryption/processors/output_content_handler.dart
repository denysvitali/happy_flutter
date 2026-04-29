part of '../message_processor.dart';

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
      'seq=$seq id=$id: output data is '
      '${nestedContent['data']?.runtimeType ?? 'null'}, '
      'expected Map',
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
          'seq=$seq id=$id: assistant message field is '
          '${rawAgentMsg?.runtimeType ?? 'null'}, expected Map or '
          'non-empty String',
        );
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
          'seq=$seq id=$id: assistant content is '
          '${agentContentList?.runtimeType ?? 'null'}, '
          'expected List or non-empty String',
        );
      }
      return;
    }

    if (agentContentList.isEmpty) {
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
          type == 'server_tool_use' ||
          type == 'mcp_tool_use' ||
          type == 'code_execution_tool_use') {
        final toolUseUuid = (block['id'] as String?)?.isNotEmpty ?? false
            ? block['id'] as String
            : effectiveUuid;
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
          'uuid': toolUseUuid,
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
      } else if (type != null) {
        droppedReasons?.add(
          'seq=$seq id=$id: unrecognized content block type=$type '
          'at index $i',
        );
      }
      i++;
    }
    return;
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
  if (dataType == 'tool-result' ||
      dataType == 'tool-call-result' ||
      data['dataType'] == 'tool-result' ||
      data['dataType'] == 'tool-call-result') {
    final result = data['output'] ?? data['content'];
    final callId = data['callId'] as String?;
    if (callId != null && callId.isNotEmpty) {
      toolResults.add({
        'toolUseId': callId,
        'result': result,
        'isError': data['isError'] == true || data['is_error'] == true,
        'createdAt': createdAt,
        if (meta.isSidechain) 'isSidechain': true,
        'uuid': ?meta.uuid,
        'parentUuid': ?meta.parentUuid,
      });
    }
    return;
  }

  // Unrecognized dataType -- log to help diagnose silent drops.
  // Omit seq/id from the reason so GlitchTip groups by dataType,
  // not per-message.
  droppedReasons?.add(
    'output dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
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
