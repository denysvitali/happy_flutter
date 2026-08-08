import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/session.dart';
import '../../core/services/logger_service.dart' show LogEntry, logger;
import '../../core/services/sync_service.dart' show SyncDomain, sync;

const sessionDebugExportClipboardMaxBytes = 512 * 1024;

/// Privacy-sensitive sections must be opted into by a caller that has already
/// explained their contents to the user. The session-info clipboard action
/// intentionally uses the metadata-only default.
class SessionDebugExportOptions {
  const SessionDebugExportOptions({
    this.includeTranscript = false,
    this.includeLogs = false,
  });

  final bool includeTranscript;
  final bool includeLogs;
}

String buildSessionDebugExportText(
  Session session, {
  SessionDebugExportOptions options = const SessionDebugExportOptions(),
}) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(_buildSessionDebugExport(session, options));
}

Map<String, dynamic> _buildSessionDebugExport(
  Session session,
  SessionDebugExportOptions options,
) {
  final sessionId = session.id;
  final messages = sync.messagesForSession(sessionId);

  return {
    'schemaVersion': 2,
    'source': 'happy_flutter.session_info',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'privacy': {
      'metadataOnly': !options.includeTranscript && !options.includeLogs,
      'transcriptIncluded': options.includeTranscript,
      'logsIncluded': options.includeLogs,
      'sensitiveSessionFields': 'presence-only',
    },
    'sessionFingerprint': _identifierFingerprint(sessionId),
    'session': _redactedSessionMetadata(session),
    'sync': {
      'isInitialized': sync.isInitialized,
      'isReady': sync.isReady,
      'connectionStatus': sync.connectionStatus.name,
      'dataChangeCounter': sync.dataChangeCounter,
      'sessionsDomainChangeCounter': sync.domainChangeCounter(
        SyncDomain.sessions,
      ),
      'messagesDomainChangeCounter': sync.domainChangeCounter(
        SyncDomain.messages,
      ),
      'messagesRevision': sync.messagesRevision(sessionId),
      'hasMessageCursor': sync.sessionMessageCursors[sessionId] != null,
      'serverLastSeq': session.lastSeq,
      'hasOlderMessages': sync.hasOlderMessages(sessionId),
      'isLoadingOlderMessages': sync.isLoadingOlderMessages(sessionId),
      'unreadCount': sync.getUnreadCount(sessionId),
      'messageSyncRegistered': sync.messagesSync.containsKey(sessionId),
      'sessionUsage': _jsonSafe(sync.sessionUsage[sessionId]),
    },
    'messageSummary': _messageSummary(messages),
    if (options.includeTranscript) ...{
      'messageSignatures': _messageSignatures(messages),
      'messages': _jsonSafe(messages),
    },
    if (options.includeLogs) 'logs': _buildLogExport(session),
  };
}

Map<String, dynamic> _redactedSessionMetadata(Session session) {
  final metadata = session.metadata;
  final agentState = session.agentState;
  return {
    'fingerprint': _identifierFingerprint(session.id),
    'seq': session.seq,
    'createdAt': session.createdAt,
    'updatedAt': session.updatedAt,
    'active': session.active,
    'activeAt': session.activeAt,
    'metadataVersion': session.metadataVersion,
    'agentStateVersion': session.agentStateVersion,
    'thinking': session.thinking,
    'thinkingAt': session.thinkingAt,
    'archived': session.archived,
    'presence': session.presence,
    'permissionMode': session.permissionMode,
    'modelMode': session.modelMode,
    'lifecycleStateCleartext': session.lifecycleStateCleartext,
    'lastSeq': session.lastSeq,
    'lastMessageAt': session.lastMessageAt,
    'pinned': session.pinned,
    'hasFolder': _isPresent(session.folder),
    'todoCount': session.todos?.length ?? 0,
    'hasDraft': _isPresent(session.draft),
    'metadata': metadata == null
        ? null
        : {
            'hasPath': _isPresent(metadata.path),
            'hasHost': _isPresent(metadata.host),
            'version': metadata.version,
            'hasName': _isPresent(metadata.name),
            'os': metadata.os,
            'hasSummary': _isPresent(metadata.summary?.text),
            'hasMachineId': _isPresent(metadata.machineId),
            'hasClaudeSessionId': _isPresent(metadata.claudeSessionId),
            'toolCount': metadata.tools?.length ?? 0,
            'slashCommandCount': metadata.slashCommands?.length ?? 0,
            'hasHomeDir': _isPresent(metadata.homeDir),
            'hasHappyHomeDir': _isPresent(metadata.happyHomeDir),
            'hasHostPid': metadata.hostPid != null,
            'flavor': metadata.flavor,
            'lifecycleState': metadata.lifecycleState,
            'hasLifecycleStateError': _isPresent(metadata.lifecycleStateError),
            'lifecycleStateSince': metadata.lifecycleStateSince,
            'hasRepoUrl': _isPresent(metadata.repoUrl),
            'hasRepoRef': _isPresent(metadata.repoRef),
            'hasRepoCommit': _isPresent(metadata.repoCommit),
            'sandboxRequested': metadata.sandboxRequested,
            'sandboxRequired': metadata.sandboxRequired,
            'sandboxEnforced': metadata.sandboxEnforced,
            'sandboxBackend': metadata.sandboxBackend,
            'hasSandboxReason': _isPresent(metadata.sandboxReason),
            'legacySandboxRequested': metadata.sandboxEnabled,
          },
    'agentState': agentState == null
        ? null
        : {
            'controlledByUser': agentState.controlledByUser,
            'pendingRequestCount': agentState.requests?.length ?? 0,
            'completedRequestCount': agentState.completedRequests?.length ?? 0,
            'hasGoal': agentState.goal?.isVisible ?? false,
          },
  };
}

bool _isPresent(String? value) => value?.trim().isNotEmpty ?? false;

String _identifierFingerprint(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 16);

Map<String, dynamic> _buildLogExport(Session session) {
  final logs = logger.getLogs();
  final matchingLogs = _takeLastLogs(
    logs.where((entry) => _logMatchesSession(entry, session)),
    300,
  );
  final recentLogs = logger.getRecentLogs(150);
  return {
    'bufferedCount': logger.count,
    'matchingCount': matchingLogs.length,
    'recentCount': recentLogs.length,
    'matchingEntries': matchingLogs.map(_logEntryToJson).toList(),
    'recentEntries': recentLogs.map(_logEntryToJson).toList(),
  };
}

Map<String, dynamic> _messageSummary(List<Map<String, dynamic>> messages) {
  final byKind = <String, int>{};
  final byRole = <String, int>{};
  final byToolName = <String, int>{};
  final byState = <String, int>{};
  var sidechainCount = 0;
  int? minSeq;
  int? maxSeq;

  for (final message in messages) {
    _increment(byKind, _stringValue(message['kind']));
    _increment(byRole, _stringValue(message['role']));
    _increment(byState, _stringValue(message['state']));
    final toolName = _toolName(message);
    if (toolName != null) {
      _increment(byToolName, toolName);
    }
    if (message['isSidechain'] == true) {
      sidechainCount++;
    }
    final seq = _intValue(message['seq']);
    if (seq != null) {
      minSeq = minSeq == null || seq < minSeq ? seq : minSeq;
      maxSeq = maxSeq == null || seq > maxSeq ? seq : maxSeq;
    }
  }

  return {
    'count': messages.length,
    'sidechainCount': sidechainCount,
    'seqMin': minSeq,
    'seqMax': maxSeq,
    'byKind': byKind,
    'byRole': byRole,
    'byToolName': byToolName,
    'byState': byState,
  };
}

List<Map<String, dynamic>> _messageSignatures(
  List<Map<String, dynamic>> messages,
) {
  final start = messages.length > 80 ? messages.length - 80 : 0;
  return [
    for (var index = start; index < messages.length; index++)
      _messageSignature(index, messages[index]),
  ];
}

Map<String, dynamic> _messageSignature(
  int index,
  Map<String, dynamic> message,
) {
  final children = message['children'];
  final childMessages = message['messages'];
  final result = message['result'];
  return {
    'index': index,
    'id': message['id'],
    'localId': message['localId'],
    'seq': message['seq'],
    'createdAt': message['createdAt'],
    'role': message['role'],
    'kind': message['kind'],
    'type': message['type'],
    'name': _toolName(message),
    'state': message['state'],
    'isSidechain': message['isSidechain'],
    'toolUseId': message['toolUseId'],
    'parentToolUseId': message['parentToolUseId'],
    'contentPreview': _preview(message['content']),
    'childrenCount': children is List ? children.length : null,
    'messagesCount': childMessages is List ? childMessages.length : null,
    'resultKeys': result is Map
        ? result.keys.map((key) => '$key').toList()
        : null,
  };
}

bool _logMatchesSession(LogEntry entry, Session session) {
  final metadata = session.metadata;
  final tokens = [
    session.id,
    if (metadata?.claudeSessionId != null) metadata!.claudeSessionId!,
    if (metadata?.machineId != null) metadata!.machineId!,
  ];
  return tokens.where((token) => token.length >= 4).any(entry.message.contains);
}

List<LogEntry> _takeLastLogs(Iterable<LogEntry> logs, int max) {
  final entries = logs.toList(growable: false);
  if (entries.length <= max) return entries;
  return entries.skip(entries.length - max).toList(growable: false);
}

Map<String, dynamic> _logEntryToJson(LogEntry entry) {
  return {
    'timestamp': entry.timestamp.toUtc().toIso8601String(),
    'level': entry.level.name,
    'message': entry.message,
    'error': entry.error?.toString(),
    'stackTrace': entry.stackTrace?.toString(),
  };
}

void _increment(Map<String, int> counts, String key) {
  counts[key] = (counts[key] ?? 0) + 1;
}

String _stringValue(Object? value) => value?.toString() ?? 'null';

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String? _toolName(Map<String, dynamic> message) {
  final direct = message['name'];
  if (direct != null) return direct.toString();
  final tool = message['tool'];
  if (tool is Map) {
    final nested = tool['name'];
    if (nested != null) return nested.toString();
  }
  return null;
}

String? _preview(Object? value) {
  if (value == null) return null;
  var preview = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (preview.isEmpty) return null;
  if (preview.length > 160) {
    preview = '${preview.substring(0, 160)}...';
  }
  return preview;
}

dynamic _jsonSafe(Object? value, [int depth = 0]) {
  if (depth > 20) return value.toString();
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _jsonSafe(entry.value, depth + 1),
    };
  }
  if (value is Iterable) {
    return [for (final item in value) _jsonSafe(item, depth + 1)];
  }
  return value.toString();
}
