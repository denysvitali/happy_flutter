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
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'codex data is '
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
    // Handle both old (message) and new (model-output) happy-cli-go formats.
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
