part of '../message_processor.dart';

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
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      'seq=$seq id=$id: output data is ${data?.runtimeType ?? 'null'}, '
      'expected Map',
    );
    return;
  }

  if (data['isMeta'] == true || data['isCompactSummary'] == true) {
    // Expected server behaviour: compact summaries and meta messages are
    // intentionally filtered. Do not add to droppedReasons — these are not
    // errors and would spam GlitchTip with unique per-message entries.
    return;
  }

  final meta = _sidechainMeta(data);
  final dataType = data['type'] as String?;

  if (dataType == 'assistant') {
    final effectiveUuid = (meta.uuid != null && meta.uuid!.isNotEmpty)
        ? meta.uuid!
        : id;

    final agentMsg = data['message'];
    if (agentMsg is! Map<String, dynamic>) {
      if (agentMsg is String && agentMsg.isNotEmpty) {
        messages.add({
          'id': id,
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': agentMsg,
          'raw': outerContent,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else {
        droppedReasons?.add(
          'seq=$seq id=$id: assistant message field is '
          '${agentMsg?.runtimeType ?? 'null'}, expected Map or '
          'non-empty String',
        );
      }
      return;
    }

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
    if (agentContentList is! List) {
      if (agentContentList is String && agentContentList.isNotEmpty) {
        messages.add({
          'id': id,
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'text',
          'content': agentContentList,
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else {
        droppedReasons?.add(
          'seq=$seq id=$id: assistant content is '
          '${agentContentList?.runtimeType ?? 'null'}, '
          'expected List or non-empty String',
        );
      }
      return;
    }

    if (agentContentList.isEmpty) {
      droppedReasons?.add(
        'seq=$seq id=$id: assistant content list is empty',
      );
      return;
    }

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
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
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
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': effectiveUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (type == 'tool_use' ||
          type == 'server_tool_use' ||
          type == 'mcp_tool_use' ||
          type == 'code_execution_tool_use') {
        final toolUseUuid =
            (c['id'] as String?)?.isNotEmpty ?? false
                ? c['id'] as String
                : effectiveUuid;
        messages.add({
          'id': '${id}_u$i',
          'localId': localId,
          'seq': seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'tool-call',
          'name': c['name'] ?? c['server_name'] ?? type,
          'input': c['input'],
          'toolUseId': c['id'],
          'state': 'running',
          'content': c,
          'raw': outerContent,
          'model': ?agentModel,
          if (meta.isSidechain) 'isSidechain': true,
          'uuid': toolUseUuid,
          'parentUuid': ?meta.parentUuid,
        });
      } else if (type == 'web_search_tool_result' ||
          type == 'server_tool_result' ||
          type == 'mcp_tool_result' ||
          type == 'code_execution_tool_result') {
        final toolUseId = c['tool_use_id'] as String?;
        if (toolUseId != null && toolUseId.isNotEmpty) {
          toolResults.add({
            'toolUseId': toolUseId,
            'result': c['content'],
            'isError': c['is_error'] == true,
            'createdAt': createdAt,
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': effectiveUuid,
            'parentUuid': ?meta.parentUuid,
          });
        }
      } else if (type != null) {
        droppedReasons?.add(
          'seq=$seq id=$id: unrecognized content block type=$type '
          'at index $i',
        );
      }
      i++;
    }
    return;
  }

  if (dataType == 'user') {
    if (meta.isSidechain) {
      final msgContent = data['message']?['content'];
      final promptText = msgContent is String
          ? msgContent
          : (msgContent is List
              ? _extractTextFromContentBlocks(msgContent)
              : null);
      if (promptText != null && promptText.isNotEmpty) {
        messages.add({
          'id': '${id}_sc',
          'seq': seq,
          'createdAt': createdAt,
          'kind': 'sidechain-root',
          'isSidechain': true,
          'prompt': promptText,
          'uuid': ?meta.uuid,
          'parentUuid': ?meta.parentUuid,
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
            if (meta.isSidechain) 'isSidechain': true,
            'uuid': ?meta.uuid,
            'parentUuid': ?meta.parentUuid,
          });
        }
      }
    }
    return;
  }

  // Unrecognized dataType -- log to help diagnose silent drops.
  // Omit seq/id from the reason so GlitchTip groups by dataType, not per-message.
  droppedReasons?.add(
    'output dataType=$dataType not handled '
    '(keys=${data.keys.toList()})',
  );
}
