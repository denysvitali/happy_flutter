import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/chat_list_pipeline.dart';

void main() {
  group('buildChatListItems', () {
    test('drops orphan recovery placeholders', () {
      final items = buildChatListItems(
        visibleMessages: [
          {'_orphanRecovery': true, 'id': 'o1'},
          {'id': 'm1', 'role': 'user', 'text': 'hi'},
        ],
        hideToolCalls: false,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (_, {required hideToolCalls}) => false,
      );
      expect(items.length, 1);
      expect(items.single?['id'], 'm1');
    });

    test('collapses consecutive hidden tool calls into summary', () {
      final items = buildChatListItems(
        visibleMessages: [
          {
            'id': 't1',
            'kind': 'tool-call',
            'name': 'Read',
            'state': 'completed',
          },
          {
            'id': 't2',
            'kind': 'tool-call',
            'name': 'Grep',
            'state': 'completed',
          },
          {'id': 'm1', 'role': 'agent', 'kind': 'text', 'text': 'done'},
        ],
        hideToolCalls: true,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (msg, {required hideToolCalls}) =>
            hideToolCalls && msg['kind'] == 'tool-call',
      );
      expect(items.length, 2);
      expect(items[0]?['kind'], 'hidden-tool-summary');
      expect((items[0]!['tools'] as List).length, 2);
      expect(items[1]?['id'], 'm1');
    });

    test('filters agent events via predicate', () {
      final items = buildChatListItems(
        visibleMessages: [
          {'id': 'e1', 'kind': 'agent-event', 'event': 'noise'},
          {'id': 'e2', 'kind': 'agent-event', 'event': 'keep'},
        ],
        hideToolCalls: false,
        shouldRenderAgentEvent: (event) => event == 'keep',
        shouldHideToolCall: (_, {required hideToolCalls}) => false,
      );
      expect(items.length, 1);
      expect(items.single?['id'], 'e2');
    });

    test('inserts null divider after /clear user message', () {
      final items = buildChatListItems(
        visibleMessages: [
          {'id': 'u1', 'role': 'user', 'text': '/clear'},
        ],
        hideToolCalls: false,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (_, {required hideToolCalls}) => false,
      );
      expect(items.length, 2);
      expect(items[0]?['id'], 'u1');
      expect(items[1], isNull);
    });
  });
}
