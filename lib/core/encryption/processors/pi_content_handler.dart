part of '../message_processor.dart';

/// Process pi agent content (content.type == 'pi').
///
/// pi's event format is structurally identical to Codex's: data types are
/// `message`, `model-output`, `tool-call`, `tool-result`, etc. This handler
/// mirrors _processCodexContent.
void _processPiContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required String sessionId,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  required List<Map<String, dynamic>> usageUpdates,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'pi data is '
      '${data?.runtimeType ?? 'null'}, expected Map',
    );
    return;
  }

  final usageData =
      _extractUsageMap(data['usage']) ??
      _extractUsageMap(
        data['message'] is Map ? (data['message'] as Map)['usage'] : null,
      );
  if (usageData != null) {
    usageUpdates.add({
      'sessionId': sessionId,
      'usage': usageData,
      'timestamp': createdAt,
    });
  }

  final dataType = data['type'] as String?;
  final meta = _sidechainMeta(data);
  final parentToolUseId = _extractParentToolUseId(data);
  final agentId = _extractAgentId(data);

  if (dataType == 'message' ||
      dataType == 'reasoning' ||
      dataType == 'model-output') {
    final content = data['fullText'] ?? data['message'];
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': content?.toString() ?? '',
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  if (dataType == 'tool-call') {
    final toolName = data['toolName'] ?? data['name'] ?? 'unknown';
    final toolInput = data['args'] ?? data['input'] ?? <String, dynamic>{};
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': toolName,
      'input': toolInput,
      'toolUseId': data['callId'],
      'state': 'running',
      'content': data,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  if (_isToolResultEnvelope(data)) {
    _addToolResultEnvelope(
      data: data,
      createdAt: createdAt,
      toolResults: toolResults,
      meta: meta,
    );
    return;
  }

  // pi's anthropic-messages API emits 'assistant' with a message.content
  // list (text, thinking, tool_use blocks) — same shape as output/assistant.
  if (dataType == 'assistant') {
    final effectiveUuid = (meta.uuid != null && meta.uuid!.isNotEmpty)
        ? meta.uuid!
        : id;

    final agentMsg = WireParsers.asMap(data['message']);
    if (agentMsg == null) {
      droppedReasons?.add('assistant message field missing');
      return;
    }

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
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
        });
      } else {
        droppedReasons?.add('assistant content missing');
      }
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
        final text = block['text']?.toString() ?? '';
        if (text.isEmpty) {
          i++;
          continue;
        }
        final segments = _splitInlineThinking(text);
        if (segments.length <= 1 &&
            (segments.isEmpty || !segments[0].isThinking)) {
          // No `  ` tags — preserve the original single-message shape.
          messages.add({
            'id': '${id}_t$i',
            'localId': localId,
            'seq': seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': segments.isEmpty ? text : segments[0].content,
            'raw': outerContent,
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': effectiveUuid,
            'parentUuid': ?meta.parentUuid,
            'parentToolUseId': ?parentToolUseId,
            'agentId': ?agentId,
          });
          i++;
          continue;
        }
        // Inline `  ` tags — emit one message per segment with a
        // `_t${i}_t<n>` / `_t${i}_k<n>` suffix so each gets a
        // unique id within the assistant content block.
        var segIndex = 0;
        for (final segment in segments) {
          final isThinking = segment.isThinking;
          messages.add({
            'id': '${id}_t${i}_${isThinking ? 'k' : 't'}$segIndex',
            'localId': localId,
            'seq': seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            if (isThinking) 'isThinking': true,
            'content': isThinking
                ? '*Thinking...*\n\n*${segment.content}*'
                : segment.content,
            'raw': outerContent,
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': effectiveUuid,
            'parentUuid': ?meta.parentUuid,
            'parentToolUseId': ?parentToolUseId,
            'agentId': ?agentId,
          });
          segIndex++;
        }
        i++;
        continue;
      } else if (type == 'thinking') {
        final thinking = block['thinking']?.toString() ?? '';
        if (thinking.isEmpty) {
          i++;
          continue;
        }
        messages.add({
          'id': '${id}_k$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'isThinking': true,
          'content': '*Thinking...*\n\n*$thinking*',
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
        });
      } else if (type == 'tool_use' ||
          type == 'toolCall' ||
          type == 'server_tool_use' ||
          type == 'mcp_tool_use' ||
          type == 'code_execution_tool_use') {
        final toolUseId = block['id'] as String?;
        final rawName = block['name'] ?? block['server_name'];
        final toolName = rawName?.toString().trim() ?? '';
        final input =
            WireParsers.asMap(block['input']) ??
            WireParsers.asMap(block['arguments']) ??
            <String, dynamic>{};
        final inputText = block['inputText']?.toString().trim() ?? '';
        final isPlaceholder =
            toolName.isEmpty &&
            input.isEmpty &&
            (inputText.isEmpty || inputText == '(map[])');
        if (isPlaceholder) {
          i++;
          continue;
        }
        messages.add({
          'id': '${id}_u$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'tool-call',
          'name': toolName.isEmpty ? type : toolName,
          'input': input,
          'toolUseId': toolUseId,
          'state': 'running',
          'content': block,
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
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
            'parentToolUseId': ?parentToolUseId,
            'agentId': ?agentId,
          });
        }
      }
      i++;
    }
    return;
  }

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
        'parentToolUseId': ?parentToolUseId,
        'agentId': ?agentId,
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
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
        });
      } else if (role == 'toolResult') {
        handled = true;
        toolResults.add({
          'toolUseId': callId,
          'result': row['content'] ?? row['output'] ?? row['result'],
          'isError': row['isError'] == true || row['is_error'] == true,
          'createdAt': createdAt,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': callId,
          'parentUuid': ?meta.parentUuid,
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
        });
      }
      i++;
    }
    if (!handled) {
      droppedReasons?.add(
        'pi result with no tool rows '
        '(keys=${data.keys.toList()})',
      );
    }
    return;
  }

  // Unrecognized pi dataType
  droppedReasons?.add(
    'pi dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}
