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
      expect((summary['tools'] as List).map((t) => (t as Map)['id']), [
        't1',
        't2',
      ]);
      // `items` preserves the full working trace in original order.
      expect((summary['items'] as List).map((t) => (t as Map)['id']), [
        'th1',
        't1',
        'th2',
        't2',
      ]);
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

  group('buildChatListItems sub-agent progress ticks', () {
    // A workflow fan-out emits one task_progress event per tool call per
    // agent. Rendered one-per-row they buried the transcript under dozens
    // of near-identical centered chips while the banner reported only two
    // agents running.
    Map<String, dynamic> tick(String agentId, String tool) => {
      'id': 'te-$agentId-$tool',
      'kind': 'agent-event',
      'role': 'agent',
      'taskEvent': true,
      'agentId': agentId,
      'subAgentLastTool': tool,
      'event': {'type': 'message', 'message': tool},
    };

    List<Map<String, dynamic>?> build(List<Map<String, dynamic>> msgs) =>
        buildChatListItems(
          visibleMessages: msgs,
          hideToolCalls: false,
          shouldRenderAgentEvent: (_) => true,
          shouldHideToolCall: (_, {required hideToolCalls}) => false,
        );

    test('collapses a run to the latest tick per agent', () {
      final items = build([
        tick('a1', 'Read'),
        tick('a2', 'Grep'),
        tick('a1', 'Bash'),
        tick('a2', 'Edit'),
        tick('a1', 'Write'),
      ]);

      expect(items.length, 2);
      // First-seen order is kept so rows do not jump around as ticks land.
      expect(items[0]?['agentId'], 'a1');
      expect(items[0]?['subAgentLastTool'], 'Write');
      expect(items[1]?['agentId'], 'a2');
      expect(items[1]?['subAgentLastTool'], 'Edit');
    });

    test('does not merge ticks across an intervening message', () {
      final items = build([
        tick('a1', 'Read'),
        {'id': 'm1', 'role': 'agent', 'kind': 'text', 'text': 'hi'},
        tick('a1', 'Bash'),
      ]);

      expect(items.length, 3);
      expect(items[0]?['subAgentLastTool'], 'Read');
      expect(items[1]?['id'], 'm1');
      expect(items[2]?['subAgentLastTool'], 'Bash');
    });

    test('terminal summary supersedes the task in-flight chips', () {
      final items = build([
        tick('a1', 'Read'),
        tick('a1', 'Bash'),
        {
          'id': 'tn1',
          'role': 'agent',
          'kind': 'text',
          'taskEvent': true,
          'taskStatus': 'completed',
          'agentId': 'a1',
          'content': 'Task completed',
        },
      ]);

      // A finished task renders exactly one row: the summary.
      expect(items.length, 1);
      expect(items[0]?['id'], 'tn1');
    });

    test('merges ticks across interleaved task lifecycle rows', () {
      final items = build([
        tick('to', 'TaskOutput'),
        tick('a1', 'Read'),
        {
          'id': 'tn1',
          'role': 'agent',
          'kind': 'text',
          'taskEvent': true,
          'taskStatus': 'completed',
          'agentId': 'a1',
          'content': 'Task completed',
        },
        tick('to', 'TaskOutput'),
      ]);

      // a1's chips drop (summary landed); the still-running TaskOutput
      // collapses to its latest tick.
      expect(items.length, 2);
      expect(items[0]?['id'], 'tn1');
      expect(items[1]?['agentId'], 'to');
    });

    test('falls back to the tool name when agentId is absent', () {
      final items = build([
        {
          'id': 'te1',
          'kind': 'agent-event',
          'taskEvent': true,
          'subAgentLastTool': 'Read',
          'event': {'type': 'message', 'message': 'first'},
        },
        {
          'id': 'te2',
          'kind': 'agent-event',
          'taskEvent': true,
          'subAgentLastTool': 'Read',
          'event': {'type': 'message', 'message': 'second'},
        },
      ]);

      expect(items.length, 1);
      expect(items.single?['id'], 'te2');
    });

    test('emits hidden tool summaries before the ticks that follow', () {
      final items = buildChatListItems(
        visibleMessages: [
          {'id': 't1', 'kind': 'tool-call', 'name': 'Read'},
          tick('a1', 'Bash'),
        ],
        hideToolCalls: true,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (msg, {required hideToolCalls}) =>
            hideToolCalls && msg['kind'] == 'tool-call',
      );

      expect(items.length, 2);
      expect(items[0]?['kind'], 'hidden-tool-summary');
      expect(items[1]?['subAgentLastTool'], 'Bash');
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
      final items = build([
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
      ], hideToolCalls: true);
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

  // Two production sessions accumulated 91 and 119 sidechain orphans whose
  // parent Task never arrived; the grouper gives up and renders them
  // inline, burying the conversation under ungrouped sub-agent tiles.
  group('buildChatListItems sidechain orphan cap', () {
    Map<String, dynamic> orphan(int i) => <String, dynamic>{
      'id': 'orphan-$i',
      'role': 'agent',
      'kind': 'text',
      'isSidechain': true,
      'text': 'sub-agent step $i',
    };

    List<Map<String, dynamic>?> build(
      List<Map<String, dynamic>> messages, {
      int? cap = kSidechainOrphanInlineCap,
    }) {
      return buildChatListItems(
        visibleMessages: messages,
        hideToolCalls: false,
        sidechainOrphanInlineCap: cap,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (_, {required hideToolCalls}) => false,
      );
    }

    test('renders orphans inline while under the cap', () {
      final items = build([
        for (var i = 0; i < kSidechainOrphanInlineCap; i++) orphan(i),
      ]);
      expect(items.length, kSidechainOrphanInlineCap);
      expect(
        items.where((m) => m?['kind'] == 'sidechain-orphan-more'),
        isEmpty,
      );
    });

    test('collapses the oldest orphans past the cap behind one row', () {
      final items = build([for (var i = 0; i < 100; i++) orphan(i)]);

      expect(items.length, kSidechainOrphanInlineCap + 1);
      expect(items.first?['kind'], 'sidechain-orphan-more');
      expect(items.first?['hiddenCount'], 100 - kSidechainOrphanInlineCap);
      // The newest orphans stay inline, in order, and are the tail.
      expect(items[1]?['id'], 'orphan-${100 - kSidechainOrphanInlineCap}');
      expect(items.last?['id'], 'orphan-99');
    });

    test('a null cap renders every orphan (the expanded state)', () {
      final items = build([for (var i = 0; i < 100; i++) orphan(i)], cap: null);
      expect(items.length, 100);
      expect(
        items.where((m) => m?['kind'] == 'sidechain-orphan-more'),
        isEmpty,
      );
    });

    test('keeps the collapse row chronologically in place', () {
      final items = build([
        {'id': 'u1', 'role': 'user', 'kind': 'text', 'text': 'go'},
        for (var i = 0; i < 30; i++) orphan(i),
        {'id': 'a1', 'role': 'agent', 'kind': 'text', 'text': 'done'},
      ]);

      expect(items.first?['id'], 'u1');
      expect(items[1]?['kind'], 'sidechain-orphan-more');
      expect(items[1]?['hiddenCount'], 30 - kSidechainOrphanInlineCap);
      expect(items.last?['id'], 'a1');
      expect(items.length, kSidechainOrphanInlineCap + 3);
    });

    test('orphaned tool rows collapse even under the prose cap', () {
      final items = build([
        <String, dynamic>{
          'id': 'tool-0',
          'role': 'agent',
          'kind': 'tool-call',
          'isSidechain': true,
          'name': 'Bash',
        },
        orphan(0),
        <String, dynamic>{
          'id': 'tool-1',
          'role': 'agent',
          'kind': 'tool-call',
          'isSidechain': true,
          'name': 'Bash',
        },
      ]);

      // Prose stays inline; both tool rows hide behind the expand row.
      expect(items.length, 2);
      expect(items[0]?['kind'], 'sidechain-orphan-more');
      expect(items[0]?['hiddenCount'], 2);
      expect(items[1]?['id'], 'orphan-0');
    });

    test('a null cap renders tool orphans too (expanded state)', () {
      final items = build([
        <String, dynamic>{
          'id': 'tool-0',
          'role': 'agent',
          'kind': 'tool-call',
          'isSidechain': true,
          'name': 'Bash',
        },
        orphan(0),
      ], cap: null);
      expect(items.length, 2);
    });

    test('hidden chain-bridge links never count as orphans', () {
      // `sidechain-link` entries exist only so the grouper can walk
      // parentUuid; they render nothing and must not inflate the count.
      final items = build([
        for (var i = 0; i < 25; i++)
          <String, dynamic>{
            'id': 'link-$i',
            'role': 'agent',
            'kind': 'sidechain-link',
            'isSidechain': true,
          },
      ]);
      expect(
        items.where((m) => m?['kind'] == 'sidechain-orphan-more'),
        isEmpty,
      );
      expect(items.length, 25);
    });
  });
  group('local_bash command de-duplication', () {
    List<Map<String, dynamic>?> build(List<Map<String, dynamic>> msgs) =>
        buildChatListItems(
          visibleMessages: msgs,
          hideToolCalls: false,
          shouldRenderAgentEvent: (_) => true,
          shouldHideToolCall: (_, {required hideToolCalls}) => false,
        );

    Map<String, dynamic> bash(String command) => <String, dynamic>{
      'id': 'tool-$command'.hashCode.toString(),
      'kind': 'tool-call',
      'name': 'Bash',
      'input': <String, dynamic>{'command': command},
    };

    test('drops a progress chip repeating the Terminal row above', () {
      final items = build([
        bash('mise run server:lint 2>&1 |\n  tail -15'),
        <String, dynamic>{
          'id': 'chip',
          'kind': 'agent-event',
          'taskEvent': true,
          'event': <String, dynamic>{
            'type': 'message',
            'message': 'mise run server:lint 2>&1 | tail -15',
          },
        },
      ]);
      expect(items.length, 1);
      expect(items.single?['kind'], 'tool-call');
    });

    test('drops a chip whose truncated label prefixes the command', () {
      final items = build([
        bash("python3 - <<'EOF' import re p='a.go' s=open(p).read()"),
        <String, dynamic>{
          'id': 'chip',
          'kind': 'agent-event',
          'taskEvent': true,
          'event': <String, dynamic>{
            'type': 'message',
            'message': "python3 - <<'EOF' import re p='a.go'…",
          },
        },
      ]);
      expect(items.length, 1);
    });

    test('keeps a chip that says something new', () {
      final items = build([
        bash('mise run server:lint'),
        <String, dynamic>{
          'id': 'chip',
          'kind': 'agent-event',
          'taskEvent': true,
          'event': <String, dynamic>{
            'type': 'message',
            'message': 'Running tests',
          },
        },
      ]);
      expect(items.length, 2);
    });

    test('flags a completion card body as redundant, keeps the card', () {
      final items = build([
        bash('mise run server:lint 2>&1 | tail -15'),
        <String, dynamic>{
          'id': 'done',
          'kind': 'text',
          'role': 'agent',
          'taskEvent': true,
          'taskStatus': 'completed',
          'taskType': 'local_bash',
          'content': 'mise run server:lint 2>&1 | tail -15',
        },
      ]);
      expect(items.length, 2);
      expect(items[1]?['redundantSummary'], isTrue);
      // Source message is not mutated.
      expect(items[1]?['id'], 'done');
    });
  });
}
