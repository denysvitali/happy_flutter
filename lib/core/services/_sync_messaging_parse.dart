part of 'sync_service.dart';

extension SyncMessagingParse on Sync {
  /// Process a decrypted message into display messages and tool results.
  /// Test helper for [_processDecryptedMessage].
  @visibleForTesting
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  testProcessDecryptedMessage({
    required String id,
    required int seq,
    required String sessionId,
    required Map<String, dynamic> content,
    String? localId,
    int? createdAtMs,
  }) {
    return _processDecryptedMessage(
      DecryptedMessage(
        id: id,
        seq: seq,
        localId: localId,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      sessionId,
    );
  }

  ///
  /// Returns a tuple of (displayMessages, toolResults).
  /// Display messages are added to the session message list.
  /// Tool results are used to update existing tool-call message states.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processDecryptedMessage(DecryptedMessage message, String sessionId) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;

    if (content is! Map<String, dynamic>) {
      // Fallback for non-map content
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'kind': 'text',
            'content': content?.toString() ?? '',
            'raw': content,
          },
        ],
        [],
      );
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    // User messages: {role: 'user', content: {type: 'text', text: '...'}}
    if (role == MessageRole.user) {
      if (nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text') {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': nestedContent['text']?.toString() ?? '',
              'raw': content,
            },
          ],
          [],
        );
      }
      // Fallback for non-text user messages
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': content.toString(),
            'raw': content,
          },
        ],
        [],
      );
    }

    // Agent messages: {role: 'agent', content: {type: ..., data: ...}}
    if (role == MessageRole.agent) {
      if (nestedContent is! Map<String, dynamic>) {
        return (
          [
            {
              'id': 'error-${message.id}_parse',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'system',
              'kind': 'error',
              'errorType': 'agent_content_not_map',
              'errorMessage':
                  'Agent message content is not '
                  'a valid structure',
              'debugData': {
                'messageId': message.id,
                'seq': message.seq,
                'contentType': '${nestedContent.runtimeType}',
              },
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      final contentType = nestedContent['type'] as String?;

      // Output type: Claude/assistant messages
      if (contentType == 'output') {
        return _attachParentToolUseId(
          _processOutputContent(
            message,
            nestedContent,
            createdAt,
            content,
            sessionId,
          ),
          nestedContent,
        );
      }

      // Event type: mode switches, limit reached, etc.
      if (contentType == 'event') {
        // When the agent sends session-cleared (after a /clear restart),
        // immediately drop the session's ephemeral presence to offline so
        // that waitForAgentReady blocks until the new Claude process sends
        // its first keep-alive. Without this, a follow-up message is posted
        // while the old Claude is dead and the new one hasn't connected yet.
        final evData = nestedContent['data'];
        if (evData is Map<String, dynamic>) {
          final evType = (evData['t'] ?? evData['type']) as String?;
          if (evType == 'session-cleared') {
            _presenceTimers[sessionId]?.cancel();
            _presenceTimers.remove(sessionId);
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged({SyncDomain.sessions});
            }
          }
        }
        return _processEventContent(message, nestedContent, createdAt, content);
      }

      // Codex type: Codex agent messages
      if (contentType == 'codex') {
        return _attachParentToolUseId(
          _processCodexContent(
            message,
            nestedContent,
            createdAt,
            content,
            sessionId,
          ),
          nestedContent,
        );
      }

      // ACP type: unified agent communication protocol
      if (contentType == 'acp') {
        return _attachParentToolUseId(
          _processAcpContent(
            message, nestedContent, createdAt, content, sessionId,
          ),
          nestedContent,
        );
      }

      // OpenCode uses the same ACP wire format
      if (contentType == 'opencode') {
        return _attachParentToolUseId(
          _processAcpContent(
            message, nestedContent, createdAt, content, sessionId,
          ),
          nestedContent,
        );
      }

      final fallback = _extractAgentFallbackText(nestedContent);
      if (fallback != null && fallback.isNotEmpty) {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'agent',
              'kind': 'text',
              'content': fallback,
              'raw': content,
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      return (
        [
          {
            'id': 'error-${message.id}_parse',
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'system',
            'kind': 'error',
            'errorType': 'unknown_agent_content_type',
            'errorMessage': 'Unrecognized agent content type: $contentType',
            'debugData': {
              'messageId': message.id,
              'seq': message.seq,
              'contentType': contentType,
            },
          },
        ],
        <Map<String, dynamic>>[],
      );
    }

    // Session protocol envelope role.
    if (role == MessageRole.session) {
      return _processSessionContent(
        message,
        nestedContent ?? content,
        createdAt,
        content,
      );
    }

    return (
      [
        {
          'id': 'error-${message.id}_parse',
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'unknown_role',
          'errorMessage': 'Unrecognized message role: $role',
          'debugData': {
            'messageId': message.id,
            'seq': message.seq,
            'role': role,
          },
        },
      ],
      <Map<String, dynamic>>[],
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

  /// Attach `parentToolUseId` to every sidechain entry returned from
  /// the underlying parser. The Claude CLI stamps `parent_tool_use_id`
  /// on every message inside a subagent run; that id matches the
  /// parent Agent/Task tool_use directly, so SidechainGrouper can
  /// resolve children with no parentUuid chain walking. We thread it
  /// through here uniformly so all per-provider parsers (Claude
  /// output, codex, acp/opencode) get the metadata without each
  /// emission site having to copy a field around.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _attachParentToolUseId(
    (List<Map<String, dynamic>>, List<Map<String, dynamic>>) result,
    Map<String, dynamic> nestedContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return result;
    final parentToolUseId =
        (data['parent_tool_use_id'] ??
                data['parentToolUseId'] ??
                data['parent_toolUseId'])
            as String?;
    if (parentToolUseId == null || parentToolUseId.isEmpty) {
      return result;
    }
    for (final m in result.$1) {
      if (m['isSidechain'] == true && m['parentToolUseId'] == null) {
        m['parentToolUseId'] = parentToolUseId;
      }
    }
    for (final m in result.$2) {
      if (m['isSidechain'] == true && m['parentToolUseId'] == null) {
        m['parentToolUseId'] = parentToolUseId;
      }
    }
    return result;
  }
}
