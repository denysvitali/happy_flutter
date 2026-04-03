part of '../message_processor.dart';

void _processUserMessage({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> content,
  required dynamic nestedContent,
  required List<Map<String, dynamic>> messages,
}) {
  final text = nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text'
      ? nestedContent['text']?.toString() ?? ''
      : content.toString();

  messages.add({
    'id': id,
    'localId': localId,
    'seq': seq,
    'createdAt': createdAt,
    'role': 'user',
    'kind': 'text',
    'content': text,
    'raw': content,
  });
}
