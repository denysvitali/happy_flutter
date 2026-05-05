part of '../message_processor.dart';

/// Process opencode agent content (content.type == 'opencode').
///
/// OpenCode uses the Agent Client Protocol (ACP) over NDJSON.
/// We receive `session/update` events and translate them into
/// Flutter-friendly message/tool representations.
void _processOpenCodeContent({
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
      'opencode data is ${data?.runtimeType ?? 'null'}, expected Map',
    );
    return;
  }

  // Usage (if present)
  final usageData = _extractUsageMap(data['usage']) ??
      _extractUsageMap(
        data['message'] is Map ? (data['message'] as Map)['usage'] : null,
      );
  if (usageData != null) {
    usageUpdates.add({
      'sessionId': sessionId,
      'usage': usageData,
      'timestamp': createdAt,
      'agent': 'opencode',
    });
  }

  final update = data['update'] as Map<String, dynamic>? ?? data;
  final sessionUpdate = update['sessionUpdate'] as String?;

  switch (sessionUpdate) {
    case 'message':
    case 'text':
      final text = update['text'] ?? update['content'] ?? '';
      messages.add({
        'id': id,
        'localId': localId,
        'seq': seq,
        'createdAt': createdAt,
        'kind': 'message',
        'role': 'agent',
        'content': [
          {
            'type': 'text',
            'text': text,
          }
        ],
        'meta': {'agent': 'opencode'},
      });
      break;

    case 'tool_call':
    case 'tool_call_update':
      final toolCallId = update['toolCallId']?.toString() ?? id;
      final kind = update['kind']?.toString() ?? 'unknown';
      final title = update['title']?.toString() ?? kind;
      final status = update['status']?.toString() ?? 'running';

      messages.add({
        'id': id,
        'localId': localId,
        'seq': seq,
        'createdAt': createdAt,
        'kind': 'tool-call',
        'name': title,
        'toolCallId': toolCallId,
        'state': status,
        'input': update['input'] ?? update['args'],
        'meta': {
          'agent': 'opencode',
          'kind': kind,
        },
      });
      break;

    case 'tool_call_result':
      // Tool results are usually correlated via toolCallId in a real impl.
      // For now we emit a generic result event.
      toolResults.add({
        'id': id,
        'seq': seq,
        'createdAt': createdAt,
        'toolCallId': update['toolCallId'],
        'result': update['result'] ?? update['output'],
        'meta': {'agent': 'opencode'},
      });
      break;

    default:
      // Unknown update type – still surface it for debugging
      messages.add({
        'id': id,
        'localId': localId,
        'seq': seq,
        'createdAt': createdAt,
        'kind': 'message',
        'role': 'agent',
        'content': [
          {
            'type': 'opencode-raw',
            'data': update,
          }
        ],
        'meta': {'agent': 'opencode', 'raw': true},
      });
  }
}
