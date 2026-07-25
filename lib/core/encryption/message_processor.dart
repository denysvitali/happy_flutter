/// Pure-Dart message processing functions that can run inside an isolate.
///
/// These are top-level functions (not methods on a class) so they can be
/// passed to [Isolate.run].  They have **no** Flutter, FFI, or shared-state
/// dependencies — only plain Dart map/list manipulation.
library;

import '../utils/grok_acp_normalize.dart';
import '../utils/task_label.dart';
import '../utils/wire_parsers.dart';
import 'processors/data_type.dart';

// Content-type handlers extracted from the main file.
part 'processors/user_message_handler.dart';
part 'processors/output_content_handler.dart';
part 'processors/event_content_handler.dart';
part 'processors/agent_event_head.dart';
part 'processors/codex_content_handler.dart';
part 'processors/pi_content_handler.dart';
part 'processors/acp_content_handler.dart';
part 'processors/session_content_handler.dart';

/// Result of processing a batch of decrypted messages.
class ProcessedMessages {
  const ProcessedMessages({
    required this.messages,
    required this.toolResults,
    required this.usageUpdates,
    required this.maxSeq,
    this.droppedReasons = const [],
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

  /// Debug info for messages that were silently dropped during
  /// processing. Each entry: `{seq, reason}`.
  final List<String> droppedReasons;
}

typedef _UserContentBlock = Map<String, dynamic>;
typedef _UserContentBlocks = List<_UserContentBlock>;

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Extracts sidechain metadata from a data envelope.
///
/// Returns a record with `(isSidechain, uuid, parentUuid)` extracted from
/// the various naming conventions used across wire formats.
({bool isSidechain, String? uuid, String? parentUuid}) _sidechainMeta(
  Map<String, dynamic> data,
) {
  return (
    isSidechain: WireParsers.isRawSidechain(data),
    uuid: (data['uuid'] ?? data['id']) as String?,
    parentUuid: (data['subagent'] ??
        data['parentUuid'] ??
        data['parent_uuid']) as String?,
  );
}

/// Extract the spawning Agent/Task tool_use id from a data envelope.
///
/// The live-ingest reference impl is
/// `lib/core/services/_sync_messaging_parse.dart::_attachParentToolUseId`
/// (with the `task_started` branch in `_sync_messaging_parse_output.dart`
/// also falling back to `tool_use_id`).  The batch decrypt pipeline used
/// to drop this entirely, so sidechain messages from cold fetch/
/// pagination/cache-restore lost their authoritative parent identity
/// and the grouper had to fall back to fragile parentUuid chain walking.
String? _extractParentToolUseId(Map<String, dynamic> data) =>
    WireParsers.sidechainParentToolUseId(data);

/// Extract the SDK-assigned agent id used for async background agents.
///
/// Mirrors `_attachParentToolUseId` in `_sync_messaging_parse.dart`.
String? _extractAgentId(Map<String, dynamic> data) =>
    WireParsers.sidechainAgentId(data);

int _parseCreatedAtMs(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
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

bool _isToolResultEnvelope(Map<String, dynamic> data) {
  final dataType = data['type'] ?? data['dataType'];
  if (dataType == DataType.toolResult || dataType == DataType.toolCallResult) {
    return true;
  }

  return dataType == null &&
      _extractToolResultCallId(data) != null &&
      (data.containsKey('output') ||
          data.containsKey('result') ||
          data.containsKey('content') ||
          data.containsKey('isError') ||
          data.containsKey('is_error'));
}

String? _extractToolResultCallId(Map<String, dynamic> data) {
  final value =
      data['callId'] ?? data['toolCallId'] ?? data['tool_use_id'] ?? data['id'];
  return value is String && value.isNotEmpty ? value : null;
}

void _addToolResultEnvelope({
  required Map<String, dynamic> data,
  required int createdAt,
  required List<Map<String, dynamic>> toolResults,
  required ({bool isSidechain, String? uuid, String? parentUuid}) meta,
}) {
  final callId = _extractToolResultCallId(data);
  if (callId == null) return;

  final parentToolUseId = _extractParentToolUseId(data);
  final agentId = _extractAgentId(data);

  toolResults.add({
    'toolUseId': callId,
    'result': data['result'] ?? data['output'] ?? data['content'],
    'isError': data['isError'] == true || data['is_error'] == true,
    'createdAt': createdAt,
    'permissions': ?data['permissions'],
    if (meta.isSidechain) 'isSidechain': true,
    'uuid': meta.uuid ?? callId,
    'parentUuid': ?meta.parentUuid,
    'parentToolUseId': ?parentToolUseId,
    'agentId': ?agentId,
  });
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

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
  final droppedReasons = <String>[];
  var maxSeq = -1;

  for (var i = 0; i < wireMessages.length; i++) {
    final wire = wireMessages[i];
    final id = wire['id'] as String? ?? '';
    final seq = wire['seq'] as int? ?? 0;
    final localId = wire['localId'] as String?;
    final createdAt = _parseCreatedAtMs(wire['createdAt']);

    final decrypted = i < decryptedJsonList.length
        ? decryptedJsonList[i]
        : null;

    if (decrypted == null) {
      if (seq > maxSeq) maxSeq = seq;

      final encrypted = wasEncrypted != null && i < wasEncrypted.length
          ? wasEncrypted[i]
          : true;

      if (!encrypted) {
        droppedReasons.add(
          'null content, not encrypted',
        );
        continue;
      }

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
          droppedReasons: droppedReasons,
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
          droppedReasons: droppedReasons,
        );
      } else if (contentType == 'codex') {
        _processCodexContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          sessionId: sessionId,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
          usageUpdates: usageUpdates,
          droppedReasons: droppedReasons,
        );
      } else if (contentType == 'pi') {
        _processPiContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          sessionId: sessionId,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
          usageUpdates: usageUpdates,
          droppedReasons: droppedReasons,
        );
      } else if (contentType == 'acp' ||
          contentType == 'opencode' ||
          contentType == 'grok') {
        _processAcpContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
          droppedReasons: droppedReasons,
        );
      } else if (_looksLikeSessionEnvelope(nestedContent) ||
          contentType == 'session') {
        _processSessionContent(
          id: id,
          localId: localId,
          seq: seq,
          createdAt: createdAt,
          outerContent: content,
          nestedContent: nestedContent,
          messages: messages,
          toolResults: toolResults,
          droppedReasons: droppedReasons,
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
            'errorMessage':
                'Unrecognized agent content type: $contentType',
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
        droppedReasons: droppedReasons,
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
    droppedReasons: droppedReasons,
  );
}

/// Extract text from Claude API content blocks format.
///
/// Handles `[{type: 'text', text: '...'}, ...]` by concatenating all
/// text blocks.
String? _extractTextFromContentBlocks(_UserContentBlocks blocks) {
  final buffer = StringBuffer();
  for (final block in blocks) {
    if (block['type'] == 'text') {
      final text = block['text'];
      if (text is String && text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(text);
      }
    }
  }
  return buffer.isEmpty ? null : buffer.toString();
}

bool _containsImageContentBlock(Object? blocks) {
  if (blocks is! List<dynamic>) return false;

  return blocks.any(
    (block) => block is Map<String, dynamic> && block['type'] == 'image',
  );
}
