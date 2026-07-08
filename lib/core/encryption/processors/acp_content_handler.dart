part of '../message_processor.dart';

void _processAcpContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'acp data is '
      '${data?.runtimeType ?? 'null'}, expected Map',
    );
    return;
  }

  final dataType = data['type'] as String?;
  final meta = _sidechainMeta(data);
  final parentToolUseId = _extractParentToolUseId(data);
  final agentId = _extractAgentId(data);

  if (dataType == DataType.message ||
      dataType == DataType.reasoning ||
      // Grok Build (and other ACP clients) may emit the sessionUpdate name
      // as the data type when streaming is coalesced into a single payload.
      dataType == 'agent_message_chunk') {
    final messageText = data['message']?.toString() ??
        data['text']?.toString() ??
        '';
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': messageText,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  if (dataType == DataType.thinking || dataType == 'agent_thought_chunk') {
    final thoughtText = data['text']?.toString() ??
        data['message']?.toString() ??
        '';
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'isThinking': true,
      'content': '*Thinking...*\n\n*$thoughtText*',
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  if (dataType == DataType.toolCall ||
      dataType == 'tool_call' ||
      dataType == 'toolCall') {
    // Grok may nest the tool call under `toolCall`; flatten when present.
    final toolCall = data['toolCall'] is Map<String, dynamic>
        ? data['toolCall'] as Map<String, dynamic>
        : data;
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': toolCall['name'] ?? toolCall['title'] ?? toolCall['kind'],
      'input': toolCall['input'] ?? toolCall['rawInput'] ?? {},
      'toolUseId':
          toolCall['callId'] ?? toolCall['toolCallId'] ?? toolCall['id'],
      'state': 'running',
      'content': toolCall,
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

  if (dataType == DataType.fileEdit) {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
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
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  // Task lifecycle events (task_started, task_progress, task_updated,
  // task_notification).
  // Mirrors the handling in output_content_handler.dart::_processMetaOutput.
  if (dataType == DataType.system) {
    final subtype = data['subtype'] as String?;
    if (subtype == 'task_started' ||
        subtype == 'task_progress' ||
        subtype == 'task_updated' ||
        subtype == 'task_notification') {
      final description = data['description'] as String?;
      final summary = data['summary'] as String?;
      final status = data['status'] as String?;
      final taskType = data['task_type'] as String?;
      final workflowName = data['workflow_name'] as String?;
      final taskExtras = <String, dynamic>{
        'taskStatus': ?status,
        'taskType': ?taskType,
        'workflowName': ?workflowName,
      };

      if ((subtype == 'task_notification' || subtype == 'task_updated') &&
          (status == 'completed' || status == 'failed')) {
        messages.add({
          'id': '${id}_tn',
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': summary ?? 'Task $status',
          'taskEvent': true,
          ...taskExtras,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': ?meta.uuid,
          'parentUuid': ?meta.parentUuid,
          'parentToolUseId': ?parentToolUseId,
          'agentId': ?agentId,
        });
        return;
      }

      final label = description ?? summary ?? 'Task $subtype';
      messages.add({
        'id': '${id}_te',
        'seq': seq,
        'createdAt': createdAt,
        'role': 'agent',
        'kind': 'agent-event',
        'event': {'type': 'message', 'message': label},
        'taskEvent': true,
        ...taskExtras,
        if (meta.isSidechain) 'isSidechain': true,
        'uuid': ?meta.uuid,
        'parentUuid': ?meta.parentUuid,
        'parentToolUseId': ?parentToolUseId,
        'agentId': ?agentId,
      });
      return;
    }
  }

  // Catch-all for any unrecognized ACP dataType values.
  // Log ALL unrecognized types including null so we can audit what was
  // actually dropped vs. legitimately filtered.  dataType is a known
  // set so this won't spam GlitchTip.
  droppedReasons?.add(
    dataType != null
        ? 'unknown acp dataType: $dataType'
        : 'acp data missing dataType (keys=${data.keys.toList()})',
  );
}
