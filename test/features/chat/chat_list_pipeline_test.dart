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

    test('folds thinking blocks into the same summary as tool calls', () {
      // Agentic loop shape: think -> tool -> think -> tool. Without
      // folding, this rendered as alternating Thinking / "1 tool
      // complete" rows instead of one collapsed group.
      final items = buildChatListItems(
        visibleMessages: [
          {
            'id': 'th1',
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'text': 'first thought',
          },
          {
            'id': 't1',
            'kind': 'tool-call',
            'name': 'Read',
            'state': 'completed',
          },
          {
            'id': 'th2',
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'text': 'second thought',
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
      final summary = items[0]!;
      expect(summary['kind'], 'hidden-tool-summary');
      // `tools` keeps only real tool calls for the counts label.
      expect(
        (summary['tools'] as List).map((t) => (t as Map)['id']),
        ['t1', 't2'],
      );
      // `items` preserves the full working trace in original order.
      expect(
        (summary['items'] as List).map((t) => (t as Map)['id']),
        ['th1', 't1', 'th2', 't2'],
      );
      expect(items[1]?['id'], 'm1');
    });

    test('folds a thinking-only run into a summary row', () {
      final items = buildChatListItems(
        visibleMessages: [
          {'id': 'm0', 'role': 'user', 'kind': 'text', 'text': 'go'},
          {
            'id': 'th1',
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'text': 'hmm',
          },
          {'id': 'm1', 'role': 'agent', 'kind': 'text', 'text': 'done'},
        ],
        hideToolCalls: true,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (msg, {required hideToolCalls}) =>
            hideToolCalls && msg['kind'] == 'tool-call',
      );
      expect(items.length, 3);
      expect(items[1]?['kind'], 'hidden-tool-summary');
      expect((items[1]!['tools'] as List), isEmpty);
      expect((items[1]!['items'] as List).length, 1);
    });

    test('keeps thinking blocks inline when hideToolCalls is false', () {
      final items = buildChatListItems(
        visibleMessages: [
          {
            'id': 'th1',
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'text': 'hmm',
          },
          {'id': 'm1', 'role': 'agent', 'kind': 'text', 'text': 'done'},
        ],
        hideToolCalls: false,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (msg, {required hideToolCalls}) =>
            hideToolCalls && msg['kind'] == 'tool-call',
      );
      expect(items.length, 2);
      expect(items[0]?['id'], 'th1');
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

  group('buildChatListItems model-change markers', () {
    List<Map<String, dynamic>?> build(
      List<Map<String, dynamic>> messages, {
      bool hideToolCalls = false,
    }) {
      return buildChatListItems(
        visibleMessages: messages,
        hideToolCalls: hideToolCalls,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (msg, {required hideToolCalls}) =>
            hideToolCalls && msg['kind'] == 'tool-call',
      );
    }

    Map<String, dynamic> agent(
      String id, {
      String? model,
      bool sidechain = false,
    }) {
      return {
        'id': id,
        'role': 'agent',
        'kind': 'text',
        'content': id,
        if (model != null) 'model': model,
        if (sidechain) 'isSidechain': true,
      };
    }

    test('emits no marker for the first model seen', () {
      final items = build([agent('a1', model: 'claude-opus-4-5')]);
      expect(items.length, 1);
      expect(items.single?['id'], 'a1');
    });

    test('emits no marker while the model is unchanged', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        agent('a2', model: 'claude-opus-4-5'),
      ]);
      expect(items.map((i) => i?['kind']), everyElement(isNot('model-change')));
    });

    test('inserts a marker before the first message of the new model', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        agent('a2', model: 'claude-sonnet-5'),
      ]);
      expect(items.length, 3);
      expect(items[0]?['id'], 'a1');
      expect(items[1]?['kind'], 'model-change');
      expect(items[1]?['fromModel'], 'claude-opus-4-5');
      expect(items[1]?['toModel'], 'claude-sonnet-5');
      expect(items[2]?['id'], 'a2');
    });

    test('tracks a switch back to the original model', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        agent('a2', model: 'claude-sonnet-5'),
        agent('a3', model: 'claude-opus-4-5'),
      ]);
      final markers = items
          .where((i) => i?['kind'] == 'model-change')
          .toList(growable: false);
      expect(markers.length, 2);
      expect(markers[1]?['fromModel'], 'claude-sonnet-5');
      expect(markers[1]?['toModel'], 'claude-opus-4-5');
    });

    test('ignores messages that report no model', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        {'id': 'u1', 'role': 'user', 'content': 'hi'},
        agent('a2'),
        agent('a3', model: 'claude-opus-4-5'),
      ]);
      expect(items.map((i) => i?['kind']), everyElement(isNot('model-change')));
    });

    test('ignores sidechain models so subagents emit no marker', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        agent('s1', model: 'claude-haiku-4-5', sidechain: true),
        agent('a2', model: 'claude-opus-4-5'),
      ]);
      expect(items.map((i) => i?['kind']), everyElement(isNot('model-change')));
    });

    test('ignores models reported by nested tool-scoped messages', () {
      final items = build([
        agent('a1', model: 'claude-opus-4-5'),
        {
          'id': 'n1',
          'role': 'agent',
          'kind': 'text',
          'model': 'claude-haiku-4-5',
          'parentToolUseId': 'toolu_1',
        },
        agent('a2', model: 'claude-opus-4-5'),
      ]);
      expect(items.map((i) => i?['kind']), everyElement(isNot('model-change')));
    });

    test('flushes the hidden-tool group so the marker stays in order', () {
      final items = build(
        [
          agent('a1', model: 'claude-opus-4-5'),
          {
            'id': 't1',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Read',
            'state': 'completed',
            'model': 'claude-opus-4-5',
          },
          {
            'id': 't2',
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Grep',
            'state': 'completed',
            'model': 'claude-sonnet-5',
          },
          agent('a2', model: 'claude-sonnet-5'),
        ],
        hideToolCalls: true,
      );
      expect(items.length, 5);
      expect(items[0]?['id'], 'a1');
      expect(items[1]?['kind'], 'hidden-tool-summary');
      expect((items[1]!['tools'] as List).length, 1);
      expect(items[2]?['kind'], 'model-change');
      expect(items[3]?['kind'], 'hidden-tool-summary');
      expect((items[3]!['tools'] as List).length, 1);
      expect(items[4]?['id'], 'a2');
    });
  });
}
