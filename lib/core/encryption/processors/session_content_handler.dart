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
  List<String>? droppedReasons,
}) {
  Map<String, dynamic>? envelope;
  final nestedMap = WireParsers.asMap(nestedContent);
  if (nestedMap != null) {
    final nestedData = WireParsers.asMap(nestedMap['data']);
    if (nestedMap['type'] == 'session' && nestedData != null) {
      envelope = nestedData;
    } else {
      envelope = nestedMap;
    }
  }
  if (envelope == null) return;

  final event = envelope['ev'] ?? envelope['event'];
  final eventMap = WireParsers.asMap(event);
  if (eventMap == null) return;

  final eventType = (eventMap['t'] ?? eventMap['type']) as String?;
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
    droppedReasons?.add('session eventType $eventType');
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
    if (eventRole != 'agent') {
      droppedReasons?.add('session eventType role not agent');
      return;
    }
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'text',
      'content':
          (eventMap['text'] ?? eventMap['message'])?.toString() ?? '',
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
    });
    return;
  }

  if (eventType == 'text') {
    final text =
        (eventMap['text'] ?? eventMap['message'])?.toString() ?? '';
    if (eventRole == 'agent') {
      final thinking = eventMap['thinking'] == true;
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
    if (eventRole != 'agent') {
      droppedReasons?.add('session eventType role not agent');
      return;
    }
    final args = eventMap['args'] ?? eventMap['input'];
    final input = WireParsers.asMap(args) ?? <String, dynamic>{};
    final callId =
        (eventMap['call'] ??
                eventMap['callId'] ??
                eventMap['toolUseId'])
            as String?;
    messages.add({
      'id': envelopeId,
      'localId': localId,
      'seq': seq,
      'createdAt': envelopeCreatedAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name':
          (eventMap['name'] ?? eventMap['tool'])?.toString() ?? 'unknown',
      'input': input,
      'toolUseId': callId ?? envelopeId,
      'state': 'running',
      'content': eventMap,
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
    });
    return;
  }

  if (eventType == 'tool-call-end') {
    final callId =
        (eventMap['call'] ??
                eventMap['callId'] ??
                eventMap['toolUseId'])
            as String?;
    if (callId == null || callId.isEmpty) return;
    toolResults.add({
      'toolUseId': callId,
      'result':
          eventMap['result'] ??
          eventMap['output'] ??
          eventMap['content'],
      'isError':
          eventMap['isError'] == true || eventMap['is_error'] == true,
      'createdAt': envelopeCreatedAt,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
    });
    return;
  }

  if (eventType == 'file') {
    if (eventRole != 'agent') return;
    final image = WireParsers.asMap(eventMap['image']);
    final imageMeta = image != null
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
        'ref': eventMap['ref'],
        'name': eventMap['name'],
        'size': eventMap['size'],
        'image': ?imageMeta,
      },
      'toolUseId': envelopeId,
      'state': 'completed',
      'content': eventMap,
      'raw': outerContent,
      if (isSidechain) 'isSidechain': true,
      if (uuid.isNotEmpty) 'uuid': uuid,
      'parentUuid': ?parentUuid,
    });
    return;
  }

  // Catch-all for unrecognized session eventType values.
  // eventType is low-cardinality (known set), so this won't spam GlitchTip.
  droppedReasons?.add('unknown session eventType: $eventType');
}
