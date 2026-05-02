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
    });
    return;
  }

  if (dataType == 'tool-result' ||
      dataType == 'tool-call-result' ||
      data['dataType'] == 'tool-result' ||
      data['dataType'] == 'tool-call-result') {
    final result = data['result'] ?? data['output'] ?? data['content'];
    toolResults.add({
      'toolUseId': data['callId'],
      'result': result,
      'isError': data['isError'] == true || data['is_error'] == true,
      'createdAt': createdAt,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
    return;
  }

  // pi's anthropic-messages API emits 'assistant' with a message.content
  // list (text, thinking, tool_use blocks) — same shape as output/assistant.
  if (dataType == 'assistant') {
    final effectiveUuid = (meta.uuid != null && meta.uuid!.isNotEmpty)
        ? meta.uuid!
        : id;

    final agentMsg = WireParsers.asMap(data['message']);
    if (agentMsg == null) return;

    final agentContentList = agentMsg['content'];
    if (agentContentList is! List) return;

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
        messages.add({
          'id': '${id}_t$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': text,
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
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
        });
      } else if (type == 'tool_use' ||
          type == 'server_tool_use' ||
          type == 'mcp_tool_use' ||
          type == 'code_execution_tool_use') {
        final toolUseId = block['id'] as String?;
        messages.add({
          'id': '${id}_u$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'tool-call',
          'name': block['name'] ?? block['server_name'] ?? type,
          'input': WireParsers.asMap(block['input']) ?? <String, dynamic>{},
          'toolUseId': toolUseId,
          'state': 'running',
          'content': block,
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': toolUseId ?? effectiveUuid,
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
      }
      i++;
    }
    return;
  }

  // Unrecognized pi dataType
  droppedReasons?.add(
    'pi dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}
