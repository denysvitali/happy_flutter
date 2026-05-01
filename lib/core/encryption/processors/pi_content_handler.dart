part of '../message_processor.dart';

/// Process pi agent content (content.type == 'pi').
///
/// pi's event format is structurally identical to Codex's: data types are
/// `message`, `model-output`, `tool-call`, `tool-result`, etc. This handler
/// mirrors _processCodexContent.
void _processPiContent({
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
      'pi data is '
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

  if (dataType == 'message' ||
      dataType == 'reasoning' ||
      dataType == 'model-output') {
    final content = data['fullText'] ?? data['message'];
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': content?.toString() ?? '',
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
    });
    return;
  }

  if (dataType == 'tool-call') {
    final toolName = data['toolName'] ?? data['name'] ?? 'unknown';
    final toolInput = data['args'] ?? data['input'] ?? <String, dynamic>{};
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'tool-call',
      'name': toolName,
      'input': toolInput,
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
    final result = data['result'] ?? data['output'] ?? data['content'];
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

  // Unrecognized pi dataType
  droppedReasons?.add(
    'pi dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}
