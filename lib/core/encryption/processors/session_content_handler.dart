part of '../message_processor.dart';

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
  final envelopeId =
      (envelope['id'] ?? envelope['uuid']) as String? ?? id;
  final envelopeCreatedAt = _parseCreatedAtMs(
    envelope['time'] ?? envelope['createdAt'] ?? createdAt,
  );
  final parentUuid = (envelope['subagent'] ??
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
      'parentUuid': ?parentUuid,
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
        'content':
            thinking ? '*Thinking...*\n\n*$text*' : text,
        'raw': outerContent,
        if (isSidechain) 'isSidechain': true,
        if (uuid.isNotEmpty) 'uuid': uuid,
        'parentUuid': ?parentUuid,
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
    final input =
        args is Map<String, dynamic> ? args : <String, dynamic>{};
    final callId =
        (event['call'] ?? event['callId'] ?? event['toolUseId'])
            as String?;
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
      'parentUuid': ?parentUuid,
    });
    return;
  }

  if (eventType == 'tool-call-end') {
    final callId =
        (event['call'] ?? event['callId'] ?? event['toolUseId'])
            as String?;
    if (callId == null || callId.isEmpty) return;
    toolResults.add({
      'toolUseId': callId,
      'result':
          event['result'] ?? event['output'] ?? event['content'],
      'isError':
          event['isError'] == true || event['is_error'] == true,
      'createdAt': envelopeCreatedAt,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
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
        'image': ?imageMeta,
      },
      'toolUseId': envelopeId,
      'state': 'completed',
      'content': event,
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
    });
  }
}
