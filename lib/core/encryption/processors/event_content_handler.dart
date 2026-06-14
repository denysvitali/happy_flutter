part of '../message_processor.dart';

void _processEventContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) return;
  final dataType = data['type'] as String?;
  // usage_report carries per-turn token/cost telemetry that the output
  // content path already extracts into usageUpdates — as a chat row it
  // has no renderable label and only inflates the list with empty,
  // padded items (one per agent turn).
  if (dataType == 'ready' ||
      dataType == 'thinking' ||
      dataType == 'usage_report' ||
      dataType == 'tool-execution-update') {
    droppedReasons?.add('event data type $dataType');
    return;
  }

  messages.add({
    'id': id,
    'localId': localId,
    'seq': seq,
    'createdAt': createdAt,
    'role': 'agent',
    'kind': 'agent-event',
    'event': data,
    'content': '',
    'raw': outerContent,
  });
}
