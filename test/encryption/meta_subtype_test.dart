// Unit coverage for `_processMetaOutput`: the isMeta subtype handler
// added in output_content_handler.dart. These shapes were previously
// silently dropped by the isolate parser (the legacy inline parser
// handled them, so behaviour diverged across fetch vs. socket paths).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

ProcessedMessages _run(Map<String, dynamic> data) {
  return processDecryptedMessages(
    decryptedJsonList: [
      {
        'role': 'agent',
        'content': {'type': 'output', 'data': data},
      },
    ],
    wireMessages: [
      {'id': 'm1', 'seq': 1, 'createdAt': 1000},
    ],
    sessionId: 's1',
  );
}

void main() {
  group('meta subtype handling', () {
    test('compact_boundary renders "Context compacted" agent event', () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'compact_boundary',
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['kind'], 'agent-event');
      expect(r.messages.first['event'],
          {'type': 'message', 'message': 'Context compacted'});
      expect(r.droppedReasons, isEmpty);
    });

    test('task_started emits event with description, preserving uuid chain',
        () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'task_started',
        'isSidechain': true,
        'uuid': 'task-uuid-1',
        'parentUuid': 'tool-use-call-1',
        'description': 'exploring repo',
        'task_id': 'task-123',
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['kind'], 'agent-event');
      expect(r.messages.first['event']['message'], 'exploring repo');
      expect(r.messages.first['isSidechain'], true);
      expect(r.messages.first['uuid'], 'task-uuid-1');
      expect(r.messages.first['parentUuid'], 'tool-use-call-1');
      expect(r.messages.first['taskEvent'], true);
      expect(r.messages.first['agentId'], 'task-123');
    });

    test('task_notification with status=completed renders summary text', () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'task_notification',
        'status': 'completed',
        'summary': 'Done — 3 files updated',
        'task_id': 'task-456',
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['kind'], 'text');
      expect(r.messages.first['content'], 'Done — 3 files updated');
      expect(r.messages.first['taskEvent'], true);
      expect(r.messages.first['taskStatus'], 'completed');
      expect(r.messages.first['agentId'], 'task-456');
    });

    test('api_retry shows attempt/max-retries label', () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'api_retry',
        'attempt': 2,
        'max_retries': 5,
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['event']['message'],
          'Retrying API request (2/5)...');
    });

    test('tool_progress shows elapsed-time label', () {
      final r = _run({
        'isMeta': true,
        'type': 'tool_progress',
        'tool_name': 'Grep',
        'elapsed_time_seconds': 12,
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['event']['message'], 'Grep running (12s)...');
    });

    test('rate_limit_event rejected renders limit-reached event', () {
      final r = _run({
        'isMeta': true,
        'type': 'rate_limit_event',
        'rate_limit_info': {'status': 'rejected'},
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['event']['type'], 'limit-reached');
      expect(r.messages.first['event']['message'],
          'Rate limit reached — waiting for reset');
    });

    test('unknown meta sidechain subtype still emits invisible bridge', () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'some_future_subtype',
        'isSidechain': true,
        'uuid': 'sc-uuid',
        'parentUuid': 'parent-uuid',
      });
      expect(r.messages, hasLength(1));
      expect(r.messages.first['isBridge'], true);
      expect(r.messages.first['uuid'], 'sc-uuid');
      expect(r.messages.first['parentUuid'], 'parent-uuid');
    });

    test('non-sidechain unknown meta is silently absorbed', () {
      final r = _run({
        'isMeta': true,
        'type': 'system',
        'subtype': 'some_unknown_subtype',
      });
      expect(r.messages, isEmpty);
      expect(r.droppedReasons, isEmpty);
    });
  });
}
