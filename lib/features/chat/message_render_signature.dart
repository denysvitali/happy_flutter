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
    // Hashing huge tool-output strings on every build is a major hotspot.
    // A bounded fingerprint is enough to detect almost all real changes.
    if (value.length <= _signatureStringThreshold) {
      return Object.hash(value.length, value.hashCode);
    }
    return Object.hash(
      value.length,
      value.substring(0, _signatureStringSample).hashCode,
      value.substring(value.length - _signatureStringSample).hashCode,
    );
  }
  if (value is num || value is bool) {
    return value.hashCode;
  }
  if (value is Map<dynamic, dynamic>) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    if (entries.length > _signatureCollectionThreshold) {
      // Large maps are almost always tool outputs/permissions; their exact
      // shape is captured by the sampled string fields above.
      return Object.hash(entries.length, value.keys.join().hashCode);
    }
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
    if (value.length > _signatureCollectionThreshold) {
      var hash = value.length;
      for (var i = 0; i < _signatureEdgeSample; i++) {
        hash = Object.hash(hash, renderValueSignature(value[i], depth + 1));
      }
      for (var i = value.length - _signatureEdgeSample;
          i < value.length;
          i++) {
        hash = Object.hash(hash, renderValueSignature(value[i], depth + 1));
      }
      return hash;
    }
    var hash = value.length;
    for (final item in value) {
      hash = Object.hash(hash, renderValueSignature(item, depth + 1));
    }
    return hash;
  }
  return Object.hash(value.runtimeType, value.hashCode);
}

const int _signatureStringThreshold = 256;
const int _signatureStringSample = 128;
const int _signatureCollectionThreshold = 16;
const int _signatureEdgeSample = 3;

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
  'sendSlow',
  'isThinking',
  'content',
  'text',
  'input',
  'result',
  'permission',
  'children',
  'tools',
  'items',
  'event',
  'taskEvent',
  'taskStatus',
  'taskPhase',
  'taskType',
  'workflowName',
  'transcriptDir',
  'workflowRunId',
  'workflowProgress',
  'subAgentLastTool',
  'error',
  'summary',
  'metadata',
];
