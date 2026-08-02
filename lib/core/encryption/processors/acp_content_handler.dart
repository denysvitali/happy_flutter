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
    final messageText =
        data['message']?.toString() ?? data['text']?.toString() ?? '';
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': messageText,
      if (dataType == DataType.message) 'isPromptEchoCandidate': true,
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
    final thoughtText =
        data['text']?.toString() ?? data['message']?.toString() ?? '';
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
    final rawName =
        toolCall['name'] ??
        toolCall['title'] ??
        toolCall['kind'] ??
        data['name'];
    final rawInput =
        WireParsers.asMap(toolCall['input']) ??
        WireParsers.asMap(toolCall['rawInput']) ??
        WireParsers.asMap(data['input']) ??
        WireParsers.asMap(data['rawInput']) ??
        <String, dynamic>{};
    // Unwrap Grok use_tool / CallMcpTool meta-dispatch so UI shows real MCP
    // tool (mcp__server__tool) instead of the dispatcher wrapper.
    final normalized = normalizeGrokToolCall(rawName, rawInput);
    final name = normalized.name;
    final input = normalized.input;
    final status = (toolCall['status'] ?? data['status'])?.toString();
    final state = _toolCallStateFromStatus(status);
    final toolUseId =
        toolCall['callId'] ??
        toolCall['toolCallId'] ??
        toolCall['tool_call_id'] ??
        toolCall['id'] ??
        data['callId'];
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': name,
      'input': input,
      'toolUseId': toolUseId,
      'state': state,
      'kindHint': toolCall['kind'] ?? data['kind'],
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
    final normalized = Map<String, dynamic>.from(data);
    final rawResult =
        data['result'] ??
        data['output'] ??
        data['content'] ??
        data['rawOutput'];
    normalized['result'] = normalizeGrokToolResult(rawResult);
    // Grok emits status: completed|failed; map onto isError when absent.
    if (normalized['isError'] != true && normalized['is_error'] != true) {
      final status = (data['status'] ?? data['state'])
          ?.toString()
          .toLowerCase();
      if (status == 'failed' || status == 'error') {
        normalized['isError'] = true;
      }
    }
    _addToolResultEnvelope(
      data: normalized,
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
      final workflowProgress = _extractWorkflowProgress(data);
      final taskExtras = <String, dynamic>{
        'taskStatus': ?status,
        'taskType': ?taskType,
        // Which lifecycle event produced this row. The chip uses it to say
        // "Task started" instead of rendering an anonymous grey line that
        // reads like any other system notice.
        'taskPhase': ?subtype,
        'workflowName': ?workflowName,
        if (workflowProgress != null && workflowProgress.isNotEmpty)
          'workflowProgress': workflowProgress,
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

      // Flatten + clamp: `local_bash` tasks carry the whole shell command
      // here, and the chip renders as a single centered line.
      final compacted = compactTaskLabel(description ?? summary ?? '');
      final label = compacted.isEmpty ? 'Task $subtype' : compacted;
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

/// Maps Grok/ACP tool status strings onto Happy tool-call UI states.
String _toolCallStateFromStatus(String? status) {
  switch (status?.toLowerCase().trim()) {
    case 'completed':
    case 'success':
    case 'succeeded':
      return 'completed';
    case 'failed':
    case 'error':
      return 'error';
    case 'in_progress':
    case 'running':
    case 'pending':
    case null:
    case '':
      return 'running';
    default:
      return 'running';
  }
}
