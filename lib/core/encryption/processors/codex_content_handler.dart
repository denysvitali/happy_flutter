part of '../message_processor.dart';

void _processCodexContent({
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required String sessionId,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> toolResults,
  required List<Map<String, dynamic>> usageUpdates,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'codex data is '
      '${data?.runtimeType ?? 'null'}, expected Map',
    );
    return;
  }

  final usageData =
      _extractUsageMap(data['usage']) ??
      _extractUsageMap(
        data['message'] is Map ? (data['message'] as Map)['usage'] : null,
      );
  if (usageData != null) {
    usageUpdates.add({
      'sessionId': sessionId,
      'usage': usageData,
      'timestamp': createdAt,
    });
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

  // Unrecognized codex dataType
  droppedReasons?.add(
    'codex dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}

Map<String, dynamic>? _extractUsageMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
