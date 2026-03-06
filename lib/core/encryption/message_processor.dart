/// Pure-Dart message processing functions that can run inside an isolate.
///
/// These are top-level functions (not methods on a class) so they can be
/// passed to [Isolate.run].  They have **no** Flutter, FFI, or shared-state
/// dependencies — only plain Dart map/list manipulation.
library;

/// Result of processing a batch of decrypted messages.
class ProcessedMessages {
  const ProcessedMessages({
    required this.messages,
    required this.toolResults,
    required this.usageUpdates,
    required this.maxSeq,
  });

  /// Display-ready message maps.
  final List<Map<String, dynamic>> messages;

  /// Tool-result maps used to update existing tool-call states.
  final List<Map<String, dynamic>> toolResults;

  /// Usage data extracted from assistant messages.
  /// Each entry: `{sessionId, usage, timestamp}`.
  final List<Map<String, dynamic>> usageUpdates;

  /// Highest `seq` seen in this batch (-1 if empty).
  final int maxSeq;
}

/// Process a list of decrypted message JSON maps into display messages,
/// tool results, and usage updates.
///
/// [decryptedJsonList] contains the raw decrypted content for each message
/// in the same order as the original encrypted list.  Entries that failed
/// decryption should be `null`.
///
/// [wireMessages] is the original list of wire-format message maps (used
/// to extract `id`, `seq`, `localId`, `createdAt`).
///
/// [sessionId] is passed through for context but is **not** used to
/// mutate any shared state.
ProcessedMessages processDecryptedMessages({
  required List<dynamic> decryptedJsonList,
  required List<Map<String, dynamic>> wireMessages,
  required String sessionId,
  List<bool>? wasEncrypted,
}) {
  final messages = <Map<String, dynamic>>[];
  final toolResults = <Map<String, dynamic>>[];
  final usageUpdates = <Map<String, dynamic>>[];
  var maxSeq = -1;

  for (var i = 0; i < wireMessages.length; i++) {
    final wire = wireMessages[i];
    final id = wire['id'] as String? ?? '';
    final seq = wire['seq'] as int? ?? 0;
    final localId = wire['localId'] as String?;
    final rawCreatedAt = wire['createdAt'];
    final createdAt = _parseCreatedAtMs(rawCreatedAt);

    final decrypted = i < decryptedJsonList.length
        ? decryptedJsonList[i]
        : null;

    if (decrypted == null) {
      if (seq > maxSeq) maxSeq = seq;

      // Check if message was actually encrypted — if not,
      // skip silently instead of showing a decryption error.
      final encrypted = wasEncrypted != null && i < wasEncrypted.length
          ? wasEncrypted[i]
          : true; // default: assume encrypted (backwards compat)

      if (!encrypted) {
        // Message was not encrypted — skip, don't show error
        continue;
      }

      // Decryption actually failed — emit error placeholder
      messages.add({
        'id': 'error-${id.isEmpty ? 'unknown-$i' : id}',
        'seq': seq,
        'createdAt': createdAt,
        'role': 'system',
        'kind': 'error',
        'errorType': 'decryption_failed',
        'errorMessage': 'Failed to decrypt message',
        'debugData': {'messageId': id, 'seq': seq, 'localId': localId},
      });
      continue;
    }

    if (seq > maxSeq) maxSeq = seq;

    final content = decrypted;
    if (content is! Map<String, dynamic>) {
      messages.add({
        'id': id,
        'localId': localId,
        'seq': seq,
        'createdAt': createdAt,
        'kind': 'text',
        'content': content?.toString() ?? '',
        'raw': content,
      });
      continue;
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    if (role == 'user') {
      _processUserMessage(
        id: id,
        localId: localId,
        seq: seq,
        createdAt: createdAt,
        content: content,
        nestedContent: nestedContent,
        messages: messages,
      );
      continue;
    }

    if (role == 'agent') {
      if (nestedContent is! Map<String, dynamic>) {
        messages.add({
          'id': 'error-${id}_parse',
          'seq': seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'agent_content_not_map',
          'errorMessage':
              'Agent message content is not '
              'a valid structure',
          'debugData': {
            'messageId': id,
            'seq': seq,
            'contentType': '${nestedContent.runtimeType}',
          },
        });
        continue;
      }

      final contentType = nestedContent['type'] as String?;

      if (contentType == 'output') {
        _processOutputContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          sessionId: sessionId,
          messages: messages,
          toolResults: toolResults,
          usageUpdates: usageUpdates,
        );
      } else if (contentType == 'event') {
        _processEventContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
        );
      } else if (contentType == 'codex') {
        _processCodexContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
        );
      } else if (contentType == 'acp') {
        _processAcpContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
        );
      } else if (_looksLikeSessionEnvelope(nestedContent)) {
        _processSessionContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
        );
      } else if (contentType == 'session') {
        _processSessionContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
        );
      } else {
        final fallback = _extractAgentFallbackText(nestedContent);
        if (fallback != null && fallback.isNotEmpty) {
          messages.add({
            'id': id,
            'localId': localId,
            'seq': seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': fallback,
            'raw': content,
          });
        } else {
          messages.add({
            'id': 'error-${id}_parse',
            'seq': seq,
            'createdAt': createdAt,
            'role': 'system',
            'kind': 'error',
            'errorType': 'unknown_agent_content_type',
            'errorMessage': 'Unrecognized agent content type: $contentType',
            'debugData': {
              'messageId': id,
              'seq': seq,
              'contentType': contentType,
            },
          });
        }
      }
      continue;
    }

    if (role == 'session') {
      _processSessionContent(
        id: id,
        localId: localId,
        seq: seq,
        createdAt: createdAt,
        outerContent: content,
        nestedContent: nestedContent ?? content,
        messages: messages,
        toolResults: toolResults,
      );
      continue;
    }

    // Unknown role
    messages.add({
      'id': 'error-${id}_parse',
      'seq': seq,
      'createdAt': createdAt,
      'role': 'system',
      'kind': 'error',
      'errorType': 'unknown_role',
      'errorMessage': 'Unrecognized message role: $role',
      'debugData': {'messageId': id, 'seq': seq, 'role': role},
    });
  }

  return ProcessedMessages(
    messages: messages,
    toolResults: toolResults,
    usageUpdates: usageUpdates,
    maxSeq: maxSeq,
  );
}

bool _looksLikeSessionEnvelope(dynamic value) {
  if (value is! Map<String, dynamic>) return false;
  final hasEvent =
      value['ev'] is Map<String, dynamic> ||
      value['event'] is Map<String, dynamic>;
  final hasIdentity =
      value['id'] != null || value['uuid'] != null || value['time'] != null;
  return hasEvent && hasIdentity;
}

String? _extractAgentFallbackText(dynamic nestedContent) {
  if (nestedContent is! Map<String, dynamic>) return null;

  final directText = nestedContent['text'] ?? nestedContent['message'];
  if (directText is String && directText.isNotEmpty) {
    return directText;
  }

  final data = nestedContent['data'];
  if (data is Map<String, dynamic>) {
    final dataMessage = data['message'];
    if (dataMessage is String && dataMessage.isNotEmpty) {
      return dataMessage;
    }
    final dataText = data['text'];
    if (dataText is String && dataText.isNotEmpty) {
      return dataText;
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

int _parseCreatedAtMs(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

void _processUserMessage({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> content,
  required dynamic nestedContent,
  required List<Map<String, dynamic>> messages,
}) {
  if (nestedContent is Map<String, dynamic> &&
      nestedContent['type'] == 'text') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'user',
      'kind': 'text',
      'content': nestedContent['text']?.toString() ?? '',
      'raw': content,
    });
  } else {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'user',
      'kind': 'text',
      'content': content.toString(),
      'raw': content,
    });
  }
}

void _processOutputContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required String sessionId,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  required List<Map<String, dynamic>> usageUpdates,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) return;

  if (data['isMeta'] == true || data['isCompactSummary'] == true) return;

  final isSidechain = data['isSidechain'] == true;
  final dataUuid = data['uuid'] as String?;
  final dataParentUuid = data['parentUuid'] as String?;
  final dataType = data['type'] as String?;

  if (dataType == 'assistant') {
    if (dataUuid == null || dataUuid.isEmpty) return;

    final agentMsg = data['message'];
    if (agentMsg is! Map<String, dynamic>) return;

    final usageData = agentMsg['usage'] as Map<String, dynamic>?;
    if (usageData != null) {
      usageUpdates.add({
        'sessionId': sessionId,
        'usage': usageData,
        'timestamp': createdAt,
      });
    }

    final agentModel = agentMsg['model'] as String?;

    final agentContentList = agentMsg['content'];
    if (agentContentList is! List) return;

    var i = 0;
    for (final c in agentContentList) {
      if (c is! Map<String, dynamic>) {
        i++;
        continue;
      }
      final type = c['type'] as String?;

      if (type == 'text') {
        messages.add({
          'id': '${id}_t$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': c['text']?.toString() ?? '',
          'raw': outerContent,
          if (agentModel != null) 'model': agentModel,
          if (isSidechain) 'isSidechain': true,
          'uuid': dataUuid,
          if (dataParentUuid != null) 'parentUuid': dataParentUuid,
        });
      } else if (type == 'thinking') {
        messages.add({
          'id': '${id}_k$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'isThinking': true,
          'content': '*Thinking...*\n\n*${c['thinking']}*',
          'raw': outerContent,
          if (agentModel != null) 'model': agentModel,
          if (isSidechain) 'isSidechain': true,
          'uuid': dataUuid,
          if (dataParentUuid != null) 'parentUuid': dataParentUuid,
        });
      } else if (type == 'tool_use') {
        messages.add({
          'id': '${id}_u$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'tool-call',
          'name': c['name'],
          'input': c['input'],
          'toolUseId': c['id'],
          'state': 'running',
          'content': c,
          'raw': outerContent,
          if (agentModel != null) 'model': agentModel,
          if (isSidechain) 'isSidechain': true,
          'uuid': dataUuid,
          if (dataParentUuid != null) 'parentUuid': dataParentUuid,
        });
      }
      i++;
    }
    return;
  }

  if (dataType == 'user') {
    if (isSidechain) {
      final msgContent = data['message']?['content'];
      if (msgContent is String) {
        messages.add({
          'id': '${id}_sc',
          'seq': seq,
          'createdAt': createdAt,
          'kind': 'sidechain-root',
          'isSidechain': true,
          'prompt': msgContent,
          if (dataUuid != null) 'uuid': dataUuid,
          if (dataParentUuid != null) 'parentUuid': dataParentUuid,
        });
        return;
      }
    }

    final msgContent = data['message']?['content'];
    if (msgContent is List) {
      for (final c in msgContent) {
        if (c is Map<String, dynamic> && c['type'] == 'tool_result') {
          toolResults.add({
            'toolUseId': c['tool_use_id'],
            'result': c['content'],
            'isError': c['is_error'] == true,
            'createdAt': createdAt,
            'permissions': c['permissions'],
            if (isSidechain) 'isSidechain': true,
            if (dataUuid != null) 'uuid': dataUuid,
            if (dataParentUuid != null) 'parentUuid': dataParentUuid,
          });
        }
      }
    }
    return;
  }

  // Skip system, result, summary messages
}

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
  if (data['type'] == 'ready') return;

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

void _processCodexContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) return;

  final dataType = data['type'] as String?;

  if (dataType == 'message' || dataType == 'reasoning') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': data['message']?.toString() ?? '',
      'raw': outerContent,
    });
    return;
  }

  if (dataType == 'tool-call') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': data['name'],
      'input': data['input'],
      'toolUseId': data['callId'],
      'state': 'running',
      'content': data,
      'raw': outerContent,
    });
    return;
  }

  if (dataType == 'tool-call-result') {
    final result = data['output'] ?? data['content'];
    toolResults.add({
      'toolUseId': data['callId'],
      'result': result,
      'isError': data['isError'] == true || data['is_error'] == true,
      'createdAt': createdAt,
    });
  }
}

void _processAcpContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) return;

  final dataType = data['type'] as String?;

  if (dataType == 'message' || dataType == 'reasoning') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': data['message']?.toString() ?? '',
      'raw': outerContent,
    });
    return;
  }

  if (dataType == 'thinking') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'isThinking': true,
      'content': '*Thinking...*\n\n*${data['text']}*',
      'raw': outerContent,
    });
    return;
  }

  if (dataType == 'tool-call') {
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': data['name'],
      'input': data['input'],
      'toolUseId': data['callId'],
      'state': 'running',
      'content': data,
      'raw': outerContent,
    });
    return;
  }

  if (dataType == 'tool-result' || dataType == 'tool-call-result') {
    final result = data['output'] ?? data['content'];
    toolResults.add({
      'toolUseId': data['callId'],
      'result': result,
      'isError': data['isError'] == true || data['is_error'] == true,
      'createdAt': createdAt,
    });
    return;
  }

  if (dataType == 'file-edit') {
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
    });
  }

  // Skip task lifecycle events
}

void _processSessionContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required dynamic nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
}) {
  Map<String, dynamic>? envelope;
  if (nestedContent is Map<String, dynamic>) {
    if (nestedContent['type'] == 'session' &&
        nestedContent['data'] is Map<String, dynamic>) {
      envelope = nestedContent['data'] as Map<String, dynamic>;
    } else {
      envelope = nestedContent;
    }
  }
  if (envelope == null) return;

  final event = envelope['ev'] ?? envelope['event'];
  if (event is! Map<String, dynamic>) return;

  final eventType = (event['t'] ?? event['type']) as String?;
  if (eventType == null) return;

  final eventRole = envelope['role'] as String?;
  final envelopeId = (envelope['id'] ?? envelope['uuid']) as String? ?? id;
  final envelopeCreatedAt = _parseCreatedAtMs(
    envelope['time'] ?? envelope['createdAt'] ?? createdAt,
  );
  final parentUuid =
      (envelope['subagent'] ??
              envelope['parentUuid'] ??
              envelope['parent_uuid'])
          as String?;
  final isSidechain = parentUuid != null && parentUuid.isNotEmpty;
  final uuid = (envelope['id'] ?? envelope['uuid']) as String? ?? id;

  if (eventType == 'turn-start' ||
      eventType == 'start' ||
      eventType == 'stop') {
    return;
  }

  if (eventType == 'turn-end') {
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'agent-event',
      'event': {'type': 'ready'},
      'content': '',
      'raw': outerContent,
    });
    return;
  }

  if (eventType == 'service') {
    if (eventRole != 'agent') return;
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'text',
      'content': (event['text'] ?? event['message'])?.toString() ?? '',
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      if (parentUuid != null) 'parentUuid': parentUuid,
    });
    return;
  }

  if (eventType == 'text') {
    final text = (event['text'] ?? event['message'])?.toString() ?? '';
    if (eventRole == 'agent') {
      final thinking = event['thinking'] == true;
      messages.add({
        'id': envelopeId,
        'localId': localId,
        'seq': seq,
        'createdAt': envelopeCreatedAt,
        'role': 'agent',
        'kind': 'text',
        if (thinking) 'isThinking': true,
        'content': thinking ? '*Thinking...*\n\n*$text*' : text,
        'raw': outerContent,
        if (isSidechain) 'isSidechain': true,
        if (uuid.isNotEmpty) 'uuid': uuid,
        if (parentUuid != null) 'parentUuid': parentUuid,
      });
      return;
    }

    // Sidechain root prompt for nested task grouping.
    if (eventRole == 'user' && isSidechain && text.isNotEmpty) {
      messages.add({
        'id': '${envelopeId}_sc',
        'seq': seq,
        'createdAt': envelopeCreatedAt,
        'kind': 'sidechain-root',
        'isSidechain': true,
        'prompt': text,
        if (uuid.isNotEmpty) 'uuid': uuid,
        'parentUuid': parentUuid,
      });
    }
    return;
  }

  if (eventType == 'tool-call-start') {
    if (eventRole != 'agent') return;
    final args = event['args'] ?? event['input'];
    final input = args is Map<String, dynamic> ? args : <String, dynamic>{};
    final callId =
        (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': (event['name'] ?? event['tool'])?.toString() ?? 'unknown',
      'input': input,
      'toolUseId': callId ?? envelopeId,
      'state': 'running',
      'content': event,
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      if (parentUuid != null) 'parentUuid': parentUuid,
    });
    return;
  }

  if (eventType == 'tool-call-end') {
    final callId =
        (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
    if (callId == null || callId.isEmpty) return;
    toolResults.add({
      'toolUseId': callId,
      'result': event['result'] ?? event['output'] ?? event['content'],
      'isError': event['isError'] == true || event['is_error'] == true,
      'createdAt': envelopeCreatedAt,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      if (parentUuid != null) 'parentUuid': parentUuid,
    });
    return;
  }

  if (eventType == 'file') {
    if (eventRole != 'agent') return;
    final image = event['image'];
    final imageMeta = image is Map<String, dynamic>
        ? {
            'width': image['width'],
            'height': image['height'],
            'thumbhash': image['thumbhash'],
          }
        : null;
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': 'file',
      'input': {
        'ref': event['ref'],
        'name': event['name'],
        'size': event['size'],
        if (imageMeta != null) 'image': imageMeta,
      },
      'toolUseId': envelopeId,
      'state': 'completed',
      'content': event,
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      if (parentUuid != null) 'parentUuid': parentUuid,
    });
  }
}
