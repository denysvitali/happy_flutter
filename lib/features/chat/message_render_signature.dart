/// Bounded content signatures for chat display maps.
///
/// Chat display rows are mutable `Map<String, dynamic>` values while they move
/// through Sync, sidechain grouping, and tool-result enrichment. Widget caches
/// need a content signal, not object identity, to avoid stale renders.
int messageRenderSignature(Map<String, dynamic> message) {
  var hash = 0;
  for (final key in _messageSignatureKeys) {
    if (!message.containsKey(key)) continue;
    hash = Object.hash(hash, key, renderValueSignature(message[key]));
  }
  return hash;
}

int compactMessageListRenderSignature(List<Map<String, dynamic>> messages) {
  var hash = messages.length;
  if (messages.isEmpty) return hash;

  hash = Object.hash(hash, messageRenderSignature(messages.first));
  final start = (messages.length - 5).clamp(0, messages.length).toInt();
  for (var i = start; i < messages.length; i++) {
    hash = Object.hash(hash, messageRenderSignature(messages[i]));
  }
  return hash;
}

int renderValueSignature(Object? value, [int depth = 0]) {
  if (value == null) return 0;
  if (depth >= 5) {
    return Object.hash(value.runtimeType, value.hashCode);
  }
  if (value is String) {
    return Object.hash(value.length, value.hashCode);
  }
  if (value is num || value is bool) {
    return value.hashCode;
  }
  if (value is Map<dynamic, dynamic>) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    var hash = entries.length;
    for (final entry in entries) {
      hash = Object.hash(
        hash,
        entry.key.toString(),
        renderValueSignature(entry.value, depth + 1),
      );
    }
    return hash;
  }
  if (value is List<dynamic>) {
    var hash = value.length;
    for (final item in value) {
      hash = Object.hash(hash, renderValueSignature(item, depth + 1));
    }
    return hash;
  }
  return Object.hash(value.runtimeType, value.hashCode);
}

const _messageSignatureKeys = <String>[
  'id',
  'localId',
  'key',
  'seq',
  'createdAt',
  'updatedAt',
  'completedAt',
  'kind',
  'role',
  'name',
  'toolUseId',
  'state',
  'status',
  'sendStatus',
  'isThinking',
  'content',
  'text',
  'input',
  'result',
  'permission',
  'children',
  'tools',
  'event',
  'taskEvent',
  'taskStatus',
  'taskType',
  'workflowName',
  'transcriptDir',
  'workflowRunId',
  'subAgentLastTool',
  'error',
  'summary',
  'metadata',
];
