part of '../message_processor.dart';

void _processEventContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) return;
  final dataType = data['type'] as String?;
  if (dataType == 'ready' ||
      dataType == 'thinking' ||
      dataType == 'tool-execution-update') {
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
