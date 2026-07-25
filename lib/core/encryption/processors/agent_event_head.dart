part of '../message_processor.dart';

/// The parsed head of a Codex/pi-shaped agent event.
///
/// Returned by [_processAgentEventHead]. [emitted] is true when the head
/// already appended a message and the caller must stop.
typedef _AgentEventHead = ({
  Map<String, dynamic> data,
  String? dataType,
  ({bool isSidechain, String? uuid, String? parentUuid}) meta,
  String? parentToolUseId,
  String? agentId,
  bool emitted,
});

/// Parses the part of a Codex/pi envelope that is identical between the two
/// vendors, and handles the text-message branch.
///
/// pi's event format is structurally identical to Codex's — same `data`
/// envelope, same `usage` placement, same `message` / `reasoning` /
/// `model-output` types — so both handlers opened with the same 40 lines.
/// That shared rule lives here; everything the two vendors genuinely disagree
/// about (Codex `thinking` and Responses-style `arguments`, pi's
/// anthropic-messages `assistant` blocks) stays in the per-vendor handler.
///
/// [vendor] appears only in the dropped-reason strings, which are grouped in
/// telemetry, so it must stay exactly `'codex'` or `'pi'`.
///
/// Returns null when `nestedContent['data']` is not a map; the drop reason has
/// already been recorded in that case.
_AgentEventHead? _processAgentEventHead({
  required String vendor,
  required String id,
  required String? localId,
  required int seq,
  required int createdAt,
  required String sessionId,
  required Map<String, dynamic> outerContent,
  required Map<String, dynamic> nestedContent,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> usageUpdates,
  List<String>? droppedReasons,
}) {
  final data = nestedContent['data'];
  if (data is! Map<String, dynamic>) {
    droppedReasons?.add(
      '$vendor data is '
      '${data?.runtimeType ?? 'null'}, expected Map',
    );
    return null;
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
  final parentToolUseId = _extractParentToolUseId(data);
  final agentId = _extractAgentId(data);

  var emitted = false;
  if (dataType == DataType.message ||
      dataType == DataType.reasoning ||
      dataType == DataType.modelOutput) {
    // Handles both old (message) and new (model-output) happy-cli-go formats.
    final content = data['fullText'] ?? data['message'];
    messages.add({
      'id': id,
      'localId': localId,
      'seq': seq,
      'createdAt': createdAt,
      'role': 'agent',
      'kind': 'text',
      'content': content?.toString() ?? '',
      if (dataType == DataType.message) 'isPromptEchoCandidate': true,
      'raw': outerContent,
      if (meta.isSidechain) 'isSidechain': true,
      'uuid': ?meta.uuid,
      'parentUuid': ?meta.parentUuid,
      'parentToolUseId': ?parentToolUseId,
      'agentId': ?agentId,
    });
    emitted = true;
  }

  return (
    data: data,
    dataType: dataType,
    meta: meta,
    parentToolUseId: parentToolUseId,
    agentId: agentId,
    emitted: emitted,
  );
}
