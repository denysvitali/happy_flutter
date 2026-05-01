part of '../message_processor.dart';

void _processAcpContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'acp data is '
      '${data?.runtimeType ?? 'null'}, expected Map',
    );
    return;
  }

  final dataType = data['type'] as String?;
  final meta = _sidechainMeta(data);

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
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
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
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
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
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
    return;
  }

  if (dataType == 'tool-result' ||
      dataType == 'tool-call-result' ||
      data['dataType'] == 'tool-result' ||
      data['dataType'] == 'tool-call-result') {
    final result = data['output'] ?? data['content'];
    toolResults.add({
      'toolUseId': data['callId'],
      'result': result,
      'isError': data['isError'] == true || data['is_error'] == true,
      'createdAt': createdAt,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
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
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
  }

  // Skip task lifecycle events

  // Catch-all for any unrecognized ACP dataType values.
  // Log ALL unrecognized types including null so we can audit what was
  // actually dropped vs. legitimately filtered.  dataType is a known
  // set so this won't spam GlitchTip.
  droppedReasons?.add(
    dataType != null
        ? 'unknown acp dataType: $dataType'
        : 'acp data missing dataType (keys=${data.keys.toList()})',
  );
}
