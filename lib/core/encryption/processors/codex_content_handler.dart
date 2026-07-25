part of '../message_processor.dart';

void _processCodexContent({
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
  final head = _processAgentEventHead(
    vendor: 'codex',
    id: id,
    localId: localId,
    seq: seq,
    createdAt: createdAt,
    sessionId: sessionId,
    outerContent: outerContent,
    nestedContent: nestedContent,
    messages: messages,
    usageUpdates: usageUpdates,
    droppedReasons: droppedReasons,
  );
  if (head == null || head.emitted) return;
  final data = head.data;
  final dataType = head.dataType;
  final meta = head.meta;
  final parentToolUseId = head.parentToolUseId;
  final agentId = head.agentId;

  if (dataType == DataType.thinking) {
    // Codex thinking / reasoning blocks. The wire payload carries the
    // thought text in either `text` or `thinking` (both are present in
    // happy-cli-go's codex envelope). Render as a collapsible thinking
    // block so the user sees the agent is actively reasoning.
    final thoughtText =
        data['text']?.toString() ?? data['thinking']?.toString() ?? '';
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'isThinking': true,
      'content': thoughtText,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    return;
  }

  if (dataType == DataType.toolCall) {
    // Handle old (name/input), current (toolName/args), and Responses-style
    // (name/arguments) tool calls from happy-cli-go/Codex.
    final toolName = data['toolName'] ?? data['name'] ?? 'unknown';
    final toolInput =
        data['args'] ??
        data['input'] ??
        data['arguments'] ??
        <String, dynamic>{};
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

  // Unrecognized codex dataType
  droppedReasons?.add(
    'codex dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}

Map<String, dynamic>? _extractUsageMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
