import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// Tests for message processing in sync service.
///
/// Verifies that decrypted messages are correctly mapped to
/// display messages for the chat UI.
void main() {
  late Sync instance;

  setUp(() {
    instance = Sync();
    // Set up required InvalidateSync instances
    instance.sessionsSync = InvalidateSync(() async {});
    instance.settingsSync = InvalidateSync(() async {});
    instance.profileSync = InvalidateSync(() async {});
    instance.purchasesSync = InvalidateSync(() async {});
    instance.machinesSync = InvalidateSync(() async {});
    instance.pushTokenSync = InvalidateSync(() async {});
    instance.nativeUpdateSync = InvalidateSync(() async {});
    instance.artifactsSync = InvalidateSync(() async {});
    instance.messagesSync.clear();
  });

  group('processDecryptedMessage', () {
    test('maps user text message', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_1',
        seq: 1,
        sessionId: 'session_1',
        content: {
          'role': 'user',
          'content': {'type': 'text', 'text': 'Hello world'},
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'user');
      expect(result.$1.first['content'], 'Hello world');
    });

    test('maps agent output with text content', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_2',
        seq: 2,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'abc-123',
              'message': {
                'role': 'assistant',
                'model': 'claude-opus-4-6',
                'content': [
                  {'type': 'text', 'text': 'Hello! How can I help?'},
                ],
              },
            },
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'agent');
      expect(result.$1.first['content'], 'Hello! How can I help?');
      // Per-message inference model from Claude Code must be surfaced so
      // the chat UI shows the real model instead of session metadata.
      expect(result.$1.first['model'], 'claude-opus-4-6');
    });

    test('maps agent output with tool_use content', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_3',
        seq: 3,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'abc-456',
              'message': {
                'role': 'assistant',
                'model': 'claude-opus-4-6',
                'content': [
                  {'type': 'text', 'text': 'Let me read that file.'},
                  {
                    'type': 'tool_use',
                    'id': 'tu_1',
                    'name': 'Read',
                    'input': {'file_path': '/tmp/test.txt'},
                  },
                ],
              },
            },
          },
        },
      );

      expect(result.$1, hasLength(2));
      expect(result.$1[0]['kind'], 'text');
      expect(result.$1[0]['model'], 'claude-opus-4-6');
      expect(result.$1[1]['kind'], 'tool-call');
      expect(result.$1[1]['name'], 'Read');
      expect(result.$1[1]['state'], 'running');
      expect(result.$1[1]['toolUseId'], 'tu_1');
      expect(result.$1[1]['model'], 'claude-opus-4-6');
    });

    test('omits model on assistant output when absent from payload', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_no_model',
        seq: 99,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'abc-no-model',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'No model field here.'},
                ],
              },
            },
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first.containsKey('model'), isFalse);
    });

    test('maps agent output tool_result to tool results', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_4',
        seq: 4,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'user',
              'message': {
                'role': 'user',
                'content': [
                  {
                    'type': 'tool_result',
                    'tool_use_id': 'tu_1',
                    'content': 'file contents here',
                  },
                ],
              },
            },
          },
        },
      );

      // No display messages, but should have tool results
      expect(result.$1, isEmpty);
      expect(result.$2, hasLength(1));
      expect(result.$2.first['toolUseId'], 'tu_1');
      expect(result.$2.first['result'], 'file contents here');
    });

    test('maps event content to agent-event', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_5',
        seq: 5,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'event',
            'data': {'type': 'switch', 'mode': 'remote'},
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'agent-event');
      expect(result.$1.first['event']['type'], 'switch');
      expect(result.$1.first['event']['mode'], 'remote');
    });

    test('renders system init as sub-agent catalog event', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_init_1',
        seq: 6,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'isMeta': true,
              'type': 'system',
              'subtype': 'init',
              'agents': ['Explore', 'general-purpose', 'Plan'],
            },
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'agent-event');
      expect(result.$1.first['event']['type'], 'message');
      expect(
        result.$1.first['event']['message'],
        contains('Available sub-agents: Explore, general-purpose, Plan'),
      );
    });

    test('falls back to text for unknown agent content shapes', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_unknown_fallback',
        seq: 51,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'message',
            'data': {'message': 'Fallback assistant text'},
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'agent');
      expect(result.$1.first['content'], 'Fallback assistant text');
    });

    test('parses output message payloads as agent text', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_output_message',
        seq: 53,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {'type': 'message', 'message': 'Parsed output text'},
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'agent');
      expect(result.$1.first['content'], 'Parsed output text');
    });

    test('emits error for unknown agent content without fallback text', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_unknown_error',
        seq: 52,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'unexpected',
            'data': {'foo': 'bar'},
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'error');
      expect(result.$1.first['errorType'], 'unknown_agent_content_type');
    });

    test('skips ready events', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_6',
        seq: 6,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'event',
            'data': {'type': 'ready'},
          },
        },
      );

      expect(result.$1, isEmpty);
    });

    test('skips messages with isMeta flag', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_7',
        seq: 7,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'isMeta': true,
              'uuid': 'meta-1',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'meta content'},
                ],
              },
            },
          },
        },
      );

      expect(result.$1, isEmpty);
    });

    test('skips assistant output without uuid', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_8',
        seq: 8,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'no uuid'},
                ],
              },
            },
          },
        },
      );

      expect(result.$1, isEmpty);
    });

    test('maps thinking blocks', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_9',
        seq: 9,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'think-1',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'thinking', 'thinking': 'Considering options...'},
                  {'type': 'text', 'text': 'Here is my answer.'},
                ],
              },
            },
          },
        },
      );

      expect(result.$1, hasLength(2));
      expect(result.$1[0]['isThinking'], true);
      expect(result.$1[1]['kind'], 'text');
      expect(result.$1[1]['content'], 'Here is my answer.');
    });

    test('maps session protocol wrapped text events', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_session_1',
        seq: 10,
        sessionId: 'session_1',
        content: {
          'role': 'session',
          'content': {
            'type': 'session',
            'data': {
              'id': 'sess_ev_1',
              'time': 1700000001000,
              'role': 'agent',
              'turn': 'turn_1',
              'ev': {'t': 'text', 'text': 'Session protocol reply'},
            },
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'agent');
      expect(result.$1.first['content'], 'Session protocol reply');
      expect(result.$2, isEmpty);
    });

    test('maps session protocol user text events', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_session_user_1',
        seq: 10,
        sessionId: 'session_1',
        content: {
          'role': 'session',
          'content': {
            'id': 'sess_user_ev_1',
            'time': 1700000001500,
            'role': 'user',
            'ev': {'t': 'text', 'text': 'User session text'},
          },
        },
      );

      expect(result.$1, hasLength(1));
      expect(result.$1.first['kind'], 'text');
      expect(result.$1.first['role'], 'user');
      expect(result.$1.first['content'], 'User session text');
      expect(result.$2, isEmpty);
    });

    test('maps session protocol tool lifecycle events', () {
      final startResult = instance.testProcessDecryptedMessage(
        id: 'msg_session_2_start',
        seq: 11,
        sessionId: 'session_1',
        content: {
          'role': 'session',
          'content': {
            'id': 'sess_ev_2_start',
            'time': 1700000002000,
            'role': 'agent',
            'turn': 'turn_2',
            'ev': {
              't': 'tool-call-start',
              'call': 'tool_1',
              'name': 'Read',
              'title': 'Read File',
              'description': 'Read a file from disk',
              'args': {'file_path': '/tmp/test.txt'},
            },
          },
        },
      );

      expect(startResult.$1, hasLength(1));
      expect(startResult.$1.first['kind'], 'tool-call');
      expect(startResult.$1.first['toolUseId'], 'tool_1');
      expect(startResult.$1.first['state'], 'running');
      expect(startResult.$2, isEmpty);

      final endResult = instance.testProcessDecryptedMessage(
        id: 'msg_session_2_end',
        seq: 12,
        sessionId: 'session_1',
        content: {
          'role': 'session',
          'content': {
            'id': 'sess_ev_2_end',
            'time': 1700000003000,
            'role': 'agent',
            'turn': 'turn_2',
            'ev': {
              't': 'tool-call-end',
              'call': 'tool_1',
              'result': 'done',
              'isError': false,
            },
          },
        },
      );

      expect(endResult.$1, isEmpty);
      expect(endResult.$2, hasLength(1));
      expect(endResult.$2.first['toolUseId'], 'tool_1');
      expect(endResult.$2.first['result'], 'done');
      expect(endResult.$2.first['isError'], false);
    });

    test('maps Codex toolName args and result fields', () {
      final startResult = instance.testProcessDecryptedMessage(
        id: 'msg_codex_tool_start',
        seq: 13,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'codex',
            'data': {
              'type': 'tool-call',
              'callId': 'call_1',
              'toolName': 'apply_patch',
              'args': {'patch': '*** Begin Patch\n*** End Patch'},
            },
          },
        },
      );

      expect(startResult.$1, hasLength(1));
      expect(startResult.$1.first['kind'], 'tool-call');
      expect(startResult.$1.first['name'], 'apply_patch');
      expect(startResult.$1.first['input'], {
        'patch': '*** Begin Patch\n*** End Patch',
      });
      expect(startResult.$1.first['toolUseId'], 'call_1');

      final endResult = instance.testProcessDecryptedMessage(
        id: 'msg_codex_tool_end',
        seq: 14,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'codex',
            'data': {
              'type': 'tool-call-result',
              'callId': 'call_1',
              'result': {'ok': true},
            },
          },
        },
      );

      expect(endResult.$1, isEmpty);
      expect(endResult.$2, hasLength(1));
      expect(endResult.$2.first['toolUseId'], 'call_1');
      expect(endResult.$2.first['result'], {'ok': true});
    });
  });

  group('usage tracking', () {
    test('extracts usage data from assistant messages', () {
      instance.testProcessDecryptedMessage(
        id: 'msg_usage',
        seq: 1,
        sessionId: 'session_1',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'usage-1',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'test'},
                ],
                'usage': {
                  'input_tokens': 1000,
                  'output_tokens': 500,
                  'cache_creation_input_tokens': 200,
                  'cache_read_input_tokens': 300,
                },
              },
            },
          },
        },
      );

      final usage = instance.sessionUsage['session_1'];
      expect(usage, isNotNull);
      expect(usage!['inputTokens'], 1000);
      expect(usage['outputTokens'], 500);
      expect(usage['cacheCreation'], 200);
      expect(usage['cacheRead'], 300);
      expect(usage['contextSize'], 1500); // 200 + 300 + 1000
    });

    test('extracts usage data from codex messages', () {
      instance.testProcessDecryptedMessage(
        id: 'msg_usage_codex',
        seq: 1,
        sessionId: 'session_codex',
        content: {
          'role': 'agent',
          'content': {
            'type': 'codex',
            'data': {
              'type': 'message',
              'message': 'Working...',
              'usage': {
                'input_tokens': 1200,
                'output_tokens': 250,
                'cache_creation_input_tokens': 100,
                'cache_read_input_tokens': 50,
              },
            },
          },
        },
      );

      final usage = instance.sessionUsage['session_codex'];
      expect(usage, isNotNull);
      expect(usage!['inputTokens'], 1200);
      expect(usage['outputTokens'], 250);
      expect(usage['cacheCreation'], 100);
      expect(usage['cacheRead'], 50);
      expect(usage['contextSize'], 1350);
    });

    test('only updates usage with newer timestamps', () {
      // First message - use a different session to avoid singleton state
      instance.testProcessDecryptedMessage(
        id: 'msg_u1',
        seq: 1,
        sessionId: 'session_ts',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u1',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'first'},
                ],
                'usage': {'input_tokens': 5000, 'output_tokens': 100},
              },
            },
          },
        },
        createdAtMs: 2000,
      );

      // Verify first call set usage
      expect(instance.sessionUsage['session_ts'], isNotNull);
      expect(instance.sessionUsage['session_ts']!['inputTokens'], 5000);

      // Older message should not overwrite
      instance.testProcessDecryptedMessage(
        id: 'msg_u2',
        seq: 0,
        sessionId: 'session_ts',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u2',
              'message': {
                'role': 'assistant',
                'content': [
                  {'type': 'text', 'text': 'older'},
                ],
                'usage': {'input_tokens': 100, 'output_tokens': 50},
              },
            },
          },
        },
        createdAtMs: 1000,
      );

      final usage = instance.sessionUsage['session_ts']!;
      expect(usage['inputTokens'], 5000);
    });
  });

  group('sidechain grouping', () {
    test('groups sidechain messages by parent uuid when prompt is absent', () {
      instance.testSetSessionMessages('session_group', [
        {
          'id': 'task_1',
          'kind': 'tool-call',
          'name': 'Task',
          'toolUseId': 'task_tool_1',
          'uuid': 'task_uuid_1',
          'state': 'running',
          'input': {'description': 'Investigate issue'},
        },
        {
          'id': 'root_1',
          'kind': 'sidechain-root',
          'isSidechain': true,
          'uuid': 'sidechain_uuid_1',
          'parentUuid': 'task_uuid_1',
          'prompt': 'Expanded prompt text from server',
        },
        {
          'id': 'child_1',
          'kind': 'text',
          'isSidechain': true,
          'uuid': 'child_uuid_1',
          'parentUuid': 'sidechain_uuid_1',
          'content': 'Subagent reply',
        },
      ]);

      instance.testGroupSidechainMessages('session_group');

      final messages = instance.messagesForSession('session_group');
      expect(messages, hasLength(1));
      expect(messages.first['id'], 'task_1');

      final children = messages.first['children'] as List<dynamic>?;
      expect(children, isNotNull);
      expect(children, hasLength(1));
      expect(children!.first['id'], 'child_1');
      expect(children.first['content'], 'Subagent reply');
    });

    test('groups children arriving incrementally after '
        'sidechain-root is removed', () {
      const sid = 'session_incremental';

      // Step 1: Task arrives alone.
      instance.testSetSessionMessages(sid, [
        {
          'id': 'task_1',
          'kind': 'tool-call',
          'name': 'Task',
          'toolUseId': 'task_tool_1',
          'uuid': 'task_uuid_1',
          'state': 'running',
          'input': {'description': 'Investigate'},
        },
      ]);
      instance.testGroupSidechainMessages(sid);
      expect(instance.messagesForSession(sid), hasLength(1));

      // Step 2: Sidechain-root arrives — gets removed.
      final msgs1 = List<Map<String, dynamic>>.from(
        instance.sessionMessages[sid]!,
      );
      msgs1.add({
        'id': 'root_1',
        'kind': 'sidechain-root',
        'isSidechain': true,
        'uuid': 'sidechain_uuid_1',
        'parentUuid': 'task_uuid_1',
        'prompt': 'Prompt text',
      });
      instance.testSetSessionMessages(sid, msgs1);
      instance.testGroupSidechainMessages(sid);
      // Root should be removed; only Task remains.
      expect(instance.messagesForSession(sid), hasLength(1));

      // Step 3: First child arrives with parentUuid pointing
      // to the removed sidechain-root's uuid.
      final msgs2 = List<Map<String, dynamic>>.from(
        instance.sessionMessages[sid]!.map((m) => Map<String, dynamic>.from(m)),
      );
      msgs2.add({
        'id': 'child_1',
        'kind': 'text',
        'isSidechain': true,
        'uuid': 'child_uuid_1',
        'parentUuid': 'sidechain_uuid_1',
        'content': 'First reply',
      });
      instance.testSetSessionMessages(sid, msgs2);
      instance.testGroupSidechainMessages(sid);

      var messages = instance.messagesForSession(sid);
      expect(messages, hasLength(1));
      var children = messages.first['children'] as List<dynamic>?;
      expect(children, isNotNull);
      expect(children, hasLength(1));
      expect(children!.first['id'], 'child_1');

      // Step 4: Second child arrives — chained through first
      // child's uuid.
      final msgs3 = List<Map<String, dynamic>>.from(
        instance.sessionMessages[sid]!.map((m) => Map<String, dynamic>.from(m)),
      );
      msgs3.add({
        'id': 'child_2',
        'kind': 'tool-call',
        'name': 'Read',
        'isSidechain': true,
        'uuid': 'child_uuid_2',
        'parentUuid': 'child_uuid_1',
        'state': 'running',
        'input': <String, dynamic>{'file_path': '/tmp/f'},
      });
      instance.testSetSessionMessages(sid, msgs3);
      instance.testGroupSidechainMessages(sid);

      messages = instance.messagesForSession(sid);
      expect(messages, hasLength(1));
      children = messages.first['children'] as List<dynamic>?;
      expect(children, isNotNull);
      expect(children, hasLength(2));
      expect(children![0]['id'], 'child_1');
      expect(children[1]['id'], 'child_2');
    });

    test('groups 5 agents sharing same assistant uuid '
        'by toolUseId', () {
      const sid = 'session_multi_agent';
      const sharedUuid = 'assistant_uuid_shared';

      // Build 5 Agent tool-calls that share the same
      // assistant message UUID (as happens when Claude
      // batches multiple Agent calls in one response).
      final messages = <Map<String, dynamic>>[];
      for (var i = 0; i < 5; i++) {
        messages.add({
          'id': 'agent_${i}_u$i',
          'kind': 'tool-call',
          'name': 'Agent',
          'toolUseId': 'tool_use_$i',
          'uuid': sharedUuid,
          'state': 'running',
          'input': <String, dynamic>{
            'description': 'Agent $i task',
            'prompt': 'Do agent $i work',
            'subagent_type': 'generic-assistant',
          },
        });
      }

      // Add sidechain-root + child for each agent.
      // The first sidechain message's parentUuid is the
      // tool_use_id (set by Go CLI).
      for (var i = 0; i < 5; i++) {
        messages.add({
          'id': 'root_$i',
          'kind': 'sidechain-root',
          'isSidechain': true,
          'uuid': 'root_uuid_$i',
          'parentUuid': 'tool_use_$i',
          'prompt': 'Do agent $i work',
        });
        messages.add({
          'id': 'child_${i}_text',
          'kind': 'text',
          'isSidechain': true,
          'uuid': 'child_uuid_$i',
          'parentUuid': 'root_uuid_$i',
          'content': 'Reply from agent $i',
        });
      }

      instance.testSetSessionMessages(sid, messages);
      instance.testGroupSidechainMessages(sid);

      final result = instance.messagesForSession(sid);
      // Only the 5 Agent tool-calls should remain.
      expect(result, hasLength(5));

      for (var i = 0; i < 5; i++) {
        expect(result[i]['id'], 'agent_${i}_u$i');
        final children = result[i]['children'] as List<dynamic>?;
        expect(children, isNotNull, reason: 'Agent $i should have children');
        expect(
          children,
          hasLength(1),
          reason: 'Agent $i should have exactly 1 child',
        );
        expect(
          (children!.first as Map<String, dynamic>)['content'],
          'Reply from agent $i',
        );
      }
    });

    test('groups agents incrementally with toolUseId-based '
        'parentUuid across streaming arrivals', () {
      const sid = 'session_multi_incremental';
      const sharedUuid = 'assistant_uuid_shared';

      // Step 1: 5 Agent tool-calls arrive.
      final agents = <Map<String, dynamic>>[];
      for (var i = 0; i < 5; i++) {
        agents.add({
          'id': 'agent_$i',
          'kind': 'tool-call',
          'name': 'Agent',
          'toolUseId': 'tu_$i',
          'uuid': sharedUuid,
          'state': 'running',
          'input': <String, dynamic>{
            'prompt': 'Task $i',
            'subagent_type': 'generic-assistant',
          },
        });
      }
      instance.testSetSessionMessages(sid, agents);
      instance.testGroupSidechainMessages(sid);
      expect(instance.messagesForSession(sid), hasLength(5));

      // Step 2: Sidechain roots arrive one at a time.
      for (var i = 0; i < 5; i++) {
        final msgs = List<Map<String, dynamic>>.from(
          instance.sessionMessages[sid]!.map(
            (m) => Map<String, dynamic>.from(m),
          ),
        );
        msgs.add({
          'id': 'root_$i',
          'kind': 'sidechain-root',
          'isSidechain': true,
          'uuid': 'root_uuid_$i',
          'parentUuid': 'tu_$i',
          'prompt': 'Task $i',
        });
        instance.testSetSessionMessages(sid, msgs);
        instance.testGroupSidechainMessages(sid);
        // Only agent tool-calls should remain.
        expect(instance.messagesForSession(sid), hasLength(5));
      }

      // Step 3: Children arrive one per agent.
      for (var i = 0; i < 5; i++) {
        final msgs = List<Map<String, dynamic>>.from(
          instance.sessionMessages[sid]!.map(
            (m) => Map<String, dynamic>.from(m),
          ),
        );
        msgs.add({
          'id': 'child_$i',
          'kind': 'text',
          'isSidechain': true,
          'uuid': 'child_uuid_$i',
          'parentUuid': 'root_uuid_$i',
          'content': 'Agent $i response',
        });
        instance.testSetSessionMessages(sid, msgs);
        instance.testGroupSidechainMessages(sid);
      }

      final result = instance.messagesForSession(sid);
      expect(result, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final children = result[i]['children'] as List<dynamic>?;
        expect(children, isNotNull, reason: 'Agent $i should have children');
        expect(children, hasLength(1), reason: 'Agent $i should have 1 child');
        expect(
          (children!.first as Map<String, dynamic>)['content'],
          'Agent $i response',
        );
      }
    });
  });

  group('sidechain field name variants', () {
    test('groups sidechain messages using parent_uuid '
        '(snake_case) instead of parentUuid', () {
      instance.testSetSessionMessages('session_snake', [
        {
          'id': 'task_1',
          'kind': 'tool-call',
          'name': 'Agent',
          'toolUseId': 'tu_1',
          'uuid': 'agent_uuid_1',
          'state': 'running',
          'input': {'description': 'Do work'},
        },
        {
          'id': 'root_1',
          'kind': 'sidechain-root',
          'isSidechain': true,
          'uuid': 'root_uuid_1',
          'parentUuid': 'agent_uuid_1',
          'prompt': 'Prompt',
        },
        {
          'id': 'child_1',
          'kind': 'text',
          'isSidechain': true,
          'uuid': 'child_uuid_1',
          'parentUuid': 'root_uuid_1',
          'content': 'Reply from agent',
        },
      ]);

      instance.testGroupSidechainMessages('session_snake');

      final messages = instance.messagesForSession('session_snake');
      expect(messages, hasLength(1));
      final children = messages.first['children'] as List<dynamic>?;
      expect(children, isNotNull);
      expect(children, hasLength(1));
      expect(children!.first['content'], 'Reply from agent');
    });

    test('output format recognises parent_uuid and subagent '
        'field names via testProcessDecryptedMessage', () {
      // Test parent_uuid (snake_case)
      final result1 = instance.testProcessDecryptedMessage(
        id: 'msg_sc1',
        seq: 10,
        sessionId: 'session_variants',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'isSidechain': true,
              'uuid': 'sc_uuid_1',
              'parent_uuid': 'task_tu_1',
              'message': {
                'content': [
                  {'type': 'text', 'text': 'Hello from sub'},
                ],
              },
            },
          },
        },
      );
      final msgs1 = result1.$1;
      expect(msgs1, hasLength(1));
      expect(msgs1.first['isSidechain'], true);
      expect(msgs1.first['parentUuid'], 'task_tu_1');

      // Test subagent field name
      final result2 = instance.testProcessDecryptedMessage(
        id: 'msg_sc2',
        seq: 11,
        sessionId: 'session_variants',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'isSidechain': true,
              'uuid': 'sc_uuid_2',
              'subagent': 'task_tu_2',
              'message': {
                'content': [
                  {'type': 'text', 'text': 'Hello from sub 2'},
                ],
              },
            },
          },
        },
      );
      final msgs2 = result2.$1;
      expect(msgs2, hasLength(1));
      expect(msgs2.first['isSidechain'], true);
      expect(msgs2.first['parentUuid'], 'task_tu_2');
    });

    test('sidechain-root created from content-block list format', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_list',
        seq: 20,
        sessionId: 'session_list',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'user',
              'isSidechain': true,
              'uuid': 'list_uuid',
              'parentUuid': 'task_uuid',
              'message': {
                'content': [
                  {'type': 'text', 'text': 'Sub-agent prompt'},
                ],
              },
            },
          },
        },
      );
      final msgs = result.$1;
      expect(msgs, hasLength(1));
      expect(msgs.first['kind'], 'sidechain-root');
      expect(msgs.first['prompt'], 'Sub-agent prompt');
      expect(msgs.first['parentUuid'], 'task_uuid');
    });

    test('is_sidechain (snake_case) flag is recognised', () {
      final result = instance.testProcessDecryptedMessage(
        id: 'msg_snake',
        seq: 30,
        sessionId: 'session_flag',
        content: {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'is_sidechain': true,
              'uuid': 'snake_uuid',
              'parentUuid': 'task_uuid',
              'message': {
                'content': [
                  {'type': 'text', 'text': 'snake flag'},
                ],
              },
            },
          },
        },
      );
      final msgs = result.$1;
      expect(msgs, hasLength(1));
      expect(msgs.first['isSidechain'], true);
    });
  });

  group('tool result application', () {
    test('applies tool results recursively to grouped subagent children', () {
      instance.testSetSessionMessages('session_results', [
        {
          'id': 'task_1',
          'kind': 'tool-call',
          'name': 'Task',
          'toolUseId': 'task_tool_1',
          'state': 'running',
          'children': [
            {
              'id': 'child_tool_1',
              'kind': 'tool-call',
              'name': 'Read',
              'toolUseId': 'read_tool_1',
              'state': 'running',
              'input': {'file_path': '/tmp/test.txt'},
            },
          ],
        },
      ]);

      instance.testApplyToolResults('session_results', [
        {
          'toolUseId': 'read_tool_1',
          'result': 'file contents',
          'isError': false,
          'createdAt': 1700000004000,
        },
      ]);

      final messages = instance.messagesForSession('session_results');
      final task = messages.first;
      final children = task['children'] as List<dynamic>;
      final childTool = children.first as Map<String, dynamic>;

      expect(childTool['state'], 'completed');
      expect(childTool['result'], 'file contents');
      expect(childTool['completedAt'], 1700000004000);
    });
  });
}
