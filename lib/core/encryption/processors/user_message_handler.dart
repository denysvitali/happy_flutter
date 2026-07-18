part of '../message_processor.dart';

void _processUserMessage({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> content,
  required Object? nestedContent,
  required List<Map<String, dynamic>> messages,
}) {
  final text = nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text'
      ? nestedContent['text']?.toString() ?? ''
      : nestedContent is List
          ? _extractTextFromContentBlocks(
              nestedContent.whereType<Map<String, dynamic>>().toList(),
            )
          : nestedContent?.toString() ?? '';

  final textOrImagePlaceholder =
      text?.isNotEmpty == true
      ? text
      : _containsImageContentBlock(nestedContent)
      ? '[image]'
      : '';

  messages.add({
    'id': id,
    'localId': localId,
    'seq': seq,
    'createdAt': createdAt,
    'role': 'user',
    'kind': 'text',
    'content': textOrImagePlaceholder,
    'raw': content,
  });
}
