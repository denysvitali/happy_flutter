import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

// Regression coverage for the permissive-fallback fix to
// `_processOutputContent`. Background: silent drops in the output handler
// caused sessions with unrecognized message shapes to appear paused — the
// daemon kept producing output, the server stored 2k+ messages, but the
// chat showed almost nothing. Each unrecognized shape now emits an
// `agent-event` of `type: 'unrendered'` so the user sees that *something*
// arrived, while `droppedReasons` still feeds Sentry/GlitchTip.
void main() {
  Map<String, dynamic> wire({
    required String id,
    required int seq,
    int createdAt = 1000,
  }) =>
      {'id': id, 'seq': seq, 'createdAt': createdAt};

  Map<String, dynamic> agentOutput(Map<String, dynamic> data) {
    return {
      'role': 'agent',
      'content': {
        'type': 'output',
        'data': data,
      },
    };
  }

  group('output handler — unrendered fallback', () {
    test('unknown data type emits an "unrendered" event instead of dropping',
        () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'some_future_event_type',
            'payload': {'foo': 'bar'},
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['kind'], 'agent-event');
      final event = result.messages.first['event'] as Map<String, dynamic>;
      expect(event['type'], 'unrendered');
      expect(event['message'], contains('some_future_event_type'));
      expect(
        result.droppedReasons.any((r) => r.contains('output data type')),
        isTrue,
        reason: 'telemetry must still fire for Sentry grouping',
      );
    });

    test('null data still surfaces an unrendered event', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          {
            'role': 'agent',
            'content': {'type': 'output', 'data': 'not-a-map'},
          },
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['kind'], 'agent-event');
      final event = result.messages.first['event'] as Map<String, dynamic>;
      expect(event['type'], 'unrendered');
    });

    test('assistant.message of unexpected type emits unrendered event', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'assistant',
            'uuid': 'u1',
            'message': 12345, // not Map, not non-empty String
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['kind'], 'agent-event');
      expect(
        (result.messages.first['event'] as Map)['type'],
        'unrendered',
      );
    });

    test('assistant.content of unexpected type emits unrendered event', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'assistant',
            'uuid': 'u1',
            'message': {'content': 42},
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['kind'], 'agent-event');
      expect(
        (result.messages.first['event'] as Map)['type'],
        'unrendered',
      );
    });

    test('unknown content block inside assistant emits one unrendered event',
        () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'assistant',
            'uuid': 'u1',
            'message': {
              'content': [
                {'type': 'text', 'text': 'Visible part.'},
                {'type': 'future_block_kind', 'payload': 'opaque'},
              ],
            },
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      // One real text message + one unrendered event for the unknown block.
      expect(result.messages, hasLength(2));
      expect(result.messages[0]['kind'], 'text');
      expect(result.messages[0]['content'], 'Visible part.');
      expect(result.messages[1]['kind'], 'agent-event');
      final event = result.messages[1]['event'] as Map<String, dynamic>;
      expect(event['type'], 'unrendered');
      expect(event['message'], contains('future_block_kind'));
    });

    test('empty assistant content list stays a silent no-op', () {
      // Empty list carries no information to surface — keep it silent so
      // legitimate empty acknowledgements (e.g. tool-only follow-ups) do
      // not spam the chat.
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'assistant',
            'uuid': 'u1',
            'message': {'content': <dynamic>[]},
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, isEmpty);
      expect(
        result.droppedReasons.any((r) => r.contains('content list is empty')),
        isTrue,
      );
    });

    test('unknown user content block emits unrendered event', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'user',
            'uuid': 'u1',
            'message': {
              'content': [
                {'type': 'audio_blob', 'data': 'opaque'},
              ],
            },
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['kind'], 'agent-event');
      expect(
        (result.messages.first['event'] as Map)['type'],
        'unrendered',
      );
      expect(
        (result.messages.first['event'] as Map)['message'],
        contains('audio_blob'),
      );
    });

    test('unrendered event preserves sidechain metadata for grouper', () {
      // Sidechain chains must still resolve even when an intermediate
      // message is unrenderable — otherwise long subagent transcripts
      // fragment into orphan placeholders.
      final result = processDecryptedMessages(
        decryptedJsonList: [
          agentOutput({
            'type': 'totally_unknown',
            'isSidechain': true,
            'uuid': 'child-uuid',
            'parentUuid': 'parent-uuid',
          }),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      final msg = result.messages.first;
      expect(msg['kind'], 'agent-event');
      expect(msg['isSidechain'], true);
      expect(msg['uuid'], 'child-uuid');
      expect(msg['parentUuid'], 'parent-uuid');
    });
  });
}
